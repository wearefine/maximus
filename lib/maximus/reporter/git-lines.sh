#!/bin/bash

# http://stackoverflow.com/questions/8259851/using-git-diff-how-can-i-get-added-and-modified-lines-numbers
# @todo this function is tricky because I don't fully understand regex in BASH. Also, getting line hunks from git is tricky. This will likely need to be refactored
function lines-added(){
  local path=
  local line=
  local start=
  local finish=
  local unified=1
  while read; do
    esc=$'\033'
    if [[ $REPLY =~ ---\ (a/)?.* ]]; then
      continue
    elif [[ $REPLY =~ \+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
      path=${BASH_REMATCH[2]}
    # @@ -1,2, +3,4 @@
    elif [[ $REPLY =~ @@\ -([0-9]+)?,([0-9]+)?\ \+([0-9]+)?,([0-9]+)?\ @@.* ]]; then

      # hunk deletion
      # @@ -7,5 +7,3 @@
      # 0..0
      if [[ ${BASH_REMATCH[2]} > ${BASH_REMATCH[4]} ]]; then
        line="0..0"

      # line(s) addition
      # @@ -3,2, +3,3 @@
      # 4..4
      elif [[ ${BASH_REMATCH[1]} = ${BASH_REMATCH[3]} ]]; then
        line="$((${BASH_REMATCH[1]} + $unified))..$((${BASH_REMATCH[4]} - ${BASH_REMATCH[2]} + ${BASH_REMATCH[1]}))"

      # full deletion
      # @@ -1,2, +0,0 @@
      # 0..0
      elif [[ ${BASH_REMATCH[3]} = ${BASH_REMATCH[4]} ]]; then
        line="0..0"

      # hunk addition
      # @@ -0,0, +1,5 @@
      # 0..4
      elif [[ ${BASH_REMATCH[1]} = ${BASH_REMATCH[2]} ]]; then
        line="$((${BASH_REMATCH[3]} - $unified))..$((${BASH_REMATCH[4]} - ${BASH_REMATCH[3]} + $unified))"

      # additions with deletions
      # @@ -13,3 +11,3 @@
      # 12..12
      elif [[ ${BASH_REMATCH[2]} = ${BASH_REMATCH[4]} ]]; then
        line="$((${BASH_REMATCH[1]} - $unified))..$((${BASH_REMATCH[1]} - $unified))"

      else

        # @@ -13,3 +11,4 @@
        # 12..13
        line="$((${BASH_REMATCH[1]} - $unified))..${BASH_REMATCH[1]}"

      fi
    elif [[ $REPLY =~ ^($esc\[[0-9;]+m)*([\ +-]) ]]; then
      echo "$path:$line"
    fi
  done
}
function diff-lines(){
  local path=
  local line=
  while read; do
    esc=$'\033'
    if [[ $REPLY =~ ---\ (a/)?.* ]]; then
      continue
    elif [[ $REPLY =~ \+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
      path=${BASH_REMATCH[2]}
    elif [[ $REPLY =~ @@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@.* ]]; then
      line=${BASH_REMATCH[2]}
    elif [[ $REPLY =~ ^($esc\[[0-9;]+m)*([\ +-]) ]]; then
      echo "$path:$line:$REPLY"
      if [[ ${BASH_REMATCH[2]} != - ]]; then
        ((line++))
      fi
    fi
  done
}

if [ -z "$2" ]; then
  first_commit=$(git rev-list --max-parents=0 HEAD)
  if [[ "$1" == "$first_commit" ]]; then
    git diff --unified=1 | lines-added
  else
    git diff $1^ $1 --unified=1 | lines-added
  fi
else
  git diff --unified=1 | lines-added
fi
