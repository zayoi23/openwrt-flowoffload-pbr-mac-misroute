# Theory of failure: flow offload + PBR + NAT wrong-MAC delivery

## Packet path without flow offload
1. Packet enters router (prerouting): conntrack allocates entry, NAT DNAT may run.
2. Routing decision: `ip rule` consulted (fwmark → table 100 for PBR; otherwise main table).
3. Neighbour resolution: ARP/ND for chosen egress.
4. Postrouting: SNAT/mangle adjustments, checksum fixup.
5. Egress: skb sent to correct L2 next-hop (neighbor entry populated).

## What flow offload changes
- Flowtable caches 5-tuple + output device + L2 neighbor information and bypasses slow path after first packets.
- skb mark and CT status may be snapshotted into flowtable entry; later route changes or mark updates may not re-evaluate.
- Hardware offload (e.g., mt7621) may program switch/ASIC tables based on early neighbor lookups.

## Competing hypotheses
- **Mark propagation bug:** Return packets inherit cached wrong `skb->mark` or bypass `ip rule`, leading to lookup in table 100 and neighbor = VPN gateway MAC.
- **Flowtable dst/neighbor caching bug:** Flowtable stores neighbor for the PBR next-hop seen during first packet and never refreshes when NAT/conntrack flips direction, delivering LAN-bound replies to the cached MAC.
- **Conntrack mark vs skb mark confusion:** `ct mark` differs from `skb mark`; flowtable may select output interface based on stale mark.
- **Asymmetric routing and stale ARP:** Dual A/AAAA queries produce near-simultaneous flows; early flow caches neighbor of VPN gateway, second flow reuses it after NAT rewrites, causing misdelivery.

## Measurements that differentiate
- `nft monitor trace` on router: confirm whether flowtable is hit and which chain sets mark; observe output device chosen.
- `nft list flowtable inet ftoffload`: inspect cached devices/counters; ensure marked/NAT flows do not appear after mitigation.
- `ip -s neigh show`: look for stale or unexpectedly used neighbors (VPN gateway MAC spikes when flow offload on).
- `conntrack -L` / `conntrack -E`: verify DNAT/SNAT tuples correct while L2 delivery is wrong.
- `tcpdump -e -i <lan>`: capture wrong destination MAC alongside correct L3 addresses; compare with same test when offload is disabled.

## Mitigation rationale
- Exclude risky flows from flow offload: any with non-zero `skb mark` (policy-routed) or with `ct status` indicating NAT (`dnat`, `snat`).
- This keeps PBR/NAT traffic in the slow path where routing + neighbor lookup is re-evaluated per packet, avoiding stale flowtable caches.
- Performance impact is bounded to marked/NAT flows; bulk unmarked LAN↔WAN traffic still uses flow offload.
