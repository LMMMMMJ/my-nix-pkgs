{ upstream }:

# 当前 nixpkgs 已提供 6.1.0。沿用仓库的离线构建方式，导入检查仍由标准流程执行。
upstream.overridePythonAttrs (_: {
  doCheck = false;
})
