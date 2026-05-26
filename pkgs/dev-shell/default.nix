{ mkShell, python3, claude-code, gemini-cli, codex, baidupcs-go,
  temporal-cli, temporal, temporal-ui-server }:

let
  my-nix-pkgs-dev = python3.withPackages (pyPkgs:
    with pyPkgs;
    [
      tushare
      pyexecjs
      # PyTorch (CUDA-enabled via torch-bin override in flake.nix)
      torch
      # HuggingFace family packages
      hf-xet
      huggingface-hub
      tokenizers
      transformers
      sentence-transformers
      # Temporal family
      temporalio
      # Add more packages here as needed
    ]);

  pythonIcon = "f3e2";

in mkShell rec {
  name = "my-nix-pkgs";

  packages = [
    my-nix-pkgs-dev
    claude-code gemini-cli codex baidupcs-go
    temporal-cli temporal temporal-ui-server
  ];

  shellHook = ''
    export PS1="$(echo -e '\u${pythonIcon}') {\[$(tput sgr0)\]\[\033[38;5;228m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]} (${name}) \\$ \[$(tput sgr0)\]"
    echo "Welcome to ${name} development environment!"
    echo "Available packages: tushare, pyexecjs, claude-code, gemini-cli, codex, baidupcs-go"
    echo "HuggingFace packages: hf-xet, huggingface-hub, tokenizers, transformers, sentence-transformers"
    echo "Temporal packages: temporal-cli (temporal), temporal-server, temporal-ui-server, temporalio (python)"
    echo "Claude Code version: $(claude --version)"
    echo "Gemini CLI version: $(gemini --version)"
    echo "Codex version: $(codex --version)"
    echo "BaiduPCS-Go version: $(BaiduPCS-Go --version | head -1)"
    echo "Temporal CLI version: $(temporal --version)"
  '';
}