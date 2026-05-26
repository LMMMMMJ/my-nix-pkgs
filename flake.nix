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
              # Use upstream PyTorch binary wheel (torch-bin) so we get a CUDA-enabled
              # build without recompiling torch from source. The wheel ships
              # torch-2.x+cuXYZ and links against nixpkgs cudaPackages.
              torch = python-prev.torch-bin;
            }
            # Import HuggingFace family packages
            // import ./pkgs/huggingface-family { inherit python-final python-prev; })
          ];
          # Add non-Python packages here
          claude-code = final.callPackage ./pkgs/claude-code { };
          gemini-cli = final.callPackage ./pkgs/gemini-cli { };
          codex = final.callPackage ./pkgs/codex { };
          baidupcs-go = final.callPackage ./pkgs/baidupcs-go { };
          temporal-cli = final.callPackage ./pkgs/temporal-family/temporal-cli { };
          temporal = final.callPackage ./pkgs/temporal-family/temporal { };
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
          xtquant = pkgs.python3Packages.xtquant;
          flash-attn = pkgs.python3Packages.flash-attn;
        };
      });
} 