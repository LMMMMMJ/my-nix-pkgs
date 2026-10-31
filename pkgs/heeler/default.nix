{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  herdr,
  tailscale,
  makeWrapper,
  openssh,
  coreutils,
  bash,
  runtimeShell,
  settingsDirectory ? "/etc/heeler",
  requireSettings ? false,
}:

let
  support = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./cli.mjs
      ./device-registry.mjs
      ./heeler.test.mjs
    ];
  };
  minimalPath = lib.makeBinPath [
    coreutils
    openssh
    bash
  ];
in
buildNpmPackage (finalAttrs: {
  pname = "heeler";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "ZingerLittleBee";
    repo = "Heeler";
    rev = "951f76edbd6dcb2b72058bc67526df21d10901be";
    hash = "sha256-iETLQMd3szOalrDbqNg6wGsP9q3IEu/0gul0KYwe6rs=";
  };
  sourceRoot = "${finalAttrs.src.name}/plugin";
  npmDepsHash = "sha256-fZtXHgS61WcJs7JYoevuIu0P6/QbtOyUjmwirwH5v40=";
  dontNpmBuild = true;
  dontNpmInstall = true;
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ openssh ];

  postPatch = ''
    mkdir -p nix
    cp ${support}/cli.mjs nix/cli.mjs
    cp ${support}/device-registry.mjs nix/device-registry.mjs
    cp ${support}/heeler.test.mjs nix/heeler.test.mjs
    cat > nix/runtime.json <<'EOF'
    ${builtins.toJSON {
      herdr = lib.getExe herdr;
      tailscale = lib.getExe tailscale;
      inherit settingsDirectory requireSettings;
    }}
    EOF
    # Keep a public-key inventory after the upstream popup clears its temporary
    # enrollment record. Authentication itself remains upstream OpenSSH pairing.
    ${nodejs}/bin/node --input-type=module <<'EOF'
    import { readFileSync, writeFileSync } from 'node:fs';
    const path = 'src/pair-accept.js';
    const source = readFileSync(path, 'utf8');
    if (!source.includes('  recordEnrollment({')) throw new Error('Upstream enrollment changed');
    writeFileSync(path, 'import { rememberDevice } from "../nix/device-registry.mjs";\n' +
      source.replace('  recordEnrollment({', '  rememberDevice({ stateDir, ...deviceKey });\n  recordEnrollment({'));
    // Endpoint launchers are executable scripts verified in a minimal environment.
    const endpoint = 'src/endpoint.js';
    writeFileSync(endpoint, readFileSync(endpoint, 'utf8')
      .replaceAll('/bin/sh', '${runtimeShell}')
      .replaceAll('/usr/bin:/bin', '${minimalPath}'));
    EOF
  '';

  doCheck = true;
  preCheck = ''
    # Upstream creates executable fixtures containing /usr/bin/env and /bin/sh,
    # and deliberately removes Node from some PATHs. Keep that isolation while
    # substituting only the test fixtures' system tool paths for the Nix sandbox.
    node --input-type=module <<'EOF'
    import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
    for (const name of readdirSync('test').filter(name => name.endsWith('.js'))) {
      const path = 'test/' + name;
      const source = readFileSync(path, 'utf8');
      // Endpoint tests also assert that arbitrary supplied PATH values are
      // captured verbatim; their probes use endpoint.js's packaged minimal PATH.
      const contents = name === 'endpoint.test.js' ? source : source.replaceAll('/usr/bin:/bin', '${minimalPath}');
      writeFileSync(path, contents
        .replaceAll('/usr/bin/env node', '${coreutils}/bin/env node')
        .replaceAll('/bin/sh', '${runtimeShell}'));
    }
    EOF
  '';
  checkPhase = ''
    runHook preCheck
    node --test --test-concurrency=4
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/heeler" "$out/bin"
    cp -R src node_modules herdr-plugin.toml package.json README.md "$out/lib/heeler/"
    install -Dm644 "$src/LICENSE" "$out/share/doc/heeler/LICENSE"
    mkdir -p "$out/lib/heeler/nix"
    cp nix/cli.mjs nix/device-registry.mjs nix/runtime.json "$out/lib/heeler/nix/"
    # Herdr hooks and SSH bootstrap commands must find Node even with sshd's
    # minimal PATH. The package is already built, so remove the npm build hook.
    substituteInPlace "$out/lib/heeler/herdr-plugin.toml" \
      --replace-fail '["node",' '["${nodejs}/bin/node",'
    ${nodejs}/bin/node --input-type=module - "$out/lib/heeler/herdr-plugin.toml" <<'EOF'
    import { readFileSync, writeFileSync } from 'node:fs';
    const path = process.argv[2];
    writeFileSync(path, readFileSync(path, 'utf8').replace(/\[\[build\]\]\ncommand = \["npm", "ci"\]\n\n/, ""));
    EOF
    makeWrapper ${nodejs}/bin/node "$out/bin/heeler" \
      --add-flags "$out/lib/heeler/nix/cli.mjs"
    runHook postInstall
  '';

  meta = {
    description = "Packaged Heeler plugin and per-user Herdr device setup";
    homepage = "https://github.com/ZingerLittleBee/Heeler";
    license = lib.licenses.asl20;
    mainProgram = "heeler";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
