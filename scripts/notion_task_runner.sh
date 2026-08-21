#!/bin/bash
# Polls the Enthasys Tasks Notion database for "Not started" tasks
# and invokes Claude to implement them as GitHub PRs.
# Intended to run via cron daily or manually.

PROJECT_DIR="/Users/chadwickbidwell/workspace/projects/enthasys"
NOTION_TOKEN="${NOTION_TOKEN:-$(grep NOTION_TOKEN "$PROJECT_DIR/.env" 2>/dev/null | cut -d '=' -f2)}"
TASKS_DB_ID="3c2f755b-9b20-8057-b1de-f2eade923adb"
CLAUDE_BIN="/Users/chadwickbidwell/.local/bin/claude"
LOG_FILE="$PROJECT_DIR/log/notion_task_runner.log"
LOCK_FILE="$PROJECT_DIR/tmp/notion_task_runner.lock"
RESULT_FILE="$PROJECT_DIR/tmp/task_result.json"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

notion_patch() {
  curl -s -X PATCH "https://api.notion.com/v1/pages/$1" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    --data "$2" > /dev/null
}

notion_comment() {
  local message
  message=$(echo "$2" | sed 's/"/\\"/g')
  curl -s -X POST "https://api.notion.com/v1/comments" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    --data "{\"parent\": {\"page_id\": \"$1\"}, \"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": \"$message\"}}]}" > /dev/null
}

fail_task() {
  local task_id="$1" branch="$2" reason="$3"
  log "Task failed: $reason"
  notion_comment "$task_id" "⚠️ Claude couldn't complete this task: $reason — Please clarify the requirements and reset the status to 'Not started'."
  notion_patch "$task_id" '{"properties": {"Status": {"status": {"name": "Not started"}}}}'
  if [ -n "$branch" ] && git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    git checkout main 2>/dev/null || true
    git branch -D "$branch" 2>/dev/null || true
    log "Cleaned up branch $branch"
  fi
}

# Prevent overlapping runs
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    log "Another run is active (PID $LOCK_PID). Exiting."
    exit 0
  else
    log "Stale lock found (PID $LOCK_PID no longer running). Continuing."
  fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

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

# Derive branch name
BRANCH="task/$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g')"

# Mark In progress immediately to prevent duplicate pickup
notion_patch "$TASK_ID" '{"properties": {"Status": {"status": {"name": "In progress"}}}}'
log "Marked In progress in Notion"

# Create branch from latest main
cd "$PROJECT_DIR"
if ! git checkout main && git pull origin main && git checkout -b "$BRANCH"; then
  fail_task "$TASK_ID" "" "Failed to create branch $BRANCH — check for conflicts or a duplicate branch name."
  exit 1
fi
log "Created branch $BRANCH"

# Clear any previous result file
rm -f "$RESULT_FILE"

# Invoke Claude for implementation only — shell handles all git/Notion ops
"$CLAUDE_BIN" --dangerously-skip-permissions -p "You are implementing a code change for the Enthasys Rails 7.1 app at /Users/chadwickbidwell/workspace/projects/enthasys.

## Task
Name: $TASK_NAME
Description: $TASK_DESC

## Your job
You are already on branch $BRANCH. Make the necessary code changes to fulfill the task requirements, write tests, and run the full test suite.

- Read relevant files first to understand the codebase
- Rails 7.1 with Hotwire (Turbo + Stimulus) and Bootstrap
- Only change what the task description asks for — no unrelated refactoring
- Write RSpec tests covering the new behaviour (add to the appropriate spec file or create a new one)
- Run the full suite: bundle exec rspec
- Attempt to fix any test failures caused by your changes (up to 2 retries)

## When finished, write your result to $RESULT_FILE as JSON

Three possible outcomes:

1. Implementation done and all tests pass:
   {\"status\": \"success\", \"tests\": \"passing\"}

2. Implementation done but tests are still failing after attempts to fix:
   {\"status\": \"tests_failing\", \"reason\": \"one sentence describing what is failing and why\"}

3. Cannot implement — task too vague, can't determine what to change:
   {\"status\": \"failed\", \"reason\": \"one concise sentence explaining the problem\"}

IMPORTANT: Do NOT git add, commit, push, or open PRs — the calling script handles that.
IMPORTANT: You MUST write to $RESULT_FILE before exiting, even on failure." >> "$LOG_FILE" 2>&1

# Check result file
if [ ! -f "$RESULT_FILE" ]; then
  fail_task "$TASK_ID" "$BRANCH" "Claude exited without writing a result — likely a timeout or crash."
  exit 1
fi

STATUS=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
REASON=$(python3 -c "import json; d=json.load(open('$RESULT_FILE')); print(d.get('reason',''))" 2>/dev/null || echo "")

if [ "$STATUS" = "failed" ]; then
  fail_task "$TASK_ID" "$BRANCH" "${REASON:-Implementation failed without a stated reason.}"
  exit 1
fi

# Check there are actually changes to commit
if git diff --quiet && git diff --cached --quiet; then
  fail_task "$TASK_ID" "$BRANCH" "Claude signaled success but made no code changes."
  exit 1
fi

# Commit and push
git add -A
git commit -m "$(cat <<EOF
task: $TASK_NAME

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
git push origin "$BRANCH"
log "Committed and pushed $BRANCH"

TESTS_PASSING=true
PR_FLAGS=""
PR_TITLE="$TASK_NAME"
TEST_NOTICE=""

if [ "$STATUS" = "tests_failing" ]; then
  TESTS_PASSING=false
  PR_FLAGS="--draft"
  PR_TITLE="[TESTS FAILING] $TASK_NAME"
  TEST_NOTICE="$(cat <<EOF

---
> ⚠️ **Tests are failing.** Claude implemented this change but could not get the test suite to pass.
>
> Reason: ${REASON:-not specified}
>
> This PR is a **draft** — review the failing tests before merging.
EOF
)"
  log "Tests failing — opening draft PR"
fi

# Open PR and capture URL
PR_URL=$(gh pr create \
  $PR_FLAGS \
  --title "$PR_TITLE" \
  --body "$(cat <<EOF
## Summary
$(git diff main.."$BRANCH" --stat | tail -1)

## Notion Task
${TASK_DESC:-No description provided.}

## Test plan
- [ ] Verify the change matches the task description
- [ ] Run \`bundle exec rspec\`
$TEST_NOTICE

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" 2>&1 | grep "https://github.com" | tail -1)

if [ -z "$PR_URL" ]; then
  log "Warning: PR may have been created but URL was not captured. Check GitHub."
else
  log "Opened PR: $PR_URL"
fi

# Post Notion comment if tests failed
if [ "$TESTS_PASSING" = false ]; then
  notion_comment "$TASK_ID" "⚠️ Tests failing: ${REASON:-see PR for details}. A draft PR has been opened at $PR_URL — review the failures before merging."
fi

# Update Notion with branch and PR URL
notion_patch "$TASK_ID" "{\"properties\": {\"Branch\": {\"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": \"$BRANCH\"}}]}, \"PR URL\": {\"url\": \"$PR_URL\"}}}"
log "Updated Notion with branch and PR URL"
log "Done."
