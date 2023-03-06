from datetime import datetime

import matplotlib.pyplot as plt
import numpy as np
import pandas_datareader as web
import seaborn

import pandas as pd

start = datetime(2022, 4, 1)
symbols_list = [
    "SOS",
    "RIOT",
    "MARA",
    "EBON",
    "ETH-USD",
    "BTC-USD",
    "DOGE-USD",
]
# array to store prices
symbols = []

data = web.yahoo.daily.YahooDailyReader(
    symbols_list, start=start, end=datetime.now()
).read()
df = pd.DataFrame(data)

print(df)
