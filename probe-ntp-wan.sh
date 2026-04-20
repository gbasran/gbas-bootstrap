#!/bin/sh
# probe-ntp-wan.sh — one-shot UDP/123 reachability test from the public internet.
#
# Purpose: verify OPNsense NTP hardening (1E.1 Phase 4-B Tier 4a) has closed
#          ntpd listening on the WAN interface. Must run from a network that
#          is OUTSIDE your LAN (cellular, coffee shop WiFi, etc.).
#
# Usage on iPhone via iSH:
#   1. Turn OFF the WireGuard tunnel in the WG app (so traffic hits cellular,
#      not the tunnel back into your own LAN).
#   2. In iSH:  curl -fsSL https://raw.githubusercontent.com/gbasran/gbas-bootstrap/main/probe-ntp-wan.sh | sh
#   3. Turn WG back ON when done.
#
# Uses python3 SOCK_DGRAM (no raw sockets) — works around iSH's Apple-sandbox
# limitation that blocks AF_NETLINK/AF_PACKET and therefore blocks nmap -sU.

HOST="${1:-vpn.phuturum.me}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found. Install it first:  apk add python3"
    exit 1
fi

python3 - "$HOST" <<'PYEOF'
import socket, sys
host = sys.argv[1]
print(f"Probing UDP/123 on {host} (ensure cellular, WG off)...")
hits = 0
for i in range(3):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(3)
    try:
        s.sendto(b"\x1b" + 47 * b"\0", (host, 123))   # NTPv3 client query
        data, _ = s.recvfrom(48)
        print(f"  attempt {i+1}: OPEN  ({len(data)}b response, hex head: {data[:4].hex()})")
        hits += 1
    except socket.timeout:
        print(f"  attempt {i+1}: no response (closed/filtered)")
    except Exception as e:
        print(f"  attempt {i+1}: ERROR  {type(e).__name__}: {e}")
    s.close()
print()
if hits:
    print(f"VERDICT: WAN NTP EXPOSED  ({hits}/3 probes got a response)")
    print("  Fix: Services -> Network Time -> Interfaces -> UNCHECK WAN -> Save")
    sys.exit(1)
else:
    print("VERDICT: WAN NTP BLOCKED  (no responses from the public internet)")
PYEOF
