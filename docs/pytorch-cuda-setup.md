# PyTorch CUDA 环境配置总结

本文档总结了在 NixOS/Nix 环境中配置 PyTorch CUDA 支持的完整方法，适用于机器学习项目开发环境。

## 🎯 配置目标

- ✅ Python 3.12 开发环境
- ✅ PyTorch 2.5.1+cu124 (CUDA 12.4 支持)
- ✅ 完整的机器学习工具链
- ✅ 无需系统级修改的 CUDA 环境
- ✅ 本地编译优化性能（推荐）

## 📁 项目结构

```
MarketDataProvider/
├── flake.nix                 # 主配置文件
├── flake.lock               # 锁定版本文件
├── nix/
│   ├── development.nix      # 开发环境配置
│   ├── packages.nix         # 包配置
│   └── README.md           # 使用说明
└── docs/
    └── pytorch-cuda-setup.md  # 本文档
```

## 🔧 关键配置要点

### 1. 编译方式选择

#### 方案 A: 本地编译（推荐 - 更优性能）

**优势**: 
- 针对本机 CPU/GPU 优化编译，性能更佳
- 可以启用特定的优化选项
- 获得最新的功能和修复

**劣势**:
- 编译时间长（1-3小时）
- 需要足够内存和存储空间
- 编译可能失败，需要多次尝试

```nix
# ✅ 本地编译方式（推荐）
torch          # 从源码编译的 CUDA PyTorch
torchvision    # 从源码编译的 CUDA torchvision  
torchaudio     # 从源码编译的 CUDA torchaudio
```

#### 方案 B: 预编译二进制（性能较弱机器推荐）

**优势**: 
- 快速安装，无需编译
- 稳定可靠
- 适合性能较弱的机器

**劣势**:
- 性能相对较低
- 无法针对特定硬件优化

```nix
# ✅ 预编译方式（性能较弱机器推荐）
torch-bin      # 预编译的 CUDA PyTorch
torchvision-bin # 预编译的 CUDA torchvision  
torchaudio-bin  # 预编译的 CUDA torchaudio
```

### 2. 全局启用 CUDA 支持

在 `development.nix` 中：

```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  config = {
    allowUnfree = true;
    cudaSupport = true;  # 🔑 关键配置
  };
};
```

### 3. 包含必要的 CUDA 依赖包

```nix
packages = with pkgs; [
  # CUDA dependencies - 关键包
  cudatoolkit
  linuxPackages.nvidia_x11
  libGLU
  libGL
  xorg.libXi
  xorg.libXmu
  freeglut
  xorg.libXext
  xorg.libX11
  xorg.libXv
  xorg.libXrandr
  ncurses5
  stdenv.cc
  binutils
];
```

### 4. 设置 CUDA 环境变量

在 `shellHook` 中：

```bash
# CUDA environment setup (no system modification needed)
export CUDA_PATH=${pkgs.cudatoolkit}
export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib:$LD_LIBRARY_PATH
export EXTRA_LDFLAGS="-L${pkgs.linuxPackages.nvidia_x11}/lib"
export EXTRA_CCFLAGS="-I${pkgs.cudatoolkit}/include"
```

## 📋 完整的开发环境包列表

### 核心机器学习包（本地编译版本）
```nix
# Core data processing
pandas
numpy
scipy

# Machine learning and scientific computing
scikit-learn
numba
lightgbm
torch          # 从源码编译的 CUDA PyTorch（推荐）
torchvision    # 从源码编译的 CUDA torchvision
torchaudio     # 从源码编译的 CUDA torchaudio
```

### 核心机器学习包（预编译版本 - 性能较弱机器）
```nix
# Core data processing
pandas
numpy
scipy

# Machine learning and scientific computing
scikit-learn
numba
lightgbm
torch-bin      # 预编译的 CUDA PyTorch（性能较弱机器）
torchvision-bin # 预编译的 CUDA torchvision
torchaudio-bin  # 预编译的 CUDA torchaudio
```

### 开发工具
```nix
# Development tools
python312Packages.black
python312Packages.flake8
python312Packages.pytest
python312Packages.mypy
python312Packages.ipython
python312Packages.jupyterlab
```

### 其他工具
```nix
# Market data and APIs
requests
httpx
aiohttp
fastapi
uvicorn

# Database
sqlalchemy
psycopg2
aiomysql
redis

# MQTT
aiomqtt
paho-mqtt
mosquitto

# Data formats
openpyxl
xlsxwriter
```

## 🚀 使用方法

### 本地编译方式（推荐）

```bash
cd MarketDataProvider

# 更新 flake 依赖
nix flake update

# 限制并发编译以提高成功率
nix develop --option cores 8 --option max-jobs 1
```

**⚠️ 重要提示**:
- `--option cores 8`: 限制每个任务最多使用 8 个 CPU 核心
- `--option max-jobs 1`: 限制同时只能运行 1 个编译任务
- 编译可能需要 1-3 小时，请耐心等待
- **注意**: 可能需要编译多次才能成功！如果编译失败，请重新运行命令

### 预编译方式（性能较弱机器）

