#!/usr/bin/env bash
#
# pr-review-cycle.sh
#
# Run the `mihhal-review` Claude Code skill on every open PR assigned to you
# (https://github.com/pulls/assigned), one PR at a time, with a FRESH Claude
# context per PR (each PR = its own `claude -p` process, launched by `wt`).
#
# Each PR is checked out into its own git worktree via `wt switch pr:N`
# (worktrunk). The worktree shares the base clone's object store, so it is
# cheap and never disturbs any primary working tree. Claude is launched
# inside the worktree with `wt switch -x`, so the mihhal-review skill reads
# the real PR diff/files locally.
#
# The skill itself decides the outcome and posts the review:
#   - no surviving HIGH/MEDIUM findings -> APPROVE (no comments)
#   - any HIGH/MEDIUM finding remains    -> REQUEST_CHANGES + inline comments
#
# Usage:
#   pr-review-cycle.sh [options]
#
# Options:
#   -n, --dry-run        List the PRs that would be reviewed, then exit.
#   -l, --limit N        Max number of PRs to fetch (default 50).
#   -m, --model NAME     Claude model alias (default: opus).
#       --cache DIR      Base-clone cache dir (default: ~/.cache/pr-review-cycle).
#   -h, --help           Show this help.
#
# Requires: gh (authenticated), git, claude, wt (worktrunk), jq.

set -euo pipefail

DRY_RUN=0
LIMIT=50
MODEL="opus"
CACHE_DIR="${HOME}/.cache/pr-review-cycle"
WT_BIN="${WORKTRUNK_BIN:-/usr/bin/wt}"   # call the binary directly, not the shell function

usage() { sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -l|--limit)   LIMIT="$2"; shift 2 ;;
    -m|--model)   MODEL="$2"; shift 2 ;;
    --cache)      CACHE_DIR="$2"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

for bin in gh git claude jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Missing required tool: $bin" >&2; exit 1; }
done
[[ -x "$WT_BIN" ]] || { echo "Missing wt binary: $WT_BIN (set WORKTRUNK_BIN)" >&2; exit 1; }

echo ">> Fetching open PRs assigned to you..."
PRS_JSON="$(gh search prs --assignee=@me --state=open --limit "$LIMIT" \
  --json number,title,url,repository)"

COUNT="$(jq 'length' <<<"$PRS_JSON")"
if [[ "$COUNT" -eq 0 ]]; then
  echo "No open PRs assigned to you. Nothing to do."
  exit 0
fi

echo ">> $COUNT PR(s) assigned:"
jq -r '.[] | "   #\(.number)  \(.repository.nameWithOwner)  \(.title)"' <<<"$PRS_JSON"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ">> Dry run; exiting without reviewing."
  exit 0
fi

mkdir -p "$CACHE_DIR"

# Login used to pick out my own review when summarising outcomes below.
MY_LOGIN="$(gh api user --jq .login)"

# Iterate PRs. Each PR is reviewed by its own `claude -p` process (launched via
# `wt switch -x`), so Claude context is cleared between PRs by construction.
FAILED=()
# Parallel arrays: one row per PR for the final overview table.
declare -a SUMMARY_PR SUMMARY_TITLE SUMMARY_STATUS

