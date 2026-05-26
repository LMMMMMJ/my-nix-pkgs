{ python-final, python-prev }:

# Temporal family packages.
#
# Most of the Temporal toolchain (CLI, server, Web UI) are Go binaries and live
# at the top level via final.callPackage in flake.nix. Only the Python SDK is
# routed through pythonPackagesExtensions, which is why this file exists in the
# same shape as huggingface-family/default.nix.

rec {
  temporalio = python-final.callPackage ./temporalio { };
}
