#!/usr/bin/env bash
set -euo pipefail

BUILD_TYPE="${1:-full}"
GIT_USER=$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
TIMESTAMP=$(date +%s)
BRANCH="remote-build/${GIT_USER}/${TIMESTAMP}"

echo "Triggering remote build..."
echo "   Branch: $BRANCH"
echo "   Type:   $BUILD_TYPE"

git push origin "HEAD:refs/heads/$BRANCH"

echo ""
echo "Waiting for GitHub Actions to pick up the run..."
sleep 3

RUN_URL=$(gh run list \
  --branch "$BRANCH" \
  --limit 1 \
  --json url \
  --jq '.[0].url' 2>/dev/null || echo "")

if [ -n "$RUN_URL" ]; then
  echo "Run started: $RUN_URL"
  gh run watch --branch "$BRANCH" --exit-status
else
  echo "Could not find run. Check: https://github.com/$GITHUB_REPOSITORY/actions"
fi
