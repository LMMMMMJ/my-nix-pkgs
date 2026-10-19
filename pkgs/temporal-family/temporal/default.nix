{
  lib,
  fetchFromGitHub,
  buildGo127Module,
  versionCheckHook,
}:

buildGo127Module (finalAttrs: {
  pname = "temporal";
  version = "1.32.1";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "temporal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-5TLxrCk1YH2LnuB0Je/jzW1xrGjA8EhcL4Dr4ertlFs=";
  };

  vendorHash = "sha256-py4OvFtc8UtVx9ei74/CrYtRDahW7Q1LK+DK8Wd1de8=";

  subPackages = [
    "cmd/server"
    "cmd/tools/cassandra"
    "cmd/tools/sql"
    "cmd/tools/tdbg"
  ];

  env.CGO_ENABLED = 0;

  tags = [ "test_dep" ];
  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  postInstall = ''
    mkdir -p $out/share
    cp -r schema $out/share/
    mv $out/bin/server $out/bin/temporal-server
    mv $out/bin/cassandra $out/bin/temporal-cassandra-tool
    mv $out/bin/sql $out/bin/temporal-sql-tool
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "Microservice orchestration platform which enables developers to build scalable applications without sacrificing productivity or reliability";
    homepage = "https://temporal.io";
    changelog = "https://github.com/temporalio/temporal/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "temporal-server";
  };
})
