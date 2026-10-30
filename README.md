# My Nix Packages

这是一个自定义的 Nix 包集合，提供了一些额外的 Python 包，特别是最新版本的 HuggingFace 生态系统包。

部署文档：[通过用户级 Tailscale 用手机访问 Collie](docs/collie-tailscale-setup.md)，
包含从零安装所需的 NixOS 模块、脚本、登录配对步骤和验收方法。
打包方式、升级步骤及兼容性检查见 [Collie 相关软件包的维护](docs/collie-packaging.md)。

## 包含的包

### 基础包

- `tushare` - 中国股票市场数据接口
- `rqdatac` - 米筐 RQData Python 客户端，包含行情、PIT 财务、业绩预告及快报接口
- `pyexecjs` - 在 Python 中运行 JavaScript 代码
- `baidupcs-go` - 百度网盘命令行工具
- `collie` - 通过 Tailscale 在手机上访问终端 Agent，包含完整网页资源
- `herdr` - 管理终端工作区和 Agent 会话，使用 Rust 和 Zig 从源码构建
- `tailscale` - 私有网络客户端和 daemon，复用 nixpkgs 打包逻辑并固定发布版本
- `collie-tailscale` - 连接当前用户的 Collie Tailscale socket，不操作系统级 daemon

### Temporal 家族包

- `temporal-cli` - Temporal 命令行工具，命令为 `temporal`
- `temporal` - Temporal 服务端，命令为 `temporal-server`
- `temporal-ui-server` - Temporal Web 界面服务
- `temporalio` - Temporal Python SDK

### HuggingFace 家族包

- `hf-xet` - Xet 客户端技术，用于 huggingface-hub
- `huggingface-hub` - HuggingFace Hub 客户端库
- `tokenizers` - 快速、现代的分词器库
- `transformers` - 最新的 Transformer 模型库
- `sentence-transformers` - 句子嵌入和语义搜索库
- `flash-attn` - FlashAttention 2 CUDA 实现，针对当前 Torch 从源码编译

## 在其他项目中使用

我们提供了多种集成方式，您可以根据项目需求选择最适合的方法：

- **方法一（Overlay）**：适合需要与现有nixpkgs无缝集成的场景，包可以通过 `pkgs.*` 直接访问
- **方法二（外部Flake）**：适合需要版本隔离和模块化管理的场景
- **方法三（NixOS系统）**：适合在NixOS系统级别安装和管理包的场景

### 方法一：使用 Overlay（推荐）

在您的项目的 `flake.nix` 中：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    my-nix-pkgs = {
      url = "path:/absolute/path/to/my-nix-pkgs";  # 本地路径
      # 或者远程仓库：
      # url = "github:LMMMMMJ/my-nix-pkgs";
    };
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, my-nix-pkgs, utils, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # 应用 overlay，使包可以通过 pkgs.python3Packages.* 访问
          overlays = [ my-nix-pkgs.overlays.default ];
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # 现在可以像使用官方包一样使用
            python3Packages.tushare
            python3Packages.pyexecjs
            # HuggingFace 家族包
            python3Packages.sentence-transformers
            python3Packages.transformers
            python3Packages.huggingface-hub
            python3Packages.tokenizers
            python3Packages.hf-xet
            temporal-cli
            python3
          ];
        };

        packages = {
          # 两种方式都可以使用
          tushare-via-overlay = pkgs.python3Packages.tushare;
          tushare-direct = my-nix-pkgs.packages.${system}.tushare;
          pyexecjs-via-overlay = pkgs.python3Packages.pyexecjs;
          pyexecjs-direct = my-nix-pkgs.packages.${system}.pyexecjs;
          # HuggingFace 包
          sentence-transformers = pkgs.python3Packages.sentence-transformers;
          transformers = pkgs.python3Packages.transformers;
          huggingface-hub = pkgs.python3Packages.huggingface-hub;
          tokenizers = pkgs.python3Packages.tokenizers;
          hf-xet = pkgs.python3Packages.hf-xet;
        };
      }
    );
}
```

### 方法二：集成外部 Flake

如果您想要集成我们的库同时保持外部flake的独立性：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # 集成我们的库作为外部 flake
    my-nix-pkgs = {
      url = "github:LMMMMMJ/my-nix-pkgs";
      # 或本地路径：url = "path:/path/to/my-nix-pkgs";
    };
    # 可以同时集成其他外部 flake
    # some-other-flake.url = "github:someone/some-flake";
  };

  outputs = { self, nixpkgs, my-nix-pkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        packages = [
          # 直接引用我们库中的包
          my-nix-pkgs.packages.${system}.temporal-cli
          # Python 包
          (pkgs.python3.withPackages (ps: [
            my-nix-pkgs.packages.${system}.tushare
            my-nix-pkgs.packages.${system}.pyexecjs
            # HuggingFace 包
            my-nix-pkgs.packages.${system}.sentence-transformers
            my-nix-pkgs.packages.${system}.transformers
            my-nix-pkgs.packages.${system}.huggingface-hub
            my-nix-pkgs.packages.${system}.tokenizers
            my-nix-pkgs.packages.${system}.hf-xet
          ]))
        ];
        
        shellHook = ''
          echo "🚀 开发环境已就绪！"
          temporal --version
          echo "可用的 Python 库："
          python3 -c "
          try:
              import tushare as ts
              print('  ✓ tushare:', ts.__version__)
          except: print('  ✗ tushare: 未安装')
          
          try:
              import execjs
              print('  ✓ PyExecJS: 已安装')
          except: print('  ✗ PyExecJS: 未安装')
          
          try:
              import transformers
              print('  ✓ transformers:', transformers.__version__)
          except: print('  ✗ transformers: 未安装')
          
          try:
              import sentence_transformers
              print('  ✓ sentence-transformers:', sentence_transformers.__version__)
          except: print('  ✗ sentence-transformers: 未安装')
          "
        '';
      };
      
      # 也可以创建专门的包输出
      packages = {
        # 创建包含 Temporal 命令行工具和服务端的环境
        temporal-tools = pkgs.buildEnv {
          name = "temporal-tools";
          paths = [
            my-nix-pkgs.packages.${system}.temporal-cli
            my-nix-pkgs.packages.${system}.temporal
            my-nix-pkgs.packages.${system}.temporal-ui-server
          ];
        };
        
        # 创建一个包含所有 Python 库的环境
        python-ml = pkgs.python3.withPackages (ps: [
          my-nix-pkgs.packages.${system}.tushare
          my-nix-pkgs.packages.${system}.pyexecjs
          my-nix-pkgs.packages.${system}.sentence-transformers
          my-nix-pkgs.packages.${system}.transformers
          my-nix-pkgs.packages.${system}.huggingface-hub
          my-nix-pkgs.packages.${system}.tokenizers
          my-nix-pkgs.packages.${system}.hf-xet
        ]);
      };
    };
}
```

