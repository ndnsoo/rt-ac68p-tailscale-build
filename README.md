# RT-AC68P Tailscale v11

完整累计构建版，保留v9式完整脚本结构，不做功能删减。

运行参数：
- tailscale_ref：手动填写，默认v1.104.4
- go_version：手动填写，默认1.27.3
- goarm：默认7，可选5
- job_mode：默认one-job-all，可选three-jobs

默认one-job-all只运行一个Job，但生成三个完整梅林安装包：
1. usb-hs3：严格采用HS3安装机制。两个核心只放ROUTERUSB，JFFS只放插件脚本和软链接；必须插U盘才能启动。
2. legacy-runtime：保留双核心双存储旧逻辑，增加netfilter-mode=off与旧iptables维护。
3. combo-core：保留双存储旧逻辑，但JFFS只保存一个ts_include_cli组合核心，适合空间较小的JFFS。

选择three-jobs后，三个方案分别独立构建、校验和上传。
双存储方案的JFFS最低空间设置为32000KB；usb-hs3不使用该限制，检查U盘EXT4、Swap和100000KB可用空间。
