#!/data/data/com.termux/files/usr/bin/bash

REPO="/data/data/com.termux/files/home/notes"
LOG="/data/data/com.termux/files/home/autopush.log"

cd "$REPO" || exit 1

# Only continue if there are changes
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "backup $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG" 2>&1
  eval $(ssh-agent -s) && ssh-add ~/.ssh/ghhr
  git push >>"$LOG" 2>&1
fi
