#!/usr/bin/env bash

PS4='l$LINENO: '
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

log_msg() {
  local status="${1:-NORMAL}"
  shift
  local text="$*"

  if [ -n "$TEAMCITY_VERSION" ]; then
    echo "##teamcity[message text='$text' errorDetails='' status='$status']"
  else
    echo "$text"
  fi
}

require_env() {
  local var_name="$1"
  local value="${!var_name}"

  if [ -z "$value" ]; then
    log_msg ERROR "$var_name is not set"
    exit 1
  fi
}

CLUSTER=$1
NAMESPACE=$2
DEPLOYMENT_NAME=$3

require_env "CLUSTER"
require_env "NAMESPACE"
require_env "DEPLOYMENT_NAME"

now=$(date +%s%3N)

read -r -d '' PAYLOAD << EOM
{
  "created": $now,
  "updated": $now,
  "time": $now,
  "timeEnd": $now,
  "text": "Deployment",
  "tags": [
    "kind:deployment",
    "version:${BUILD_NUMBER:-unknown}",
    "${CLUSTER}",
    "${NAMESPACE}",
    "${DEPLOYMENT_NAME}"
  ]
}
EOM

log_msg NORMAL "Annotating Grafana with deployment information for ${CLUSTER}/${NAMESPACE}/${DEPLOYMENT_NAME}"

curl -X POST "https://${GRAFANA_URL}/api/annotations" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
  -d "$PAYLOAD"