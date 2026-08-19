#!/data/data/com.termux/files/usr/bin/bash
set -x
set -e

REPO=~/omega-agent-v2
cd "$REPO"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Confirm local main matches known-good origin (tommyleeharvey) state ==="
git fetch origin
git checkout main
git reset --hard origin/main
git log --oneline -3

echo ""
echo "=== Ensure a remote exists for cipherxsniper v1 (omega-agent, different repo name) ==="
git remote | grep -q '^cipherxsniper-v1$' || git remote add cipherxsniper-v1 https://github.com/cipherxsniper/omega-agent.git
git remote -v

for target in cipherxsniper cipherxsniper-v1; do
  echo ""
  echo "=== Backing up + syncing remote: $target ==="
  git fetch "$target"

  REMOTE_MAIN="$target/main"
  if ! git rev-parse --verify "$REMOTE_MAIN" >/dev/null 2>&1; then
    echo "No 'main' branch on $target, trying 'master'"
    REMOTE_MAIN="$target/master"
  fi

  BACKUP_BRANCH="backup/pre-sync-$TIMESTAMP"
  echo "--- Preserving $target's CURRENT code as $BACKUP_BRANCH, pushed back to $target itself (nothing lost, recoverable anytime) ---"
  git branch -f "$BACKUP_BRANCH" "$REMOTE_MAIN"
  git push "$target" "$BACKUP_BRANCH":"$BACKUP_BRANCH"

  echo "--- Force-syncing $target's main to tommyleeharvey's known-good main ---"
  git push "$target" main:main --force

  echo "--- Confirm $target now matches local main ---"
  git fetch "$target"
  git log --oneline -1 "$target/main"
done

echo ""
echo "=== Push should auto-trigger each repo's own deploy.yml on push-to-main. Also try a manual dispatch as backup (will 401 harmlessly if GITHUB_TOKEN isn't set) ==="
for repo in cipherxsniper/omega-agent-v2 cipherxsniper/omega-agent; do
  WORKFLOW_ID=$(curl -s "https://api.github.com/repos/$repo/actions/workflows" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for wf in d.get('workflows', []):
    if wf['name'] == 'deploy':
        print(wf['id'])
")
  echo "$repo deploy workflow id: $WORKFLOW_ID"
  curl -s -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: token ${GITHUB_TOKEN:-}" \
    "https://api.github.com/repos/$repo/actions/workflows/$WORKFLOW_ID/dispatches" \
    -d '{"ref":"main"}'
  echo ""
done

echo ""
echo "=== DONE ==="
echo "Both cipherxsniper repos now mirror tommyleeharvey/omega-agent-v2's main exactly."
echo "Each repo's PRE-SYNC state is safe on branch: backup/pre-sync-$TIMESTAMP"
echo "Use that branch later to cherry-pick the mission-graph/swarm-intelligence commits into the now-synced codebase."
