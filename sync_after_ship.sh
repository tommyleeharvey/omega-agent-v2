#!/data/data/com.termux/files/usr/bin/bash
set -x
set -e

REPO=~/omega-agent-v2
cd "$REPO"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Confirm local main matches known-good origin (tommyleeharvey) ==="
git fetch origin
git checkout main
git reset --hard origin/main
git log --oneline -3

for target in cipherxsniper cipherxsniper-v1; do
  echo ""
  echo "=== Backing up + syncing remote: $target ==="
  git fetch "$target"

  REMOTE_MAIN="$target/main"
  if ! git rev-parse --verify "$REMOTE_MAIN" >/dev/null 2>&1; then
    REMOTE_MAIN="$target/master"
  fi

  BACKUP_BRANCH="backup/pre-sync-$TIMESTAMP"
  git branch -f "$BACKUP_BRANCH" "$REMOTE_MAIN"
  git push "$target" "$BACKUP_BRANCH":"$BACKUP_BRANCH"

  echo "--- Force-syncing $target's main to tommyleeharvey's known-good main ---"
  git push "$target" main:main --force

  git fetch "$target"
  git log --oneline -1 "$target/main"
done

echo ""
echo "=== Confirm all three GitHub Pages sites are serving and reachable ==="
for url in \
  https://tommyleeharvey.github.io/omega-agent-v2/ \
  https://cipherxsniper.github.io/omega-agent-v2/ \
  https://cipherxsniper.github.io/omega-agent/ ; do
  echo "--- $url ---"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" "$url"
done

echo ""
echo "=== DONE — all three should now match tommyleeharvey/omega-agent-v2's main exactly ==="
echo "Pre-sync state for each is safe on: backup/pre-sync-$TIMESTAMP"
