{ upstream, python, addDriverRunpath }:

# libcuda_dirs 必须返回目录列表。当前 nixpkgs 轮子补丁误将共享库文件名作为字符串返回。
upstream.overridePythonAttrs (old: {
  postFixup = (old.postFixup or "") + ''
    substituteInPlace "$out/${python.sitePackages}/triton/backends/nvidia/driver.py" \
      --replace-fail \
        "return '${addDriverRunpath.driverLink}/lib/libcuda.so'" \
        "return ['${addDriverRunpath.driverLink}/lib']"
  '';
})
