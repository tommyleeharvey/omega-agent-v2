#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== tommyleeharvey/omega-agent-v2 live site ==="
curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" https://tommyleeharvey.github.io/omega-agent-v2/

echo ""
echo "=== cipherxsniper/omega-agent (v1) live site ==="
curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" https://cipherxsniper.github.io/omega-agent/

echo ""
echo "=== cipherxsniper/omega-agent-v2 live site (in case this is the one actually serving) ==="
curl -s -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" https://cipherxsniper.github.io/omega-agent-v2/

echo ""
echo "=== tommyleeharvey/omega-agent-v2 deploy workflow: latest runs ==="
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=5" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_branch'], '-', r['head_sha'][:8])
"

echo ""
echo "=== cipherxsniper/omega-agent-v2: does it have its own deploy workflow? ==="
curl -s "https://api.github.com/repos/cipherxsniper/omega-agent-v2/actions/workflows" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for wf in d.get('workflows', []):
    print(wf['id'], '-', wf['name'], '-', wf['state'])
"

echo ""
echo "=== cipherxsniper/omega-agent: does it have its own deploy workflow? ==="
curl -s "https://api.github.com/repos/cipherxsniper/omega-agent/actions/workflows" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for wf in d.get('workflows', []):
    print(wf['id'], '-', wf['name'], '-', wf['state'])
"

echo ""
echo "=== Pages config for each repo (source branch/path, custom domain, build type) ==="
for repo in tommyleeharvey/omega-agent-v2 cipherxsniper/omega-agent cipherxsniper/omega-agent-v2; do
  echo "--- $repo ---"
  curl -s "https://api.github.com/repos/$repo/pages" | python3 -m json.tool
done
