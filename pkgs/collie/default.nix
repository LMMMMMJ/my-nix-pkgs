{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:

let
  # 打包布局参照 AltanS/collie 的 packaging/nix/collie.nix。
  sources = lib.importJSON ./sources.json;
  platformKeys = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
  payload = sources.platforms.${platformKeys.${stdenv.hostPlatform.system}};
in
stdenv.mkDerivation {
  pname = "collie";
  version = sources.version;

  src = fetchurl {
    inherit (payload) url sha256;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  dontConfigure = true;
  dontBuild = true;
  # Bun 把程序内容附加在 ELF 中，strip 会破坏可执行文件。
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Collie 通过真实可执行路径定位安装根目录，必须同时保留网页资源和插件标记。
    mkdir -p "$out/lib/collie" "$out/bin"
    cp -R ./. "$out/lib/collie/"
    chmod +x "$out/lib/collie/bin/collie"
    if [ -d "$out/lib/collie/scripts" ]; then
      chmod +x "$out/lib/collie/scripts/"*.sh
    fi
    ln -s "$out/lib/collie/bin/collie" "$out/bin/collie"

    runHook postInstall
  '';

  postInstallCheck = ''
    test -s "$out/lib/collie/herdr-plugin.toml"
    test -s "$out/lib/collie/web/dist/index.html"
  '';

  meta = {
    description = "Phone web UI for terminal agents over Tailscale";
    homepage = "https://github.com/AltanS/collie";
    changelog = "https://github.com/AltanS/collie/releases/tag/v${sources.version}";
    license = lib.licenses.mit;
    mainProgram = "collie";
    platforms = builtins.attrNames platformKeys;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
