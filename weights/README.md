# CNN权重文件目录

此目录用于存放CNN神经网络的训练权重文件。

## ⚠️ 重要说明

**本目录当前为空**。权重文件需要从原始开源项目手动下载。

## 权重文件来源

权重文件来自GitHub开源项目：
- **项目名称**: CNN-Implementation-in-Verilog
- **地址**: https://github.com/boaaaang/CNN-Implementation-in-Verilog
- **路径**: `pyTorch/mnist_cnn/`

## 快速获取权重文件

### 方法1: 使用Git克隆（推荐）

```powershell
# 在PowerShell中执行
cd d:\newcode\fpga-hack\base\urbana_digit_recognition

# 克隆完整仓库
git clone https://github.com/boaaaang/CNN-Implementation-in-Verilog.git temp_repo

# 复制权重文件
New-Item -ItemType Directory -Force -Path weights
Copy-Item temp_repo\pyTorch\mnist_cnn\*.txt weights\

# 删除临时仓库
Remove-Item -Recurse -Force temp_repo

# 验证
Get-ChildItem weights\*.txt
```

### 方法2: 手动下载

1. 访问: https://github.com/boaaaang/CNN-Implementation-in-Verilog/tree/master/pyTorch/mnist_cnn
2. 下载所有 `.txt` 文件
3. 放入此目录

## 所需文件清单

下载后，此目录应包含以下文件：

### 卷积层1权重 (4个文件)
- [ ] `conv1_weight_1.txt`
- [ ] `conv1_weight_2.txt`
- [ ] `conv1_weight_3.txt`
- [ ] `conv1_bias.txt`

### 卷积层2权重 (4个文件)
- [ ] `conv2_weight_11.txt`
- [ ] `conv2_weight_12.txt`
- [ ] `conv2_weight_13.txt`
- [ ] `conv2_bias.txt`

### 全连接层权重 (2个文件)
- [ ] `fc_weight.txt`
- [ ] `fc_bias.txt`

### 输出层权重 (10个文件)
- [ ] `0_20.txt`
- [ ] `0_21.txt`
- [ ] `0_22.txt`
- [ ] `0_23.txt`
- [ ] `0_24.txt`
- [ ] `0_25.txt`
- [ ] `0_26.txt`
- [ ] `0_27.txt`
- [ ] `0_28.txt`
- [ ] `0_29.txt`

**总计**: 20个文件

## 验证权重文件

下载完成后，可以运行以下命令验证：

```powershell
# 检查文件数量
(Get-ChildItem weights\*.txt).Count
# 应该输出: 20

# 列出所有文件
Get-ChildItem weights\*.txt | Select-Object Name
```

## 修改源代码中的权重路径

下载权重文件后，需要修改以下源文件中的 `$readmemh` 路径：

### 1. conv1.sv (第67-70行)
```verilog
// 修改前:
$readmemh("D:/YJS_TCL_FPGA/.../conv1_weight_1.txt", weight_1);

// 修改后:
$readmemh("weights/conv1_weight_1.txt", weight_1);
$readmemh("weights/conv1_weight_2.txt", weight_2);
$readmemh("weights/conv1_weight_3.txt", weight_3);
$readmemh("weights/conv1_bias.txt", bias);
```

### 2. conv2.sv (第87-91行)
```verilog
$readmemh("weights/conv2_bias.txt", bias);
$readmemh("weights/conv2_weight_11.txt", weight_1);
$readmemh("weights/conv2_weight_12.txt", weight_2);
$readmemh("weights/conv2_weight_13.txt", weight_3);
```

### 3. full_layer.sv (第34-35行)
```verilog
$readmemh("weights/fc_weight.txt", weight);
$readmemh("weights/fc_bias.txt", bias);
```

### 4. output_layer.sv (第21-30行)
```verilog
$readmemh("weights/0_20.txt", T0);
$readmemh("weights/0_21.txt", T1);
$readmemh("weights/0_22.txt", T2);
// ... 依此类推
$readmemh("weights/0_29.txt", T9);
```

## 转换为COE格式（用于综合）

如果要在Vivado中综合FPGA比特流，需要将权重转换为COE格式：

```powershell
cd util
python txt_to_coe.py --batch ../weights/ --output ../weights_coe/
```

这将创建 `weights_coe/` 目录，包含所有的 `.coe` 文件。

## 权重文件格式

所有权重文件都是16进制文本格式，每行一个值：

```
12
34
AB
...
```

- 数据宽度: 8位
- 格式: 有符号补码
- 范围: -128 到 +127 (8'shXX)

## 许可证

权重文件继承自原项目的许可证。请遵守开源协议。

## 更多信息

详细说明请参考项目根目录的 **[WEIGHTS_README.md](../WEIGHTS_README.md)**

---
**状态**: 等待下载权重文件 📥
