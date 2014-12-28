#!/bin/bash
set -e
chown squid:squid /var/cache/squid

# Apply the changes to the squid config
echo "Please wait, performing surface level configuration..."
cd /storage && chef-client -Fmin -z -N squid.docker.local -o squid,dnsmasq,iptables

# Setup the squid cache dirs
echo "Please wait, initialising squid cache directories..."
[ -e /var/cache/squid/swap.state ] || squid -z 2>/dev/null

# Generate the certificates used for signing
echo "Please wait, validating SSL setup for ssl-bump..."
if [ ! -f /etc/squid/ssl_cert/key.pem ]; then
  echo "Key used for HTTPS not found.  Will generate..."
  cd /etc/squid/ssl_cert && \
  openssl req -subj "/CN=squid.docker.local/O=FakeOrg/C=UK/subjectAltName=DNS.1=*,DNS.2=*.*,DNS.3=*.*.*" -new -newkey rsa:2048 -days 1365 -nodes -x509 -sha256 -keyout key.pem -out cert.pem
else
  echo "Existing key found."
fi

# Output the certificate for people to use
echo "The CA certificate that will be used for signing is:"
cat /etc/squid/ssl_cert/cert.pem

# Set the ownership of stuff
chown -R squid:squid /etc/squid

echo "Done!  Starting Supervisor..."
exec supervisord -c /etc/supervisord.conf -j /var/run/supervisor.pid &
SPID="$!"
echo "Supervisor PID: $SPID"

trap "kill $SPID >/dev/null 2>&1 && wait $SPID" exit INT TERM

wait $SPID
