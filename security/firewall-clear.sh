#!/bin/bash
set -euo pipefail

# Set default policy to allow
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# Clear all rules
sudo iptables -F # flush all chains
sudo iptables -X # delete all chains
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
