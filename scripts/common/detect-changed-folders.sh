#!/bin/bash
set -e

log() { echo "[Detect] $(date +'%Y-%m-%d %H:%M:%S') $*"; }
error_exit() { echo "❌ [Detect] $1" >&2; exit 1; }

log "Detecting changed folders between the two latest commits..."
LATEST_COMMIT=$(git rev-parse HEAD)
PREV_COMMIT=$(git rev-parse HEAD~1)

CHANGED_FOLDERS=$(git diff --name-only "$PREV_COMMIT" "$LATEST_COMMIT" | awk -F/ 'NF>1{print $1}' | sort -u)

if [ -z "$CHANGED_FOLDERS" ]; then
  log "No folder changes detected. Skipping apply."
  exit 0
fi

log "Changed folders:"
echo "$CHANGED_FOLDERS"
echo "$CHANGED_FOLDERS" > changed_folders.txt
log "Changed folders written to changed_folders.txt"