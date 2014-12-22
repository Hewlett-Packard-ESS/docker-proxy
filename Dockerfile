FROM hpess/base:latest
# Install pre-reqs
RUN yum -y install squid python dnsmasq net-tools telnet bind-utils && \
    yum -y clean all

# dnsmasq configuration
RUN mkdir -p /var/cache/squid && \
    chown -R squid:squid /var/cache/squid && \
    echo 'resolv-file=/etc/resolv.dnsmasq.conf' >> /etc/dnsmasq.conf && \
    echo 'conf-dir=/etc/dnsmasq.d' >> /etc/dnsmasq.conf

#RUN echo 'address="/esscontrol-npm/172.19.3.16"' >> /etc/dnsmasq.d/00hosts
ADD squid.conf /etc/squid/squid.conf
ADD start.sh /usr/local/bin/start.sh
ADD iptables.py /usr/local/bin/iptables.py

ADD dnsmasq.service.conf /etc/supervisord.d/dnsmasq.service.conf
ADD squid.service.conf /etc/supervisord.d/squid.service.conf
ADD iptables.service.conf /etc/supervisord.d/iptables.service.conf

ENTRYPOINT ["/bin/sh"]
CMD ["/usr/local/bin/start.sh"]
