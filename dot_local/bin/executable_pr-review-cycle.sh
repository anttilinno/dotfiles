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

# Iterate PRs. Each PR is reviewed by its own `claude -p` process (launched via
# `wt switch -x`), so Claude context is cleared between PRs by construction.
FAILED=()
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
  if "$WT_BIN" -C "$CLONE" switch "pr:$NUM" -y --cd \
        -x "claude -p --model $MODEL --permission-mode bypassPermissions" \
        -- "/mihhal-review $NUM" </dev/null; then
    echo ">> Done with #$NUM."
  else
    echo "!! review failed for $SLUG#$NUM (exit $?)." >&2
    FAILED+=("$SLUG#$NUM")
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
