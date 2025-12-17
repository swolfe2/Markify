measures = [
    {
        "name": "Last PP Date",
        "displayFolder": "Misc Measures",
        "expression": "switch(\ntrue,\nisinscope('Calendar'[Walmart Year Week]),\n    CALCULATE(max('Calendar'[PP_WMT_WEEKEND_DATE])),\nisinscope('Calendar'[Calendar Year Month]) && not  ISFILTERED('Calendar Latest Weeks') ,\n    CALCULATE(max('Calendar'[PM_MONTH_END_DATE])),\nisinscope('Calendar'[Calendar Year Quarter]) && not  ISFILTERED('Calendar Latest Weeks'),\n    CALCULATE(max('Calendar'[PQ_QUARTER_END_DATE])),\nisfiltered('Calendar'[Walmart Year Week]), \n    CALCULATE(max('Calendar'[PP_WMT_WEEKEND_DATE])),\nisfiltered('Calendar'[Calendar Year Month]) && not  ISFILTERED('Calendar Latest Weeks'),\n    CALCULATE(max('Calendar'[PM_MONTH_END_DATE])),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) IN {"CW","LW","LW-1","LW-2","LW-3"} && not  ISFILTERED('Calendar') ,\n    CALCULATE(max('Calendar'[PP_WMT_WEEKEND_DATE])),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L4" && not  ISFILTERED('Calendar') ,\n    CALCULATE(MAX('Calendar'[Date]), 'Calendar'[L4] ="PP L4",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L12" && not  ISFILTERED('Calendar') ,\n    CALCULATE(MAX('Calendar'[Date]), 'Calendar'[L12] ="PP L12",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L13" && not  ISFILTERED('Calendar') ,\n    CALCULATE(MAX('Calendar'[Date]), 'Calendar'[L13] ="PP L13",ALL('Calendar Latest Weeks')),        \nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L26" && not  ISFILTERED('Calendar') ,\n    CALCULATE(MAX('Calendar'[Date]), 'Calendar'[L26] ="PP L26",ALL('Calendar Latest Weeks')),\nBLANK()\n)  "
    },
    {
        "name": "Prior Period AUR",
        "displayFolder": "Store Sales\\Prior Period",
        "expression": "VAR endDt = [Last PP Date]\n\nreturn\nswitch(\ntrue,\nISINSCOPE('Calendar'[Walmart Year Week]), \n    calculate([This Year AUR],'Calendar'[Walmart Week Ending Date] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,\nISINSCOPE('Calendar'[Calendar Year Month]), \n    calculate([This Year AUR], 'Calendar'[MONTH_END_DATE] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,\nISFILTERED('Calendar'[Walmart Year Week]) ,\n    calculate([This Year AUR],'Calendar'[Walmart Week Ending Date] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,    \nISFILTERED('Calendar'[Calendar Year Month]) ,\n    calculate([This Year AUR],'Calendar'[MONTH_END_DATE] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,    \nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) IN {"CW","LW","LW-1","LW-2","LW-3"} && not ISFILTERED('Calendar') ,\n   calculate([This Year AUR],'Calendar'[Walmart Week Ending Date] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L12" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year AUR],'Calendar'[L12] ="PP L12",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L13" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year AUR],'Calendar'[L13] ="PP L13",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L26" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year AUR],'Calendar'[L26] ="PP L26",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L4" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year AUR],'Calendar'[L4] ="PP L4",ALL('Calendar Latest Weeks')),\nBLANK()\n)     "
    },
    {
        "name": "Prior Period POS Quantity",
        "displayFolder": "Store Sales\\Prior Period",
        "expression": "VAR endDt = [Last PP Date]\n\nreturn\nswitch(\ntrue,\nISINSCOPE('Calendar'[Walmart Year Week]), \n    calculate([This Year POS Quantity],'Calendar'[Walmart Week Ending Date] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,\nISINSCOPE('Calendar'[Calendar Year Month]), \n    calculate([This Year POS Quantity], 'Calendar'[MONTH_END_DATE] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,\nISFILTERED('Calendar'[Walmart Year Week]) ,\n    calculate([This Year POS Quantity],'Calendar'[Walmart Week Ending Date] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,    \nISFILTERED('Calendar'[Calendar Year Month]) ,\n    calculate([This Year POS Quantity],'Calendar'[MONTH_END_DATE] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,    \nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) IN {"CW","LW","LW-1","LW-2","LW-3"} && not ISFILTERED('Calendar') ,\n   calculate([This Year POS Quantity],'Calendar'[Walmart Week Ending Date] = endDt, ALL('Calendar'),ALL('Calendar Latest Weeks')) ,\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L12" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year POS Quantity],'Calendar'[L12] ="PP L12",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L13" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year POS Quantity],'Calendar'[L13] ="PP L13",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L26" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year POS Quantity],'Calendar'[L26] ="PP L26",ALL('Calendar Latest Weeks')),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group]) ="L4" && not  ISFILTERED('Calendar'),\n    CALCULATE([This Year POS Quantity],'Calendar'[L4] ="PP L4",ALL('Calendar Latest Weeks')),\nBLANK()\n)     "
    },
    {
        "name": "Last Year POS Store Count",
        "displayFolder": "Store Sales\\Last Year",
        "expression": "SWITCH(\nTRUE,\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group])=\"CW\" && NOT ISFILTERED('Calendar')\n    ,CALCULATE(distinctcount('xFact Store Count Latest Weeks'[STORE_NBR]),\n     'xFact Store Count Latest Weeks'[LY_CW_STORE_IND]=1),\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group])=\"LW\" && NOT ISFILTERED('Calendar')\n    ,CALCULATE(distinctcount('xFact Store Count Latest Weeks'[STORE_NBR]),\n     'xFact Store Count Latest Weeks'[LY_LW_STORE_IND]=1),\n/* ... repeated conditions ... */\nHASONEVALUE('Calendar'[Walmart Year Week]) && HASONEVALUE('Items'[All Links Item Number]) ,\n    [Last Year POS Store/Item Count] ,     \n[Last Year POS Store Distinct Count]\n ) "
    },
    {
        "name": "This Year POS Store Count",
        "displayFolder": "Store Sales",
        "expression": "SWITCH(\nTRUE,\nSELECTEDVALUE('Calendar Latest Weeks'[Week Group])=\"CW\" && NOT ISFILTERED('Calendar')\n    ,CALCULATE(distinctcount('xFact Store Count Latest Weeks'[STORE_NBR]),\n     'xFact Store Count Latest Weeks'[TY_CW_STORE_IND]=1),\n/* ... repeated conditions ... */\nHASONEVALUE('Calendar'[Walmart Year Week]) && HASONEVALUE('Items'[All Links Item Number]) ,\n    [This Year POS Store/Item Count] ,     \n[This Year POS Store Distinct Count]\n ) "
    },
    {
        "name": "Prior Period Traited Store Count Base",
        "displayFolder": "Store Item\\Prior Period",
        "expression": "VAR mxDate =  [Last PP Date]\n\nRETURN \nCALCULATE(\n    DISTINCTCOUNT('xFact Traited Store Count'[STORE_NBR]),\n    'xFact Traited Store Count'[BEGIN_DT]<=mxDate,\n    'xFact Traited Store Count'[END_DT]>=mxDate\n    )"
    },
    {
        "name": "Prior Period Traited Store/Item Count",
        "displayFolder": "Store Item\\Prior Period",
        "expression": "VAR mxDate =  [Last PP Date]\n\nvar traitVal =   CALCULATE(\n        SUM( 'xFact Traited Store Count by Item'[TRAITED_STORE_CNT] ),\n        'xFact Traited Store Count by Item'[WMT_WEEKEND_DATE]= mxDate\n        )\n        \nreturn         \nSWITCH(\nTRUE,\nISINSCOPE('Items'[Walmart Item Number]),traitVal,\n/* ... repeated ISINSCOPE branches ... */\nBLANK()\n) "
    },
    {
        "name": "This Year Traited Store/Item Count",
        "displayFolder": "Store Item",
        "expression": "VAR mxDate =  [Latest Date]\n\nvar traitVal =   CALCULATE(\n        SUM('xFact Traited Store Count by Item'[TRAITED_STORE_CNT]),\n        'xFact Traited Store Count by Item'[WMT_WEEKEND_DATE]= mxDate\n        )\n        \nreturn         \nSWITCH(\nTRUE,\nISINSCOPE('Items'[Walmart Item Number]),traitVal,\n/* ... */\nBLANK()\n) "
    },
    {
        "name": "This Year POS Store/Item Count",
        "displayFolder": "Store Sales",
        "expression": "VAR vStoreCnt =IF(HASONEVALUE('Calendar'[Walmart Year Week]) ,sum('xFact Store Count By Item'[STORE_CNT]) ,BLANK())\n\nRETURN \nSWITCH(\nTRUE,\nHASONEVALUE('Items'[Walmart Item Number]),vStoreCnt, \n/* ... */\nBLANK()\n) "
    },
    {
        "name": "LY $/S/W",
        "displayFolder": "Store Sales\\$ or U/S/W",
        "expression": "VAR vSales = [Last Year POS Sales]\nVAR vStores = [Last Year POS Store Count]\nVAR Weeks = DISTINCTCOUNT( 'Calendar'[Walmart Year Week] )\nRETURN DIVIDE( (vSales / vStores), Weeks, BLANK() )"
    },
    {
        "name": "TY $/S/W",
        "displayFolder": "Store Sales\\$ or U/S/W",
        "expression": "VAR vSales = [This Year POS Sales]\nVAR vStores = [This Year POS Store Count]\nVAR Weeks = DISTINCTCOUNT( 'Calendar'[Walmart Year Week] )\nRETURN DIVIDE( (vSales / vStores), Weeks, BLANK() )"
    },
    {
        "name": "LY $/S/W Traited",
        "displayFolder": "Store Sales\\$ or U/S/W",
        "expression": "VAR vSales = [Last Year POS Sales]\nVAR vStores = [Last Year Traited Store Count]\nVAR Weeks = DISTINCTCOUNT( 'Calendar'[Walmart Year Week] )\nRETURN DIVIDE( (vSales / vStores), Weeks, BLANK() )"
    },
    {
        "name": "TY $/S/W Traited",
        "displayFolder": "Store Sales\\$ or U/S/W",
        "expression": "VAR vSales = [This Year POS Sales]\nVAR vStores = [This Year Traited Store Count]\nVAR Weeks = DISTINCTCOUNT( 'Calendar'[Walmart Year Week] )\nRETURN DIVIDE( (vSales / vStores), Weeks, BLANK() )"
    },
    {
        "name": "Last Year POS Quantity",
        "displayFolder": "Store Sales\\Last Year",
        "expression": "CALCULATE( SUM( 'xFact Sales'[TY_QTY] ), 'xFact Sales'[COMPARE_TYPE] = \"LY\" )"
    },
    {
        "name": "This Year POS Store Distinct Count DQ",
        "displayFolder": "Store Sales",
        "expression": "CALCULATE(\n    DISTINCTCOUNT('xFact Sales'[STORE_NBR]),\n    'xFact Sales'[TY_QTY]>0,\n    'xFact Sales'[STORE_NBR]< 99998\n    )"
    },
    {
        "name": "TY POS Quantity % of Total",
        "displayFolder": "Store Sales",
        "expression": "calculate(sum('xFact Sales'[TY_QTY]),ALLSELECTED('Calendar'))"
    },
    {
        "name": "Last Year Traited Store/Item Count",
        "displayFolder": "Store Item\\Last Year",
        "expression": "VAR mxDate =  [Last PY Date]\n\nvar traitVal =   CALCULATE(\n        SUM('xFact Traited Store Count by Item'[TRAITED_STORE_CNT]),\n        'xFact Traited Store Count by Item'[WMT_WEEKEND_DATE]= mxDate\n        )\n        \nreturn  traitVal"
    },
    {
        "name": "This Year Traited Store Distinct Count",
        "displayFolder": "Store Item",
        "expression": "VAR mxDate =  [Latest Date]\n\nRETURN \nCALCULATE(\n    DISTINCTCOUNT('xFact Traited Store Count'[STORE_NBR]),\n    'xFact Traited Store Count'[BEGIN_DT]<=mxDate,\n    'xFact Traited Store Count'[END_DT]>=mxDate\n    )"
    },
    {
        "name": "Max TY Date by  L4W",
        "displayFolder": "Misc Measures",
        "expression": "if(ISCROSSFILTERED('Calendar'), CALCULATE(max('Calendar'[Date]) ),BLANK()\n)"
    }
]

import json, csv

for m in measures:
    m['length'] = len(m['expression'])
    m['expression_trunc'] = m['expression'][:1000]

# Write CSV
with open(r'c:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Code\Copilot\top20_measures.csv','w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=['name','displayFolder','length','expression_trunc'])
    w.writeheader()
    for m in measures:
        w.writerow({'name':m['name'],'displayFolder':m['displayFolder'],'length':m['length'],'expression_trunc':m['expression_trunc']})

# Write JSON
with open(r'c:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Code\Copilot\top20_measures.json','w',encoding='utf-8') as f:
    json.dump(measures,f,indent=2)

print('Wrote Copilot/top20_measures.csv and Copilot/top20_measures.json')
