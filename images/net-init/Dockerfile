FROM debian:12-slim@sha256:5fb19f759c4aedbb1bdcd51901f6300056f94411f12667dbb58b723cd509d973

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bridge-utils \
      net-tools \
      iptables \
      procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=lib helpers.sh /usr/local/lib/mezz/helpers.sh
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["init"]
