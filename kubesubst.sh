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

validate_vars_present() {
  exitCode=0
  vars=$(awk 'BEGIN{RS=" ";FS="\\$\\{|\\}"} /\$\{[^\}]+\}/ {print $2}' $1 | sort -u)

  # Check for the existence of each in the current environment
  for VAR in $vars; do
    # Using parameter substitution ${!var} to get value of variable named $var
    if [[ ${!VAR:-"unset"} == "unset" ]]; then
      log_msg ERROR "The environment variable $VAR is missing"
      exitCode=1
    else
      log_msg NORMAL "${VAR} is present set to ${!VAR}"
    fi
  done
  if [ $exitCode -eq 1 ]; then
    die "Exiting due to error"
  fi
}

# check if file name is provided as an argument
if [ $# -eq 0 ]; then
	echo "No arguments supplied. Please provide a YAML file."
	exit 1
fi

# check if the file exists
if [ ! -f $1 ]; then
	echo "File not found!"
	exit 1
fi

# check if the second argument (env file) is provided and exists
if [ -n "$2" ] && [ -f "$2" ]; then
	echo "Loading env file into env"
	set -o allexport
	source "$2"
	set +o allexport
else
	echo "No env file set or found, assuming env is all set in CI"
fi

# check if yq is installed and has PyYAML library
# used for validation
if ! command -v yq &>/dev/null; then
	echo "yq could not be found. Install it https://mikefarah.gitbook.io/yq/v/v4.x/"
	exit 1
fi

# get the file name without extension
filename=$(basename -- "$1")
filename="${filename%.*}"

# create a new file name for the output
output_file="${filename}_output.yaml"

validate_vars_present "$1"

# use envsubst to replace the env vars and output to a new file
envsubst <$1 >$output_file

# Validate yaml using python and PyYAML
yq -v $output_file

# check if the yaml is valid
if [ $? -eq 0 ]; then
	log_msg NORMAL "YAML file is valid"
	cat $output_file
else
	log_msg ERROR "YAML file is not valid"
	# remove the invalid file
	rm $output_file
	exit 1
fi

echo "Output written to $output_file"
