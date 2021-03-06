#!/bin/bash

# http://stackoverflow.com/questions/8259851/using-git-diff-how-can-i-get-added-and-modified-lines-numbers
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

if [ -z "$3" ]; then
  first_commit=$(git rev-list --max-parents=0 HEAD)
  if [[ "$2" == "$first_commit" ]]; then
    git -C $1 diff --unified=1 | lines-added
  else
    git -C $1 diff $2^ $2 --unified=1 | lines-added
  fi
else
  git -C $1 diff --unified=1 | lines-added
fi
