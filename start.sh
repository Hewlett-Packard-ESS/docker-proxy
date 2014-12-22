#!/bin/bash
chown squid:squid /var/cache/squid
[ -e /var/cache/squid/swap.state ] || squid -z 2>/dev/null

#sleep 5
echo "Running squid..."

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

# Run squid 
squid -N

echo "Exiting squid..."
