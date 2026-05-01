#!/bin/bash
set -e

cd "$CLAUDE_PROJECT_DIR/.claude/hooks"
cat | node "$HOME/.claude/hooks/skill-activation-prompt.js"
