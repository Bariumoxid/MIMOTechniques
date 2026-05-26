import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # needed for 3d plot

variable = "Period"
configuration = "Config1"

file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Plot_Generation\{configuration}_{variable}.xlsx'
data = pd.read_excel(file_path.format(configuration=configuration, variable=variable))

# 1) 找到 Throughput 和 maxThroughput 的所有列
throughput_cols = [c for c in data.columns if c.startswith(f"Throughput_{configuration}_")]
max_cols        = [c for c in data.columns if c.startswith(f"maxThroughput_{configuration}_")]

# 2) 解析所有变量的 index，例如取 1, 2, 3, ...
def extract_idx(colname):
    # e.g. "Throughput_Config1_4" -> "4"
    return int(colname.split('_')[-1])

idx_th = sorted([extract_idx(c) for c in throughput_cols])
idx_max = sorted([extract_idx(c) for c in max_cols])

# 确保 index 一致
assert idx_th == idx_max
all_idx = idx_th

# 3) 构建 3D 数据矩阵 Z：shape = (len(index), len(all_idx))
Z = np.zeros((len(data), len(all_idx)))

for j, i in enumerate(all_idx):
    th_col = f"Throughput_{configuration}_{i}"
    mx_col = f"maxThroughput_{configuration}_{i}"

    th = data[th_col].values
    max_val = data[mx_col].iloc[0]   # 关键：只取第一行

    Z[:, j] = th / max_val


# 4) 创建网格
X = np.arange(len(data))[:, None]          # x = throughput row index
Y = np.array(all_idx)[None, :]             # y = variables #
X, Y = np.meshgrid(np.arange(len(data)), all_idx, indexing='ij')

# 5) 绘制 3D 图
fig = plt.figure(figsize=(10, 6))
ax = fig.add_subplot(111, projection='3d')

ax.plot_surface(X, Y, Z, cmap='viridis')
ax.set_xlabel("Index")
ax.set_ylabel("SNR")
ax.set_zlabel("Throughput / Max Throughput")

plt.title(f"Normalised Throughput Surface for {configuration}")
plt.show()


plt.imshow(Z.T, aspect='auto', cmap='viridis')
plt.colorbar(label="Normalised Throughput")
plt.xlabel("Index")
plt.ylabel("SNR")
plt.yticks(ticks=range(len(all_idx)), labels=all_idx)
plt.show()