```bash
cd MarketDataProvider

# 使用预编译版本，快速进入开发环境
nix develop
```

### 验证 CUDA 状态
```python
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA devices: {torch.cuda.device_count()}")
print(f"Current device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}")
```

### 测试 GPU 计算
```python
import torch

# 创建张量并移到 GPU
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
x = torch.randn(1000, 1000).to(device)
y = torch.randn(1000, 1000).to(device)

# GPU 矩阵乘法
result = torch.matmul(x, y)
print(f"计算完成，设备: {result.device}")
```

## 🔍 故障排查

### 问题 1: CUDA available: False

**可能原因**:
1. 缺少 NVIDIA 驱动包
2. 环境变量未正确设置
3. 使用了 CPU 版本的 torch

**解决方案**:
1. 确保包含 `linuxPackages.nvidia_x11`
2. 检查 `LD_LIBRARY_PATH` 设置
3. 使用 `torch`（本地编译）或 `torch-bin`（预编译）

### 问题 2: 编译错误或失败

**可能原因**:
1. 内存不足
2. 磁盘空间不足
3. 并发任务过多导致资源竞争
4. 网络问题导致依赖下载失败

**解决方案**:
1. 使用 `--option cores 8 --option max-jobs 1` 限制并发
2. 确保至少有 16GB 可用内存
3. 确保至少有 20GB 可用磁盘空间
4. **多次尝试编译**，有时需要 2-3 次才能成功
5. 如果多次失败，切换到预编译版本（`torch-bin`）

### 问题 3: 编译时间过长

**解决方案**:
1. 本地编译通常需要 1-3 小时，这是正常的
2. 可以在后台运行：`nohup nix develop --option cores 8 --option max-jobs 1 &`
3. 如果时间紧急，使用预编译版本（`torch-bin`）

### 问题 4: 版本冲突

**可能原因**:
1. 混用不同来源的 PyTorch 包
2. 依赖包版本不匹配

**解决方案**:
1. 统一使用 nixpkgs 的版本（`torch` 或 `torch-bin`）
2. 确保 `cudaSupport = true` 全局设置
3. 运行 `nix flake update` 更新依赖

## 📊 性能对比

### 本地编译 vs 预编译性能测试

```python
import torch
import time

def benchmark_performance():
    if not torch.cuda.is_available():
        print("CUDA 不可用")
        return
    
    device = torch.device('cuda')
    
    # 测试不同矩阵大小
    sizes = [1000, 3000, 5000]
    
    for size in sizes:
        a = torch.randn(size, size, device=device)
        b = torch.randn(size, size, device=device)
        
        # 预热
        torch.matmul(a, b)
        torch.cuda.synchronize()
        
        # 基准测试
        start_time = time.time()
        for _ in range(10):
            result = torch.matmul(a, b)
        torch.cuda.synchronize()
        end_time = time.time()
        
        avg_time = (end_time - start_time) / 10
        print(f"矩阵大小 {size}x{size}: {avg_time:.4f}s")

if __name__ == "__main__":
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print("=" * 50)
    benchmark_performance()
```

**预期性能差异**:
- 本地编译版本通常比预编译版本快 5-15%
- 在特定硬件上优化更明显
- 对于大规模训练任务，性能提升更显著

## 💡 最佳实践建议

### 选择编译方式的决策树

```
你的机器配置如何？
├── 高性能 (32GB+ 内存, 8+ 核心 CPU)
│   ├── 时间充裕 → 选择本地编译
│   └── 时间紧急 → 选择预编译，后续再切换
├── 中等性能 (16GB+ 内存, 4+ 核心 CPU)
│   ├── 愿意等待 → 尝试本地编译
│   └── 追求稳定 → 选择预编译
└── 低性能 (< 16GB 内存, < 4 核心 CPU)
    └── 强烈建议使用预编译
```

### 混合策略
1. **开发阶段**: 使用预编译版本快速开始
2. **优化阶段**: 切换到本地编译版本获得更好性能
3. **生产部署**: 根据服务器配置选择合适版本

## 🎉 成功标志

当环境正确配置后，你应该看到：

```
🔥 PyTorch CUDA status:
PyTorch: 2.5.1+cu124
CUDA available: True
CUDA devices: 1
```

## 📚 参考资源

- [NixOS CUDA Wiki](https://nixos.wiki/wiki/CUDA)
- [PyTorch CUDA 文档](https://pytorch.org/get-started/locally/)
- [nixpkgs CUDA 文档](https://ryantm.github.io/nixpkgs/languages-frameworks/cuda/)
- [Nix 编译选项文档](https://nixos.org/manual/nix/stable/command-ref/conf-file.html)

## 🏷️ 版本信息

- **创建日期**: 2025-01-31
- **更新日期**: 2025-01-31
- **NixOS 版本**: 24.11
- **PyTorch 版本**: 2.5.1+cu124
- **CUDA 版本**: 12.4
- **Python 版本**: 3.12.8

---

*本文档基于 MarketDataProvider 项目的实际配置经验编写，已在 NVIDIA GeForce RTX 4070 Ti SUPER 上验证成功。包含本地编译和预编译两种方案，适用于不同性能需求的机器。* 