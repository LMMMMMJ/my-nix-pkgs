# HerdrChat 的 NixOS SSH shell

HerdrChat 0.12.0 将安装 Codex launcher 的 POSIX 脚本直接交给 SSH 登录 shell。
fish 无法解析其中的 `name=value`、`for ...; do ...; done`，返回 127。App 将这个
失败统一提示为 `Check write access to ~/.local/bin`；创建目录、修改权限或只执行
`herdr integration install codex` 都不能修复这个解析错误。

依据：[安装命令](https://github.com/cobanov/herdrchat/blob/73512ca5231c124e37576e3964196d48b0b0a3cc/src/lib/herdr/codexLauncher.ts)、
[launcher](https://github.com/cobanov/herdrchat/blob/73512ca5231c124e37576e3964196d48b0b0a3cc/scripts/herdr-codex.sh)。

`herdr-ssh-shell` 是可作为 NixOS 用户登录 shell 的包。仅在存在 `SSH_CONNECTION`
且收到 `-c` 时，用 Nix store 中的 Bash 执行原命令，原样传递参数和退出状态。
普通 SSH 交互登录仍进入 fish login shell；本地 `-c` 仍交给 fish。可用
`.override { interactiveShell = pkgs.fish; }` 选择宿主的 fish。

远程命令的 PATH 包含 `~/.local/bin`、`${PNPM_HOME:-$HOME/.local/share/pnpm}`、
Nix 用户和系统 profile 路径，以及 Bash、coreutils、grep、sed、Python 3 的固定路径。
因此 App 安装的 `#!/usr/bin/env bash` launcher 能找到解释器和 hook 运行时，
也能找到用户用 pnpm 安装的真实 Codex。Codex 等 Agent CLI 仍由用户自己安装、
登录和更新，系统已有的 Node.js 等运行时仍通过系统 profile 提供。

推荐使用 `my-nix-modules` 的 `services.my-modules.herdr-ssh` 模块按用户启用。
直接使用时，可在已有的 NixOS 配置中声明：

```nix
{ pkgs, ... }:
let
  # myPkgs 为固定到具体提交的 my-nix-pkgs flake。
  shell = myPkgs.packages.${pkgs.stdenv.hostPlatform.system}.herdr-ssh-shell.override {
    interactiveShell = pkgs.fish;
  };
in {
  programs.fish.enable = true;
  users.users.alice.shell = shell; # alice 必须是已经声明的普通用户
}
```

部署后重新连接 HerdrChat，再点安装/更新集成；App 会以当前用户安装
`~/.local/bin/codex` 和 `~/.local/bin/herdrchat-codex`。这些文件保持可写，不放到
Nix store。原有同名文件若不带 App 管理标记，安装器会拒绝覆盖，需用户检查后处理。
升级后在新的 Herdr pane 启动 Codex；正在运行的 Agent 不会自动获得新 launcher。
App 的 herdr path 继续填写 `/run/current-system/sw/bin/herdr`。

此包不配置 SSH `ForceCommand`，不改 SSH 密钥、端口、认证或用户配置文件，也不启动
Herdr。配置生效的账号会将 SSH 远程命令统一按 Bash 语法解释，需要运行 fish
命令时显式执行 `fish -c '...'`。

验证：`nix build .#herdr-ssh-shell .#checks.x86_64-linux.herdr-ssh-shell`。
回归测试使用上述提交的完整 App 安装命令和 launcher，覆盖 fish 的 127、安装和重装、
冲突保护、pnpm Codex 发现、pane 环境和参数传递；模块另用 NixOS VM 测试真实 SSH。
