{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "temporal-ui-server";
  version = "2.50.0";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "ui-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wUUzG707on61HMHjrL1vkg6/Ct78eFr9K8ZjMg4F0NI=";
  };

  vendorHash = "sha256-9G1So2AQQELDA2/EWcTcPRVkZBWGyec+YpdeLCykFNI=";

  postInstall = ''
    mv $out/bin/server $out/bin/temporal-ui-server
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Golang Server for Temporal Web UI";
    homepage = "https://github.com/temporalio/ui-server";
    changelog = "https://github.com/temporalio/ui-server/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "temporal-ui-server";
  };
})
