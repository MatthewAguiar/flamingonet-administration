#!/bin/bash

#
# nest-drives-mount.sh
#
# Procedure for mounting nest drives:
#
#   1. Determine which drive (/dev/sda? /dev/sdb? etc) is the primary and which are mirrors.
#      This can be done by searching for a small partition labeled "primary", to signify
#      a primary drive (can only be one). Mirrors will have a small partition labeled
#      "mirror" to signify a mirror (can be many). These small partitions could be useful for storing
#      metadata as well. Note, these drives will have one partition for each user.
#      So a drive with partition, "primary", and partition, "matthew", signifies that
#      that's matthew's primary partition.
#
#   2. Modify the /etc/fstab file as needed to mount these partitions under
#      /flamingonet/nest-storage/primary/{matthew} /flamingonet/nest-storage/primary/{jane} ...
#      /flamingonet/nest-storage/mirror1/{matthew} /flamingonet/nest-storage/mirror1/{jane} ...
#      /flamingonet/nest-storage/mirror2/{matthew} /flamingonet/nest-storage/mirror2/{jane} ...
#
#      If no nest drives are found, then leave the fstab file as is and don't
#      make the /flamingonet/nest-storage directory.
#
#      If only a primary drive is found, simply mount that and warn that there are no mirrors.
#
#      If only mirror(s) are found then ask if you'd like to mark one of them as primary.
#      Should be as simple as updating the label of the small partition to "primary", since
#      mirrors are just clones of the primary.
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

# Iterate through the list of block devices and use the labels "nest-primary" and "nest-mirror" 
# on partitions to detect primary and mirror drive
echo "Searching for nest drives..."
blks=$(lsblk -o PATH,PARTLABEL)
primary_drive=""
mirror_drives=""
while read -r line; do

  # Read the block device path (everything up to the first space)
  path=${line% *}

  # Read the block device label (everything after the first space)
  label=${line#* }

  # If the label is "nest-primary", then this is the primary drive
  # Otherwise, if the label is "nest-mirror", then this is a mirror
  # TODO: Investigate nvme partitions just for fun to see if we need to remove more than just [0-9]?*
  if [[ -z "$primary_drive" && $label =~ "nest-primary" ]]; then
    primary_drive=${path%[0-9]?*}
  elif [[ $label =~ "nest-mirror" ]]; then
    mirror_drives="$mirror_drives ${path%[0-9]?*}"
    mirror_drives=${mirror_drives# }
  fi

done <<< $blks

primary_partitions=$(ls $primary_drive?*)
if [[ -n "$primary_drive" ]]; then
  echo "Found primary drive: $primary_drive"
  echo "Found primary partitions: $primary_partitions"
  get_partition_label $primary_partitions
fi

if [[ -n "$mirror_drives" ]]; then
  echo "Found mirror drives: $mirror_drives"
  # echo "Found mirror partitions: $(ls $mirror_drives?*)"
fi

if [[ -z "$primary_drive" && -z "$mirror_drives" ]]; then
  echo "No nest drives found. You can run mount-nest-drives.sh to try again."
  exit 0
fi
