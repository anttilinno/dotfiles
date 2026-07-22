#!/usr/bin/env bash
#
# pr-review-cycle.sh
#
# Run the `code-review` Claude Code skill on every open PR assigned to you
# (https://github.com/pulls/assigned), one PR at a time, with a FRESH Claude
# context per PR (each PR = its own `claude -p` process, launched by `wt`).
#
# Each PR is checked out into its own git worktree via `wt switch pr:N`
# (worktrunk). The worktree shares the base clone's object store, so it is
# cheap and never disturbs any primary working tree. Claude is launched
# inside the worktree with `wt switch -x`, so the code-review skill reads
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
#   -d, --drafts         Review your own DRAFT PRs (--author=@me --draft)
#                        instead of open PRs assigned to you.
#   -l, --limit N        Max number of PRs to fetch (default 50).
#   -m, --model NAME     Claude model alias (default: opus).
#       --cache DIR      Base-clone cache dir (default: ~/.cache/pr-review-cycle).
#   -h, --help           Show this help.
#
# Requires: gh (authenticated), git, claude, wt (worktrunk), jq.

set -euo pipefail

DRY_RUN=0
DRAFTS=0
LIMIT=50
MODEL="opus"
CACHE_DIR="${HOME}/.cache/pr-review-cycle"
WT_BIN="${WORKTRUNK_BIN:-/usr/bin/wt}"   # call the binary directly, not the shell function

usage() { sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -d|--drafts)  DRAFTS=1; shift ;;
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

if [[ "$DRAFTS" -eq 1 ]]; then
  echo ">> Fetching your open DRAFT PRs..."
  PRS_JSON="$(gh search prs --author=@me --state=open --draft --limit "$LIMIT" \
    --json number,title,url,repository)"
else
  echo ">> Fetching open PRs assigned to you..."
  PRS_JSON="$(gh search prs --assignee=@me --state=open --limit "$LIMIT" \
    --json number,title,url,repository)"
