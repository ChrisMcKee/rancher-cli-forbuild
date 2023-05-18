#!/usr/bin/env bash

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

# check if the file exists
if [ ! -f $2 ]; then
	echo "No env file set or found, assuming env is all set in CI"
else
	echo "Loading env file into env"
	set -o allexport
	source $2
	set +o allexport
fi

# check if yq is installed and has PyYAML library
# used for validation
if ! command -v yq &>/dev/null; then
	echo "yq could not be found. Install it https://mikefarah.gitbook.io/yq/v/v3.x/"
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
yq -v $output_file

# check if the yaml is valid
if [ $? -eq 0 ]; then
	echo "YAML file is valid"
	cat $output_file
else
	echo "YAML file is not valid"
	# remove the invalid file
	rm $output_file
	exit 1
fi

echo "Output written to $output_file"
