# RT-AC68P Tailscale v12r3

v12r3是完整累计修正版，保留可读、可逐行检查的完整脚本结构，不使用压缩成单行的实现。

## 保留的六个方案

- usb-upstream
- usb-legacy
- usb-combo
- dual-upstream
- dual-legacy
- dual-combo

默认一个Job生成六个完整安装包，也可选择六个独立Job。

## v12r3确认的修正

1. 默认ARM level为5，仍保留5和7可选。
2. 修复原插件advertise-routes覆盖login-server和hostname的参数拼接Bug。
3. 三个USB版只检查EXT4 ROUTERUSB、Swap和USB空间。
4. 三个dual版继续检查JFFS至少32000KB。
5. 保留30秒延迟启动、五分钟守护、日志轮换、Web UI、三语言和原注册状态。
