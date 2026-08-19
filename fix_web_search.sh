#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Locate where tools/actions are defined ==="
grep -rln "def web_fetch\|\"web_fetch\"\|'web_fetch'" --include="*.py" agent/ . 2>/dev/null | sort -u

echo ""
echo "=== Create a real search tool backed by DuckDuckGo HTML (Google blocks scraping) ==="
cat > agent/web_search_tool.py << 'PYEOF'
"""
Real web search backed by DuckDuckGo's HTML endpoint (no API key required).
Google's search results page blocks direct scraping, which is why any
web_fetch(google.com/search?q=...) call fails every time.
"""
import re
import html
import urllib.parse
import requests

DDG_HTML_URL = "https://html.duckduckgo.com/html/"

def web_search(query: str, num_results: int = 5):
    """Returns a list of {title, url, snippet} dicts for the query."""
    resp = requests.post(
        DDG_HTML_URL,
        data={"q": query},
        headers={"User-Agent": "Mozilla/5.0 (OmegaAgent)"},
        timeout=15,
    )
    resp.raise_for_status()
    body = resp.text

    results = []
    for m in re.finditer(
        r'<a rel="nofollow" class="result__a" href="(.*?)">(.*?)</a>.*?'
        r'class="result__snippet">(.*?)</a>',
        body,
        re.DOTALL,
    ):
        raw_url, raw_title, raw_snippet = m.groups()
        url = urllib.parse.unquote(raw_url.split("uddg=")[-1].split("&")[0])
        title = html.unescape(re.sub("<.*?>", "", raw_title)).strip()
        snippet = html.unescape(re.sub("<.*?>", "", raw_snippet)).strip()
        results.append({"title": title, "url": url, "snippet": snippet})
        if len(results) >= num_results:
            break
    return results
PYEOF

echo ""
echo "=== Syntax check ==="
python3 -m py_compile agent/web_search_tool.py && echo "OK: compiles"

echo ""
echo "=== Auto-wire the import into agent_loop.py ==="
python3 - << 'PYEOF'
path = "agent/agent_loop.py"
with open(path) as f:
    content = f.read()

if "from agent.web_search_tool import web_search" not in content:
    lines = content.split("\n")
    insert_at = 0
    for i, line in enumerate(lines[:40]):
        if line.startswith("import ") or line.startswith("from "):
            insert_at = i + 1
    lines.insert(insert_at, "from agent.web_search_tool import web_search")
    content = "\n".join(lines)
    with open(path, "w") as f:
        f.write(content)
    print("Inserted import for web_search")
else:
    print("Import already present, skipping")
PYEOF

echo ""
echo "=== Show where web_fetch is registered as a tool (for the manual step below) ==="
grep -n "web_fetch" --include="*.py" -r agent/ | grep -i "prompt\|description\|tool\|name" | head -20

echo ""
echo "=== MANUAL STEP (required — tool schema shape varies too much to patch blindly) ==="
echo "1. In agent/agent_loop.py, wherever the 'web_fetch' tool schema is defined"
echo "   for the model, add a sibling entry:"
echo '     {"name": "web_search", "description": "Search the web via DuckDuckGo. Use this instead of fetching google.com/search directly — that is always blocked."}'
echo "2. In the tool dispatcher (wherever tool_name == \"web_fetch\" is handled), add:"
echo '     elif tool_name == "web_search":'
echo '         result = web_search(tool_args["query"])'
echo "3. In the system prompt text, add: 'Never call web_fetch on google.com/search — use the web_search tool instead.'"

echo ""
echo "=== Commit and push what's automated ==="
git add agent/web_search_tool.py agent/agent_loop.py
git status
git commit -m "feat: add DuckDuckGo-backed web_search tool (google.com/search was always blocked)"
git push origin main
