{
  description = "Provide extra Nix packages for my custom modules.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

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
            } 
            # Import HuggingFace family packages
            // import ./pkgs/huggingface-family { inherit python-final python-prev; })
          ];
          # Add non-Python packages here
          claude-code = final.callPackage ./pkgs/claude-code { };
          claude-code-router = final.callPackage ./pkgs/claude-code-router { };
          gemini-cli = final.callPackage ./pkgs/gemini-cli { };
        };
      };
    } // inputs.utils.lib.eachSystem [ "aarch64-linux" "x86_64-linux" ] (system:
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
          # Add claude-code-router package
          claude-code-router = pkgs.claude-code-router;
          # Add gemini-cli package
          gemini-cli = pkgs.gemini-cli;
        };
      });
} 