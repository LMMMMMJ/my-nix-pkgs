{ mkShell, python3, claude-code, claude-code-router, gemini-cli }:

let
  my-nix-pkgs-dev = python3.withPackages (pyPkgs:
    with pyPkgs;
    [
      tushare
      pyexecjs
      # HuggingFace family packages
      hf-xet
      huggingface-hub
      tokenizers
      transformers
      sentence-transformers
      # Add more packages here as needed
    ]);

  pythonIcon = "f3e2";

in mkShell rec {
  name = "my-nix-pkgs";

  packages = [ my-nix-pkgs-dev claude-code claude-code-router gemini-cli ];

  shellHook = ''
    export PS1="$(echo -e '\u${pythonIcon}') {\[$(tput sgr0)\]\[\033[38;5;228m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]} (${name}) \\$ \[$(tput sgr0)\]"
    echo "Welcome to ${name} development environment!"
    echo "Available packages: tushare, pyexecjs, claude-code, claude-code-router, gemini-cli"
    echo "HuggingFace packages: hf-xet, huggingface-hub, tokenizers, transformers, sentence-transformers"
    echo "Claude Code version: $(claude --version)"
    echo "Claude Code Router version: $(ccr -v)"
    echo "Gemini CLI version: $(gemini --version)"
  '';
} 