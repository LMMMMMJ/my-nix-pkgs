{
  lib,
  fetchFromGitHub,
  buildGo127Module,
  installShellFiles,
  stdenv,
}:

buildGo127Module (finalAttrs: {
  pname = "temporal-cli";
  version = "1.9.1";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jlcJYtX+2MLuAm8lcnzSb+YbxNKoFa+gYO0VYXgafUk=";
  };

  vendorHash = "sha256-26KejpzCVRKVvoCZazNBi/vUyXlCgYCmHxy2AiA08vA=";

  nativeBuildInputs = [ installShellFiles ];

  subPackages = [ "cmd/temporal" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/temporalio/cli/internal/temporalcli.Version=${finalAttrs.version}"
  ];

  doCheck = false;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd temporal \
      --bash <($out/bin/temporal completion bash) \
      --fish <($out/bin/temporal completion fish) \
      --zsh <($out/bin/temporal completion zsh)
  '';

  meta = {
    description = "Command-line interface for running Temporal Server and interacting with Workflows, Activities, Namespaces, and other parts of Temporal";
    homepage = "https://docs.temporal.io/cli";
    changelog = "https://github.com/temporalio/cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "temporal";
  };
})
