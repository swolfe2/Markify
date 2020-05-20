import io
import os
import difflib
import pandas as pd
import numpy as np
import sqlalchemy as sa
from urllib.parse import quote_plus
from turbodbc import connect, make_options
from io import StringIO
from datetime import datetime
import time
from shutil import copyfile

#Set starting directory
startDir = '\\\\USTCA097\\Stage\\Database Files\\USBank\\1 - Files To Process'

#Set directory which has files
fileDir = '\\\\sappa4fs.kcc.com\\interfaces\\PA4\\Mulesoft\\EDI\\USBANK\\IN\\Processed'

#Loop through all files, and if it's a PAID .txt file that was modified in the last 24 hours, copy to the Files to Process folder
for filename in os.listdir(fileDir):
    now = datetime.today()
    if filename.endswith('.txt') and "PAID" in filename.upper():
        filepath = fileDir +'\\'+ filename
        modDate = datetime.fromtimestamp(os.path.getmtime(filepath))
        hoursOld = (now - modDate).total_seconds() / 3600
        if hoursOld != 24:
            destfilepath = startDir +'\\'+ filename
            copyfile(filepath, destfilepath)