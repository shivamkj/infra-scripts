#!/bin/bash
set -euo pipefail

bash firewall-clear.sh

# Allow previously initiated and accepted exchanges bypass rule checking
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

# Open SSH or any other required ports
SSH_PORT=22
sudo iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT

# Allow all loopback traffic (important for local system processes)
# Basically, allows localhost connections
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Set Default rules to deny
sudo iptables -P INPUT DROP   # Drop all incoming traffic
sudo iptables -P FORWARD DROP # Drop all forwarding traffic
sudo iptables -P OUTPUT DROP  # Drop all outgoing traffic

# Set iptables-persistent prefrences to avoid prompt during installation
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
# Install iptables-persistent for saving rules
sudo apt-get install -y --no-install-recommends iptables-persistent
sudo netfilter-persistent save
