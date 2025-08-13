#!/usr/bin/env bash

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

require_env "RANCHER_ACCESS_KEY"
require_env "RANCHER_SECRET_KEY"
require_env "RANCHER_URL"
require_env "RANCHER_ENVIRONMENT"
require_env "RANCHER_CACERT"

mkdir -p ~/.rancher

log_msg NORMAL "Writing rancher CLI2 file"

tee ~/.rancher/cli2.json >/dev/null <<EOF
{
  "Servers":
  {
    "rancherDefault":
    {
      "accessKey":"$RANCHER_ACCESS_KEY",
      "secretKey":"$RANCHER_SECRET_KEY",
      "tokenKey":"$RANCHER_ACCESS_KEY:RANCHER_SECRET_KEY",
      "url":"$RANCHER_URL",
      "project":"$RANCHER_ENVIRONMENT",
      "cacert":"$RANCHER_CACERT"
    }
  },
  "CurrentServer":"rancherDefault"
}
EOF

chmod 600 ~/.rancher/cli2.json
