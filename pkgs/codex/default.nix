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
}:

let
  version = "0.101.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  hashes = {
    "aarch64-apple-darwin" = "1y07h9gxp5ggfn8a9d3qp5df28bq6yg6a9xazq5if3my0a87w27w";
    "x86_64-apple-darwin" = "1sf3xb9nvhsw1yrr41n2sd1ns0q87grnacxy68qr7w3mgi8y7m2i";
    "x86_64-unknown-linux-gnu" = "0dl2lnjz64ggz1bk8yb776283x8fc6cld92brqwnmpvhp3ijswz9";
    "aarch64-unknown-linux-gnu" = "0x14l1prms163ylfhm88y4ygd36ib794q3wyy0a1f3j2l2mr7j77";
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
  buildInputs = lib.optionals stdenv.isLinux [ openssl libcap ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    tar -xzf ${binary} -C build
    mv build/codex-${platform} build/codex
    chmod u+w,+x build/codex

    ${lib.optionalString stdenv.isLinux ''
    patchelf \
      --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath [ openssl libcap ]}" \
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
