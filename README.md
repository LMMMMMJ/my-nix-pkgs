# My Nix Packages

这是一个自定义的 Nix 包集合，提供了一些额外的 Python 包，特别是最新版本的 HuggingFace 生态系统包。

## 包含的包

### 基础包
- `tushare` - 中国股票市场数据接口
- `pyexecjs` - 在Python中运行JavaScript代码
- `claude-code` - Anthropic的智能编程助手，直接在终端中运行
- `claude-code-router` - Claude Code 路由器，支持多模型提供商和请求路由

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
ccr --help
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
- **sentence-transformers**: v5.1.0
- **transformers**: v4.55.2
- **huggingface-hub**: v0.34.4 