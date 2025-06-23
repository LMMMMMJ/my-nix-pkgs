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
              # Example: my-package = python-final.callPackage ./pkgs/my-package { };
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

        packages = pkgs.python3Packages // {
          # Expose packages for direct building
          tushare = pkgs.python3Packages.tushare;
          # Example: my-package = pkgs.python3Packages.my-package;
        };
      });
} 