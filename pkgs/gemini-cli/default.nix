{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  ripgrep,
  jq,
  pkg-config,
  libsecret,
}:

buildNpmPackage (finalAttrs: {
  pname = "gemini-cli";
  version = "0.33.1";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dDP+UcIuajyad0tZz6/jqJ9AMERUtyn0z2ohkGiSSj0=";
  };

  npmDepsHash = "sha256-Frne1xZoMqcJowMzhGrBpTYcjqQuUgbP2ak63NYbHlY=";

  nativeBuildInputs = [
    jq
  ] ++ lib.optionals stdenv.isLinux [
    pkg-config
  ];

  buildInputs = [
    ripgrep
  ] ++ lib.optionals stdenv.isLinux [
    libsecret
  ];

  preConfigure = ''
    npm run generate
  '';

  dontNpmBuild = true;

  preInstall = ''
    npm run build --workspace @google/gemini-cli-devtools
    npm run build --workspace @google/gemini-cli-core
    npm run build --workspace @google/gemini-cli-sdk
    npm run build --workspace @google/gemini-cli-a2a-server
    npm run build --workspace @google/gemini-cli
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
    cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
    cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    cp -r packages/sdk $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk
    mkdir -p $out/share/gemini-cli/packages
    cp -r packages/devtools $out/share/gemini-cli/packages/devtools

    # Remove broken symlinks that point to /build directory
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    cat > $out/bin/gemini <<EOF
    #!${stdenv.shell}
    exec ${nodejs}/bin/node "$out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js" "\$@"
    EOF
    chmod +x "$out/bin/gemini"

    runHook postInstall
  '';

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [
      xiaoxiangmoe
      FlameFlag
      taranarmo
    ];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
})
