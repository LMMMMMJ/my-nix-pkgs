{
  lib,
  stdenv,
  fetchurl,
  bash,
  patchelf,
}:

let
  version = "2.1.51";

  baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  platformMap = {
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or null;

  hashes = {
    "darwin-arm64" = "1f8qkgid0mg5akgpc8m20n1rcf0s8605h153mm45w27z960d03j5";
    "darwin-x64" = "13i9720xfrya9ckh8wzm18jfdblwgyj75v2xymbxwmzrwva2318p";
    "linux-x64" = "1ism0hsf91gp529wkbq7v90kcn1a5dw7szp9a4bki23xms98lk47";
    "linux-arm64" = "06y85v9sahf479wscg3il7x617nj8ypspv1r4srp0d33hajk6z8j";
  };

  binary = fetchurl {
    url = "${baseUrl}/${version}/${platform}/claude";
    sha256 = hashes.${platform};
  };
in
assert platform != null || throw "Platform ${stdenv.hostPlatform.system} not supported. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux";

stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.isLinux [ patchelf ];

  buildPhase = ''
    runHook preBuild
    cp ${binary} claude
    chmod u+w,+x claude

    ${lib.optionalString stdenv.isLinux ''
    patchelf \
      --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
      claude
    ''}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    cp claude $out/bin/claude-raw
    chmod +x $out/bin/claude-raw

    cat > $out/bin/claude << 'WRAPPER_EOF'
#!${bash}/bin/bash
export DISABLE_AUTOUPDATER=1
exec "$out/bin/claude-raw" "$@"
WRAPPER_EOF
    chmod +x $out/bin/claude

    substituteInPlace $out/bin/claude \
      --replace-fail '$out' "$out"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    license = licenses.unfree;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "claude";
  };
}
