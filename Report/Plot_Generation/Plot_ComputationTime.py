import pandas as pd
import matplotlib.pyplot as plt
import numpy as np


# 两组坐标点
points1 = [(0,0),(250,420)] #personal computer
points2 = [(0,0),(250,720)] #ts-access

# 拆分 x 和 y
x1, y1 = zip(*points1)
x2, y2 = zip(*points2)

# 绘图
plt.plot(x1, y1, marker='o', linestyle='-', color='blue', label='Personal Computer')
plt.plot(x2, y2, marker='s', linestyle='--', color='red', label='TS-Access System')

# 设置标题和标签
plt.xlabel('NFrames')
plt.xlim(0,500)
plt.ylim(0,1000)
plt.axis([0, 500, 0, 1000])   
plt.ylabel('Computation Time (min)')
plt.title('Computation Time vs NFrames')
plt.legend()
plt.grid(True)
plt.show()
