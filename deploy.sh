#!/usr/bin/env bash

PS4='l$LINENO: '
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

alias k8="rancher kubectl"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-V] -validate deployment-file.yml [env-file...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-V, --validate  Validate the deployment has completed
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
  validate=false
  env_file=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -e | --env-file)
      env_file="${2-}"
      shift
      ;;
    -V | --validate) validate=true ;;
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

kube_subst() {
  # check if yq is installed and has PyYAML library
  # used for validation
  if ! command -v yq &>/dev/null; then
    msg "${RED} --- yq could not be found. Install it https://mikefarah.gitbook.io/yq/v/v3.x/"
    exit 1
  fi

  # get the file name without extension
  filename=$(basename -- "$1")
  filename="${filename%.*}"

  # create a new file name for the output
  output_file="${filename}_output.yaml"

  # use envsubst to replace the env vars and output to a new file
  envsubst <$1 >$output_file

  # Validate yaml using python and PyYAML
  yq "$output_file" > /dev/null

  # check if the yaml is valid
  if [ $? -eq 0 ]; then
    cat -b $output_file
    msg "${GREEN} ---  YAML file is valid"
  else
    # remove the invalid file
    rm $output_file
    die "YAML file is not valid"
  fi

  yaml_file=$output_file
  msg "${BLUE} ---  Output written to $output_file"
  return 0
}

deploy_to_k8s() {

  k8 apply -f $1

  # Validate
  # Extract all Deployment name + namespaces
  deployments=$(yq eval-all -N 'select(.kind == "Deployment") | .metadata.namespace + "~" + .metadata.name' $1 | sort -u)

  # Check if there are multiple deployments
  if [ $(echo "$deployments" | wc -l) -gt 1 ]; then
    echo "Multiple Deployments found."

    # Iterate over each deployment
    while IFS= read -r deployment; do
      echo "Validating Deployment:"
      IFS="~"
      read -r namespace name <<<"$deployment"
      echo "Namespace: $namespace"
      echo "Name: $name"
      k8 rollout status "deployment/${deployment}" --namespace $namespace
    done <<<"$deployments"
  else
    echo "Validating Deployment:"
    IFS="~"
    read -r namespace name <<<"$deployments"
    echo "Namespace: $namespace"
    echo "Name: $name"
    k8 rollout status "deployment/${deployment}" --namespace $namespace
  fi
}

parse_params "$@"
setup_colors

# script logic here

msg "${RED}Read parameters:${NOFORMAT}"
msg "- validate: ${validate}"
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
kube_subst "$yaml_file"
deploy_to_k8s "${yaml_file}"
