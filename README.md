# My Nix Packages

这是一个自定义的 Nix 包集合，提供了一些额外的 Python 包。

## 包含的包

- `tushare` - 中国股票市场数据接口
- `pyexecjs` - 在Python中运行JavaScript代码

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
            python3
          ];
        };

        packages = {
          # 两种方式都可以使用
          tushare-via-overlay = pkgs.python3Packages.tushare;
          tushare-direct = my-nix-pkgs.packages.${system}.tushare;
          pyexecjs-via-overlay = pkgs.python3Packages.pyexecjs;
          pyexecjs-direct = my-nix-pkgs.packages.${system}.pyexecjs;
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

# 进入开发环境
nix develop
```

### 测试包

```bash
# 进入开发环境后测试
python3 -c "import tushare as ts; print('Tushare version:', ts.__version__)"
python3 -c "import execjs; print('PyExecJS test: 1 + 2 =', execjs.eval('1 + 2'))"
```

## 添加新包

1. 在 `pkgs/` 目录下创建新的包目录和 `default.nix`
2. 在 `flake.nix` 的 overlay 中添加包定义：
   ```nix
   my-new-package = python-final.callPackage ./pkgs/my-new-package { };
   ```
3. 在 `packages` 部分暴露新包：
   ```nix
   my-new-package = pkgs.python3Packages.my-new-package;
   ```
4. 更新 `pkgs/dev-shell/default.nix` 以包含新包（如果需要）

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

## 维护

- 使用 `nix flake update` 更新依赖
- 使用 `nix flake check` 验证配置
- 使用 `nix build .#package-name` 测试特定包 