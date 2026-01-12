{
  lib,
  stdenv,
  fetchzip,
  nodejs_20,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "claude-code-router";
  version = "2.0.0";

  src = fetchzip {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-tBHiImDaAsLrjm8nkpDrJuh95B8sv4UzdM+qNiVFlwo=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ nodejs_20 ];

  installPhase = ''
    runHook preInstall

    # Create output directories
    mkdir -p $out/lib/claude-code-router
    mkdir -p $out/bin
    mkdir -p $out/share/claude-code-router

    # Copy all package contents
    cp -r . $out/lib/claude-code-router/

    # Create wrapper script for the main binary
    makeWrapper ${nodejs_20}/bin/node $out/bin/ccr \
      --add-flags "$out/lib/claude-code-router/dist/cli.js"

    # Copy example files if they exist
    if [ -f custom-router.example.js ]; then
      cp custom-router.example.js $out/share/claude-code-router/
    fi

    runHook postInstall
  '';

  meta = {
    description = "Use Claude Code without an Anthropics account and route it to another LLM provider";
    homepage = "https://github.com/musistudio/claude-code-router";
    downloadPage = "https://www.npmjs.com/package/@musistudio/claude-code-router";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ccr";
    platforms = lib.platforms.all;
  };
} 