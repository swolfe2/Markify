import requests
from bs4 import BeautifulSoup
import pandas as pd

url = "https://pro.coinbase.com/orders/fees"
requests.get(url)
page = requests.get(url)

soup = BeautifulSoup(page.text, "lxml")
print(soup)

table_data = soup.find(
    "table",
    class_="table table-striped table-bordered table-hover table-condensed table-list",
)

headers = []
for i in table_data.find_all("th"):
    title = i.text
    headers.append(title)

df = pd.DataFrame(columns=headers)

for j in table_data.find_all("tr")[1:]:
    row_data = j.find_all("td")
    row = [tr.text for tr in row_data]
    length = len(df)
    df.loc[length] = row
