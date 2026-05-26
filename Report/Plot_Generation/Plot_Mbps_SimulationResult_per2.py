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
file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Data\mbps_snr_per2.xlsx'
#schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom','CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIBest','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIBest','CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom']
#schemes = ['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIBest']
#schemes = ['CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom','CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom_CW1','CDL-C_8Tx_8Rx_8Layer_10Hz_noHARQ_PMIRandom_CW2']
#schemes = ['CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CW1','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CW2']
# === 读取 Excel ===
schemes=['CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_1Y', ]
#schemes=['CDL-C_4Tx_4Rx_4Layer_10Hz_noHARQ_PMIRandom_CSIBenchmark_1Y','CDL-C_4Tx_4Rx_4Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_1Y', ]
#schemes=['CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CSIBenchmark','CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_L1', 'CDL-C_8Tx_8Rx_8Layer_10Hz_HARQ_PMIRandom_CSIBenchmark_L2']
df = pd.read_excel(file_path)

#schemes = ['CDL-C_10Hz_4', 'CDL-C_10Hz_64','CDL-C_10Hz_160']
schemes=['CDL-C_10Hz_UE0','CDL-C_10Hz_4', 'CDL-C_10Hz_UE10']
schemes=['Test_5Frame1', 'Test_5Frame2', 'Test_5Frame3','Test_50Frame1', 'Test_50Frame2', 'Test_100Frame1']
schemes=['CDL-C_10Hz_4','CDL-C_10Hz_Sub_8','CDL-C_10Hz_Sub_16']
schemes = ['CDL-C_0Hz_4', 'CDL-C_0Hz_64','CDL-C_0Hz_160']



fig, axes = plt.subplots(
    1, 2,
    figsize=(6, 3.0),
    sharex=True
)

ax_left, ax_right = axes

# === 通用 SNR ===
snr_min, snr_max, step = -5, 35, 2
snr = np.arange(snr_min, snr_max + step, step)

# =========================
# 左图：Throughput (%)
# =========================
for scheme in schemes:
    t_col = f'{scheme}'

    throughput = df[t_col].dropna().to_numpy()
    snr_local = snr[:len(throughput)]
    if scheme=='CDL-C':
        ax_left.plot(
            snr_local,
            throughput,
            linestyle='-',
            linewidth=1.0,
            markersize=3,
            color="black",
            markerfacecolor='white',
            label={scheme},
            clip_on=False)
    else:
        ax_left.plot(
            snr_local,
            throughput,
            linestyle='--',
            linewidth=1.0,
            markersize=3,
            markerfacecolor='white',
            label={scheme},
            clip_on=False
    )

# =========================
# 右图：BLER
# =========================
schemes = ['CDL-C_100Hz_4', 'CDL-C_100Hz_64','CDL-C_100Hz_160']
schemes=['CDL-C_100Hz_UE0','CDL-C_100Hz_4','CDL-C_100Hz_UE10']
schemes=['CDL-C_100Hz_4','CDL-C_100Hz_Sub_8']
for scheme in schemes:
    t_col = f'{scheme}'
    bler = df[t_col].dropna().to_numpy()
    snr_local = snr[:len(bler)]

    ax_right.plot(
        snr_local,
        bler,
        linestyle='--',
        linewidth=1.0,
        label={scheme},
        clip_on=False
    )

# =========================
# Axis styling
# =========================
for ax in axes:
    ax.set_xlim(-5, 35)
    ax.tick_params(axis="both", labelsize=8)
    ax.grid(False)
    ax.set_xlabel("SNR (dB)", labelpad=2)

ax_left.set_ylim(0, 160)
ax_left.set_ylabel("Throughput (Mbps)", labelpad=2)
ax_left.set_title("Throughput", fontsize=9)
ax_left.grid(True, linestyle=':', linewidth=0.8, alpha=0.7)

ax_right.set_ylim(0, 130)
ax_right.set_ylabel("Throughput (Mbps)", labelpad=2)
ax_right.set_title("Throughput", fontsize=9)
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
