
import csv
from collections import namedtuple
from itertools import zip_longest

import ceODBC as dbi
#import pyodbc as dbi

def read_csv(fpath, enc):
    """
    Simply read a CSV file.
    """
    with open(fpath, 'r', newline='', encoding=enc) as fp:
        rdr = csv.reader(fp)
        cnames = [''.join(cn.split()) for cn in next(rdr)]
        Rec = namedtuple('Rec', cnames)
        for row in rdr:
            rec = Rec(*[v.strip() for v in row])
            yield rec


def gen_insert(tname, cnames):
    ifmt = """
INSERT INTO {tn}
 ({cn})
VALUES
 ({prm})""".format
    cn_fmt = '[{0}]'.format
    return ifmt(
        tn=tname,
        cn=', '.join(cn_fmt(cn) for cn in cnames),
        prm=', '.join('?' for cn in cnames),
        ).strip()


def chunker_padded(iterable, n, fillvalue=None):
    """
    Collect data into fixed-length chunks or blocks
    """
    # grouper('ABCDEFG', 3, 'x') --> ABC DEF Gxx
    args = [iter(iterable)] * n
    return zip_longest(fillvalue=fillvalue, *args)


def chunker(iterable, n):
    """
    Consume the iterable in chunks.
    """
    for chunk in chunker_padded(iterable, n):
        yield [val for val in chunk if val is not None]


def rec2val(rec, cnames):
    """
    Switch to the "expected" column order.
    """
    vals = []
    for cn in cnames:
        v = getattr(rec, cn, None)
        vals.append(None if v=='' else v)
    return tuple(vals)


def load2db(rows, conn, tblname, chunk_size=12250):
    """
    Shove the records into the table.
    """
    cur = conn.cursor()
    # Get column names/order.
    cur.execute(f'select * from {tblname}')
    cnames = [d[0] for d in cur.description]

    # Prep the cursor for execution.
    isql = gen_insert(tblname, cnames)
    cur.prepare(isql)

    i = 0
    for chunk in chunker(rows, chunk_size):
        vals = [rec2val(rec, cnames) for rec in chunk]
        cur.executemany(None, vals)
        i += len(vals)
    cur.close()
    return i


cfg = {
    'connstr': 'SERVER={server};DATABASE={dbname};Trusted_Connection=yes;DRIVER={{ODBC Driver 13 for SQL Server}}',
    'server': '<sql-server-name/ip>',
    'dbname': '<dbname>',
    }


conn =  dbi.connect(cfg['connstr'].format(**cfg))
rows = read_csv('<csv-file-path>', 'cp-1252')
load2db(rows, conn, '<tbl-name>')