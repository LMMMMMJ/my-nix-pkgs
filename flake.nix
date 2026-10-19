{
  description = "Provide extra Nix packages for my custom modules.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    {
      overlays = {
        # It is recommended that the downstream user apply overlays.default directly.
        default = final: prev: {
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (python-final: python-prev: rec {
              # Add your custom Python packages here
              tushare = python-final.callPackage ./pkgs/tushare { };
              pyexecjs = python-final.callPackage ./pkgs/pyexecjs { };
              regex = python-final.callPackage ./pkgs/regex { };
              flash-attn = python-final.callPackage ./pkgs/flash-attention {
                upstream = python-prev.flash-attn;
              };
              # huggingface-hub 1.33 要求 Click >= 8.4.2，锁定的 nixpkgs 提供 8.3.3。
              click = python-prev.click.overridePythonAttrs (old: rec {
                version = "8.5.0";
                src = final.fetchFromGitHub {
                  owner = "pallets";
                  repo = "click";
                  tag = version;
                  hash = "sha256-VYdaEN9l2MRVz42I8t8IDOpG5XeDM8bf34dLZy3yf10=";
                };
                meta = old.meta // {
                  changelog = "https://github.com/pallets/click/blob/${version}/CHANGES.rst";
                };
              });
              # Typer 0.25.1 仍使用 Click 8.5 弃用的接口；新版使用自带实现。
              typer = python-prev.typer.overridePythonAttrs (old: rec {
                version = "0.27.3";
                src = final.fetchFromGitHub {
                  owner = "fastapi";
                  repo = "typer";
                  tag = version;
                  hash = "sha256-Rg5vFInHqLDObGTFQ8k86Yw45+lXGdLIcgVFV6Z/gB0=";
                };
                dependencies = builtins.filter (dep: (dep.pname or "") != "click") old.dependencies;
                # 子进程直接运行测试文件时，也需要找到仓库根目录的 tests 模块。
                preCheck = (old.preCheck or "") + ''
                  export PYTHONPATH="$PWD''${PYTHONPATH:+:$PYTHONPATH}"
                '';
                meta = old.meta // {
                  changelog = "https://github.com/fastapi/typer/releases/tag/${version}";
                };
              });
              # httpx2 的下载测试仍调用 Click 8.5 弃用的辅助函数；保留测试并仅过滤该警告。
              httpx2 = python-prev.httpx2.overridePythonAttrs (old: {
                pytestFlags = (old.pytestFlags or [ ]) ++ [
                  "-Wignore:'isolated_filesystem' is deprecated:DeprecationWarning"
                ];
              });
              triton-bin = python-final.callPackage ./pkgs/torch/triton-bin.nix {
                upstream = python-prev.triton-bin;
              };
              # 使用 PyTorch 二进制轮子。2.13 的 Linux 轮子为 cu130，使用对应的 CUDA 13.0。
              # 新版 nixpkgs 会同时为 torch-bin 选择对应的 cuda-bindings。
              torch = python-prev.torch-bin.override {
                cudaPackages = final.cudaPackages_13_0 // {
                  libnvshmem = final.callPackage ./pkgs/torch/libnvshmem-runtime.nix {
                    upstream = final.cudaPackages_13_0.libnvshmem;
                  };
                };
              };
            }
            # Import HuggingFace family packages
            // import ./pkgs/huggingface-family { inherit python-final python-prev; }
            // import ./pkgs/temporal-family { inherit python-final python-prev; })
          ];
          # Add non-Python packages here
          baidupcs-go = final.callPackage ./pkgs/baidupcs-go { };
          temporal-cli = final.callPackage ./pkgs/temporal-family/temporal-cli { };
          temporal = final.callPackage ./pkgs/temporal-family/temporal { };
          temporal-ui-server = final.callPackage ./pkgs/temporal-family/temporal-ui-server { };
        };
      };
    } // inputs.utils.lib.eachSystem [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
      in {
        devShells.default = pkgs.callPackage ./pkgs/dev-shell { };

        packages = {
          # Expose packages for direct building
          tushare = pkgs.python3Packages.tushare;
          pyexecjs = pkgs.python3Packages.pyexecjs;
          hf-xet = pkgs.python3Packages.hf-xet;
          huggingface-hub = pkgs.python3Packages.huggingface-hub;
          tokenizers = pkgs.python3Packages.tokenizers;
          transformers = pkgs.python3Packages.transformers;
          sentence-transformers = pkgs.python3Packages.sentence-transformers;
          pydantic = pkgs.python3Packages.pydantic;
          pydantic-core = pkgs.python3Packages.pydantic-core;
          # Add baidupcs-go package
          baidupcs-go = pkgs.baidupcs-go;
          temporal-cli = pkgs.temporal-cli;
          temporal = pkgs.temporal;
          temporal-ui-server = pkgs.temporal-ui-server;
          temporalio = pkgs.python3Packages.temporalio;
          flash-attn = pkgs.python3Packages.flash-attn;
        };
      });
}
