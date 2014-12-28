# docker-proxy
The purpose of this container is to ease some of the networking issues developing with isolated docker containers - for example, proxy configuration, DNS resolution (host files etc).

It's a nightmare having to ensure all the settings are correct in every container, and then further to that working from different locations (so proxy sometimes, not others) so this container solves that problem (hopefully).   

It contains the following software:
  - dnsmasq (v2.66)
  - squid (v3.5.0.4, patched)
  - chef (--local-mode, as provided by hpess/chef)

## How it works
Running this container will modify IPTables on your host to NAT the configured traffic from docker containers to this container, where the request will be handled in a single place (transparent http/https with squid and transparent dns with dnsmasq).  Upon stopping the container these rules get removed:
```
iptables stdout | iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to 53 -w
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to 3130 -w
```
CTRL+C...
```
Please wait, tidying up IPTables...
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to 53 -w
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to 3130 -w
```
If for whatever reason you stop this container and it doesn't tidy up the iptables rules (it should...) you can check them with this:
```
sudo iptables -t nat --line-numbers -L
```
And then remove the rules with:
```
sudo iptables -t nat -D PREROUTING <line number>
```

### DNS Resolution
Your DNS server in your other containers can be set to whatever you like, the traffic will be routed regardless to dnsmasq and the contains will be unaware.

dnsmasq will use the nameservers you specify in the nameservers environment variable.  If you don't pass any name servers it will use the /etc/resolv.conf from your host.

### HTTP
HTTP traffic is transparently proxied by squid, the other containers are blissfully unaware of its presence and everything should just work (TM).

### HTTPS (Important, please read and absorb...)
Squid is effectively acting as a man in the middle using ssl-bump.  What this does is intercepts the clients incoming request and generates a new certificate, signed by squid so that we can read the clients message.  

Take this curl from a container to https://www.google.co.uk for example:
```
* Server certificate:
*   subject: CN=www.google.com,O=Google Inc,L=Mountain View,ST=California,C=US
*   start date: Dec 10 12:05:39 2014 GMT
*   expire date: Mar 10 00:00:00 2015 GMT
*   common name: www.google.com
*   issuer: OID.2.5.29.17="DNS.1=*,DNS.2=*.*,DNS.3=*.*.*",C=UK,O=HP,CN=squid.docker.local
```
You can see the subject matches the real certificate, but its been issued by squid.  This is an example of `ssl-bump server-first`, where squid has grabbed the certificate from the target of the CONNECT which was intercepted and used it to generate the new certificate.

ssl-bump server-first is used in the following situations:
  - Your destination is in a subnet defined in the localnet acls (the local_servers environment variable)
  - You have not specified an upstream cache_peer, subsequently all requests are going direct.
  - You have specified an upstream cache_peer which supports ssl (NOTE: not currently implemented)

ssl-bump client-first is the backup option, what this does is sets the CN of the certificate equal to the target IP of the intercepted CONNECT.

ssl-bump client-first is used in the following situations:
  - You have specified an upstream cache_peer which does not support SSL.

Currently there doesn't seem to be any way to relay an intercepted CONNECT to a HTTP cache_peer via a new CONNECT tunnel.  Therefore any traffic sent by the client to squid as HTTPS will end up going to the cache_peer unencrypted (HTTP) if your cache_peer is not configured with the ssl flag.

The version of squid in this container is patched to allow this behaviour, however it obviously poses numerous obvious ethical and security implications, as such be it on your shoulders if you do something stupid with it.  I only use it for internal development environments where there is nothing sensitive going over it anyway.  It's entirely your responsibility to inform anyone who uses this container in the configuration mentioned above of the risks.

#### Squid signed certificates...
As you've seen above, certificates in a ssl-bump server-first scenario will be valid, apart from the issuer.

You a few options here
  1. Install the CA file generated and outputted during `fig up` on the other containers
  2. Use `insecure` options such as curl -k
  3. Create your own Dockerfile, inheriting from hpess/dockerproxy which copies a trusted CA key.pem and cert.pem to /etc/squid/ssl_cert which will be used for signing.

## Use
The easiest way (or at least my preferred way) is by using a fig file and storing configurations for the different places that I work.  Please note that the container MUST be privileged and MUST have net HOST for this to work.
```
corp:
  image: hpess/dockerproxy
  privileged: true
  net: "host"
  environment:
    cache_peer: 'your.upstream.proxy'
    cache_peer_port: 8080
    insecure: 'true'
    local_servers: "172.19.0.0/12"
    nameservers: "172.19.2.5"
    hosts: "somehost=172.19.0.3"

home:
  image: hpess/dockerproxy
  privileged: true
  net: "host"
  nameservers: "8.8.8.8 8.8.4.4"
```
And type `sudo fig up <corp/home>` of `sudo fig up <corp/home> -d` if you want to daemonize.

Or you can just use docker
```
sudo docker run -it --rm --privileged --net=host -e="cache_peer=your.upstream.proxy" hpess/dockerproxy
```
The available environment variables are:
  - cache_peer: This is your corporate/second proxy that squid should backend on to, if you don't specify an upstream proxy - all requests will be sent direct (always_direct)
  - cache_peer_port: The port of your second proxy, defaults to 8080
  - insecure: Will tell squid not to verify certificates when using ssl-bump.  Useful if you're bumping to servers with self signed certificates.
  - local_servers: Subnets that squid should always go directly to, bypassing cache_peer, defaults to []
  - nameservers: DNS servers that you want dnsmasq to use for resolution, by default we will copy the contents of /etc/resolv.conf.
  - hosts: Additional host file entries that you want dnsmasq to use for resolution on top of the contents of your hosts /etc/hosts file.

Chef configuration and starting of services takes 5 seconds or so, but then you'll be good to go.

## Firewalls
I've noticed that firewalld likes to cause you issues, as a result you'll need to allow the traffic on your host (or disable firewalld):
```
firewall-cmd --zone=<whatever/public> --add-port=53/udp
firewall-cmd --zone=<whatever/public> --add-port=3129/tcp
firewall-cmd --zone=<whatever/public> --add-port=3130/tcp
```
Use --permanent if you want the rules to persist.
