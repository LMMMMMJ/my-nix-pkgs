# My Nix Packages

这是一个自定义的 Nix 包集合，提供了一些额外的 Python 包。

## 使用方法

### 作为 Flake 输入使用

在你的 `flake.nix` 中添加这个仓库作为输入：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    my-nix-pkgs.url = "path:./my-nix-pkgs";  # 或者你的 git 地址
  };

  outputs = { self, nixpkgs, my-nix-pkgs, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [{
        nixpkgs.overlays = [ my-nix-pkgs.overlays.default ];
        
        # 现在你可以使用这些包了
        environment.systemPackages = with pkgs; [
          python3Packages.tushare
        ];
      }];
    };
  };
}
```

### 直接构建包

```bash
# 构建特定包
nix build .#tushare

# 进入开发环境
nix develop
```

## 包含的包

- `tushare` - 中国股票市场数据接口

## 添加新包

1. 在 `pkgs/` 目录下创建新的包目录
2. 在 `flake.nix` 中添加包定义
3. 更新 `packages` 部分以暴露新包

## 开发

```bash
# 进入开发环境
nix develop

# 或者使用 direnv
echo "use flake" > .envrc
direnv allow
``` 