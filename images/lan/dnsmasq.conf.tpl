# Bind only on the bridge + loopback (loopback for healthcheck)
interface=$BR_IFACE
bind-interfaces
listen-address=127.0.0.1,$LAN_IP

# DNS hygiene
domain-needed
bogus-priv
no-resolv
server=$LAN_DNS_UPSTREAM
cache-size=1000
# Strip AAAA records: forces clients to IPv4 since v6 is suppressed at the host
filter-AAAA

# Logging
log-facility=-
log-queries
log-dhcp

# Local domain - clients get e.g. "kitchen-pi.lan"
domain=$LAN_DOMAIN
local=/$LAN_DOMAIN/
expand-hosts

# DHCP
dhcp-range=$LAN_DHCP_START,$LAN_DHCP_END,$LAN_NETMASK,12h
dhcp-option=3,$LAN_IP
dhcp-option=6,$LAN_IP
dhcp-authoritative
dhcp-leasefile=/var/lib/misc/dnsmasq.leases

# Drop-in for user *.conf files. Mount /etc/dnsmasq.d to extend.
conf-dir=/etc/dnsmasq.d,*.conf
