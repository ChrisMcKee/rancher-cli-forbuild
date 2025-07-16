#!/usr/bin/env bash

PS4='l$LINENO: '
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

export TERM=xterm

CLUSTER=$1
NAMESPACE=$2
DEPLOYMENT_NAME=$3

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

echo "Annotating Grafana with deployment information for ${CLUSTER}/${NAMESPACE}/${DEPLOYMENT_NAME}"

curl -X POST "https://${GRAFANA_URL}/api/annotations" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
  -d "$PAYLOAD"