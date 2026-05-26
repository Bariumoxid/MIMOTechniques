import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import matplotlib as mpl


#FIG_WIDTH = 6  # inch, ~ \columnwidth
FIG_WIDTH =6
FIG_HEIGHT = 2  # inch
COLORS = {
    "proposed": "#1f3a5f",   # 深蓝（主结果）
    "proposed_alt":   "#355f8a",  # 浅蓝（备选）
    "Samsung":  "#6b7280",   # 冷灰
    "Ericsson": "#9ca3af",   # 浅灰
    "MediaTek": "#4b5563",   # 深灰
}

LINESTYLES = {
    "Samsung":  "--",
    "Ericsson": ":",
    "MediaTek": "-."
}


# === 配置 ===
file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\throughput_data_Comparison_1Y.xlsx'
#schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom','CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIBest','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIBest','CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom']
#schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIBest']
#schemes = ['CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom','CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom_CW1','CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom_CW2']
#schemes = ['CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CW1','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CW2']
# === 读取 Excel ===
schemes=['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_1Y']
#schemes=['CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom_CSIBenchmark_1Y','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_1Y', ]
#schemes=['CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CSIBenchmark','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_L1', 'CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_L2']
df = pd.read_excel(file_path)

# === 通用 SNR 设置 ===
snr_min, snr_max, step = -5, 55, 1
snr = np.arange(snr_min, snr_max + step, step)  # ✅ +step 让 35 包含在内no
fig, ax = plt.subplots(figsize=(FIG_WIDTH,FIG_HEIGHT))
#ax.set_box_aspect(1)

#Single Graph
for scheme in schemes:
    # 检查列是否存在
    t_col = f'Throughput_{scheme}'
    m_col = f'maxThroughput_{scheme}'

    # === 获取 throughput 数据 ===
    throughput = df[t_col].dropna().to_numpy()

    # === 获取该配置唯一的 maxThroughput 值 ===
    max_throughput = df[m_col].dropna().iloc[0]
    max_throughput_arr = np.full(len(throughput), max_throughput)

    # === 归一化 ===
    throughput_pct = throughput / max_throughput_arr * 100

    # === 对应 SNR ===
    snr_local = snr[:len(throughput)]

    # === 绘图 ===
    ax.plot(
        snr_local,
        throughput_pct,
        linestyle='-',
        linewidth=2.0,
        marker='o',
        markersize=3,
        markerfacecolor='white',
        label='Simulation',
        color=COLORS["proposed"],clip_on=False
        )


file_path_2 = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\throughput_data_3GPP_1Y.xlsx'  # ← 修改为第二个文件路径
df2 = pd.read_excel(file_path_2)
schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom']
companies=['Samsung', 'Ericsson', 'MediaTek']
#companies=[]
snr = np.arange(snr_min, 45, step) 
for scheme in schemes:
    for company in companies:
    # 检查列是否存在
        t_col = f'Throughput_{scheme}_AAV1Y_CW1_{company}'
        if t_col not in df2.columns:
            continue

        # === 读取 throughput 数据（已计算好） ===
        throughput = df2[t_col].dropna().to_numpy()

        # === 生成对应的 SNR ===
        snr_local = snr[:len(throughput)]
        # === 绘图 ===
        ax.plot(
            snr_local,
            throughput*100,
            linestyle=LINESTYLES[company],
            linewidth=1,
            alpha=0.8,
            label=company,
            color=COLORS[company],
        )


# === 样式 ===
ax.set_xlabel(r'SNR (dB)', labelpad=2)
ax.set_ylabel(r'Throughput (%)', labelpad=0)
ax.grid(True, linestyle=':', linewidth=0.8, alpha=0.7)
ax.set_ylim(0, 101)
ax.set_xlim(-5,27)
ax.legend(frameon=False, fontsize=9)
plt.tight_layout()
plt.show()


#Two graphs
file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\throughput_data_Comparison_1Y.xlsx'
df = pd.read_excel(file_path)

schemes = [
    'CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom_CSIBenchmark_1Y',
    'CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_1Y',
]

fig, axes = plt.subplots(
    1, 2,
    figsize=(6, 3.0),
    sharex=True
)

