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
  version = "0.120.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  hashes = {
    "aarch64-apple-darwin" = "1w4m5halbs6489brxsrx98a264wdylswgf3z0n9a4bvmid1kq25i";
    "x86_64-apple-darwin" = "02j6ir8q5i3py7csf1z31c5b4imqz7sfchfbi7rd27db6x2x971l";
    "x86_64-unknown-linux-gnu" = "12iwc50shr9nj0k2636v68npak8rw5fymmvm6y0vzjp7vg4qr1qd";
    "aarch64-unknown-linux-gnu" = "0zihkzgncjsl0jfdda3mfrrblg383qc8j1zdpxw5b82j80dbbq41";
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
