{
  lib,
  fetchFromGitHub,
  buildGo127Module,
  versionCheckHook,
}:

buildGo127Module (finalAttrs: {
  pname = "temporal-ui-server";
  version = "2.56.0";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "ui-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rj9by/QUznZ3vWZM8fVkCrfYXH2YKjwBZmNKZCb+4uU=";
  };

  vendorHash = "sha256-koUTvqkyUYmiEIBIhSPompMQHi+HI4Zsq0SOJ0wnQFc=";

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
