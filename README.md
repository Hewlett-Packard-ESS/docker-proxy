# docker-proxy
The purpose of this lovely little container is to solve all of the woes of working behind a corporate proxy and wanting to use docker.

Not only that, but allow you to use resources which your host has access to, via VPNs for example.

If any of the above cause you issues, this container is for you.

## Setup
The container runs both squid and dnsmasq in a transparent fashion.
On start up, the container will add some prerouting rules to your iptables tables which will route all port 80, 443 and 53/udp traffic from docker containers through to squid/dnsmasq.

squid/dnsmasq will then backend onto the resources you configure.

And voilla, no more having to worry about proxy or dns in your containers!

## Running
The easier way is using a fig file:
```
saveMeFromCorporateChains:
  image: hpess/docker-proxy
  privileged: true
  environment:
    NAMESERVERS: "8.8.8.8 8.8.4.4"
  net: "host"
```
From there, just do fig up -d and give it 5-10s to sort its stuff out and you're good to go - you should have functioning DNS and Web from your containers.

## Firewalls
I've noticed that firewalld likes to cause you issues, as a result you'll need to allow the traffic on your host:
```
firewall-cmd --zone=<whatever/public> --add-port=53/udp
firewall-cmd --zone=<whatever/public> --add-port=3129/tcp
firewall-cmd --zone=<whatever/public> --add-port=3130/tcp
```
