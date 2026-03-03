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
  version = "0.107.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-gnu";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  hashes = {
    "aarch64-apple-darwin" = "06zwgaiqalp6f11zpxbh6xm7acij15qa8pmly8spa9c2kh676zlq";
    "x86_64-apple-darwin" = "110nk72d4mhzappr5q1czz1whwrkqmf2z1pj78yx55vndic3g22h";
    "x86_64-unknown-linux-gnu" = "1p0qw9rkr19071mhg9l9wcari0bq2zbpwdzw7hr8yihvyysrrsp8";
    "aarch64-unknown-linux-gnu" = "1bc8hhwxxw5mv8wmdmnmsxizryksqhx1fp0b3y24vjq4q6qq8arj";
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