# Print the overview from an EXIT trap so it always shows, even if the cycle is
# cut short (set -e/pipefail abort mid-loop, claude killed via Ctrl-C, etc.).
# Without this the table only printed when every prior command succeeded.
print_summary() {
  echo
  echo ">> Reviewed PR overview:"
  if [[ ${#SUMMARY_PR[@]} -eq 0 ]]; then
    echo "   (no PRs processed)"
    return
  fi

  # Colors only on a real terminal (skip when piped/redirected).
  local R='' BOLD='' GRN='' RED='' YLW='' DIM='' CYN=''
  if [[ -t 1 ]]; then
    R=$'\e[0m'; BOLD=$'\e[1m'; CYN=$'\e[36m'
    GRN=$'\e[32m'; RED=$'\e[31m'; YLW=$'\e[33m'; DIM=$'\e[2m'
  fi

  # Column widths from header + data (plain text; color codes add no width).
  local h1="PR" h2="STATUS" h3="TITLE" i
  local w1=${#h1} w2=${#h2} w3=${#h3}
  for i in "${!SUMMARY_PR[@]}"; do
    (( ${#SUMMARY_PR[i]}     > w1 )) && w1=${#SUMMARY_PR[i]}
    (( ${#SUMMARY_STATUS[i]} > w2 )) && w2=${#SUMMARY_STATUS[i]}
    (( ${#SUMMARY_TITLE[i]}  > w3 )) && w3=${#SUMMARY_TITLE[i]}
  done

  local V="${CYN}│${R}"
  seg() { printf '─%.0s' $(seq 1 "$1"); }
  local s1 s2 s3
  s1=$(seg $((w1+2))); s2=$(seg $((w2+2))); s3=$(seg $((w3+2)))

  printf '   %s┌%s┬%s┬%s┐%s\n' "$CYN" "$s1" "$s2" "$s3" "$R"
  printf '   %s %s%-*s%s %s %s%-*s%s %s %s%-*s%s %s\n' \
    "$V" "$BOLD" "$w1" "$h1" "$R" "$V" "$BOLD" "$w2" "$h2" "$R" "$V" "$BOLD" "$w3" "$h3" "$R" "$V"
  printf '   %s├%s┼%s┼%s┤%s\n' "$CYN" "$s1" "$s2" "$s3" "$R"
  for i in "${!SUMMARY_PR[@]}"; do
    local st="${SUMMARY_STATUS[i]}" c
    case "$st" in
      approved)  c=$GRN ;;
      rejected)  c=$RED ;;
      commented) c=$YLW ;;
      *)         c=$DIM ;;
    esac
    # Status cell padded manually: %-*s would miscount the color escapes.
    local pad=$(( w2 - ${#st} ))
    printf '   %s %-*s %s %s%s%s%*s %s %-*s %s\n' \
      "$V" "$w1" "${SUMMARY_PR[i]}" \
      "$V" "$c" "$st" "$R" "$pad" "" \
      "$V" "$w3" "${SUMMARY_TITLE[i]}" "$V"
  done
  printf '   %s└%s┴%s┴%s┘%s\n' "$CYN" "$s1" "$s2" "$s3" "$R"
}
trap print_summary EXIT
# Read PR rows on FD 3 (not stdin): claude -p inside the loop reads stdin, and
# if the loop fed it via stdin it would drain the remaining rows and only the
# first PR would ever be reviewed.
while IFS=$'\t' read -r -u 3 NUM SLUG URL TITLE; do
  echo
  echo "============================================================"
  echo ">> Reviewing #$NUM  $SLUG"
  echo "   $TITLE"
  echo "   $URL"
  echo "============================================================"

  # wt needs a base clone (with the gh remote) to resolve pr:N and base the
  # worktree on. Clone once per repo, reuse across runs.
  CLONE="$CACHE_DIR/$SLUG"
  if [[ -d "$CLONE/.git" ]]; then
    echo ">> Updating base clone: $CLONE"
    git -C "$CLONE" fetch --quiet origin || true
  else
    echo ">> Cloning $SLUG -> $CLONE"
    gh repo clone "$SLUG" "$CLONE" -- --quiet
  fi

  # Create/reuse the PR worktree and launch a fresh Claude inside it.
  # -x execs claude in the worktree cwd; --cd ensures the worktree is the cwd.
  echo ">> Worktree + mihhal-review (fresh Claude context)..."
  STATUS="error"
  if "$WT_BIN" -C "$CLONE" switch "pr:$NUM" -y --cd \
        -x "claude -p --model $MODEL --permission-mode bypassPermissions" \
        -- "/mihhal-review $NUM" </dev/null; then
    echo ">> Done with #$NUM."
    # Map my latest review on this PR to a human-friendly outcome.
    case "$(gh api "repos/$SLUG/pulls/$NUM/reviews" \
              --jq "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .state" \
              2>/dev/null)" in
      APPROVED)          STATUS="approved" ;;
      CHANGES_REQUESTED) STATUS="rejected" ;;
      COMMENTED)         STATUS="commented" ;;
      *)                 STATUS="no review" ;;
    esac
  else
    echo "!! review failed for $SLUG#$NUM (exit $?)." >&2
    FAILED+=("$SLUG#$NUM")
  fi

  SUMMARY_PR+=("$SLUG#$NUM")
  SUMMARY_TITLE+=("$TITLE")
  SUMMARY_STATUS+=("$STATUS")
done 3< <(jq -r '.[] | [.number, .repository.nameWithOwner, .url, .title] | @tsv' <<<"$PRS_JSON")

echo
echo ">> Cycle complete."
echo "   Worktrees kept under each base clone (reused next run)."
echo "   Inspect/clean: wt -C \"$CACHE_DIR/<owner>/<repo>\" list   |   wt ... remove"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "!! ${#FAILED[@]} PR(s) failed:"
  printf '   %s\n' "${FAILED[@]}"
  exit 1
fi
