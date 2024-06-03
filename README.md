# CSV Row Extraction Utilities

This repository showcases practical programming experiments centered around extracting a specific row from a CSV file and presenting it in an INI-like format.

## Experiment 1: csv2ini.awk

`csv2ini.awk` is an AWK script that takes a CSV file as input, extracts a specific row based on a provided key value in the first column, and presents the extracted row in an INI-like format, treating column headers (if uppercase) as keys and assigning corresponding values.

## Experiment 2: csvget.sh

`csvget.sh` is a Bash script that retrieves CSV files from various sources: local paths, remote URLs, or config files containing the CSV location. It leverages `rclone` for file retrieval, ensuring compatibility with cloud storage services and remote file systems.

## Experiment 3: csvrow.lua

`csvrow.lua` is a Lua script that combines the functionality of the previous two experiments into a single utility. It also leverages `rclone` to retrieve CSV files from various sources (local, remote, or config files) and extracts a specific row based on a provided key value, presenting the output in an INI-like format.
