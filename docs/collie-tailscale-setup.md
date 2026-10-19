# 在 NixOS 上通过用户级 Tailscale 用手机访问 Collie

本文从一台可以正常 SSH 登录的 NixOS 开发机开始，安装 Herdr 和 Collie，为普通用户
运行独立的 Tailscale，最后在手机上完成配对。无需事先安装 `collie-tailscale`，也不
依赖某台机器已有的脚本、systemd 服务或私有 Nix 模块。

适用系统为 `x86_64-linux` 和 `aarch64-linux`。主机需使用 systemd，并允许管理员
修改 NixOS 配置。手机可以是 iPhone 或 Android。所有多行 shell 示例均按 Bash 编写；
默认 shell 为 fish 的用户可先执行 `bash`。

## 1. 组件及访问权限

```text
手机浏览器 / 主屏幕应用
  │ Tailscale 私有网络中的 HTTPS
  ▼
该用户的 tailscaled：Tailscale Serve，端口 443
  │ 转发至 127.0.0.1:8787
  ▼
该用户的 Collie：手机界面、配对、读取输出和发送按键
  │ Unix socket：~/.config/herdr/herdr.sock
  ▼
该用户的 Herdr：终端窗口及其中运行的 Agent
```

Herdr 管理终端会话。Agent 必须运行在它的终端窗口里，才能通过这套配置在手机上
操作；启动 Herdr 不会自动接管其他 SSH 终端中已经运行的程序。

Tailscale 把设备加入一个私有网络，称为 **tailnet**。这里每个 Unix 用户运行独立的
`tailscaled`，可以分别登录自己的 tailnet。Collie 通过 Tailscale Serve 提供 HTTPS，
无需将 Collie 的本地端口开放到公网。不要用会向公网发布服务的 Tailscale Funnel。

手机配对后可以向终端发送任意按键，权限等同于运行 Collie 的 Unix 用户。本文同时
设置 `COLLIE_TRUSTED_USER`，只接受指定 Tailscale 登录身份，并使用设备配对凭据。
Tailscale 登录身份、Unix 用户名、手机配对名称是三个不同的值。

