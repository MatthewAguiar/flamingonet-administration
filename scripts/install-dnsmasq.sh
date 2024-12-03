#!/bin/bash

#
# install-dnsmasq.sh
#
# This script follows the steps outlined here to setup a DNSMasq server
# https://www.youtube.com/watch?v=2KYeUCorJ-M
#

# Strict Mode - https://redsymbol.net/articles/unofficial-bash-strict-mode/
#
#   set -e           Causes script to immediately exit if any command's return status in non-zero
#   set -u           Causes script to immediately exit if a variable is referenced that is not defined
#   set -o pipefail  If an error happens in a pipeline, the return code is that of the failed command
#
set -euo pipefail

# Disable the systemd-resolved service as that is listening on the same port DNSMasq
# will listen on (53)
sudo systemctl stop systemd-resolved || echo "systemd-resolved not running"
sudo systemctl disable systemd-resolved || true

# Rename the /etc/resolv.conf file to /etc/resolv.conf.bak
sudo mv /etc/resolv.conf /etc/resolv.conf.bak

# Install DNSMasq
sudo apt update
sudo apt install dnsmasq

# Copy the dnsmasq.conf file to the /etc/dnsmasq.d directory to make it available for DNSMasq
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
sudo cp ../dnsmasq/dnsmasq.conf /etc/dnsmasq.conf

# (Re)start the dnsmasq service with
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq