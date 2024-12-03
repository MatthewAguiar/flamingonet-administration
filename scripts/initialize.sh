#!/bin/bash

#
# initialize.sh
#
# This script initializes the FlamingoNet Nest server.
# It installs the necessary software, configures the necessary
# services and any other configurations needed for the FlamingoNet Nest.
#
# Steps to proper Nest bring up:
#   1. Log into Nest locally
#   2. Assign static IP address to Nest
#   3. Run this script
#   4. Reboot Nest

# Strict Mode - https://redsymbol.net/articles/unofficial-bash-strict-mode/
#
#   set -e           Causes script to immediately exit if any command's return status in non-zero
#   set -u           Causes script to immediately exit if a variable is referenced that is not defined
#   set -o pipeline  If an error happens in a pipeline, the return code is that of the failed command
#
set -euo pipefail

# Update all software
sudo apt update
sudo apt upgrade -y

# Install additional software
sudo apt install -y git

# Enable the SSH daemon by default
systemctl enable ssh

#
# The following code builds the FlamingoNet filesystem:
#
# /
#   flamingonet/
#     nest-scripts/
#     client-scripts/
#

# Make the root directory
sudo mkdir -p /flamingonet

# Deploy the nest scripts (these are run on the Nest)
./deploy-nest-scripts.sh

# Deploy the client scripts (these are downloaded and run by clients)
./deploy-client-scripts.sh

# Mount any Nest drives
./mount-nest-drives.sh

# Install Software / Web Apps
./install-part-db.sh