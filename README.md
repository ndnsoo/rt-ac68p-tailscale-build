# Selectable Tailscale RT-AC68P dual-job build v9

The workflow accepts manually entered versions while keeping safe defaults:

- `tailscale_ref`: default `v1.104.4`
- `go_version`: default `1.27.3`
- `goarm`: default `7`

Before compilation, the workflow reads the selected Tailscale source `go.mod` and stops with a clear error if the manually selected Go version is older than the source requirement.

Two independent jobs are always created:

1. `upstream-router`: official Tailscale networking behavior plus Softcenter, dual-storage, memory, swap and watchdog adaptations.
2. `legacy-runtime`: the same official source build, with runtime `--netfilter-mode=off`, manual legacy iptables rules and five-minute firewall repair added to the generated plugin package.

Both jobs directly generate complete Softcenter offline installers with the selected versions embedded in the filename. No third-party source patch is applied.
