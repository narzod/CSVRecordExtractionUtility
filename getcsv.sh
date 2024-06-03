#!/bin/bash

#  getcsv.sh
#  Outputs a local or hosted CSV file using rclone.
#
#  Usage: getcsv.sh [-c path] [-o path] [-v] [URL or path]
#  Example: getcsv.sh -c config.txt -o out.csv

usage() {
  cat <<EOF
Usage: $(basename "$0") [-c path] [-o path] [-v] [URL or path]

Options:
  -c path       Use a predefined URL from a remote hosted config.
  -o path       Send output to the provided file (default: stdout).
  -v            Enable verbose output to stderr.

Arguments:
  URL or path   The URL or file path to the local or hosted file.

Examples:
  $(basename "$0") http://example.com/path/to/file.csv
  $(basename "$0") remote:/path/to/file.csv
  $(basename "$0") -c remote:/path/to/config.txt
  $(basename "$0") -o out.csv http://example.com/path/to/file.csv
  $(basename "$0") -c ./config.txt -o out.csv
EOF
  exit 1
}

is_url() {
  [[ "$1" =~ ^https?:// ]]
}

strip_cr() {
  while IFS= read -r line; do
    printf '%s\n' "$line"
  done
}

config_file=""
output_file="/dev/stdout"
verbose=false

while getopts ":vc:o:" opt; do
  case $opt in
    v) verbose=true ;;
    c) config_file="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

input="$1"

if [ -n "$config_file" ]; then
  input=$(rclone cat "$config_file" 2> /dev/null) || {
    echo "Unable to retrieve predefined URL." >&2
    exit 1
  }
elif [ -z "$input" ]; then
  usage
fi

if is_url "$input"; then
  $verbose && echo "Input is a URL: $input" >&2
  rclone copyurl "$input" --stdout --contimeout 2s | strip_cr > "$output_file"
else
  $verbose && echo "Input is a path: $input" >&2
  rclone cat "$input" | strip_cr > "$output_file"
fi

