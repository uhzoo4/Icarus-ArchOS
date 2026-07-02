#!/bin/bash
# Icarus Grimoire Keeper - Automatically records all changes
# to the icarus-linux repository every hour.

REPO_PATH="$HOME/icarus-linux"
cd "$REPO_PATH" || exit 1

if [[ -n $(git status --porcelain) ]]; then
    git add -A
    COMMIT_MSG="Grimoire auto-commit: $(date +'%Y-%m-%d %H:%M')"
    git commit -m "$COMMIT_MSG"
fi