ax_left, ax_right = axes

# === 通用 SNR ===
snr_min, snr_max, step = -5, 55, 1
snr = np.arange(snr_min, snr_max + step, step)

# =========================
# 左图：Throughput (%)
# =========================
for scheme in schemes:
    t_col = f'Throughput_{scheme}'
    m_col = f'maxThroughput_{scheme}'

    throughput = df[t_col].dropna().to_numpy()
    max_throughput = df[m_col].dropna().iloc[0]
    throughput_pct = throughput / max_throughput * 100
    snr_local = snr[:len(throughput)]

    if 'noHARQ' in scheme:
        label = 'HARQ Disabled'
        marker = 'o'
        color = COLORS["proposed"]
    else:
        label = 'HARQ Enabled'
        marker = 's'
        color = COLORS["proposed_alt"]

    ax_left.plot(
        snr_local,
        throughput_pct,
        linestyle='-',
        linewidth=2.0,
        marker=marker,
        markersize=3,
        markerfacecolor='white',
        label=label,
        color=color,
        clip_on=False
    )

# =========================
# 右图：BLER
# =========================
for scheme in schemes:
    t_col = f'BLER_{scheme}'
    bler = df[t_col].dropna().to_numpy()
    snr_local = snr[:len(bler)]

    if 'noHARQ' in scheme:
        label = 'HARQ Disabled'
        marker = 'o'
        color = COLORS["proposed"]
    else:
        label = 'HARQ Enabled'
        marker = 's'
        color = COLORS["proposed_alt"]

    ax_right.plot(
        snr_local,
        bler,
        linestyle='-',
        linewidth=2.0,
        marker=marker,
        markersize=3,
        markerfacecolor='white',
        label=label,
        color=color,
        clip_on=False
    )

# =========================
# Axis styling
# =========================


ax_left.set_ylim(0, 101)
ax_left.set_ylabel("Throughput (%)", labelpad=2)
ax_left.set_title("Throughput", fontsize=9)
ax_left.grid(True, linestyle=':', linewidth=0.8, alpha=0.7)

ax_right.set_ylim(0, 1)
ax_right.set_ylabel("BLER", labelpad=2)
ax_right.set_title("BLER", fontsize=9)
ax_right.grid(True, linestyle=':', linewidth=0.8, alpha=0.7)

# Legend（只放一次）
ax_left.legend(frameon=False, fontsize=8, loc="upper left")
ax_right.legend(frameon=False, fontsize=8, loc="lower left")
# 手动布局（不要 tight_layout）
fig.subplots_adjust(
    left=0.1,
    right=0.98,
    top=0.90,
    bottom=0.18,
    wspace=0.30
)

plt.show()

snr_min, snr_max, step = -5, 55, 1
snr = np.arange(snr_min, snr_max + step, step)  # ✅ +step 让 35 包含在内no
fig, ax = plt.subplots(figsize=(FIG_WIDTH,FIG_HEIGHT))

file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\throughput_data_Comparison_1Y.xlsx' # ← 修改为第二个文件路径
df2 = pd.read_excel(file_path)
schemes = ['CDL-C_tab1', 'CDL-C_tab2']
#companies=[]
snr = np.arange(snr_min, 45, step) 
for scheme in schemes:
    # 检查列是否存在
        t_col = f'{scheme}'

        # === 读取 throughput 数据（已计算好） ===
        throughput = df2[t_col].dropna().to_numpy()
        print(throughput)
        # === 生成对应的 SNR ===
        snr_local = snr[:len(throughput)]
        # === 绘图 ===
        ax.plot(
            snr_local,
            throughput,
            linewidth=1,
            alpha=0.8,
            label=scheme,
        )


# === 样式 ===
ax.set_xlabel(r'SNR (dB)', labelpad=2)
ax.set_ylabel(r'Throughput (%)', labelpad=0)
ax.grid(True, linestyle=':', linewidth=0.8, alpha=0.7)
ax.set_ylim(0, 101)
ax.set_xlim(-5,27)
ax.legend(frameon=False, fontsize=9)
plt.tight_layout()
plt.show()