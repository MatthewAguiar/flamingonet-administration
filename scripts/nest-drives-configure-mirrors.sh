#!/bin/bash

#
# nest-drives-configure-mirrors.sh
#
# This script takes a parted command as an argument
# and applies it to all nest drives including the primary drive and any mirrors
#
# It performs the following procedure:
#
#   1. Find Primary Drive:
#       Checks if there exists a primary drive (a drive with a "nest-primary" partition)
#
#   2. Exit if no Primary Drive:
#       If there is no primary drive, then exit
#
#   3. Compare Partitions:
#       If there is a primary drive, compare the partitions of the primary drive
#       to the partitions on any mirror drives (drives with a "nest-mirror" partition).
#       That is, each partition on the primary drive starting at 1, should have the exact
#       START and END positions as the corresponding partition on the mirror drive.
#
#   4. For any mirrors whose partitions do not match exactly, prompt the user asking
#      if they want to reformat the drive. These drives will be saved for the end of the
#      script. This will wipe all data on the mirror drive and create each partition
#      with the exact same properties as they are on the primary drive.
#   5. Apply the parted command passed into this script to the primary drive and all mirrors
#      whose partitions match exactly with the primary drive.
#   6. Any drives the user chose to wipe and reformat, perform afterwards.
#      
#

# Strict Mode - https://redsymbol.net/articles/unofficial-bash-strict-mode/
#
#   set -e           Causes script to immediately exit if any command's return status in non-zero
#   set -u           Causes script to immediately exit if a variable is referenced that is not defined
#   set -o pipefail  If an error happens in a pipeline, the return code is that of the failed command
#
set -euo pipefail

# Import library functions
source library.sh

########################################################
# Functions
########################################################

#
# Check if the partitions on two drives are identical in size and position
#
# @param $1 The block device path of the first drive
# @param $2 The block device path of the second drive
# @return 0 if the partitions are identical, 1 otherwise
function are_partitions_identical {

  # Capture the block device paths
  local drive_one="$1"
  local drive_two="$2"

  # Get the partitions on each drive
  local partitions_one=$( get_partition_paths "$drive_one" )
  local partitions_two=$( get_partition_paths "$drive_two" )

  # If the number of partitions on each drive is not the same, then they are not identical
  if [[ $(echo "$partitions_one" | wc -l) -ne $(echo "$partitions_two" | wc -l) ]]; then
    return 1
  fi

  # Otherwise, loop through each partition on each drive and
  # verify they start and end at the exact same positions
  while read -r partition_one; do

  done

}

########################################################
# 1. Find Primary Drive
########################################################

# First, find the primary nest drive by searching for a small partition labeled "nest-primary"
primary_partition=$(lsblk -o PATH,PARTLABEL | grep -m 1 "nest-primary" | awk '{print $1}')
primary_drive=${primary_partition%%[0-9]*}

########################################################
# 2. Exit if no Primary Drive:
########################################################

# If there is no primary drive, then exit
if [[ -z "$primary_drive" ]]; then
  echo "Error: Could not find a primary Nest Drive. Exiting..."
  exit 1
fi

########################################################
# 3. Compare Partitions
########################################################

# Get a list of primary partition paths
primary_partitions=$( get_partition_paths "$primary_drive" )

# Get a list of mirror drives by searching for a small partition labeled "nest-mirror"
mirror_drives=$( get_mirror_drives )

# Loop through each mirror drive and apply the parted command to
# each of them as long as their partitions match in size and position
for mirror_drive in $mirror_drives; do

  # Check if all partitions are identical in size and position
  if ! are_partitions_identical $primary_drive $mirror_drive; then



  fi

done



# Output the list of primary partitions
echo "Primary Nest Drive Partitions: $primary_partitions"

