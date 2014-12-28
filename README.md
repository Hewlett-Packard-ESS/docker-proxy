# docker-proxy
The purpose of this container is to ease some of the networking issues working with isloated docker containers - for example, proxy configuration, DNS resolution (host files etc).

It contains the following software:
  - dnsmasq (v
  - squid (v3.5.0.4, patched)

Running this container will modify IP Tables on your host to NAT the configured traffic from docker containers to this container, where the request will be handled in a single place (transparent http/https with squid and transparent dns with dnsmasq).  Upon stopping the container these rules get removed:
```
iptables stdout | iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to 53 -w
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to 3130 -w
Please wait, tidying up IP Tables...
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to 53 -w
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to 3130 -w
```

## Use
The easiest way (or at least my preferred way) is by using a fig file.  Please note that the container MUST be privileged and net HOST for this to work.
```
trans:
  image: hpess/dockerproxy
  privileged: true
  environment:
    cache_peer: 'your.proxy.com'
    cache_peer_port: 8080
    insecure: 'true'
    local_servers: "172.19.0.0/12"
    nameservers: "172.19.2.5,172.19.2.6"
    hosts: 'your-host1=127.0.0.2,your-host2=127.0.0.3'
  net: "host"
```
The available environment variables are:
  - cache_peer: This is your corporate/second proxy that squid should backend on to.
  - cache_peer_port: The port of your second proxy, defaults to 8080
  - insecure: Will allow transparent https to be reverse proxied to a http cache_peer, defaults to false.
  - local_servers: Subnets that squid should always go directly to, bypassing cache_peer, defaults to []
  - nameservers: Additional DNS servers that you want dnsmasq to use for resolution
  - hosts: Additional host file entried that you want dnsmasq to use for resolution.

## Caveats
There are several.  Please take note of these:
  - This container should be run as a privileged container, with net host.  That pretty much gives it outright access to your host.  The reason for this is we need to configure the iptables routing on your host for docker containers, plus we need to access network resources that your host has acccess to.
  - This container patches squid to enable intercept and relay SSL CONNECT requests to insecure (http) peers.  It's really important you pay attention to this, basically any https requests that squid intercepts will be translated to http APART from subnets specified in the local_servers environment variable (they'll go as SSL, but will be presented to the client as an insecure self-signed certificated due to squids ssl-bump).

## Firewalls
I've noticed that firewalld likes to cause you issues, as a result you'll need to allow the traffic on your host (or disable firewalld):
```
firewall-cmd --zone=<whatever/public> --add-port=53/udp
firewall-cmd --zone=<whatever/public> --add-port=3129/tcp
firewall-cmd --zone=<whatever/public> --add-port=3130/tcp
```
