#!/bin/bash
set -e
chown squid:squid /var/cache/squid

# Apply the changes to the squid config
cd /storage && chef-client -l error -z -N squid.docker.local -o squid,dnsmasq,iptables

# Setup the squid cache dirs
[ -e /var/cache/squid/swap.state ] || squid -z 2>/dev/null

sleep 3
supervisord -c /etc/supervisord.conf -j /var/run/supervisor.pid
