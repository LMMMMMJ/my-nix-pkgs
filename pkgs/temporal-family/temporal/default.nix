{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "temporal";
  version = "1.31.0";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "temporal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FgqJcDHY7p6k5Z7TFBQHMV0xZjfdqBPRDIQ2hsa+1LQ=";
  };

  vendorHash = "sha256-CRoBLiHi9EBOuTm4Ue6tpg7SGDdvG7ySGUcM+8w4HCU=";

  excludedPackages = [ "./build" ];

  env.CGO_ENABLED = 0;

  tags = [ "test_dep" ];
  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r ./schema $out/share/

    install -Dm755 "$GOPATH/bin/server" -T $out/bin/temporal-server
    install -Dm755 "$GOPATH/bin/cassandra" -T $out/bin/temporal-cassandra-tool
    install -Dm755 "$GOPATH/bin/sql" -T $out/bin/temporal-sql-tool
    install -Dm755 "$GOPATH/bin/tdbg" -T $out/bin/tdbg

    runHook postInstall
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