# Get list of all drives passed to the script and create a partition
# for every primary nest drive partition
for drive in $@; do

  # Don't configure the primary drive as a mirror if that was passed
  if [[ "$drive" == "$primary_drive" ]]; then
    echo "Cannot configure primary drive as a mirror: $drive"
    continue
  fi

  # If the drive is not already a mirror drive, ask if the user wants to
  # make it one, and warn that doing so will wipe the data on the drive
  is_mirror=$(lsblk -o PATH,PARTLABEL | grep "$drive" | grep "nest-mirror")
  if [[ -z "$is_mirror" ]]; then

    # Ask the user if they want to make the drive a mirror
    echo "The drive, $drive, is not a mirror drive. Do you want to make it one? (y/n)"
    read make_mirror
    if [[ "$make_mirror" != "y" ]]; then
      echo "Skipping drive: $drive"
      continue
    fi

    # Alert the user that the all data will be lost on this drive
    echo "All data on this drive will be lost if you continue. Are you sure? (y/n)"
    read make_mirror
    if [[ "$make_mirror" != "y" ]]; then
      echo "Skipping drive: $drive"
      continue
    fi 

    # Open gdisk and create a new partition table (THIS WILL WIPE THE DATA ON THE DRIVE)
    #  o - Create a new empty GUID partition table (GPT)
    #  y - Confirm that you want to do this
    #  w - Write changes
    #  y - Confirm changes
    echo -e "o\ny\nw\ny" | sudo gdisk "$drive"
    echo "Created new GUID partition table on drive: $drive"

  fi

  # Output the drive we're configuring as a mirror
  echo "Configuring mirror drive: $drive"

  # Use the list of partitions on the primary drive to create equivalent
  # partitions (in size and label) on the mirror drive
  for primary_partition in $primary_partitions; do

    # Get the label and size of this partition
    primary_partition_row=$(get_partition_row "$primary_partition")
    primary_partition_label=$(echo "$primary_partition_row" | cut -d ' ' -f 3)
    primary_partition_size=$(echo "$primary_partition_row" | cut -d ' ' -f 2)

    # Each partition on the primary drive must have a label
    # If it doesn't, then skip it
    if [[ -z "$primary_partition_label" ]]; then
      echo "Each partition on the primary drive must have a label. No label found for partition: $primary_partition"
      echo "Skipping..."
      continue
    fi

    # Each partition on the primary drive must have a size
    # If it doesn't, then skip it
    if [[ -z "$primary_partition_size" ]]; then
      echo "Could not detect partition size for partition: $primary_partition"
      echo "Skipping..."
      continue
    fi

    # If the partition is labeled "nest-primary", then we need to check for
    # a corresponding partition labeled "nest-mirror" on the mirror drive.
    # Otherwise, we look for partitions on the mirror drive with the same label
    if [[ "$primary_partition_label" == "nest-primary" ]]; then
      primary_partition_label="nest-mirror"
    fi

    # Search for a matching partition on the mirror drive
    mirror_partition=$(get_partition_path "$drive" "$primary_partition_label")

    # If the partition is not found on the mirror drive, then create
    # a new partition with the same size and label
    if [[ -z "$mirror_partition" ]]; then

      # Log that we're creating a new partition
      echo "Creating new partition, $primary_partition_label, with size, $primary_partition_size, on mirror drive: $drive"
      
      # TODO: Use gdisk to create new partition
      #   n
      #   -
      #   -
      #   +$size
      #   0700
      #   w
      #   y

      # Continue to next partition
      continue

    fi

    # If the partition does exist on the mirror drive, then we need to
    # get the size and number of the partition to do any resizing
    mirror_partition_row=$(get_partition_row "$mirror_partition")
    mirror_partition_size=$(echo "$mirror_partition_row" | cut -d ' ' -f 2)
    mirror_partition_number=$(parse_partition_number "$mirror_partition")

    # If the sizes don't match, then resize the partition
    if [[ "$primary_partition_size" != "$mirror_partition_size" ]]; then

      # Resize the filesystem on the partition
      sudo ntfsresize --size "$primary_partition_size" "$mirror_partition"

      # Resize the partition
      echo -e "resizepart $mirror_partition_number $primary_partition_size\nquit" | sudo parted "$drive"

      # Check health of filesystem
      sudo ntfsfix "$mirror_partition"

    fi

  done

done