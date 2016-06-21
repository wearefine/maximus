#!/bin/bash

REPO_NAME=${PWD##*/}
AUTHOR_EMAIL=`git log -1 --format=%ae`
SHA=`git rev-parse --verify HEAD`

# ENV variables are passed to the deploy.sh script and used in the commit message
body='{
  "request": {
    "message": "Automated: New build started by '$AUTHOR_EMAIL' on wearefine/'$REPO_NAME'@'$SHA'",
    "branch": "automated-build",
    "config": {
      "env": {
        "TRIGGER_REPO": "'$REPO_NAME'",
        "TRIGGER_SHA": "'$SHA'",
        "AUTHOR_EMAIL": "'$AUTHOR_EMAIL'"
      }
    }
  }
}'

# $AUTH_TOKEN is an encrypted variable that must be generated per project
# See https://github.com/wearefine/wearefine.github.io/blob/master/README.md#travis-ci
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token $AUTH_TOKEN" \
  -d "$body" \
  https://api.travis-ci.org/repo/wearefine%2Fwearefine.github.io/requests
