FROM debian:12-slim@sha256:5fb19f759c4aedbb1bdcd51901f6300056f94411f12667dbb58b723cd509d973

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      gettext-base \
      dnsmasq \
      dnsutils \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/misc /etc/dnsmasq.d

COPY --from=lib helpers.sh /usr/local/lib/mezz/helpers.sh
COPY dnsmasq.conf.tpl /etc/dnsmasq.conf.tpl
COPY entrypoint.sh /entrypoint.sh

# Drop-in for user *.conf files. Mount your own dir to extend.
VOLUME /etc/dnsmasq.d

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/dnsmasq", "--keep-in-foreground", "--conf-file=/etc/dnsmasq.conf"]
