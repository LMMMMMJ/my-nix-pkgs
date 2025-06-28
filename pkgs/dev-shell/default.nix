{ mkShell, python3 }:

let
  my-nix-pkgs-dev = python3.withPackages (pyPkgs:
    with pyPkgs;
    [
      tushare
      pyexecjs
      # Add more packages here as needed
    ]);

  pythonIcon = "f3e2";

in mkShell rec {
  name = "my-nix-pkgs";

  packages = [ my-nix-pkgs-dev ];

  shellHook = ''
    export PS1="$(echo -e '\u${pythonIcon}') {\[$(tput sgr0)\]\[\033[38;5;228m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]} (${name}) \\$ \[$(tput sgr0)\]"
    echo "Welcome to ${name} development environment!"
    echo "Available packages: tushare, pyexecjs"
  '';
} 