**这种方法的优势：**
- ✅ **版本隔离**：每个外部flake使用自己的nixpkgs版本，避免版本冲突
- ✅ **自动更新**：使用 `nix flake update` 可以自动更新所有依赖
- ✅ **模块化**：可以选择性地引用需要的包，不会引入不必要的依赖
- ✅ **灵活性**：可以同时集成多个外部flake，构建复杂的开发环境
- ✅ **缓存友好**：每个flake都可以有自己的二进制缓存

**快速开始示例：**
```bash
# 1. 创建新项目
mkdir my-ai-project && cd my-ai-project

# 2. 创建 flake.nix（使用上面的模板）
cat > flake.nix << 'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    my-nix-pkgs.url = "github:LMMMMMJ/my-nix-pkgs";
  };
  
  outputs = { nixpkgs, my-nix-pkgs, ... }:
    let system = "x86_64-linux"; in {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = [
          my-nix-pkgs.packages.${system}.temporal-cli
        ];
      };
    };
}
EOF

# 3. 进入开发环境
nix develop

# 4. 检查 Temporal CLI
temporal --version
```

### 方法三：在 NixOS 系统配置中使用

```nix
{
  inputs.my-nix-pkgs.url = "github:LMMMMMJ/my-nix-pkgs";
  
  outputs = { nixpkgs, my-nix-pkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [({ pkgs, ... }: {
        nixpkgs.overlays = [ my-nix-pkgs.overlays.default ];
        
        environment.systemPackages = with pkgs; [
          python3Packages.tushare
          python3Packages.pyexecjs
          # HuggingFace 家族包
          python3Packages.sentence-transformers
          python3Packages.transformers
          python3Packages.huggingface-hub
          python3Packages.tokenizers
          python3Packages.hf-xet
          temporal-cli
        ];
      })];
    };
  };
}
```

## 本地开发

### 直接构建包

```bash
# 构建特定包
nix build .#tushare
nix build .#rqdatac
nix build .#pyexecjs
nix build .#temporal-cli
nix build .#collie .#herdr .#tailscale .#collie-tailscale

# 构建 HuggingFace 包
nix build .#sentence-transformers
nix build .#transformers
nix build .#huggingface-hub
nix build .#tokenizers
nix build .#hf-xet

# 进入开发环境
nix develop
```

### 测试包

```bash
python3 -c "import tushare; print('tushare OK')"
python3 -c "import execjs; print('PyExecJS test: 1 + 2 =', execjs.eval('1 + 2'))"
python3 -c "import sentence_transformers; print('sentence-transformers OK')"
python3 -c "import transformers; print('transformers OK')"
python3 -c "import huggingface_hub; print('huggingface-hub OK')"
temporal --version
```

## RQData 客户端

`rqdatac` 固定使用 PyPI 官方 wheel，并按 CPython 3.10–3.14 和 Linux/macOS 的
x86_64、aarch64 平台选择相应文件，SHA-256 记录在 `pkgs/rqdatac/sources.json`。
当前锁定的 nixpkgs 已停止支持 x86_64-darwin，该平台 wheel 仅供仍支持 Intel macOS 的下游 nixpkgs 使用。
该 wheel 不支持 PyPy、自由线程 Python 或 musl。上游未声明开源许可证，
因此包标记为 `unfree`；下游应用 overlay 时须配置 `config.allowUnfree = true`。

