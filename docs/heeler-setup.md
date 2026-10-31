# 用 Heeler 连接 Herdr，并管理多台设备

`heeler` 包提供固定版本的官方 Heeler 插件、Node.js 运行时和 `heeler` 辅助命令。
插件和 npm 依赖在 Nix 构建时准备，用户注册插件时不需要下载源码或运行 `npm ci`。
它适用于 Heeler 的 iPhone、iPad 客户端；Android 和浏览器可以继续使用 Collie。
两个客户端可以连接同一用户的 Herdr，但各自独立配对、管理授权。

## 前提与安装

开发机需要 OpenSSH、Herdr 0.7.5 或更新版本，以及已登录的 Tailscale。SSH 服务
必须允许 stream-local forwarding，以便 Heeler 访问 Herdr Unix socket。
本仓库固定 Herdr TUI 0.9.5，满足 Heeler 0.8.0 插件的最低版本要求。
还没有这些基础配置时，先完成 [用户级 Tailscale 配置指南](collie-tailscale-setup.md)。

可通过本仓库的 `packages.<system>.heeler` 安装；使用 overlay 时为 `pkgs.heeler`。
默认辅助命令调用包中的 `herdr` 和标准 Tailscale。使用独立的用户级 daemon 时，
管理员为账号生成 `/etc/heeler/<Unix用户名>.json`，例如：

```json
{
  "sshPort": 22,
  "tailscaleCommand": ["/run/current-system/sw/bin/collie-tailscale"]
}
```

`tailscaleCommand` 是可执行文件与参数组成的数组，也可以填写其他 daemon 的 CLI
和 `--socket` 参数。不经过 Tailscale 的环境可配置公开的 `addresses` 数组。
这些文件只放公开默认设置，不存放 SSH 私钥、配对码或推送密钥。
包的 `.override { requireSettings = true; }` 可要求账号必须先由管理员配置。

## 每台新设备的操作

1. 直接用自己的 Unix 账号 SSH 登录开发机，不通过 `sudo -iu` 切换账号。
   手机或平板连接同一 tailnet，且访问策略允许该设备连接开发机的 TCP 22。
2. 在自己的交互终端进入 `herdr`。如果已有 Herdr 会话，使用现有会话中的 shell
   pane；不要从 Agent 的工具子进程启动 Herdr。
3. 在这个 pane 中执行：

   ```bash
   heeler pair
   ```

   命令注册 Nix 打包的插件，准备 `pair.json`，并在当前 Herdr 中打开配对弹窗。
   默认读取当前用户 Tailscale 节点的 IPv4、IPv6 和 DNS 名称，不使用手机的 IP，
   也不硬编码某一台 iPad 或某一个账号的地址。
4. 确认弹窗勾选的是该设备能够访问的地址，按 Enter。保持弹窗打开，在两分钟内
   使用 Heeler 的 **Hosts → Scan to Pair** 扫码。无法扫码时，可按 `c` 输出配对文本，
   在 Heeler 中使用 Paste Pairing Code。
5. 等待设备端检查通过，在服务器执行 `heeler doctor` 和 `heeler devices list`。

命名会话可以使用 `heeler pair --session work`。没有运行中的 Herdr 时，辅助命令
不会启动服务器或接管已有终端，应先由用户进入相应 Herdr 会话。

以后增加另一台 iPhone、iPad，只需重复上述配对步骤。每台设备使用独立的 SSH
Device Key；新增设备不删除旧设备，更新 Nix 包也不重置 SSH 授权或通知注册。
默认生成的 `pair.json` 随节点地址变化更新；用户手动修改的文件保持优先级，辅助
命令不会覆盖它。需要恢复自动默认配置时，先备份并移走这个手动文件，再执行 setup。

## 设备清单与单独撤销

```bash
heeler devices list
heeler devices list --json
heeler devices rename 'SHA256:完整指纹' 'My iPad'
heeler devices revoke 'SHA256:完整指纹'
```

撤销也支持唯一的设备名称；同名设备使用完整指纹区分。清单仅管理经本封装配对的
设备，数据保存在用户自己的 Herdr 插件状态目录 `nix-devices/` 中，记录公钥、指纹
和名称，不记录设备私钥。已有的其他 SSH 登录密钥不自动归类为 Heeler 设备。
从手工安装迁移时，旧 Heeler 密钥仍然有效，但不自动进入本封装的设备清单。

`revoke` 删除所选设备的 SSH 授权，阻止它再次登录；不会终止已经建立的 SSH
会话，也不会删除其他设备。推送注册由上游 `notifications.json` 管理，当前协议
不提供与 SSH 指纹的一一对应关系，因此该命令不声称撤销 APNs 通知。仍可操作的
设备应先在 Heeler 中关闭这个 Host 的通知；遗失设备还需要单独核对其通知注册。

**同一设备丢失凭据后重配**与**增加另一台设备**不同：只有确认新授权可用后，
才按旧指纹撤销不再使用的授权；不要因为新增设备就清空既有列表。
Android 或浏览器设备使用 `collie pair` / `collie devices list`，它们的令牌与 Heeler
SSH 密钥独立；一台设备同时使用两种客户端时，两份授权分别管理。

多设备授权可以并存。Heeler 的实时终端使用 Herdr 的 takeover attach；多台
Heeler 设备同时打开同一个终端时，后连接的设备可能接管此前的终端连接。这种
终端连接切换不会删除设备配对记录。

## 可复现打包与检查

插件源码固定到上游提交 `951f76edbd6dcb2b72058bc67526df21d10901be`，使用官方
`plugin/package-lock.json` 构建 npm 依赖。选择完整源码是为了运行同一提交的原始
Node 测试。安装时把 manifest 中的 Node 命令固定为 Nix 路径，移除运行时的 npm
构建条目，再用 Herdr 的 `plugin link` 注册预先构建的只读插件。
非默认 Herdr 实例生成的 launcher 同时使用 Nix 的 shell 与基础工具路径，保持
SSH 最小环境中的启动检查可用。
上游测试会动态创建带 `/usr/bin/env`、`/bin/sh` 和系统 PATH 的可执行 fixture；
构建时只将这些测试工具路径替换为 Nix 路径，保留其“缺少 Node”测试的隔离条件，
不禁用这些测试。

包只对 Enrollment 添加公钥清单记录；密钥校验、一次性 Bootstrap Key、120 秒
期限和 `authorized_keys` 的原子修改沿用上游实现。新增测试通过真实 Enrollment
子进程验证多设备、单独撤销、无关 SSH 密钥保留、用户隔离、默认配置更新及手动
配置优先级。`setup` 只管理插件与配对默认设置，设备认证仍由用户在客户端完成。

上游依据：[插件与协议](https://github.com/ZingerLittleBee/Heeler/blob/951f76edbd6dcb2b72058bc67526df21d10901be/plugin/README.md)、
[配对操作](https://docs.heeler.bybee.dev/pairing)。
