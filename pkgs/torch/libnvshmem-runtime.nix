{ lib, upstream }:

# Torch 只使用 NVSHMEM 的库和头文件，无需额外构建示例及性能测试程序。
upstream.overrideAttrs (old: {
  pname = "${old.pname}-runtime";
  outputs = [ "out" ];
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    (lib.cmakeBool "NVSHMEM_BUILD_TESTS" false)
    (lib.cmakeBool "NVSHMEM_BUILD_EXAMPLES" false)
  ];
  postInstall = lib.replaceStrings [
    ''moveToOutput "bin/examples" "$samples"''
    ''moveToOutput "bin/perftest" "$test"''
  ] [ "" "" ] old.postInstall;
})
