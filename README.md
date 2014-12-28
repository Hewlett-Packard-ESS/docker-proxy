# docker-proxy
The purpose of this container is to ease some of the networking issues working with isloated docker containers - for example, proxy configuration, DNS resolution (host files etc).

It's a nightmare having to ensure all the settings are correct in every container, so this container solves that problem (hopefully).   

It contains the following software:
  - dnsmasq (v2.66)
  - squid (v3.5.0.4, patched)
  - chef (--local-mode, as provided by hpess/docker-chef)

## How it works
Running this container will modify IP Tables on your host to NAT the configured traffic from docker containers to this container, where the request will be handled in a single place (transparent http/https with squid and transparent dns with dnsmasq).  Upon stopping the container these rules get removed:
```
iptables stdout | iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to 53 -w
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to 3130 -w
```
CTRL+C...
```
Please wait, tidying up IP Tables...
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to 53 -w
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to 3130 -w
```
Sometimes, for whatever reason, the iptables rules aren't cleaned up (i'm trying to work on these edge cases).  In this scenario - unless this container is running, your networking from other containers will be buggered.  You can check your iptables rules with:
```
sudo iptables -t nat --line-numbers -L
```
And then remove the rules with:
```
sudo iptables -t nat -D PREROUTING <line number>
```

### DNS Resolution
Your DNS server in your other containers can be set to whatever you like, the traffic will be routed regardless to dnsmasq and the contains will be unaware.

### HTTP
HTTP traffic is transparently proxied by squid, the other contains are blissfully unaware of its presence.

### HTTPS (Important)
Squid is effectively acting as a man in the middle using ssl-bump.  What this does is recieves the clients incoming request and generates a new certificate, signed by squid so that we can read the clients message.  

If the destination server is localnet (as defined in the local_servers environment variable), squid will first get the certificate for that server and use its CN in the certificate generation previously mentioned this is called `ssl-bump server first`.

However, if the destination is the cache_peer we will use `ssl-bump client first`, which means the CN will be set to the IP of the destination, not the CN, and traffic will be sent unencrypted over the cache_peer proxy.  Currently there doesn't seem to be any way of making squid relay intercepted CONNECT requests via another CONNECT request to a cache_peer.

This poses numerous obviously ethical implications, as such be it on your shoulders if you do something stupid with it.  I only use it for internal development environments where there is nothing sensitive going over it anyway.

## Use
The easiest way (or at least my preferred way) is by using a fig file.  Please note that the container MUST be privileged and MUST have net HOST for this to work.
```
trans:
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
```
Or you can just use docker
```
sudo docker run -it --privileged --net=host -e="cache_peer=your.upstream.proxy" hpess/dockerproxy
```
The available environment variables are:
  - cache_peer: This is your corporate/second proxy that squid should backend on to.
  - cache_peer_port: The port of your second proxy, defaults to 8080
  - insecure: Will tell squid not to verify certificates when using ssl-bump.  Useful if you're bumping to servers with self signed certificates.
  - local_servers: Subnets that squid should always go directly to, bypassing cache_peer, defaults to []
  - nameservers: DNS servers that you want dnsmasq to use for resolution, by default we will copy the contents of /etc/resolv.conf.
  - hosts: Additional host file entried that you want dnsmasq to use for resolution on top of the contents of your hosts /etc/hosts file.

From there, just run the container with `sudo fig run trans` and you should see a bunch of chef configuration and then services starting, it should only take about 10seconds and then its all done, your other containers should be using this one for dns and web.

## Firewalls
I've noticed that firewalld likes to cause you issues, as a result you'll need to allow the traffic on your host (or disable firewalld):
```
firewall-cmd --zone=<whatever/public> --add-port=53/udp
firewall-cmd --zone=<whatever/public> --add-port=3129/tcp
firewall-cmd --zone=<whatever/public> --add-port=3130/tcp
```
