#!/usr/bin/env bash

#  setremote.sh
#  Creates the local rclone remote needed for use with updateini.sh.

remote="conf"
rclone config create $remote alias remote $(dirname $(rclone config file | tail -1))

