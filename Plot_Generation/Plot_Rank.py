import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

file_path = r'C:\Wichtig\cam\IIB\ForthYearProj\Mich_PPT\rank.xlsx'
schemes=["Test"]
df = pd.read_excel(file_path)
bar=0
for scheme in schemes:
    rank_col = f'{scheme}'
    rank = df[rank_col].dropna().to_numpy()
    if bar==1:
        plt.hist(rank, bins=[1,2,3,4,5],
            label=f'Scheme {scheme}'
        )

    #also scatter the change in values vs. row number
    else:
        plt.scatter(
            np.arange(len(rank)),
            rank,
            s=1,marker='x',
            label=f'Scheme {scheme} points'
        )
        plt.ylim(0,5)
        plt.show()
