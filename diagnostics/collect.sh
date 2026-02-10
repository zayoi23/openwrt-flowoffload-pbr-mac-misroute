#!/usr/bin/env sh
set -euo pipefail

# Collects routing, nft, neighbor, conntrack, and tcpdump outputs.
# Run on OpenWrt or generic Linux. Needs: nft, ip, conntrack (if available), tcpdump.

OUT_DIR=${OUT_DIR:-/tmp/offload-pbr-diag}
CAP_SECONDS=${CAP_SECONDS:-5}
LAN_IF=${LAN_IF:-br-lan}
WAN_IF=${WAN_IF:-wan}
TCPDUMP_FILTER=${TCPDUMP_FILTER:-"udp port 53"}

mkdir -p "$OUT_DIR"
log() { echo "[collect] $*"; }

log "output -> $OUT_DIR"

nft list ruleset >"$OUT_DIR/nft-ruleset.txt" || true
nft list flowtable | sed 's/^/    /' >"$OUT_DIR/nft-flowtable.txt" || true
ip rule show >"$OUT_DIR/ip-rule.txt"
ip route show table all >"$OUT_DIR/ip-route.txt"
ip -s neigh show >"$OUT_DIR/ip-neigh.txt"

if command -v conntrack >/dev/null 2>&1; then
  conntrack -L >"$OUT_DIR/conntrack.txt" || true
fi

log "capturing $CAP_SECONDS seconds on $LAN_IF and $WAN_IF"
if command -v tcpdump >/dev/null 2>&1; then
  tcpdump -nn -e -i "$LAN_IF" -w "$OUT_DIR/lan.pcap" $TCPDUMP_FILTER -G "$CAP_SECONDS" -W 1 >/dev/null 2>&1 || true
  tcpdump -nn -e -i "$WAN_IF" -w "$OUT_DIR/wan.pcap" $TCPDUMP_FILTER -G "$CAP_SECONDS" -W 1 >/dev/null 2>&1 || true
fi

log "done"
