{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "temporal-ui-server";
  version = "2.49.1";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "ui-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-cCYBMNkQZBdy1OpofI0THT9qDtYdsfI/rl3MWi0K1CU=";
  };

  vendorHash = "sha256-nw4OHa13kRvdR6IFop5eZiB+5+cJCry4sgTnercRq9s=";

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
