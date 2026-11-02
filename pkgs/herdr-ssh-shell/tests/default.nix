{ pkgs, shellPackage }:
pkgs.runCommand "herdr-ssh-shell-tests" { } ''
  ${pkgs.python3}/bin/python3 ${./test_launcher.py} \
    ${shellPackage}/bin/herdr-ssh-shell \
    ${pkgs.fish}/bin/fish \
    ${./install-codex-launcher.sh} \
    ${pkgs.bashInteractive}/bin/bash | tee "$out"
''
