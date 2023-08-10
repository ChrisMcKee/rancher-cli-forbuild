#!/usr/bin/env bash

PS4='l$LINENO: '
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

export TERM=xterm

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(
    basename "${BASH_SOURCE[0]}"
  ) [-h] [-cd] --checkdeployment deployment-file.yml [env-file...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-cd, --checkdeployment  Validate the deployment has completed
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

hr() {
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' "${1:--}"
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  check_deployment=false
  verbose=false
  env_file=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose)
      set -x
      verbose=true
      ;;
    --no-color) NO_COLOR=1 ;;
    -e | --env-file)
      env_file="${2-}"
      shift
      ;;
    -cd | --checkdeployment) check_deployment=true ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

  return 0
}

validate_vars_present() {
  exitCode=0
  vars=$(awk 'BEGIN{RS=" ";FS="\\$\\{|\\}"} /\$\{[^\}]+\}/ {print $2}' $1 | sort -u)

  # Check for the existence of each in the current environment
  for VAR in $vars; do
    # Using parameter substitution ${!var} to get value of variable named $var
    if [[ ${!VAR:-"unset"} == "unset" ]]; then
      msg "${RED} ---  ERROR: The environment variable $VAR is missing"
      exitCode=1
    else
      msg "${GREEN} ---  ${VAR} is present set to ${!VAR}"
    fi
  done
  if [ $exitCode -eq 1 ]; then
    die "Exiting due to error"
  fi
}

kube_subst() {
  # check if yq is installed and has PyYAML library
  # used for validation
  if ! command -v yq &>/dev/null; then
    msg "${RED} --- yq could not be found. Install it https://mikefarah.gitbook.io/yq/v/v3.x/"
    die "Exiting due to error"
  fi

  # get the file name without extension
  filename=$(basename -- "$1")
  filename="${filename%.*}"

  # create a new file name for the output
  output_file="${filename}_output.yaml"

  # use envsubst to replace the env vars and output to a new file
  envsubst <$1 >$output_file

  # Validate yaml using python and PyYAML
  yq $output_file

  # check if the yaml is valid
  if [ $? -eq 0 ]; then
    msg "${GREEN} ---  YAML file is valid"
    if [ "${verbose}" = true ]; then
      msg "${YELLOW} ---  Outputting configuration"
      cat "$output_file"
    fi
  else
    # remove the invalid file
    rm "$output_file"
    die "YAML file is not valid"
  fi

  yaml_file=$output_file
  msg "${BLUE} ---  Output written to $output_file"
  return 0
}

monitor_deployment_rollback_on_fail() {

  DEPLOYMENT_NAME=$1
  NAMESPACE=$2

  # Timeout variables
  TIMEOUT=300  # 5 minutes
  ELAPSED=0

  # Monitor the deployment
  while true; do
    # Get the rollout status
    ROLLOUT_STATUS="$(rancher kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE)"

    # Check if deployment has successfully rolled out
    if echo "${ROLLOUT_STATUS}" | grep -q 'successfully rolled out'; then
      msg "${GREEN} ---  Deployment successful!"
      exit 0
    fi

    # Check for a timeout
    if [ $ELAPSED -ge $TIMEOUT ]; then
      msg "${RED} ---  Timeout reached! Rolling back..."
      rancher kubectl rollout undo deployment $DEPLOYMENT_NAME -n $NAMESPACE
      die "Exiting due to timeout"
    fi

    # Wait before checking again
    sleep 5
    ELAPSED=$((ELAPSED+5))
  done
}

create_ranchercli_config() {

  RANCHER_ACCESS_KEY=$1
  RANCHER_SECRET_KEY=$2
  RANCHER_URL=$3
  RANCHER_ENVIRONMENT=$4
  RANCHER_CACERT=$5

  if [ -z "$RANCHER_ACCESS_KEY" ] || [ -z "$RANCHER_SECRET_KEY" ] || [ -z "$RANCHER_URL" ] || [ -z "$RANCHER_ENVIRONMENT" ]; then
    echo "No rancher vars present"
    exec "$@"
    exit 0
  fi

  mkdir -p ~/.rancher

  echo Writing rancher CLI2 file ...

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

}

check_connectivity() {
  rancher kubectl version >/dev/null
  if [[ $? -ne 0 ]]; then
    msg "${RED} ---  Failed to connect to Kubernetes server"
    die "Exiting due to error"
  fi
}

deploy_to_k8s() {

  rancher kubectl apply -f "$1"

  if [ "${check_deployment}" = false ]; then
    msg "${YELLOW} ---  Skipping validation"
    exit 0
  fi

  # Validate
  # Extract all Deployment name + namespaces
  deployments=$(yq eval-all -N 'select(.kind == "Deployment") | .metadata.namespace + "~" + .metadata.name' $1 | sort -u)

  # Check if there are multiple deployments
  if [ $(echo "$deployments-0" | wc -l) -gt 1 ]; then
    msg "${GREEN} ---  Multiple Deployments found."

    # Iterate over each deployment
    while IFS= read -r deployment; do
      msg "${YELLOW} ---  Validating Deployment:"
      IFS="~"
      read -r namespace name <<<"$deployment"
      msg "${YELLOW} ---  Namespace: $namespace"
      msg "${YELLOW} ---  Name: $name"
      monitor_deployment_rollback_on_fail $name $namespace
    done <<<"$deployments"
  else
    msg "${GREEN} ---  Validating Deployment:"
    IFS="~"
    read -r namespace name <<<"$deployments"
    msg "${YELLOW} ---  Namespace: $namespace"
    msg "${YELLOW} ---  Name: $name"
    monitor_deployment_rollback_on_fail $name $namespace
  fi
}

parse_params "$@"
setup_colors

# script logic here

msg "${RED}Read parameters:${NOFORMAT}"
msg "- check deployment: ${check_deployment}"
msg "- arguments: ${args[*]-}"

export yaml_file=${args[0]}

if [ -z "${yaml_file-unset}" ] || [ ! -f "${yaml_file}" ]; then
  die "File not found! - $yaml_file"
fi

if [ -z "${env_file-unset}" ] || [ ! -f "${env_file}" ]; then
  msg "${YELLOW} --- No env file set or found, assuming env is all set in CI"
else
  msg "${GREEN} ---  Loading env file ($env_file) into env"
  set -o allexport
  source $env_file
  set +o allexport
fi

# envsubst the yaml file
validate_vars_present "$yaml_file"
hr
kube_subst "$yaml_file"
hr
create_ranchercli_config $RANCHER_ACCESS_KEY $RANCHER_SECRET_KEY $RANCHER_URL $RANCHER_ENVIRONMENT $RANCHER_CACERT
check_connectivity
deploy_to_k8s "${yaml_file}"
