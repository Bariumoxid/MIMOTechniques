import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import matplotlib as mpl


FIG_WIDTH = 5.5   # inch, ~ \columnwidth
FIG_HEIGHT = 3.5  # inch
COLORS = {
    "proposed": "#1f3a5f",   # 深蓝（主结果）
    "Samsung":  "#6b7280",   # 冷灰
    "Ericsson": "#9ca3af",   # 浅灰
    "Mediatek": "#4b5563",   # 深灰
}

LINESTYLES = {
    "Samsung":  "--",
    "Ericsson": ":",
    "Mediatek": "-."
}


# === 配置 ===
file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\throughput_data_Comparison_1Y.xlsx'
#schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom','CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIBest','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIBest','CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom']
#schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIBest']
#schemes = ['CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom','CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom_CW1','CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom_CW2']
#schemes = ['CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CW1','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CW2']
# === 读取 Excel ===
schemes=['CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom_CSIBenchmark_1Y','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_1Y', ]
df = pd.read_excel(file_path)

# === 通用 SNR 设置 ===
snr_min, snr_max, step = -5, 55, 1
snr = np.arange(snr_min, snr_max + step, step)  # ✅ +step 让 35 包含在内no
plt.figure(figsize=(FIG_WIDTH, FIG_HEIGHT))

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
    plt.plot(
        snr_local,
        throughput_pct,
        linestyle='-',
        linewidth=2.0,
        marker='o',
        markersize=4,
        markerfacecolor='white',
        label='Simulation',
        color=COLORS["proposed"],
    )

file_path_2 = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\throughput_data_3GPP_1Y.xlsx'  # ← 修改为第二个文件路径
df2 = pd.read_excel(file_path_2)
schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom']
companies=['Samsung', 'Ericsson', 'Mediatek']
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
        plt.plot(
            snr_local,
            throughput*100,
            linestyle=LINESTYLES[company],
            linewidth=1,
            alpha=0.8,
            label=company,
            color=COLORS[company],
        )


# === 样式 ===
plt.xlabel(r'SNR (dB)')
plt.ylabel(r'Throughput (%)')
#plt.grid(True, linestyle=':', linewidth=0.8, alpha=0.7)
plt.ylim(0, 105)
plt.xlim(-5,30)
plt.legend(frameon=False, fontsize=9)
plt.tight_layout()
plt.show()
