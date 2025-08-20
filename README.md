# My Nix Packages

这是一个自定义的 Nix 包集合，提供了一些额外的 Python 包，特别是最新版本的 HuggingFace 生态系统包。

## 包含的包

### 基础包
- `tushare` - 中国股票市场数据接口
- `pyexecjs` - 在Python中运行JavaScript代码
- `claude-code` - Anthropic的智能编程助手，直接在终端中运行

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
```

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