# My Nix Packages

这是一个自定义的 Nix 包集合，提供了一些额外的 Python 包，特别是最新版本的 HuggingFace 生态系统包。

## 包含的包

### 基础包
- `tushare` - 中国股票市场数据接口
- `pyexecjs` - 在Python中运行JavaScript代码
- `claude-code` - Anthropic的智能编程助手，直接在终端中运行
- `claude-code-router` - Claude Code 路由器，支持多模型提供商和请求路由
- `gemini-cli` - Google Gemini AI助手的命令行工具，直接在终端中与Gemini交互
- `codex` - OpenAI的AI编程助手，轻量级编程代理，直接在终端中运行

### HuggingFace 家族包
- `hf-xet` (v1.1.8) - Xet 客户端技术，用于 huggingface-hub
- `huggingface-hub` (v0.34.4) - HuggingFace Hub 客户端库
- `tokenizers` (v0.21.1) - 快速、现代的分词器库
- `transformers` (v4.55.2) - 最新的 Transformer 模型库
- `sentence-transformers` (v5.1.0) - 句子嵌入和语义搜索库

## 在其他项目中使用

### 方法一：使用 Overlay（推荐）

在您的项目的 `flake.nix` 中：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    my-nix-pkgs = {
      url = "path:/home/jacob/project/my-nix-pkgs";  # 本地路径
      # 或者远程仓库：
      # url = "github:yourusername/my-nix-pkgs";
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
            claude-code
            claude-code-router
            gemini-cli
            python3
          ];
        };

        packages = {
          # 两种方式都可以使用
          tushare-via-overlay = pkgs.python3Packages.tushare;
          tushare-direct = my-nix-pkgs.packages.${system}.tushare;
          pyexecjs-via-overlay = pkgs.python3Packages.pyexecjs;
          pyexecjs-direct = my-nix-pkgs.packages.${system}.pyexecjs;
          claude-code-via-overlay = pkgs.claude-code;
          claude-code-direct = my-nix-pkgs.packages.${system}.claude-code;
          claude-code-router-via-overlay = pkgs.claude-code-router;
          claude-code-router-direct = my-nix-pkgs.packages.${system}.claude-code-router;
          gemini-cli-via-overlay = pkgs.gemini-cli;
          gemini-cli-direct = my-nix-pkgs.packages.${system}.gemini-cli;
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

### 方法二：在 NixOS 系统配置中使用

```nix
{
  inputs.my-nix-pkgs.url = "github:yourusername/my-nix-pkgs";
  
  outputs = { nixpkgs, my-nix-pkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [{
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
          claude-code
          claude-code-router
          gemini-cli
        ];
      }];
    };
  };
}
```

## 本地开发

### 直接构建包

```bash
# 构建特定包
nix build .#tushare
nix build .#pyexecjs
nix build .#claude-code
nix build .#claude-code-router
nix build .#gemini-cli
nix build .#codex

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
python3 -c "import tushare as ts; print('Tushare version:', ts.__version__)"
python3 -c "import execjs; print('PyExecJS test: 1 + 2 =', execjs.eval('1 + 2'))"
python3 -c "
import sentence_transformers
print('sentence-transformers version:', sentence_transformers.__version__)

from sentence_transformers import SentenceTransformer
model = SentenceTransformer('all-MiniLM-L6-v2')
embeddings = model.encode(['Hello World', '你好世界'])
print('Embeddings shape:', embeddings.shape)
"

python3 -c "
from transformers import AutoTokenizer
tokenizer = AutoTokenizer.from_pretrained('bert-base-uncased')
print('Transformers tokenizer test:', tokenizer.tokenize('Hello world'))
"

python3 -c "
import huggingface_hub
print('huggingface-hub version:', huggingface_hub.__version__)
"
claude --version
ccr --version
gemini --version
codex --version
```

## Claude Code Router 使用说明

### 快速开始

Claude Code Router 是一个强大的工具，允许你将 Claude Code 请求路由到不同的模型提供商。

#### 1. 基本配置

创建配置文件 `~/.claude-code-router/config.json`：

```json
{
  "log": true,
  "OPENAI_API_KEY": "your-api-key-here",
  "OPENAI_BASE_URL": "https://api.openai.com/v1",
  "OPENAI_MODEL": "gpt-4o-mini",
  "router": {
    "default": "openai,gpt-4o-mini",
    "background": "openai,gpt-4o-mini",
    "think": "openai,gpt-4o",
    "longContext": "openai,gpt-4o",
    "longContextThreshold": 60000
  },
  "providers": {
    "openai": {
      "apiKey": "${OPENAI_API_KEY}",
      "baseURL": "${OPENAI_BASE_URL}"
    }
  }
}
```

#### 2. 常用命令

```bash
# 启动服务
ccr start

# 停止服务
ccr stop

# 重启服务
ccr restart

# 查看状态
ccr status

# 使用 Claude Code 与路由器
ccr code

# 打开 Web UI 进行配置
ccr ui
```

#### 3. 支持的提供商

- **OpenRouter** - 多模型聚合平台
- **DeepSeek** - 高性价比的中文优化模型
- **Ollama** - 本地运行的开源模型
- **Gemini** - Google 的多模态模型
- **Volcengine** - 火山引擎的模型服务
- **SiliconFlow** - 硅流的模型平台

#### 4. 高级功能

- **模型路由**: 根据任务类型自动选择最适合的模型
- **动态切换**: 在 Claude Code 中使用 `/model provider,model` 命令切换模型
- **自定义转换器**: 支持自定义请求/响应处理逻辑
- **GitHub Actions 集成**: 在 CI/CD 流程中使用

更多详细配置请参考：https://github.com/musistudio/claude-code-router

## Gemini CLI 使用说明

### 快速开始

Gemini CLI 是 Google 官方的 Gemini AI 助手命令行工具，让你可以直接在终端中与 Gemini 模型交互。

#### 1. 基本使用

```bash
# 直接与 Gemini 对话
gemini "你好，请介绍一下自己"

# 从文件读取内容并提问
gemini "请解释这段代码" < script.py

# 使用管道输入
echo "Hello World" | gemini "请翻译成中文"
```

#### 2. 常用命令

```bash
# 查看版本信息
gemini --version

# 查看帮助信息
gemini --help

# 设置 API 密钥（如果需要）
gemini config set api-key YOUR_API_KEY

# 查看当前配置
gemini config list
```

#### 3. 高级功能

- **多轮对话**: 支持上下文感知的连续对话
- **文件处理**: 可以处理多种文件格式的输入
- **代码分析**: 专门优化的代码理解和生成功能
- **多语言支持**: 支持多种编程语言和自然语言

更多详细使用方法请参考：https://github.com/google-gemini/gemini-cli

## Codex 使用说明

### 快速开始

Codex 是 OpenAI 的AI编程助手，轻量级编程代理，可以直接在终端中运行，提供智能代码生成、代码解释和编程协助功能。

**注意**：本项目使用 [sadjow/codex-nix](https://github.com/sadjow/codex-nix) 外部flake提供Codex包，该包基于 `nixpkgs-unstable` 构建，确保获得最新的工具链支持和自动更新功能。

#### 1. 基本使用

```bash
# 直接与 Codex 对话
codex "如何在Python中读取CSV文件？"

# 代码生成
codex "写一个快速排序算法的Python实现"

# 交互模式
codex

# 执行模式（非交互）
codex exec "解释这段代码的功能"
```

#### 2. 常用命令

```bash
# 查看版本信息
codex --version

# 查看帮助信息
codex --help

# 登录管理
codex login

# 登出
codex logout

# 应用最新的diff到本地工作树
codex apply

# 恢复之前的会话
codex resume
```

#### 3. 高级功能

- **代码生成**: 根据自然语言描述生成代码
- **代码解释**: 分析和解释现有代码
- **交互式编程**: 支持多轮对话的编程协助
- **Git集成**: 可以应用生成的代码diff到工作树
- **多种沙盒模式**: 安全的代码执行环境
- **模型选择**: 支持不同的AI模型

#### 4. 配置选项

```bash
# 使用特定模型
codex -m o3 "你的问题"

# 启用网络搜索
codex --search "查询最新的API文档"

# 设置沙盒权限
codex -s workspace-write "修改这个文件"

# 全自动模式（谨慎使用）
codex --full-auto "自动化任务"
```

#### 5. 包特性

- **自动更新**: 每日检查OpenAI Codex的新版本
- **预构建二进制**: 通过Cachix提供缓存，快速安装
- **Node.js 22 LTS**: 捆绑最新长期支持版本
- **跨平台支持**: 支持Linux和macOS
- **版本隔离**: 使用独立的nixpkgs-unstable，不影响项目其他包

更多详细使用方法请参考：
- [OpenAI Codex CLI官方文档](https://github.com/openai/codex)  
- [codex-nix包文档](https://github.com/sadjow/codex-nix)

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

### 🚀 最新版本
- **codex v0.39.0** - OpenAI AI编程助手，通过外部flake自动更新，基于nixpkgs-unstable
- **sentence-transformers v5.1.0** - 支持 ONNX 和 OpenVINO 后端，提供 2-3x 加速
- **transformers v4.55.2** - 最新的模型支持和功能
- **huggingface-hub v0.34.4** - 完整的 Hub 功能支持
- **tokenizers v0.21.1** - 快速分词性能
- **hf-xet v1.1.8** - 包含 Rust 补丁，解决编译问题

### 🔧 技术特点
- 所有包都有正确的依赖关系配置
- 自动处理版本兼容性
- 包含必要的运行时修复
- 统一的包管理结构
- **混合nixpkgs版本支持**: 项目主体使用稳定的nixos-24.11，而codex使用nixpkgs-unstable获得最新工具链支持
- **外部flake集成**: 无缝集成第三方flake包，保持项目模块化

## 维护

- 使用 `nix flake update` 更新依赖
- 使用 `nix flake check` 验证配置
- 使用 `nix build .#package-name` 测试特定包
- 定期检查上游包更新

### 包更新脚本

项目中包含了自动更新脚本：

```bash
# 更新 claude-code 到最新版本
cd pkgs/claude-code && ./update.sh

# 更新 claude-code-router 到最新版本
cd pkgs/claude-code-router && ./update.sh
```

### 版本信息

当前包版本：
- **claude-code**: v1.0.113
- **claude-code-router**: v1.0.49
- **gemini-cli**: v0.5.5
- **codex**: v0.39.0 (通过外部flake自动更新)
- **sentence-transformers**: v5.1.0
- **transformers**: v4.55.2
- **huggingface-hub**: v0.34.4 