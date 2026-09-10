#!/usr/bin/env bash
# Claude Code statusline: dir, git branch, worktree, model + effort, context
# usage, plan rate limits, prompt-cache health, plus caveman/ponytail badges.
# Renders in its own row above the built-in footer badges.
# Badge scripts stay in ~/.claude/hooks — they are vendored by the caveman and
# ponytail plugins, not by this repo.
h="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"

# One field per line — display names contain spaces, so don't word-split.
# "" marks an absent string, -1 an absent number: jq's // keeps 0 intact.
mapfile -t f < <(jq -r '
  .workspace.current_dir // .cwd // "",
  .model.display_name // "",
  (.context_window.used_percentage // 0 | floor),
  (.context_window.context_window_size // 0),
  .effort.level // "",
  (.fast_mode // false),
  .workspace.git_worktree // "",
  (.rate_limits.five_hour.used_percentage // -1 | floor),
  (.rate_limits.five_hour.resets_at // -1),
  (.rate_limits.seven_day.used_percentage // -1 | floor),
  (.prompt_cache.hit_ratio // -1),
  (.prompt_cache.warm // false)
')
cwd=${f[0]} model=${f[1]} ctx=${f[2]} ctxmax=${f[3]} effort=${f[4]} fast=${f[5]}
wt=${f[6]} rl5=${f[7]} rl5at=${f[8]} rl7=${f[9]} cache=${f[10]} warm=${f[11]}

# green under 60%, yellow under 80%, red above — shared by context and limits.
heat() { if   [ "$1" -ge 80 ]; then printf 196
         elif [ "$1" -ge 60 ]; then printf 214
         else                       printf 71; fi; }

# 4500 -> 1h15m, 2700 -> 45m. Sub-minute reads as 0m rather than empty.
countdown() {
  local s=$(( $1 - $(date +%s) ))
  [ "$s" -le 0 ] && { printf 'now'; return; }
  if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s/3600)) $((s%3600/60))
  else                       printf '%dm' $((s/60)); fi
}

dir="${cwd/#$HOME/\~}"
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

printf '\033[38;5;110m%s\033[0m' "$dir"
[ -n "$branch" ] && printf ' \033[38;5;245m%s\033[0m' "$branch"
[ -n "$wt" ]     && printf ' \033[38;5;140m⑂%s\033[0m' "$wt"

# model, with effort and a bolt when fast mode is on
printf ' \033[38;5;245m| %s\033[0m' "$model"
[ -n "$effort" ]     && printf '\033[38;5;245m/%s\033[0m' "$effort"
[ "$fast" = true ]   && printf '\033[38;5;220m⚡\033[0m'

# context, tagged 1M so the extended window is visible at a glance
printf ' \033[38;5;245m|\033[0m \033[38;5;%sm%s%%\033[0m' "$(heat "$ctx")" "$ctx"
[ "$ctxmax" -ge 1000000 ] && printf '\033[38;5;245m(1M)\033[0m'

# plan usage: the 5h window carries a reset countdown, the 7d one does not
if [ "$rl5" -ge 0 ]; then
  printf ' \033[38;5;245m| 5h\033[0m \033[38;5;%sm%s%%\033[0m' "$(heat "$rl5")" "$rl5"
  [ "$rl5at" -gt 0 ] && printf '\033[38;5;245m→%s\033[0m' "$(countdown "$rl5at")"
fi
[ "$rl7" -ge 0 ] && printf ' \033[38;5;245m· 7d\033[0m \033[38;5;%sm%s%%\033[0m' "$(heat "$rl7")" "$rl7"

# cache: hit ratio once warm, an explicit cold marker before that
if [ "$warm" = true ] && [ "${cache%%.*}" != "-1" ]; then
  printf ' \033[38;5;245m| ⚡%.0f%%\033[0m' "$(awk "BEGIN{print $cache*100}")"
elif [ "$cache" != "-1" ]; then
  printf ' \033[38;5;245m| cold\033[0m'
fi

# Mode badges. Each script prints nothing when its mode is inactive.
for s in caveman-statusline.sh ponytail-statusline.sh; do
  badge=$(bash "$h/$s" 2>/dev/null)
  [ -n "$badge" ] && printf ' %s' "$badge"
done
