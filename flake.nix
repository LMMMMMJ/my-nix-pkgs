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
              xtquant = python-final.callPackage ./pkgs/xtquant { };
              regex = python-final.callPackage ./pkgs/regex { };
              flash-attn = python-final.callPackage ./pkgs/flash-attention { };
              # numpy-groupies 0.11.3's `test_scalar_input` uses the
              # `pytest.raises(exc, func, ...)` form that pytest 9.1 removed.
              # Only that test is affected. Drop when nixpkgs picks up a fixed
              # release.
              numpy-groupies = python-prev.numpy-groupies.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [ "test_scalar_input" ];
              });

              # Use upstream PyTorch binary wheel (torch-bin) so we get a CUDA-enabled
              # build without recompiling torch from source. The 2.12.1 wheel is a
              # cu130 build and refuses to evaluate against the default cudaPackages
              # (12.9), so both CUDA arguments point at the matching 13.0. Drop
              # the overrides once the default catches up.
              #
              # The wheel's metadata declares `setuptools<82` and nixpkgs ships 83,
              # which fails `pythonRuntimeDepsCheckHook`. Skipped rather than
              # pinning an older setuptools, which would rebuild the Python set.
              # Re-check `import torch` after bumping either one.
              torch = (python-prev.torch-bin.override {
                cudaPackages = final.cudaPackages_13_0;
                cuda-bindings = python-prev.cuda-bindings.override {
                  cudaPackages = final.cudaPackages_13_0;
                };
              }).overridePythonAttrs (_: {
                dontCheckRuntimeDeps = true;
              });
            }
            # Import HuggingFace family packages
            // import ./pkgs/huggingface-family { inherit python-final python-prev; }
            // import ./pkgs/temporal-family { inherit python-final python-prev; })
          ];
          # Add non-Python packages here
          claude-code = final.callPackage ./pkgs/claude-code { };
          gemini-cli = final.callPackage ./pkgs/gemini-cli { };
          codex = final.callPackage ./pkgs/codex { };
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
          # Add claude-code package
          claude-code = pkgs.claude-code;
          # Add gemini-cli package
          gemini-cli = pkgs.gemini-cli;
          # Add codex package
          codex = pkgs.codex;
          # Add baidupcs-go package
          baidupcs-go = pkgs.baidupcs-go;
          temporal-cli = pkgs.temporal-cli;
          temporal = pkgs.temporal;
          temporal-ui-server = pkgs.temporal-ui-server;
          temporalio = pkgs.python3Packages.temporalio;
          xtquant = pkgs.python3Packages.xtquant;
          # The wheel is cp313; python3Packages is 3.14, where the package
          # marks itself broken.
          flash-attn = pkgs.python313Packages.flash-attn;
        };
      });
} 