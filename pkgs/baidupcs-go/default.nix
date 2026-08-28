{
  fetchFromGitHub,
  buildGoModule,
  lib,
  versionCheckHook,
}:
buildGoModule rec {
  pname = "baidupcs-go";
  version = "4.0.2";

  src = fetchFromGitHub {
    owner = "qjfoidnh";
    repo = "BaiduPCS-Go";
    rev = "v${version}";
    hash = "sha256-o0Oh6zLJT25+smEgWy7E8fTigJ2FLpBXoaZSYCRFvic=";
  };

  vendorHash = "sha256-3kvB5QxtWuElhDIFFr3Awf5myf6l2Hx0M2k53ltQYeQ=";
  doCheck = false;

  ldflags = [
    "-X main.Version=v${version}"
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/${meta.mainProgram}";

  postInstall = ''
    rm -f $out/bin/AndroidNDKBuild
  '';

  postVersionCheck = ''
    rm -f $out/bin/pcs_config.json
  '';

  meta = {
    mainProgram = "BaiduPCS-Go";
    description = "Baidu Netdisk commandline client, mimicking Linux shell file handling commands";
    homepage = "https://github.com/qjfoidnh/BaiduPCS-Go";
    license = lib.licenses.asl20;
  };
}
