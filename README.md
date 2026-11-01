# RT-AC68P 专用 Tailscale GitHub Actions 构建仓库

这个仓库用于给 ASUS RT-AC68P / 梅林固件 / Linux 2.6.36 / ARMv7 构建静态 `tailscale` 和 `tailscaled`。

## 设计原则

- 固定使用 Go 1.23.x。
- 强制 `GOOS=linux`、`GOARCH=arm`、`GOARM=7`、`CGO_ENABLED=0`。
- `GOTOOLCHAIN=local`，禁止 Go 自动下载更新工具链。
- 检查 Tailscale 源码的 `go.mod`。如果源码要求 Go 1.24 或更高，工作流直接失败，不会篡改 `go.mod`。
- 默认 Tailscale 基线为 `v1.78.3`。这是稳定性测试基线，不是最新版。
- 使用 Tailscale 官方源码仓库中的 `build_dist.sh` 写入版本与提交信息。
- 构建后校验 32 位 ARM ELF、静态链接、Go 构建信息和 SHA-256。

## 使用方法

1. 新建一个空 GitHub 仓库。
2. 把本压缩包内的所有文件上传到仓库根目录。
3. 打开 GitHub 仓库的 **Actions** 页面。
4. 选择 **Build Tailscale for RT-AC68P (Linux 2.6.36 ARMv7)**。
5. 点击 **Run workflow**。
6. 第一次保持默认值：
   - `tailscale_ref`: `v1.78.3`
   - `go_version`: `1.23.12`
   - `publish_release`: `false`
7. 构建成功后，在该次运行底部下载 Artifact。

## 为什么默认不使用 v1.104.4

`v1.104.4` 源码要求较新的 Go 工具链。该工作流不会通过修改 `go.mod` 或删除代码来伪造兼容性。若输入的版本要求 Go 1.24 以上，构建会在“Check source Go requirement”步骤中明确失败。

## 输出内容

- `tailscale`
- `tailscaled`
- `build-info.txt`
- `SHA256SUMS`
- ELF 检查结果
- Go 模块构建信息
- `.tar.gz` 压缩包及压缩包 SHA-256

## 路由器部署注意

首次测试不要删除原文件，也不要删除状态文件。必须备份原二进制：

```sh
cp -p /tmp/mnt/ROUTERUSB/tailscale/bin/tailscale /tmp/mnt/ROUTERUSB/tailscale/bin/tailscale.official.backup
cp -p /tmp/mnt/ROUTERUSB/tailscale/bin/tailscaled /tmp/mnt/ROUTERUSB/tailscale/bin/tailscaled.official.backup
```

状态文件必须保留：

```text
/tmp/mnt/ROUTERUSB/tailscale/state/tailscaled.state
```

本仓库只负责构建，不会远程连接路由器，也不会自动替换路由器文件。

## 安全说明

旧版 Tailscale 可能缺少新版安全修复。这个构建用于确定 Go 1.23 与 Linux 2.6.36 的稳定性，不应在未评估风险的情况下长期作为最终版本。
