#!/bin/bash

# http://stackoverflow.com/questions/8259851/using-git-diff-how-can-i-get-added-and-modified-lines-numbers
# TODO - this function is tricky because I don't fully understand regex in BASH. Also, getting line hunks from git is tricky. This will likely need to be refactored
function lines-added(){
  local path=
  local line=
  local start=
  local finish=
  while read; do
    esc=$'\033'
    if [[ $REPLY =~ ---\ (a/)?.* ]]; then
      continue
    elif [[ $REPLY =~ \+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
      path=${BASH_REMATCH[2]}
    elif [[ $REPLY =~ @@\ -[0-9]+,([0-9]+)?\ \+([0-9]+)?,([0-9]+)?\ @@.* ]]; then
      if [[ ${BASH_REMATCH[2]} = ${BASH_REMATCH[3]} ]]; then
        line="0..0"
      elif [[ ${BASH_REMATCH[2]} = $((${BASH_REMATCH[2]} + ${BASH_REMATCH[3]})) ]]; then
        line="$((${BASH_REMATCH[2]} + ${BASH_REMATCH[3]} - ${BASH_REMATCH[1]}))..$((${BASH_REMATCH[2]} + ${BASH_REMATCH[3]} - ${BASH_REMATCH[1]}))"
      else
        line="${BASH_REMATCH[2]}..$((${BASH_REMATCH[2]} + ${BASH_REMATCH[3]}))"
      fi
    elif [[ $REPLY =~ @@\ -([0-9])?,([0-9]+)?\ \+([0-9]+)?\ @@.* ]]; then
      line="${BASH_REMATCH[3]}..${BASH_REMATCH[3]}"
    elif [[ $REPLY =~ @@\ -([0-9]+)?,\ \+([0-9]+)?\ @@.* ]]; then
      line="0..${BASH_REMATCH[2]}"
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

git diff $1^ $1 --unified=0 | lines-added