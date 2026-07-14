# Check network: can we reach github?
if ! curl --silent --max-time 5 --head https://github.com > /dev/null 2>&1; then
  echo "jj-git-fetch: github unreachable, skipping" | systemd-cat -t jj-git-fetch -p info
  exit 0
fi

repos=$(fd --type d --hidden --no-ignore '^\.jj$' "$HOME/dev" 2>/dev/null | while read -r jjdir; do
  dirname "$jjdir"
done)

if [ -z "$repos" ]; then
  echo "jj-git-fetch: no jj repos found under $HOME/dev" | systemd-cat -t jj-git-fetch -p info
  exit 0
fi

failed=0
while IFS= read -r repo; do
  # Skip local-only repos: `jj git fetch` errors with "No git remotes to
  # fetch from" when a repo has no configured remote, which is an expected
  # state (not a failure worth alerting on). Guarding here keeps the timer
  # green so a real fetch failure still stands out.
  if [ -z "$(jj --repository "$repo" git remote list 2>/dev/null)" ]; then
    echo "jj-git-fetch: skipping $repo (no remotes)" | systemd-cat -t jj-git-fetch -p info
    continue
  fi

  echo "jj-git-fetch: fetching $repo" | systemd-cat -t jj-git-fetch -p info
  if ! jj --repository "$repo" git fetch --all-remotes 2>&1 | \
      systemd-cat -t jj-git-fetch -p info; then
    echo "jj-git-fetch: FAILED for $repo" | systemd-cat -t jj-git-fetch -p err
    failed=1
  fi
done <<< "$repos"

exit $failed
