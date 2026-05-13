{
  description = "Provide extra Nix packages for my custom modules.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
              xtquant = python-final.callPackage ./pkgs/xtquant { };
              regex = python-final.callPackage ./pkgs/regex { };
              flash-attn = python-final.callPackage ./pkgs/flash-attn { };
            }
            # Import HuggingFace family packages
            // import ./pkgs/huggingface-family { inherit python-final python-prev; })
          ];
          # Add non-Python packages here
          claude-code = final.callPackage ./pkgs/claude-code { };
          gemini-cli = final.callPackage ./pkgs/gemini-cli { };
          codex = final.callPackage ./pkgs/codex { };
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
          xtquant = pkgs.python3Packages.xtquant;
          # 注意：flash-attn 不在此处单独暴露 standalone package。
          # 该 wheel 为 cu12torch2.5cxx11abiTRUE-cp312，仅在下游（research-incubator
          # 通过 ml-pkgs.overlays.torch-family 提供匹配的 torch 2.5.1+cu12+cxx11）才能正常构建。
          # 在 my-nix-pkgs 内 standalone build 会拉到 nixpkgs 25.11 的不兼容 torch，
          # 既慢又无意义；overlay 已通过 pythonPackagesExtensions 注入，由 consumer 解析。
        };
      });
} 