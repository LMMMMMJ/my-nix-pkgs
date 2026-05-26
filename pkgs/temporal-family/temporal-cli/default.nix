{
  lib,
  fetchFromGitHub,
  buildGoModule,
  installShellFiles,
  stdenv,
}:

buildGoModule (finalAttrs: {
  pname = "temporal-cli";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-P/wfvKRAvqRgUJabVE9RvT4o3fNZ52JX48hXm3C3orI=";
  };

  vendorHash = "sha256-dD21m6tlwkZkclYOcYUNlsPXxYmLggjrFTv9XctCIt0=";

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
