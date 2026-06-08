{
  lib,
  buildNpmPackage,
  fetchzip,
  makeWrapper,
  nodejs_22,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.1.168";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-CmEESVkvMJtROO5t66PEdOD20rKz9K8iJE8Zhy3pj8g=";
  };

  npmDepsHash = "sha256-+Zp2pt1gRZDjDOcc6vyq8SWDAT477LQEwa01o/Wv2hY=";

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
