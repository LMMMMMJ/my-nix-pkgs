{
  description = "Provide extra Nix packages for my custom modules. (nixos-24.11 compatibility branch)";

  inputs = {
    # 主 nixpkgs：本分支锚定到 24.11，与下游 research-incubator 同源。
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # 备用 nixpkgs：用作 24.11 兼容层的 backport 源（newer rustc/cargo/setuptools）。
    # 选择 25.11 而非 unstable，固定窗口、可重现，且本仓 master 即基于 25.11。
    nixpkgs-newer.url = "github:NixOS/nixpkgs/nixos-25.11";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-newer, ... }@inputs:
    {
      overlays = {
        # nixos-24.11 兼容 overlay。
        # 推荐下游用户直接 apply overlays.default。
        # 本 overlay 把若干在 nixpkgs 24.11 中过老/缺失/有缺陷的项替换为 25.11 的对应版本，
        # 使得 my-nix-pkgs 自有包（regex / hf-xet / tokenizers / transformers ...）
        # 在 24.11 环境下也能从源码构建。
        default = final: prev:
          let
            # 通过 prev.stdenv 反查 system，避免在 overlay 内部硬编码。
            system = prev.stdenv.hostPlatform.system;
            # 用同样的 system 导入 25.11，提供 backport 资源。
            # 关闭 cudaSupport：本 overlay 只取 rust/setuptools 等 CPU 工具，没必要触发 CUDA 构建。
            pkgsNewer = import nixpkgs-newer {
              inherit system;
              config = { allowUnfree = true; };
            };
          in {
            # 注意：不在顶层全局替换 rustc / cargo / rustPlatform。
            # 之前尝试全局 backport 25.11 的 rustc（≥1.91），但 polars 1.12.0 的
            # argminmax 0.6.2 在 1.91 下编译失败（_mm512_loadu_si512 类型变严格），
            # 而 ray、polars 等 24.11 内大量 Rust 依赖只需 1.82。
            # 改为在 huggingface-family 内为 hf-xet / tokenizers 显式注入 25.11 的 rust，
            # 其余 Rust 包保持 24.11 1.82 不动，避免重编译波及与版本不兼容。

            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (python-final: python-prev: rec {
                # ===== Python 集合：兼容补丁 =====
                # 说明：曾尝试用 pkgsNewer.python312Packages.setuptools 全局替换以支持 PEP 639，
                # 但 25.11 的 python 3.12.13 与 24.11 的 python 3.12.8 是不同 store path，
                # 触发 Nix 跨 Python 版本严格检查（setuptools-scm 等 propagatedBuildInputs 不一致）。
                # 改为局部处理：受影响的包（如 regex）自行在 postPatch 中修正其 pyproject.toml。

                # cfn-lint 测试固件含已过期硬编码日期（如 'nodejs18.x deprecated 2025-07-31'），
                # 在 2026 年构建必然触发断言失败；它是 moto/ray 链的传递依赖，关闭测试以解阻塞。
                cfn-lint = python-prev.cfn-lint.overridePythonAttrs (_: { doCheck = false; });

                # httplib2 的 test_unknown_server 等用例与互联网状态相关，沙盒中常飘红，关闭测试。
                httplib2 = python-prev.httplib2.overridePythonAttrs (_: { doCheck = false; });

                # gpytorch 的 priors 用例要求 .cuda()，沙盒无 GPU；它通过 optuna/botorch 被
                # ray 间接拉入。关闭测试以避免阻塞。
                gpytorch = python-prev.gpytorch.overridePythonAttrs (_: { doCheck = false; });

                # botorch test_cuda 同样需要 GPU；与 gpytorch 同链。
                botorch = python-prev.botorch.overridePythonAttrs (_: { doCheck = false; });

                # cloudpathlib 的 test_loc_dir[azure_rig] 用例在 sandbox 中找不到临时缓存目录，
                # 测试 fixture 与 NixOS 沙盒文件系统模型不兼容；它通过 spacy 等链路被传递依赖。
                cloudpathlib = python-prev.cloudpathlib.overridePythonAttrs (_: { doCheck = false; });

                # linear-operator test_psd_safe_cholesky_*_cuda 用例在 sandbox / 小显存机器上
                # 触发 CUDA OOM；它是 gpytorch/botorch 链路的传递依赖。
                linear-operator = python-prev.linear-operator.overridePythonAttrs (_: { doCheck = false; });

                # jax 的 GPU 测试套件（scipy_stats / pjit / python_callback 等近 3000 个）在
                # 大多数沙盒/小显存机器上都会 "Failed to launch CUDA kernel" / RESOURCE_EXHAUSTED。
                # `pythonImportsCheck` 在构建沙盒中执行 `import jax`，而 jax 在 24.11 的
                # 沙盒里找不到 jaxlib（jaxlib 是单独包，runtime path 在 dev shell 里才完整），
                # 所以同时关闭 import 检查；下游 dev shell 仍能正常 `import jax`。
                jax = python-prev.jax.overridePythonAttrs (_: {
                  doCheck = false;
                  dontUsePythonImportsCheck = true;
                });

                # JAX 生态（equinox / optax / flax）以及 PyTorch Lightning / torchmetrics 都属于
                # "测试套件依赖完整 GPU runtime 才能通过 / 跑非常慢" 的类别。沙盒里逐个踩雷代价高，
                # 一并关闭测试；下游 dev shell 使用 `import` 是 OK 的。
                equinox = python-prev.equinox.overridePythonAttrs (_: { doCheck = false; });
                optax = python-prev.optax.overridePythonAttrs (_: { doCheck = false; });
                flax = python-prev.flax.overridePythonAttrs (_: { doCheck = false; });
                pytorch-lightning = python-prev.pytorch-lightning.overridePythonAttrs (_: { doCheck = false; });
                torchmetrics = python-prev.torchmetrics.overridePythonAttrs (_: { doCheck = false; });

                # ===== my-nix-pkgs 自有 Python 包 =====
                tushare = python-final.callPackage ./pkgs/tushare { };
                pyexecjs = python-final.callPackage ./pkgs/pyexecjs { };
                xtquant = python-final.callPackage ./pkgs/xtquant { };
                regex = python-final.callPackage ./pkgs/regex { };
                flash-attn = python-final.callPackage ./pkgs/flash-attn { };
                # nixpkgs 24.11 缺少 typer-slim attr。
                # 注：typer-slim 与 typer 都对外暴露同一个 `typer/` Python 模块（路径冲突），
                # 不能与 nixpkgs 已有的 typer 同时进 env。
                # 实践上 typer 包含 typer-slim 的全部 API（24.11 的 typer 0.12+ 已默认 slim），
                # 故直接将 typer-slim 别名为 typer，使 transformers v5.x 的依赖解析得到满足。
                typer-slim = python-final.typer;
              }
              # Import HuggingFace family packages.
              # 把 25.11 的 rust 工具链（rustc 1.91+ + 新版 rustPlatform 含 fetchCargoVendor）
              # 通过 rustOverride 注入到 hf-xet / tokenizers 这两个需要 edition2024 的包。
              // import ./pkgs/huggingface-family {
                inherit python-final python-prev;
                rustOverride = {
                  rustPlatform = pkgsNewer.rustPlatform;
                  cargo = pkgsNewer.cargo;
                  rustc = pkgsNewer.rustc;
                };
              })
            ];
            # Add non-Python packages here
            claude-code = final.callPackage ./pkgs/claude-code { };
            gemini-cli = final.callPackage ./pkgs/gemini-cli { };
            codex = final.callPackage ./pkgs/codex { };
            baidupcs-go = final.callPackage ./pkgs/baidupcs-go { };
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
          # Add claude-code package
          claude-code = pkgs.claude-code;
          # Add gemini-cli package
          gemini-cli = pkgs.gemini-cli;
          # Add codex package
          codex = pkgs.codex;
          # Add baidupcs-go package
          baidupcs-go = pkgs.baidupcs-go;
          xtquant = pkgs.python3Packages.xtquant;
          # 注意：flash-attn 不在此处单独暴露 standalone package。
          # 该 wheel 为 cu12torch2.5cxx11abiTRUE-cp312，仅在下游（research-incubator
          # 通过 ml-pkgs.overlays.torch-family 提供匹配的 torch 2.5.1+cu12+cxx11）才能正常构建。
          # 在 my-nix-pkgs 内 standalone build 会拉到 nixpkgs 24.11 默认 torch（CPU 或不匹配 ABI），
          # 既慢又无意义；overlay 已通过 pythonPackagesExtensions 注入，由 consumer 解析。
        };
      });
}
