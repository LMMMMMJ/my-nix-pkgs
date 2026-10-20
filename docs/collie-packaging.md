# Collie 相关软件包的维护

本仓库管理以下版本，核查日期为 2026-10-20：

| 包 | 版本 | 打包方式 |
| --- | --- | --- |
| Collie | 1.23.0 | 官方发布归档，保留完整网页资源 |
| Herdr | 0.9.5 | 固定源码、Cargo 和 Zig 依赖，从源码构建 |
| Tailscale | 1.104.1 | 复用 nixpkgs 的打包逻辑，固定版本和哈希 |
| collie-tailscale | 跟随 Tailscale | 为当前用户选择 daemon socket 的脚本 |

这四个包均提供 overlay 和 `packages.<system>` 输出，并加入开发环境。用户服务、
账号、端口和 tailnet 身份由使用方的 NixOS 配置管理，包本身不登录、不启动服务。
Linux 用户的完整安装步骤见 [配置指南](collie-tailscale-setup.md)。

## Collie

参考官方的
[packaging/nix/collie.nix](https://github.com/AltanS/collie/blob/fafa44b6fd9fdfaf6fa969e31d467d18a296b2d6/packaging/nix/collie.nix)。
本仓库独立维护 `pkgs/collie/default.nix` 和 `sources.json`，不调用官方 flake。

Collie 是 Bun 编译的可执行文件，官方 Nix 包也使用发布归档。必须保留
`lib/collie/bin/collie`、`herdr-plugin.toml` 和 `web/dist` 的相对位置，入口通过
`bin/collie` 符号链接定位安装目录。仅复制二进制会使网页资源不可用。

Linux 使用 `autoPatchelfHook` 修正解释器和库路径。`dontStrip` 必须保留，因为
strip 会破坏附加在可执行文件中的 Bun 程序。安装检查同时验证版本、插件标记和网页。

升级时检查官方 release 和 `collie-<version>.manifest.json`，更新版本、归档 URL
及哈希，再实际运行 `collie version`。不要只看 Git 标签：`v1.22.5` 标签中的旧 Nix
清单曾安装 1.22.4。当前支持与官方 Nix 包相同的 Linux x64、Linux ARM64、macOS ARM64。

1.23.0 沿用 1.22.6 的 `.env` 加载顺序、systemd unit 和配对接口，可继续使用
Herdr 0.9.5。新增的 Sent 会记录通过 Collie 发送的 shell 命令，Walky talky 提供
会话间消息，两者默认启用；可在用户私有 `.env` 中用 `COLLIE_SENT=off` 关闭记录、
用 `COLLIE_WALKY=off` 拒收消息，然后执行 `collie restart`。Walky talky 的 Agent 指令
需按需执行 `collie skill install <agent>` 安装；启动 bridge 不会自动写入这些指令。
详见 [1.23.0 发布说明](https://github.com/AltanS/collie/releases/tag/v1.23.0)。

## Herdr

参考官方的
[nix/package.nix](https://github.com/herdrdev/herdr/blob/2ecf19a92fc3a7fff75b6ce3655ef04f4625ec01/nix/package.nix)。
本仓库使用 `rustPlatform.buildRustPackage`，保留上游的 libghostty-vt 构建方式，
使用 Zig 0.16 和 ReleaseFast。Rust 固定为与官方相同的 1.96.1，由固定提交的
rust-overlay 提供最小工具链，仅传给 Herdr，不改变其他包的 Rust 或 nixpkgs。
实测当前 nixpkgs 原生 Rust 1.98.1 与 Zig 0.16 的组合出现 `.eh_frame_hdr` 链接
失败；与官方一致的 Rust 1.96.1 组合可以完成链接。无需给 Herdr 添加源码或链接器补丁。

源码通过提交和哈希固定，Cargo 依赖由 `cargoHash` 固定。
`pkgs/herdr/build.zig.zon.nix` 来自同一源码提交中的
`vendor/libghostty-vt/build.zig.zon.nix`，包含 Zig 依赖地址和哈希。升级源码时需同步
核对这个生成文件，不能只改版本号。将依赖清单保存在本仓库，可以避免评估包时为了
读取源码中的 Nix 文件而先执行取源构建。

Zig 依赖在构建前准备，构建阶段使用 `--system` 读取它们，不访问网络。两个 Zig
缓存目录位于构建临时目录。官方包不执行 Rust 测试，本仓库额外运行
`cargo test --package=ghostty-vt --lib`，验证核心终端解析库和工具链组合；硬编码
`/var/tmp` 的图片文件测试在 Nix 沙箱内不可写，明确排除这三组相关用例。安装检查会
实际运行 `herdr --version`。不要为了验证安装，在 Agent 工具子进程中启动
交互式 Herdr。

## Tailscale 和包装器

`pkgs/tailscale/default.nix` 复用锁定 nixpkgs 的 Tailscale derivation，固定本仓库
选择的版本、源码和 Go 依赖哈希。保留 nixpkgs 对运行依赖、systemd 文件、命令补全及
分拆输出的处理。若升级需要更新 Go 工具链，应先核对该版本的 `go.mod`，不能只更改
归档地址。当前 1.104.1 与锁定的 nixpkgs 原生包相同。

`collie-tailscale` 使用真实 Tailscale 的绝对路径，传入
`--socket=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/collie-tailscale/tailscaled.sock`，
再原样传递参数。使用 `.override { commandName = "tailscale"; }` 可以生成 Collie
内部使用的同名命令。只将这个内部目录放在 Collie 的 PATH 最前面，不替换系统的
原始命令。命令行和后台服务都需要设置相同的 PATH。

CLI、包装器和 daemon 必须使用同一套 Tailscale。配置指南的模块提供
`tailscalePackage` 参数，HomeServer 也直接从本 flake 取得三者，避免宿主旧版本与
新版 CLI 混用。

## 验证

每个包单独提交。使用仓库约定的全包构建方式，将 Collie、Herdr、Tailscale 和
collie-tailscale 一起构建，最后进入 `nix develop` 检查所有新增命令和现有 Python、
Temporal 工具。对 HomeServer 还需使用其当前 nixpkgs 完整构建系统配置。

兼容性检查包括发布说明、Collie 的 CLI 配置和服务生成接口、Herdr 版本、Tailscale
的 userspace 和 Serve 参数。用临时 socket 模拟 LocalAPI，检查包装器、Collie CLI
及后台服务 PATH 的用户隔离；检查生成的 systemd 覆盖文件。以上不需要登录 tailnet
或激活系统。手机实际访问、证书和配对需要在部署后另行验收。
