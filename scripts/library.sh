#!/bin/bash

#
# library.sh
#
# This script contains a set of functions that can be used through the admin scripts
# You can do the following to include the functions in another script:
#   source library.sh
#

#
# Get the paths of partitions on a drive seperated by spaces
#
# @param $1 The block device path of the drive
# @return The paths of partitions on the drive seperated by spaces
#
function get_partition_paths {
  ls "$1"[0-9]*
}

#
# Get the paths of mirror drives seperated by spaces
#
# @return The paths of mirror drives seperated by spaces
#
function get_mirror_drives {

  # Get rows representing mirror partitions which indicate a drive is a mirror
  local mirror_partitions=$(lsblk -o PATH,PARTLABEL | grep "nest-mirror")

  # Get the paths of the drives by removing the partition number at the end
  while read -r line; do
    echo "$line" | awk '{print $1}' | sed 's/[0-9]*$//g'
  done <<< "$mirror_partitions"

}





#
# Get the label of a partition
#
# @param $1 The block device path of the partition
# @return The label of the partition
#
function get_partition_label {
  blkid "$1" | grep -o 'PARTLABEL="[^"]*"' | sed 's/PARTLABEL="//;s/"$//'
}

#
# Get the path of a partition given a drive path and a label
#
# @param $1 The block device path of the drive
# @param $2 The label of the partition
# @return The path of the partition, or empty string if not found
#
function get_partition_path {
  lsblk -o PATH,PARTLABEL | grep "$1" | grep -w -m 1 "$2" | cut -d ' ' -f 1
}

#
# Get a row of text from lsblk by grepping
#
# @param $1 The search term to grep for
# @return The first row from lsblk that matches the search term
#
function get_block_row {
  lsblk -o PATH,SIZE,PARTLABEL | grep -m 1 "$1" | sed 's/[[:space:]]\+/ /g'
}

#
# Get the path from a row of lsblk
#
# @return The path 
#
function get_path_from_row {
  echo "$1" | cut -d ' ' -f 1
}

#
# Get the partition number from a partition block device path
#
# @param $1 The block device path of the partition
# @return The partition number on the drive, or empty string if not found
#
function parse_partition_number {
  echo "$1" | sed 's/^[^0-9]*//'
}