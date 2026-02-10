# OpenWrt Flow Offload + PBR + NAT Wrong-MAC Reproducer

This repository reproduces, diagnoses, and mitigates an OpenWrt 24.10.0 bug where enabling software or hardware flow offloading can misdeliver policy-routed NAT traffic to the wrong LAN MAC address (often the MAC of the PBR next-hop/VPN gateway). It ships a netns lab, diagnostics bundle, and an OpenWrt-ready mitigation that excludes risky flows from flow offload.

## Quick start (Linux host)

### Lab options
- `FLOW_OFFLOAD=1` enables nft flowtable offload; default 0.
- `MITIGATION=0` disables the guard rules inside the lab to demonstrate the risky path.
- `USE_PBR_MARK=0` avoids tagging DNS flows with fwmark 0xff (table 100); default 1.
- `DNS_QUERIES=<n>` controls concurrent UDP queries (default 4) to stress flowtable.
- `CLEAN_LOGS=1` removes previous `reproducer/output/*.{pcap,log}` on cleanup.

## OpenWrt hotfix (firewall4 include)
- Apply mitigation: `ssh root@router 'sh -s' < mitigation/apply.sh`
- Rollback: `ssh root@router 'sh -s' < mitigation/rollback.sh`
- The include adds nftables rules that skip flow offload when `meta mark != 0` (PBR-marked traffic) or when `ct status { dnat, snat }` is present. Performance impact is limited to policy-routed/NATted flows.

## Repository layout
- README.md — overview, quick start, upstreaming notes.
- docs/theory-of-failure.md — packet path analysis, hypotheses, measurements.
- reproducer/ — netns lab and traffic generator.
- diagnostics/ — data collection helper.
- mitigation/ — firewall4-compatible mitigation and installer/rollback.
- patches/ — proposed firewall4 change and guidance for kernel/nftables report.
- scripts/smoke-test.sh — CI-friendly check of lab and mitigation.

## Filing upstream / artifacts to attach
When filing upstream bugs (OpenWrt firewall4, netfilter, or kernel), attach:
- `nft list ruleset` and `nft list flowtable inet ftoffload` output
- `ip rule show`, `ip route show table all`, `ip -s neigh show`
- `conntrack -L` excerpt for affected flows
- `tcpdump -e` traces showing wrong destination MAC vs expected
- Flowtable counters before/after mitigation

## Running on OpenWrt
- Install dependencies: `opkg update && opkg install tcpdump conntrack-tools` (nftables/firewall4 are present by default in 24.10.0 images).
- Copy `diagnostics/collect.sh` to the router (or run via `scp && ssh`).
- Apply mitigation via `mitigation/apply.sh`.
- Re-run diagnostics after reproducing to confirm offload exclusion of marked/NAT flows.

## Upstream patch proposal (high level)
- firewall4: in `ft_offload` chain (or equivalent flowtable hook), add a guard `meta mark != 0 return` and `ct status { dnat, snat } return` before `flow add @ft`. See [patches/firewall4-flowoffload-pbr.patch](patches/firewall4-flowoffload-pbr.patch).
- Kernel/netfilter: investigate flowtable neighbor/route caching interaction with skb marks and NAT, particularly on mt7621 hw offload path; ensure dst/neighbor ref invalidation on mark/routing changes.

## Notes
- Scripts are idempotent and exit on error (`set -euo pipefail`).
- The lab targets correctness over throughput; mitigation is deliberately conservative to avoid misdelivery.
