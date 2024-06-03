#!/usr/bin/sh

#  updateini.sh
#  Updates local settings from a remote CSV file via getcsv.sh and csv2ini.awk.
#
#  Usage: updateini.sh <key>
#  Example: updateini.sh F1
#
#  This script fetches a remote CSV file using getcsv.sh with the -c option,
#  processes it with csv2ini.awk to convert it into an INI-like format based on
#  the provided key, and uploads the resulting INI file to a remote location
#  using rclone.

if [ -z "$1" ]; then
  echo "usage:" $(basename $0) "<key>"
  exit 1
fi

settings="conf:settings.ini"

getcsv.sh -c 2> /dev/null | csv2ini.awk -v key=$1 | rclone rcat $settings

