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
  version = "0.112.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  hashes = {
    "aarch64-apple-darwin" = "0f27s2ma8jjr8jl3jc7c9jc2s0a4pz6llqs4g1ir4924qzny7vhr";
    "x86_64-apple-darwin" = "0w4dpcvd0blgnrcci99b7js7iqfky982p11g5jivm9rqb07msvr5";
    "x86_64-unknown-linux-gnu" = "0vlvsx05qcrnma0fs4ygdc5wd9ypn0v50nsy28w107afzj5bj5lh";
    "aarch64-unknown-linux-gnu" = "1ajakb0kd7fnsa7ax88z3x8pbdscksdnidv79k6jibaaxp3w4iv3";
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
