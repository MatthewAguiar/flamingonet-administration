#!/bin/bash

#
# deploy-nest-scripts.sh
#
# This script deploys the latest client scripts from the main branch
# of https://github.com/MatthewAguiar/flamingonet-client-scripts
#
# These scripts are dowloaded for use on client devices
#

# Strict Mode - https://redsymbol.net/articles/unofficial-bash-strict-mode/
#
#   set -e           Causes script to immediately exit if any command's return status in non-zero
#   set -u           Causes script to immediately exit if a variable is referenced that is not defined
#   set -o pipefail  If an error happens in a pipeline, the return code is that of the failed command
#
set -euo pipefail

# Install git if not already installed
git --version > /dev/null || sudo apt install -y git

# Navigate to the FlamingoNet directory
cd /flamingonet

# Clone the latest nest scripts
git clone https://github.com/MatthewAguiar/flamingonet-client-scripts
mv flamingonet-client-scripts/scripts client-scripts
rm -rf flamingonet-client-scripts