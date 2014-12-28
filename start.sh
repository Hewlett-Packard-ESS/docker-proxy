#!/bin/bash
set -e
chown squid:squid /var/cache/squid

touch /etc/resolv.dnsmasq.conf
add_line () {
  grep -q -F "$1" $2 || echo $1 >> $2
}

NAMESERVERS=${NAMESERVERS:-"8.8.8.8 8.8.4.4"}
for i in $NAMESERVERS 
do
  echo "Setting nameserver $i..."
  add_line "nameserver $i" "/etc/resolv.dnsmasq.conf"
done

# Apply the changes to the squid config
cd /storage && chef-client -z -N squid.docker.local -o squid,dnsmasq

# Setup the squid cache dirs
[ -e /var/cache/squid/swap.state ] || squid -z 2>/dev/null
sleep 3
supervisord -c /etc/supervisord.conf -j /var/run/supervisor.pid
