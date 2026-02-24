{
  lib,
  stdenv,
  fetchurl,
  bash,
  patchelf,
  gnutar,
  gzip,
  openssl,
  libcap,
  zlib,
}:

let
  version = "0.104.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  hashes = {
    "aarch64-apple-darwin" = "0497mhfx2r91qfh78xl4bcb8cmfinys803h09m6m4md073h520dp";
    "x86_64-apple-darwin" = "1v6ljkbhxfx7kg834isfihvyf0lhnc3lhjkljaxw02v0hm7j98kc";
    "x86_64-unknown-linux-gnu" = "123zw5xdx62lcbmcq3pdlr1hbqfdqjn7cq37z0h6c7dyrsvwrxjj";
    "aarch64-unknown-linux-gnu" = "19789gl4i9fxz8bipg3mqpcyha8hp103vdisp2ckrdx2vqldffng";
  };

  binaryUrl = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${platform}.tar.gz";

  binary = fetchurl {
    url = binaryUrl;
    sha256 = hashes.${platform};
  };
in
assert platform != null || throw "Platform ${stdenv.hostPlatform.system} not supported. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux";

stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ gnutar gzip ] ++ lib.optionals stdenv.isLinux [ patchelf ];
  buildInputs = lib.optionals stdenv.isLinux [ openssl libcap zlib ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    tar -xzf ${binary} -C build
    mv build/codex-${platform} build/codex
    chmod u+w,+x build/codex

    ${lib.optionalString stdenv.isLinux ''
    patchelf \
      --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath [ openssl libcap zlib ]}" \
      build/codex
    ''}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    cp build/codex $out/bin/codex-raw
    chmod +x $out/bin/codex-raw

    cat > $out/bin/codex << 'WRAPPER_EOF'
#!${bash}/bin/bash
export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/codex"
export DISABLE_AUTOUPDATER=1
exec "$out/bin/codex-raw" "$@"
WRAPPER_EOF
    chmod +x $out/bin/codex

    substituteInPlace $out/bin/codex \
      --replace-fail '$out' "$out"
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "codex";
  };
}
