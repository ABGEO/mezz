FROM debian:12-slim@sha256:5fb19f759c4aedbb1bdcd51901f6300056f94411f12667dbb58b723cd509d973

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      gettext-base \
      hostapd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=lib helpers.sh /usr/local/lib/mezz/helpers.sh
COPY hostapd.conf.tpl /etc/hostapd/hostapd.conf.tpl
COPY entrypoint.sh /entrypoint.sh

RUN [ -f /etc/default/hostapd ] && sed -i 's|#DAEMON_CONF=.*|DAEMON_CONF=/etc/hostapd/hostapd.conf|' /etc/default/hostapd || true

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/hostapd", "/etc/hostapd/hostapd.conf"]