参考：[Collie 安全说明](https://github.com/AltanS/collie/blob/c539913e924bfed179142d0ad517802b80ff5010/docs/security.md)、
[Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)。

## 2. 准备信息及版本

后文示例使用以下值。按自己的环境替换；不要把示例邮箱直接用于部署。

| 信息 | 示例 | 含义 |
| --- | --- | --- |
| SSH 主机名 | `devbox` | 当前可以 SSH 登录的开发机 |
| Unix 用户 | `alice` | 已存在、可以直接 SSH 登录的普通用户 |
| Tailscale 登录身份 | `alice@example.com` | Tailscale 管理界面显示的实际登录名 |
| 新 Tailscale 节点名 | `devbox-alice` | 用户级实例在 tailnet 中的名称，建议包含用户名 |
| Collie 本地端口 | `8787` | 同一主机上每个用户必须使用不同端口 |
| NixOS 配置名称 | `devbox` | flake 中 `nixosConfigurations` 下的名称 |

先完成这些准备：

1. 主机可以访问 GitHub、Nix 下载源和 Tailscale 服务。
2. 有一个 Tailscale 账号，并有权限将开发机和手机加入同一 tailnet。
3. 手机安装 Tailscale 应用并登录该账号。使用共享 tailnet 时，确认访问策略允许手机
   访问新节点的 TCP 443；节点审批也要完成。
4. 在 tailnet 的 DNS 设置中启用 MagicDNS 和 HTTPS Certificates。
5. 如需操作编程 Agent，先在开发机安装该 CLI 并完成它自己的登录。Collie 不提供
   Agent 账号或订阅。

Nix 需要启用 `nix-command` 和 `flakes`。如果现有系统还未启用，在
`configuration.nix` 中加入下面一行，先按原有方式完成一次系统重建：

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

示例固定使用 Herdr `v0.9.5`，以及 Collie 的提交
`c539913e924bfed179142d0ad517802b80ff5010`，后者的 Nix 发布清单安装 `1.22.5`。
固定提交的原因是：Collie `v1.22.5` 标签内的 `packaging/nix/sources.json` 仍引用
`1.22.4`，标签名与 Nix 包版本不总是一致。升级时应同时检查发布清单和安装后的
`collie version`，不能只看输入标签。

版本依据：[1.22.5 的 Nix 发布清单](https://github.com/AltanS/collie/blob/c539913e924bfed179142d0ad517802b80ff5010/packaging/nix/sources.json)、
[Herdr Nix 安装说明](https://herdr.dev/docs/install/#install-with-nix)。

## 3. 安装完整的 NixOS 模块

本目录提供可以直接复制的完整模块：
[examples/collie-mobile.nix](examples/collie-mobile.nix)。它包含所有包装脚本和服务定义，
不引用本仓库的 overlay，也不依赖 `my-nix-modules`。

### 3.1 复制模块

尚未取得仓库时，先执行以下命令；已有同名目录时不要重复克隆：

```bash
mkdir -p ~/projects
git clone https://github.com/LMMMMMJ/my-nix-pkgs.git ~/projects/my-nix-pkgs
```

在包含系统 `flake.nix` 的配置目录中，将模块保存为 `collie-mobile.nix`。例如系统
配置位于 `/etc/nixos`：

```bash
sudo cp ~/projects/my-nix-pkgs/docs/examples/collie-mobile.nix /etc/nixos/collie-mobile.nix
```

也可以在文档页面打开模块链接，下载原始文件并保存到系统配置目录。

若系统配置放在其他目录，复制到那个目录即可。后续命令都在系统配置目录执行，
不是在 `my-nix-pkgs` 的目录执行。

### 3.2 引入软件包和模块

已有系统 flake 时，合并下面的 `collie`、`herdr` 输入、模块 import 和
`services.collieMobile` 配置；保留原有 `nixpkgs` 输入、硬件配置及其他模块。

下面是完整的最小 flake 示例，前提是相邻的 `configuration.nix` 已经能正确配置
这台机器，并包含硬件配置和 `alice` 用户。不要用此示例覆盖已有系统配置。

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    collie.url = "github:AltanS/collie/c539913e924bfed179142d0ad517802b80ff5010";
    herdr.url = "github:herdrdev/herdr/v0.9.5";
  };

  outputs = { nixpkgs, collie, herdr, ... }: {
    nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # ARM 主机改为 aarch64-linux
      modules = [
        ./configuration.nix
        ./collie-mobile.nix
        ({ pkgs, ... }: {
          services.collieMobile = {
            enable = true;
            colliePackage = collie.packages.${pkgs.stdenv.hostPlatform.system}.default;
            herdrPackage = herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
            users.alice = {
              port = 8787;
              tailnetLogin = "alice@example.com";
            };
          };
        })
      ];
    };
  };
}
```

本方案要求 `users.users.alice.isNormalUser = true`，并使用该用户在 NixOS 中配置的
实际 home 路径。模块不会创建可登录的新账号或安装 SSH 公钥。现有账号不满足条件时，
先完成普通用户和 SSH 登录配置。

如果主机上已经在 `environment.systemPackages` 或用户 profile 中安装了其他 Collie，
先移除重复的命令安装项，保留状态目录。否则同名 `collie` 可能绕过本文的包装器。
本模块已经安装 Herdr，也不需要再添加一份。

### 3.3 构建并应用

```bash
# 仅当系统配置由 Git 管理时执行；Nix 不会读取未跟踪的新文件。
git add flake.nix collie-mobile.nix

# 为新增输入生成锁记录，保留已有输入的锁定版本。
nix flake lock

sudo nixos-rebuild build --flake .#devbox
sudo nixos-rebuild switch --flake .#devbox
```

提交系统配置时一并保存 `flake.lock`。不需要为了安装 Collie 更新整个 `nixpkgs`。
Herdr 的上游 Nix 包从源码构建，首次构建可能需要下载编译工具并等待编译结束。

## 4. 模块生成了什么

### 4.1 `collie-tailscale` 与内部 `tailscale`

`collie-tailscale` 是包装脚本。下列代码展示完整逻辑；模块生成时会把 `tailscale`
和 `id` 替换为 Nix 包的绝对路径，避免递归调用包装器：

```bash
exec /path/to/real/tailscale \
  --socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/collie-tailscale/tailscaled.sock" \
  "$@"
