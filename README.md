# Tailscale v1.104.4 legacy runtime package for RT-AC68P

This workflow builds the unmodified Tailscale v1.104.4 source with Go 1.27.3 and packages it with a Merlin/Softcenter Linux 2.6.36 runtime compatibility layer.

The previously referenced community patch file is malformed (`corrupt patch at line 66`) and is not applied. Instead, v7 adopts the community project's reliable operational approach without pretending to patch upstream source:

- run Tailscale with `--netfilter-mode=off`;
- maintain idempotent manual INPUT/FORWARD/MASQUERADE rules;
- keep IP forwarding enabled;
- re-check firewall rules every five minutes;
- support JFFS fallback plus ROUTERUSB detailed logging;
- build directly into a complete Softcenter offline installer.

Fixed build inputs:

- Tailscale `v1.104.4`
- Go `1.27.3`
- Linux ARM, default `GOARM=7`
- `CGO_ENABLED=0`
- no UPX
- stripped with `-s -w`

The generated package remains an unofficial legacy-kernel build because Go 1.27 does not officially support Linux 2.6.36.
