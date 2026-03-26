# statusLine settings attrset for Claude Code.
# Called as: import ./statusline.nix pkgs
pkgs: {
  type = "command";
  command = "${pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [pkgs.jq];
    text = ''
      input=$(cat)

      dir=$(basename "$(echo "$input" | jq -r '.workspace.current_dir // .cwd')")
      model=$(echo "$input" | jq -r '.model.display_name // empty')
      used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
      five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
      seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

      # Returns a colour-coded "label:N%" string based on thresholds.
      # Usage: colorize_pct <label> <float_value>
      colorize_pct() {
        local label=$1
        local val=$2
        local n
        n=$(printf '%.0f' "$val")
        if [ "$n" -ge 80 ]; then
          printf '\033[31m%s:%d%%\033[0m' "$label" "$n"
        elif [ "$n" -ge 50 ]; then
          printf '\033[33m%s:%d%%\033[0m' "$label" "$n"
        else
          printf '%s:%d%%' "$label" "$n"
        fi
      }

      parts=()
      [ -n "$dir" ] && parts+=("$dir")
      [ -n "$model" ] && parts+=("$model")

      # Context window % — how full this conversation's context is
      [ -n "$used" ] && parts+=("$(colorize_pct ctx "$used")")

      # Plan rate-limit usage (absent until first API response)
      [ -n "$five_hr" ] && parts+=("$(colorize_pct 5h "$five_hr")")
      [ -n "$seven_day" ] && parts+=("$(colorize_pct 7d "$seven_day")")

      result=""
      for part in "''${parts[@]}"; do
        [ -n "$result" ] && result="$result | "
        result="$result$part"
      done
      [ -n "$result" ] && printf '%s' "$result"
    '';
  }}/bin/claude-statusline";
}