```

这里的 `/path/to/real/tailscale` 仅用于解释，不需要手动创建这个文件。
模块的 `tailscaleCommand` 已提供可执行的实现。

模块还生成一个内容相同、名字为 `tailscale` 的内部脚本。运行 `collie` 时，它所在
目录被放到 PATH 最前面，因此 Collie 内部的 `tailscale status` 和 `tailscale serve`
也连接用户 socket。内部脚本不加入系统全局 PATH，日常直接执行的 `tailscale` 仍是
系统提供的命令。

### 4.2 用户级 `collie-tailscaled.service`

服务的主要参数如下：

```ini
[Service]
ExecStart=/path/to/real/tailscaled --tun=userspace-networking --socket=%t/collie-tailscale/tailscaled.sock --statedir=%S/collie-tailscale --port=0
RuntimeDirectory=collie-tailscale
RuntimeDirectoryMode=0700
StateDirectory=collie-tailscale
StateDirectoryMode=0700
UMask=0077
Restart=on-failure
RestartSec=5
```

上面同样是参数说明，真正的完整 unit 由 NixOS 模块生成。

- `--tun=userspace-networking`：在用户进程内处理网络，无需创建系统 TUN 网卡。
- `%t`：用户运行目录，通常是 `/run/user/<UID>`，放控制 socket。
- `%S`：用户持久状态目录，通常是 `~/.local/state`，放 Tailscale 登录状态。
- `--port=0`：让 Tailscale 自动选取 UDP 监听端口，避免多个实例争用固定端口。

服务仅对 `services.collieMobile.users` 中列出的用户启动。每个用户有自己的状态和
Tailscale 节点，即使主机还运行着系统级 Tailscale，也无需停止或重新登录它。

参考：[Tailscale 用户态网络](https://tailscale.com/docs/concepts/userspace-networking)。

### 4.3 `collie` 包装器、配置和服务覆盖文件

模块生成 `/etc/collie-mobile/<用户名>.env`，写入该用户的端口、Tailscale 登录身份、
Herdr socket 和 Collie 状态路径。`collie` 包装器先读取这个文件，再调用真实二进制。
本模块为每个 Unix 用户配置一个默认 Collie 实例，`COLLIE_INSTANCE` 固定为空。

`collie start` 自己生成 `~/.config/systemd/user/collie.service`。模块只向
`/etc/systemd/user/collie.service.d/overrides.conf` 提供覆盖配置：

1. 启动 Collie 时同时启动用户级 Tailscale，并设置启动顺序。
2. 为后台服务也设置包含内部 `tailscale` 包装器的 PATH。systemd 不读取交互 shell 的
   alias、函数和 shell 初始化脚本，仅包装命令行入口还不够。
3. 再次读取 `/etc/collie-mobile/%u.env`，使后台服务与 CLI 使用相同的用户配置。

不要把生成的主服务文件整体复制到 `/etc/systemd/user`。这会干扰 Collie 自己生成
和更新服务的流程。`collie start` 执行前，主服务尚不存在是正常现象。

以下路径需要区分：

| 路径 | 内容及管理方式 |
| --- | --- |
| `/etc/collie-mobile/alice.env` | NixOS 生成；修改模块配置后 rebuild，不直接编辑 |
| `~/.config/herdr/plugins/config/herdr.collie/.env` | Collie 的其他配置，例如推送密钥 |
| `~/.local/state/collie-tailscale` | Tailscale 身份及登录状态，应保持私有 |
| `~/.local/state/collie` | Collie 的配对等持久状态，应保持私有 |
| `/run/user/<UID>/collie-tailscale` | 临时 socket 目录，重启后由服务重建 |

注意两种读取顺序不同：systemd 后读取的环境文件覆盖前面的同名变量，而 Collie CLI
会让用户 `.env` 覆盖进程环境变量。因此包装器会拒绝用户 `.env` 重复定义模块管理的
变量，并指出需要移除的键名。端口和受信任账号只在 NixOS 配置里修改；迁移已有安装
时，先备份用户 `.env`，再移除这些重复项，保留推送密钥等其他配置。

示例采用默认 XDG 配置布局；已有自定义 Herdr 配置目录的安装，应先把
模块的 `HERDR_SOCKET_PATH` 调整到实际路径，不能把两个目录中的会话混用。

生成的 `/etc` 文件和 Nix store 内容可被其他本地用户读取，因此这里只放端口、
路径和登录名，不能放 Tailscale auth key、配对 token、私钥或其他秘密。

### 4.4 退出 SSH 后保活

模块对指定用户设置 `users.users.<name>.linger = true`。这使用户级 systemd 在用户
退出后仍可运行，并在系统启动时启动。手工安装对应的命令是
`loginctl enable-linger <用户名>`，使用本模块时无需重复执行。

服务自动启动与恢复 Agent 任务是两件事。机器重启会结束原有进程；本模块不为 Herdr
创建开机服务，也不自动重启 Agent。重启后要重新进入 Herdr，按需要恢复会话。

参考：[systemd 的 linger](https://www.freedesktop.org/software/systemd/man/latest/loginctl.html)。

## 5. 每位用户首次启用

以下步骤全部在目标用户自己的 SSH 会话中执行，不使用 root，也不通过 `sudo -iu`
切换用户。管理员完成系统配置后，每位用户仍需亲自完成 Tailscale 登录。

### 5.1 直接 SSH 登录并检查环境

```bash
ssh alice@devbox

