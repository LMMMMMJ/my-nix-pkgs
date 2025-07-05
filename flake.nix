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
              pydantic = python-final.callPackage ./pkgs/pydantic { };
            })
          ];
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
          pydantic = pkgs.python3Packages.pydantic;
        };
      });
} 