fi

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
declare -a SUMMARY_PR SUMMARY_TITLE SUMMARY_STATUS SUMMARY_OUTCOME

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
  # OUTCOME sits between STATUS and TITLE (short cols grouped left).
  local h1="PR" h2="STATUS" h4="OUTCOME" h3="TITLE" i
  local w1=${#h1} w2=${#h2} w4=${#h4} w3=${#h3}
  for i in "${!SUMMARY_PR[@]}"; do
    (( ${#SUMMARY_PR[i]}      > w1 )) && w1=${#SUMMARY_PR[i]}
    (( ${#SUMMARY_STATUS[i]}  > w2 )) && w2=${#SUMMARY_STATUS[i]}
    (( ${#SUMMARY_OUTCOME[i]} > w4 )) && w4=${#SUMMARY_OUTCOME[i]}
    (( ${#SUMMARY_TITLE[i]}   > w3 )) && w3=${#SUMMARY_TITLE[i]}
  done

  local V="${CYN}│${R}"
  seg() { printf '─%.0s' $(seq 1 "$1"); }
  local s1 s2 s4 s3
  s1=$(seg $((w1+2))); s2=$(seg $((w2+2))); s4=$(seg $((w4+2))); s3=$(seg $((w3+2)))

  printf '   %s┌%s┬%s┬%s┬%s┐%s\n' "$CYN" "$s1" "$s2" "$s4" "$s3" "$R"
  printf '   %s %s%-*s%s %s %s%-*s%s %s %s%-*s%s %s %s%-*s%s %s\n' \
    "$V" "$BOLD" "$w1" "$h1" "$R" "$V" "$BOLD" "$w2" "$h2" "$R" \
    "$V" "$BOLD" "$w4" "$h4" "$R" "$V" "$BOLD" "$w3" "$h3" "$R" "$V"
  printf '   %s├%s┼%s┼%s┼%s┤%s\n' "$CYN" "$s1" "$s2" "$s4" "$s3" "$R"
  for i in "${!SUMMARY_PR[@]}"; do
    local st="${SUMMARY_STATUS[i]}" c
    case "$st" in
      approved)  c=$GRN ;;
      rejected)  c=$RED ;;
      commented) c=$YLW ;;
      *)         c=$DIM ;;
    esac
    # Outcome coloured by its leading glyph: ✓ ready (green), ✗ failed/rejected
    # (red), ● action-needed (yellow).
    local oc="${SUMMARY_OUTCOME[i]}" oc_c
    case "$oc" in
      "✓"*) oc_c=$GRN ;;
      "✗"*) oc_c=$RED ;;
      *)    oc_c=$YLW ;;
    esac
    # Status/outcome cells padded manually: %-*s would miscount the colour escapes.
    local pad=$(( w2 - ${#st} )) padoc=$(( w4 - ${#oc} ))
    printf '   %s %-*s %s %s%s%s%*s %s %s%s%s%*s %s %-*s %s\n' \
      "$V" "$w1" "${SUMMARY_PR[i]}" \
      "$V" "$c" "$st" "$R" "$pad" "" \
      "$V" "$oc_c" "$oc" "$R" "$padoc" "" \
      "$V" "$w3" "${SUMMARY_TITLE[i]}" "$V"
  done
  printf '   %s└%s┴%s┴%s┴%s┘%s\n' "$CYN" "$s1" "$s2" "$s4" "$s3" "$R"
}
trap print_summary EXIT

# Count inline comments attached to a specific review (own-PR finding count).
review_findings() {
  local slug="$1" num="$2" rid="$3"
  [[ -z "$rid" ]] && { echo 0; return; }
  gh api "repos/$slug/pulls/$num/reviews/$rid/comments" --jq 'length' 2>/dev/null || echo 0
}

# Merge-readiness verdict from the raw review state. For own PRs GitHub forbids
# APPROVE, so a COMMENTED review with 0 inline findings is the clean/ready
# signal; with findings it needs a fix pass. Failed rows pass status="failed".
compute_outcome() {
  local st="$1" slug="$2" num="$3" rid="$4" n
  case "$st" in
    approved) echo "✓ ready to merge" ;;
    rejected) echo "✗ changes needed" ;;
    commented)
      if [[ "$DRAFTS" -eq 1 ]]; then
        n="$(review_findings "$slug" "$num" "$rid")"
        (( n == 0 )) && echo "✓ ready to merge" || echo "● fix findings ($n)"
      else
        echo "● needs decision"
      fi
      ;;
    *) echo "✗ failed" ;;
  esac
}

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

  # Skip PRs already reviewed at the current head. Compare my latest review's
  # commit_id against the PR head SHA: exact, unlike a commit-date proxy (rebase
  # / squash rewrite SHAs but not dates). --paginate avoids missing a later
  # review past the first 30-result page; gh merges the pages into one array.
  REVIEWS="$(gh api "repos/$SLUG/pulls/$NUM/reviews" --paginate 2>/dev/null || echo '[]')"
  REVIEWED_SHA="$(jq -r "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .commit_id // \"\"" <<<"${REVIEWS:-[]}")"
  PULL="$(gh api "repos/$SLUG/pulls/$NUM" 2>/dev/null || echo '{}')"
  HEAD_SHA="$(jq -r '.head.sha // ""' <<<"$PULL")"
  # GitHub drops me from requested_reviewers once I submit a review, so being
  # back on the list means an explicit re-review request landed after it — must
  # re-review even when the head is unchanged (e.g. findings now resolved).
  RE_REQUESTED="$(jq -r --arg me "$MY_LOGIN" '[.requested_reviewers[]?.login] | index($me) // empty' <<<"$PULL")"
  if [[ -z "$RE_REQUESTED" && -n "$REVIEWED_SHA" && -n "$HEAD_SHA" && "$REVIEWED_SHA" == "$HEAD_SHA" ]]; then
    echo ">> Already reviewed #$NUM at $REVIEWED_SHA (PR head unchanged, no re-request); skipping."
    case "$(jq -r "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .state" <<<"${REVIEWS:-[]}")" in
      APPROVED)          STATUS="approved" ;;
      CHANGES_REQUESTED) STATUS="rejected" ;;
      COMMENTED)         STATUS="commented" ;;
      *)                 STATUS="no review" ;;
    esac
    RID="$(jq -r "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .id // \"\"" <<<"${REVIEWS:-[]}")"
    SUMMARY_PR+=("$SLUG#$NUM"); SUMMARY_TITLE+=("$TITLE"); SUMMARY_STATUS+=("$STATUS")
    SUMMARY_OUTCOME+=("$(compute_outcome "$STATUS" "$SLUG" "$NUM" "$RID")")
    continue
  fi

  # My latest review id BEFORE the run (from the pre-run snapshot above). The
  # safety net below requires this to change — a stale prior review must not
  # mask a silent phase-6 skip. Empty when I have not reviewed this PR yet.
  REVIEW_ID_BEFORE="$(jq -r "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .id // \"\"" <<<"${REVIEWS:-[]}")"

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
  echo ">> Worktree + code-review (fresh Claude context)..."
  STATUS="error"
  ROW_FAILED=0
  # The trailing directive is load-bearing: headless `claude -p` otherwise
  # prints the verdict and exits WITHOUT posting when the outcome is APPROVE,
  # leaving the PR with no review event (mapped to "no review" below).
  # Draft mode reviews your OWN PRs, where GitHub forbids APPROVE/REQUEST_CHANGES
  # ("can not approve your own pull request") — so require a COMMENTED review with
  # any findings as inline comments, and never approve.
  if [[ "$DRAFTS" -eq 1 ]]; then
    DIRECTIVE="/code-review $NUM -- IMPORTANT: this is my own PR; do NOT approve or request changes. You MUST submit a COMMENTED GitHub PR review via gh before finishing (post any findings as inline comments; an empty-body COMMENTED review if none). Printing the verdict is not enough."
  else
    DIRECTIVE="/code-review $NUM -- IMPORTANT: you MUST submit the GitHub PR review via gh before finishing, even on APPROVE. Printing the verdict is not enough."
  fi
  if "$WT_BIN" -C "$CLONE" switch "pr:$NUM" -y --cd \
        -x "claude -p --model $MODEL --permission-mode bypassPermissions" \
        -- "$DIRECTIVE" </dev/null; then
    echo ">> Done with #$NUM."
    # Map my latest review on this PR to a human-friendly outcome.
    REVIEWS_AFTER="$(gh api "repos/$SLUG/pulls/$NUM/reviews" --paginate 2>/dev/null || echo '[]')"
    REVIEW_ID_AFTER="$(jq -r "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .id // \"\"" <<<"${REVIEWS_AFTER:-[]}")"
    case "$(jq -r "[.[] | select(.user.login==\"$MY_LOGIN\")] | last | .state" <<<"${REVIEWS_AFTER:-[]}")" in
      APPROVED)          STATUS="approved" ;;
      CHANGES_REQUESTED) STATUS="rejected" ;;
      COMMENTED)         STATUS="commented" ;;
      *)                 STATUS="no review" ;;
    esac
    # Safety net: require a NEW review of mine since before the run. Checking
    # STATUS alone is not enough — a stale prior review (approved/rejected/
    # commented) would mask a silent phase-6 skip. Compare review ids and fail
    # loudly so the PR is retried rather than read as freshly reviewed.
    if [[ -z "$REVIEW_ID_AFTER" || "$REVIEW_ID_AFTER" == "$REVIEW_ID_BEFORE" ]]; then
      echo "!! #$NUM: claude exited 0 but posted no new review (phase 6 skipped)." >&2
      FAILED+=("$SLUG#$NUM"); ROW_FAILED=1
    # The skill posts only APPROVE or REQUEST_CHANGES; a COMMENTED review means
    # it invented a comment-only "approve-with-comments" verdict (skipping the
    # binary event), so the PR has no real approve/reject decision — flag it.
    # In draft mode COMMENTED is the ONLY valid outcome (own PR), so don't flag.
    elif [[ "$DRAFTS" -ne 1 && "$STATUS" == "commented" ]]; then
      echo "!! #$NUM: posted a COMMENTED review (skill must emit APPROVE or REQUEST_CHANGES)." >&2
      FAILED+=("$SLUG#$NUM"); ROW_FAILED=1
    fi
  else
    echo "!! review failed for $SLUG#$NUM (exit $?)." >&2
    FAILED+=("$SLUG#$NUM"); ROW_FAILED=1
  fi

  SUMMARY_PR+=("$SLUG#$NUM")
  SUMMARY_TITLE+=("$TITLE")
  SUMMARY_STATUS+=("$STATUS")
  if [[ "$ROW_FAILED" -eq 1 ]]; then
    SUMMARY_OUTCOME+=("✗ failed")
  else
    SUMMARY_OUTCOME+=("$(compute_outcome "$STATUS" "$SLUG" "$NUM" "$REVIEW_ID_AFTER")")
  fi
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
