{
  lib,
  buildNpmPackage,
  fetchzip,
  makeWrapper,
  nodejs_20,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.1.150";

  nodejs = nodejs_20; # required for sandboxed Nix builds on Darwin

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-ZV03EuQiC3rHbu84chQupmcnUNfpzyKbwcy81icqh6w=";
  };

  npmDepsHash = "sha256-pRurEULi+A1C1biWhK2hn2mZ8/uuZAOsHSSS0c36os4=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  AUTHORIZED = "1";

  nativeBuildInputs = [ makeWrapper ];

  # claude-code now ships a native binary at bin/claude.exe (postinstall script
  # copies it from the platform-specific optionalDependency). The npm-generated
  # launcher tries to `node claude.exe`, which fails — replace with a direct exec.
  # DISABLE_AUTOUPDATER stops auto-updates; DEV=true crashes with WebSocket errors.
  postInstall = ''
    rm -f $out/bin/claude $out/bin/.claude-wrapped
    makeWrapper \
      $out/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe \
      $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --unset DEV
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
  };
}