```nix
# 在应用本仓 overlay 的 pkgs 中使用
python3.withPackages (ps: [ ps.rqdatac ])
```

本仓 `nix develop` 已包含该客户端，可执行：

```bash
python3 -c "import rqdatac; print(rqdatac.__version__)"
```

安装检查不需要账户或网络，会验证二进制扩展、财务 API 导出和传输编解码。
实际取数仍需调用 `rqdatac.init()` 并提供有效账户；凭据不写入 Nix 表达式。
此包包含上游 `proxy` extra 所需的 `python-socks`，可通过 `rqdatac.init(proxy_info=...)`
仅为 RQData 连接指定 SOCKS/HTTP 代理；不会设置系统代理或替换 Python 全局 socket。
不包含另行发布的 `fund`、`bond`、`news`、`esg` 扩展包。

升级时从 [PyPI 发布元数据](https://pypi.org/pypi/rqdatac/json) 更新版本和各平台 wheel
校验值，重新构建并在开发环境验证。

## RQData 独立代理所需工具

`x86_64-linux` 新增两个输出，均可通过 overlay 或 `packages` 取得：

| 输出 | 内容 |
| --- | --- |
| `ruijie-sslvpn-cli` | 锐捷 SSLVPN 3.5.0（DEB 版本 `3.5.0.1789643503`）命令行客户端 |
| `rqdata-proxy-tools` | CLI、含代理依赖的 RQData/Python、bubblewrap、slirp4netns、Dante、iproute2、net-tools、socat、jq、OpenSSL |

```bash
nix build .#ruijie-sslvpn-cli .#rqdatac .#rqdata-proxy-tools
nix shell .#rqdata-proxy-tools
ruijie-sslvpn-cli --help
sockd -v
python -c 'import rqdatac, python_socks; print(rqdatac.__version__)'
```

客户端从锐捷官方 `Linux_64` DEB 提取，固定版本、无临时签名的下载地址和 SHA-256。
仅保留 CLI、语言文件和配置模板，修复 ELF 解释器及动态库路径；不执行 DEB 安装脚本，
不安装 GUI、pkexec 入口或系统服务。软件为 `unfree`，下游须允许该包。

工具组合只提供命令，不包含 VPN 启动器、账号、证书或代理配置。CLI 的 `conn` 会配置
TUN、路由和 DNS，应放在独立网络及挂载命名空间中运行，隔离 `/etc`、`/run` 及系统服务套接字。
其调用的 NetworkManager/systemd 集成不随此包安装；在独立环境中须由启动器配置并检查路由。
运行时通过 `--config` 传入受限配置文件，不能把密码或 License 写入 Nix store。
`--autoconnect` 和 `--optimize` 是启用开关，不能通过后接 `false` 关闭；关闭值应写入
JSON 配置。CLI 在 stdin EOF 后会循环打印提示，监督进程须保持输入通道并用 `disc`、
`exit` 正常退出，同时设置输出和退出超时限制。

安装测试仅检查 CLI 帮助和资源文件，不建立 VPN。RQData 的离线安装测试还检查 SOCKS
连接适配，并确认普通 `socket.create_connection` 不被修改。实际部署须另外验证证书、
权限、目标限制、断线时拒绝代理请求，以及宿主机网络保持不变。

## 添加新包

### 添加普通包
1. 在 `pkgs/` 目录下创建新的包目录和 `default.nix`
2. 在 `flake.nix` 的 overlay 中添加包定义：
   ```nix
   my-new-package = python-final.callPackage ./pkgs/my-new-package { };
   ```
3. 在 `packages` 部分暴露新包：
   ```nix
   my-new-package = pkgs.python3Packages.my-new-package;
   ```

## 引用方式

### 本地开发
```nix
my-nix-pkgs.url = "path:/absolute/path/to/my-nix-pkgs";
```

### Git 仓库
```nix
my-nix-pkgs.url = "github:username/my-nix-pkgs";
my-nix-pkgs.url = "git+https://github.com/username/my-nix-pkgs.git";
```

### 指定版本
```nix
my-nix-pkgs.url = "github:username/my-nix-pkgs/v1.0.0";
```

## 开发环境

```bash
# 进入开发环境
nix develop

# 或者使用 direnv
echo "use flake" > .envrc
direnv allow
```

## 特性

### 🔧 技术特点
- 所有包都有正确的依赖关系配置
- 自动处理版本兼容性
- 包含必要的运行时修复
- 统一的包管理结构
- **多种集成方式**: 提供Overlay、外部Flake、NixOS系统三种集成方式，适应不同使用场景
- **开箱即用的开发环境**: 提供完整的shellHook和版本检测，快速验证环境配置

## 维护

- 包版本更新保留现有 `flake.lock`；只有明确需要更新 nixpkgs 时才执行 `nix flake update`
- 使用 `nix flake check` 验证配置
- 使用 `nix build .#package-name` 测试特定包
- 定期检查上游包更新
