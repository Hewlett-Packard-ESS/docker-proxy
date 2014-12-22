FROM hpess/base:latest
RUN http_proxy=http://proxy.sdc.hp.com:8080 https_proxy=http://proxy.sdc.hp.com:8080 yum -y install squid python dnsmasq net-tools telnet bind-utils && \
    yum -y clean all

ADD squid.conf /etc/squid/squid.conf
RUN mkdir -p /var/cache/squid
RUN chown -R squid:squid /var/cache/squid
ADD start.sh /usr/local/bin/start.sh
ADD iptables.py /usr/local/bin/iptables.py

# dnsmasq configuration
RUN echo 'resolv-file=/etc/resolv.dnsmasq.conf' >> /etc/dnsmasq.conf && \
    echo 'conf-dir=/etc/dnsmasq.d' >> /etc/dnsmasq.conf

# es labs dns
#RUN echo 'nameserver 172.19.2.5' >> /etc/resolv.dnsmasq.conf

# google dns, set the dnsmasq user to run as root
#RUN echo 'nameserver 8.8.8.8' >> /etc/resolv.dnsmasq.conf && \
#    echo 'nameserver 8.8.4.4' >> /etc/resolv.dnsmasq.conf && \
#    echo 'user=root' >> /etc/dnsmasq.conf

#RUN echo 'address="/esscontrol-npm/172.19.3.16"' >> /etc/dnsmasq.d/00hosts
ADD dnsmasq.service.conf /etc/supervisord.d/dnsmasq.service.conf
ADD squid.service.conf /etc/supervisord.d/squid.service.conf
ADD iptables.service.conf /etc/supervisord.d/iptables.service.conf
