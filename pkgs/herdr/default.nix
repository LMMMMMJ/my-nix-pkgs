{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  callPackage,
  runCommand,
  zig_0_16,
  zstd,
  pkg-config,
  git,
  versionCheckHook,
  cctools ? null,
  xcbuild ? null,
}:

let
  # 与官方 nix/package.nix 相同，预先提供 libghostty-vt 的 Zig 依赖。
  zigDeps = callPackage ./build.zig.zon.nix {
    name = "herdr-libghostty-vt-zig-cache";
    inherit zstd;
    linkFarm =
      name: entries:
      runCommand name { } ''
        mkdir -p "$out"
        ${lib.concatMapStringsSep "\n" (entry: ''
          cp -rL ${entry.path} "$out/${entry.name}"
        '') entries}
      '';
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr";
  version = "0.9.5";

  src = fetchFromGitHub {
    owner = "herdrdev";
    repo = "herdr";
    rev = "2ecf19a92fc3a7fff75b6ce3655ef04f4625ec01";
    hash = "sha256-N7e7oCKxeCoxek6UT8Lweq16rSsQQi34QMb7C2iNpm8=";
  };

  cargoHash = "sha256-a6DgQodo+qa5yg/d+yMfsM9EUv2LQRFrqZgmwgVxggE=";

  nativeBuildInputs = [
    git
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools
    xcbuild
  ];

  env = {
    LIBGHOSTTY_VT_OPTIMIZE = "ReleaseFast";
    LIBGHOSTTY_VT_SIMD = "true";
    LIBGHOSTTY_VT_ZIG_SYSTEM_DIR = zigDeps;
    ZIG = lib.getExe zig_0_16;
  };

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
  '';

  # 运行终端解析库的原有测试，验证新的 Rust/Zig 和链接器组合。
  cargoTestFlags = [
    "--package=ghostty-vt"
    "--lib"
  ];
  # 这些图片文件测试硬编码 /var/tmp，Nix 构建用户不能写入该目录。
  checkFlags = [
    "--skip=pane_graphics_files::tests::"
    "--skip=native_source_tests::"
    "--skip=tests::kitty_file_image_survives_source_mutation_and_unlink"
  ];
  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/herdrdev/herdr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "herdr";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
