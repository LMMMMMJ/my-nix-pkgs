{
  lib,
  writeShellApplication,
  bashInteractive,
  coreutils,
  gnugrep,
  gnused,
  python3,
  fish,
  interactiveShell ? fish,
}:

# HerdrChat sends POSIX commands directly to sshd, which runs the user's shell
# with -c. Keep fish for terminals, but parse remote commands with Bash.
writeShellApplication {
  name = "herdr-ssh-shell";
  text = ''
    if [[ -n "''${SSH_CONNECTION:-}" && "''${1:-}" == -c ]]; then
      # SSH exec does not read fish's pnpm setup or a login profile. Keep the
      # phone's writable launcher first, followed by the user's real binaries.
      export PATH="$HOME/.local/bin:''${PNPM_HOME:-$HOME/.local/share/pnpm}:$HOME/.nix-profile/bin:/nix/profile/bin:$HOME/.local/state/nix/profile/bin:/etc/profiles/per-user/''${USER:-}/bin:/run/current-system/sw/bin:${
        lib.makeBinPath [
          bashInteractive
          coreutils
          gnugrep
          gnused
          python3
        ]
      }:''${PATH:-}"
      exec ${lib.getExe bashInteractive} --noprofile --norc "$@"
    fi

    # sshd supplies no arguments for an interactive login. A script shebang
    # loses the leading '-' in argv[0], so restore login mode explicitly.
    if [[ -n "''${SSH_CONNECTION:-}" && $# -eq 0 ]]; then
      set -- --login
    fi
    exec ${lib.getExe interactiveShell} "$@"
  '';
  derivationArgs.passthru.shellPath = "/bin/herdr-ssh-shell";
  meta = {
    description = "Fish login shell with POSIX-compatible SSH commands for HerdrChat";
    mainProgram = "herdr-ssh-shell";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