id -un
command -v herdr collie collie-tailscale
printf '%s\n' "$XDG_RUNTIME_DIR"
systemctl --user is-system-running
loginctl show-user "$(id -un)" -p Linger
```

用户名应为 `alice`，用户运行目录通常为 `/run/user/<UID>`，linger 应为 `yes`。
`is-system-running` 如果返回 `degraded`，需查看失败服务是否与本方案有关。

`sudo -iu` 不一定建立完整的 systemd 用户会话。遇到 `Failed to connect to bus`
时，退出并直接 SSH 登录目标账号，再检查用户会话，不能仅靠设置一个环境变量判断
已经修复。

### 5.2 启动并登录自己的 Tailscale

```bash
systemctl --user start collie-tailscaled
collie-tailscale up --hostname=devbox-alice
```

在浏览器打开终端打印的登录链接，确认账号与配置中的 `tailnetLogin` 一致。
命令结束后检查：

```bash
collie-tailscale status
systemctl --user is-enabled collie-tailscaled
```

应看到 `devbox-alice` 在线，服务为 `enabled`。首次注册时如果需要管理员审批设备，
先完成审批。不要把这里的命令换成普通 `tailscale up`，后者可能操作系统级实例。

### 5.3 启动 Herdr 和 Agent

在正常的交互 SSH 终端执行 `herdr`，不要让正在运行的编程 Agent 在它自己的工具
子进程中执行这一步：

```bash
herdr
```

进入 Herdr 后，在其中的终端窗口切换到项目目录，启动已经安装并登录的 Agent，
例如 `claude` 或 `codex`。先按 `Ctrl+B`，松开，再按 `Q`，即可脱离界面，后台继续
运行。再次执行 `herdr` 可以回到原会话。

若需要准确显示 Agent 状态和会话记录，先检查 Herdr 集成：

```bash
herdr integration status
# 按实际使用的 Agent 选择；安装会修改该 Agent 的用户配置。
herdr integration install claude
# 或：herdr integration install codex
```

安装集成后，在 Herdr 内重新启动对应 Agent。它自己的信任提示仍需用户确认。
仅需要普通终端查看和按键输入时，不必安装用不到的集成。

参考：[Herdr 快速开始](https://herdr.dev/docs/quick-start/)。

### 5.4 启动 Collie

```bash
collie start
collie status
collie-tailscale serve status
```

预期显示 Collie 正在运行，并列出类似地址：

```text
local     http://127.0.0.1:8787
tailnet   https://devbox-alice.tailXXXX.ts.net
```

以实际打印的 `tailnet` 地址为准。`local` 只适合在开发机本机访问；在手机打开
`127.0.0.1` 指向的是手机自身。

已经运行过 Collie、刚修改过配置或包装器的安装，使用 `collie restart`，让主服务
重新生成并加载配置。Tailscale Serve 的 HTTPS 首次访问可能需要等待证书签发。
如果明确提示未启用 HTTPS，应先在 Tailscale 管理界面启用，再执行 `collie serve`。

### 5.5 配对手机并添加到主屏幕

```bash
collie pair
```

配对码有效期为 10 分钟。手机保持 Tailscale 已连接，打开打印的配对链接或扫描二维码，
输入手机名称并提交。也可以先打开 `tailnet` 地址，在配对界面输入配对码。

- iPhone：在 Safari 打开地址，使用“分享 → 添加到主屏幕”。
- Android：在 Chrome 打开地址，使用“安装应用”或“添加到主屏幕”。

从新建的主屏幕图标再次打开并确认能够访问。如果主屏幕应用没有继承浏览器中的
配对状态，就在该应用中重新完成配对，不要只确认浏览器标签页能用。

配对码的 10 分钟期限不是设备 token 的有效期。默认设备 token 持续有效，直到撤销；
若需限制期限，可在生成配对码时使用 `collie pair --expires 30d`。

**旧版本差异：** Collie `1.18.0` 起，未配对设备不能读取或操作终端。`1.17.2` 在
没有任何已配对设备时不启用配对校验，输入只受其他访问规则限制，不能把“配对列表
为空”理解为禁止访问。使用旧版本时，应先限制网络和账号访问，再及时完成首次配对。
本教程的固定版本已包含强制配对。

参考：[1.18.0 发布说明](https://github.com/AltanS/collie/releases/tag/v1.18.0)。

## 6. 验收

```bash
collie version
collie devices list
collie doctor
systemctl --user is-active collie-tailscaled collie
systemctl --user is-enabled collie-tailscaled collie
collie-tailscale serve status
loginctl show-user "$(id -un)" -p Linger
```

依次确认：

1. 实际 Collie 版本与发布清单一致，设备列表包含刚配对的手机。
2. `doctor` 没有与本次功能有关的失败；`skipped` 要看原因。未启用推送、未安装不用的
   集成可以跳过。尚未配对时的提示应在配对后重新检查。
3. 两个服务均为 `active`、`enabled`，linger 为 `yes`。
4. Serve 映射的本地端口与该用户配置一致。
5. 手机可以看到 Herdr 内的实际终端，在测试 shell 中发送 `pwd` 并看到正确输出。
6. 退出所有 SSH 会话后，手机仍能查看并输入。测试重启恢复时，安排维护窗口，并按
   前文说明重新启动 Herdr；不要据此承诺原 Agent 进程跨重启保留。

主机上 `doctor` 通过不代表手机的 DNS、Tailscale 或访问策略一定正常，必须完成
手机实际访问测试。文档和模块的静态检查也不能替代这一步。

## 7. 多用户、通知及日常维护

### 同一主机增加用户

为已经存在的另一个普通用户增加配置：

```nix
services.collieMobile.users.bob = {
  port = 8788;
  tailnetLogin = "bob@example.com";
};
```

rebuild 后由 `bob` 自己 SSH 登录，重复第 5 节，节点名使用 `devbox-bob`。
两个 userspace Tailscale 实例可以各自使用 tailnet 的 HTTPS 443，但 Collie 的本地
TCP 监听仍处于同一主机网络中，所以 `127.0.0.1` 上的端口必须不同。模块会拒绝
重复端口。同一个 tailnet 中的两位用户也应分别设置各自的 `tailnetLogin`。

### 可选：推送通知

基本访问和配对不自动启用推送。需要通知时执行：

```bash
collie push-keys
collie restart
```

再在手机 Collie 的通知设置中授权并订阅，最后执行 `collie push-test`。iPhone 的
Web Push 需要 iOS 16.4 或更新版本，并从主屏幕图标打开应用。生成的密钥保留在用户
配置里，不复制进 Nix 文件。

### 更新

在系统 flake 中修改所需工具的固定版本或提交，然后仅更新相关输入。例如修改
`collie.url` 后：

```bash
nix flake update collie
sudo nixos-rebuild build --flake .#devbox
sudo nixos-rebuild switch --flake .#devbox
```

随后每位用户在自己的 SSH 会话中执行 `collie restart`，再检查 `collie version`
和 `collie doctor`。主 unit 可能仍引用旧 Nix store 路径，因此不要只执行普通的
`systemctl --user restart collie` 就认定升级完成。保留自己的配置、Tailscale 状态和
配对状态，不必为了更新清空目录。Nix 安装应通过 Nix 更新，不能在只读 store 中
执行 Collie 的自更新。

### 撤销设备和停止服务

```bash
collie devices list
collie devices revoke old-phone
collie stop
```

`revoke` 的参数是列表中的准确设备名称；撤销后立即失去相应凭据。`collie stop`
仅停止 Collie，不会退出 Tailscale 或停止 Herdr。永久移除时，先按需要撤销设备并
执行 `collie uninstall`，再从 NixOS 配置移除相应用户配置或关闭本模块并 rebuild。
不要把删除整个状态目录作为普通的停止或升级步骤。

## 8. 常见问题

| 现象 | 检查和处理 |
| --- | --- |
| `collie-tailscale: command not found` | 确认模块已 import、`enable = true`、rebuild 成功；重新 SSH 登录并检查 PATH |
| `Failed to connect to bus` | 直接以目标账号 SSH 登录，检查 `XDG_RUNTIME_DIR` 和用户 systemd；不通过 `sudo -iu` 代替登录 |
| 找不到 `tailscaled.sock` | 查看 `systemctl --user status collie-tailscaled` 和 `journalctl --user -u collie-tailscaled -n 80`；核对当前 UID |
| 普通 `tailscale status` 已登录，Collie 仍未登录 | 两个命令可能连接不同 daemon；本方案以 `collie-tailscale status` 为准 |
| CLI 正常，后台服务使用错误的 Tailscale | 用 `systemctl --user cat collie` 确认覆盖文件存在，PATH 最前面是内部包装器，再执行 `collie restart` |
| 包装器提示 `Remove ... from ...` | 备份提示的用户 `.env`，移除与模块重复的变量，在 NixOS 配置中统一修改该值；不要删除其他配置 |
| `address already in use` | 本地端口与其他用户或程序冲突；修改该用户的 `port`，rebuild 后执行 `collie restart` |
| Collie 正常运行，手机地址打不开 | 检查手机 Tailscale、同一 tailnet、MagicDNS、节点审批、TCP 443 访问策略；开发机本地成功不证明手机可达 |
| `403` 或无法配对 | 核对 `tailnetLogin` 与手机实际账号；手机节点不要使用会失去用户身份的 tag；检查配对码是否过期 |
| 手机能打开，但看不到目标 Agent | 确认 Agent 在同一 Unix 用户的 Herdr 中运行，且 `HERDR_SOCKET_PATH` 指向该会话 |
| Agent 终端可见，但没有历史记录 | 检查 Herdr 集成、Agent 对 hooks 的信任和启动时间；新会话可能在第一次交互后才报告 session |
| 退出 SSH 后失联 | 分别检查两个服务的 enabled 状态和 `Linger=yes`，再检查 Herdr 是否仍在运行 |
| 改名或换 tailnet 后，旧主屏幕图标失效 | 用 `collie url` 获取新地址，重新添加主屏幕入口；新浏览器来源可能需要重新配对 |

进一步排查可查看
[Collie 故障排查文档](https://github.com/AltanS/collie/blob/c539913e924bfed179142d0ad517802b80ff5010/docs/troubleshooting.md)。
