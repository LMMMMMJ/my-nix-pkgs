{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_22,
  cmake,
  git,
  python3,
  pkg-config,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.2.25";

  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-Csh6i5pxlXgldmkuUiOs9fVmy/Njq+eV5sy0XXcDyIM=";
  };

  npmDepsHash = "sha256-KZjCvI7WTkgMEa2dV3kVeTWzrA6UpKAV6uJ0uRD8AAU=";

  makeCacheWritable = true;

  nativeBuildInputs = [
    cmake
    git
    python3
    pkg-config
    jq
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    # Remove prepack script that tries to run pnpm build (dist/ is already pre-built)
    jq 'del(.scripts.prepack)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  dontNpmBuild = true;
  dontUseCmakeConfigure = true;

  meta = {
    description = "Multi-channel AI gateway with extensible messaging integrations";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
