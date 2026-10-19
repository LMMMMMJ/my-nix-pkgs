{ upstream, fetchFromGitHub }:

# 复用 nixpkgs 的 Go 构建、运行依赖、服务文件和补全，只在本仓库固定发布版本。
upstream.overrideAttrs (old: rec {
  version = "1.104.1";
  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    tag = "v${version}";
    hash = "sha256-f80GVxstQrr8ENP1bseoIpLflQ+QYEisDF8PHzTs7Lg=";
  };
  vendorHash = "sha256-f9abuyk1qvVr6MPpfmHay6p/U/+8flm1SBmHGjZa1aU=";
  meta = old.meta // {
    changelog = "https://tailscale.com/changelog";
  };
})
