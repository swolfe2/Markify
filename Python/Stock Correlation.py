import numpy as np 
import pandas as pd 
import pandas_datareader as web 
from datetime import datetime 
import matplotlib.pyplot as plt 
import seaborn

start = datetime(2021, 3, 1)
symbols_list = ['SOS', 'RIOT', 'MARA', 'ETH-USD', 'BTC-USD', 'DOGE-USD']#array to store prices
symbols=[]

#array to store prices
symbols=[]
for ticker in symbols_list:     
    r = web.DataReader(ticker, 'yahoo', start)   
    # add a symbol column   
    r['Symbol'] = ticker    
    symbols.append(r)# concatenate into df
df = pd.concat(symbols)
df = df.reset_index()
df = df[['Date', 'Close', 'Symbol']]
df.head()
df_pivot=df.pivot('Date','Symbol','Close').reset_index()
df_pivot.head()

corr_df = df_pivot.corr(method='pearson')
#reset symbol as index (rather than 0-X)
corr_df.head().reset_index()
#del corr_df.index.name
corr_df.head(10)

plt.figure(figsize=(13, 13))
seaborn.heatmap(corr_df, annot=True, annot_kws={"size": 20}, linewidths=.5)
plt.figure()