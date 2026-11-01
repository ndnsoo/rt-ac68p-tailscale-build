# RT-AC68P Tailscale v12 six-package build

默认 `one-job-all-six` 用一个Job生成六个完整梅林离线安装包；选择 `six-jobs` 则创建六个独立Job。

三种核心形态：upstream、legacy、combo。
每种核心各有两种安装机制：
- usb-*：HS3 U盘机制，核心仅写ROUTERUSB，JFFS只放脚本、Web UI和软链接。
- dual-*：旧双存储逻辑，核心写JFFS并在U盘可用时镜像/优先使用U盘；JFFS最低32000KB。

版本参数继续支持手工填写Tailscale标签、Go版本和GOARM。

## v12r log limits

The existing five-minute watchdog also maintains logs:

- `tailscaled.log`: 8 MB active limit, two rotated copies retained.
- `watchdog.log`: 256 KB limit, last 128 KB retained.
- `/tmp/tailscale-status/status.log`: 256 KB limit, last 128 KB retained.
- `failure-*.log`: newest 10 snapshots retained.

## v12r1 storage checks

USB-only packages check only the mounted EXT4 `ROUTERUSB` capacity. The required USB free space is the uploaded `bin` directory size plus 64 MB reserve, with a 100000 KB minimum. Dual-storage packages continue to require 32000 KB free JFFS space.
