{
  lib,
  writeShellApplication,
  tailscale,
  coreutils,
  commandName ? "collie-tailscale",
}:

writeShellApplication {
  name = commandName;
  text = ''
    exec ${lib.getExe tailscale} \
      --socket="''${XDG_RUNTIME_DIR:-/run/user/$(${lib.getExe' coreutils "id"} -u)}/collie-tailscale/tailscaled.sock" \
      "$@"
  '';
  meta = {
    description = "Tailscale CLI using the current user's Collie socket";
    mainProgram = commandName;
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
