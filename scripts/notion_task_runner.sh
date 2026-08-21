#!/bin/bash
# Polls the Enthasys Tasks Notion database for "Not started" tasks
# and invokes Claude to implement them as GitHub PRs.
# Intended to run via cron every hour.

set -e

PROJECT_DIR="/Users/chadwickbidwell/workspace/projects/enthasys"
NOTION_TOKEN="${NOTION_TOKEN:-$(grep NOTION_TOKEN "$PROJECT_DIR/.env" 2>/dev/null | cut -d '=' -f2)}"
TASKS_DB_ID="3c2f755b-9b20-8057-b1de-f2eade923adb"
CLAUDE_BIN="/Users/chadwickbidwell/.local/bin/claude"
LOG_FILE="$PROJECT_DIR/log/notion_task_runner.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Query Notion for the first "Not started" task
RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$TASKS_DB_ID/query" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  --data '{"filter": {"property": "Status", "status": {"equals": "Not started"}}, "page_size": 1}')

TASK_COUNT=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('results', [])))" 2>/dev/null || echo "0")

if [ "$TASK_COUNT" -eq "0" ]; then
  log "No pending tasks."
  exit 0
fi

TASK_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['results'][0]['id'])")
TASK_NAME=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); t=d['results'][0]['properties']['Name']['title']; print(t[0]['plain_text'] if t else '')")
TASK_DESC=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); rt=d['results'][0]['properties']['Description']['rich_text']; print(rt[0]['plain_text'] if rt else '')")

if [ -z "$TASK_NAME" ]; then
  log "Skipping unnamed task (ID: $TASK_ID) — add a Name in Notion."
  exit 0
fi

log "Picked up task: $TASK_NAME (ID: $TASK_ID)"

cd "$PROJECT_DIR"

"$CLAUDE_BIN" --dangerously-skip-permissions -p "You are implementing a task for the Enthasys Rails 7.1 project located at /Users/chadwickbidwell/workspace/projects/enthasys.

## Task
Name: $TASK_NAME
Description: $TASK_DESC
Notion page ID: $TASK_ID

## Your workflow — follow these steps in order

### 1. Mark task In progress in Notion
Run:
curl -s -X PATCH 'https://api.notion.com/v1/pages/$TASK_ID' \
  -H 'Authorization: Bearer $NOTION_TOKEN' \
  -H 'Notion-Version: 2022-06-28' \
  -H 'Content-Type: application/json' \
  --data '{\"properties\": {\"Status\": {\"status\": {\"name\": \"In progress\"}}}}'

### 2. Create a branch
- Slugify the task name: lowercase, spaces to hyphens, remove special chars
- Branch format: task/<slug>
- Run: git checkout main && git pull origin main && git checkout -b task/<slug>

### 3. Implement the task
- Read the relevant files to understand the codebase
- Make the necessary code changes to fulfill the task requirements
- This is a Rails 7.1 app with Hotwire (Turbo + Stimulus) and Bootstrap
- Do not refactor unrelated code

### 4. Run tests
Run: bundle exec rspec
Fix any test failures caused by your changes before proceeding.

### 5. Commit and push
Run:
git add -A
git commit -m \"\$(cat <<'EOF'
task: $TASK_NAME

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)\"
git push origin task/<slug>

### 6. Open a PR
Run:
gh pr create --title \"$TASK_NAME\" --body \"\$(cat <<'EOF'
## Summary
<bullet points of what changed>

## Notion Task
$TASK_DESC

## Test plan
<checklist of what to verify>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)\"

Capture the PR URL from the output.

### 7. Update Notion with branch and PR URL
Run:
curl -s -X PATCH 'https://api.notion.com/v1/pages/$TASK_ID' \
  -H 'Authorization: Bearer $NOTION_TOKEN' \
  -H 'Notion-Version: 2022-06-28' \
  -H 'Content-Type: application/json' \
  --data '{\"properties\": {\"Branch\": {\"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": \"task/<slug>\"}}]}, \"PR URL\": {\"url\": \"<pr_url>\"}}}'

## Rules
- Only implement what the task description says
- Never push to main
- If you cannot implement the task, revert the Notion status to 'Not started' and stop" >> "$LOG_FILE" 2>&1

log "Claude finished for task: $TASK_NAME"
