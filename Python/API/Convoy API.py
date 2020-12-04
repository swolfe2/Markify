#Import Requests
import requests
import json
from requests.auth import HTTPBasicAuth

"""
Docs: https://convoy.com/convoy-api-documentation/
"""

# Set Scope, which is the same for sandbox and prod
scope = "rate-vending-service/get_rate"

# Set run type; "Production" will use production creds / anything else will use sandbox
runType = 'Production'

def creds():
    if runType == 'Production':
        return {"client_id" : '227bk1d5m5l5jevnpcp5o1u9at' 
        ,"client_secret" : '10g7b3o2lggvincjplhgchf6hklbsuvb3jb36gjp757p4cbo509j'
        ,"token_endpoint" : 'https://id.convoy.com/oauth2/token'
        ,"api_endpoint" : 'https://rates.convoy.com/api/v1/rates'}
    else:
        return {"client_id" : '7nmtomcjlk0p0odpr563slrtqc'
        ,"client_secret" : '1aqnlm155idpcn41s0anka8hqmsinukor8nf4iiamue9a08d7bd5'
        ,"token_endpoint" : 'https://demo-rate-vending-service.auth.us-west-2.amazoncognito.com/oauth2/token' 
        ,"api_endpoint" : 'https://demo-rates.convoy.com/api/v1/rates'}

# Get the credentials dictionary
credsDict = creds()

# Get api_key / endpoint from creds() / credentials dictionary
client_id = credsDict.get("client_id")
client_secret = credsDict.get("client_secret")
token_endpoint = credsDict.get("token_endpoint")
api_endpoint = credsDict.get("api_endpoint")

def getToken():
    # Make API POST for credentials
    authPayload = {'grant_type' : 'client_credentials',
        'scope' : 'rate-vending-service/get_rate'}
    headers = {'Content-Type':'application/x-www-form-urlencoded'}    
    r = requests.post(token_endpoint, auth=HTTPBasicAuth(client_id, client_secret), data=authPayload, headers=headers)
    if r.status_code == 200:
        jsonResponse = r.json()
        return jsonResponse['access_token']
    else:
        raise Exception("Query failed to run by returning code of {}. {}".format(r.status_code, authPayload))

# Token used to make calls against endpoints
token = getToken()

payload = json.dumps({
        "shipmentId": "123456",
        "shipperId": "KCNAUSD",
        "truckTypes": [
            "DRY_VAN"
        ],
        "hazmat": False,
        "totalMiles": 654,
        "weightLbs": 4599,
        "notes": "",
        "stops": [
            # Pickup Info
            {
            "isDropTrailer": False,
            "notes": "",
            "address": {
                "country": "USA",
                "city": "BEECH ISLAND",                
                "postalCode": "29842",
                "state": "SC",
                "addressOne": "246 OLD JACKSON HWY",
                "full": "246 OLD JACKSON HWY, BEECH ISLAND, SC, 29842"
            },
            "timezone": "EST",
            "stopType": "PICKUP",
            "startTime": "2020-11-06T13:12:06.556Z",
            "endTime": "2020-11-06T13:12:06.556Z"
            },

            # Stop 1 info
            {
            "isDropTrailer": False,
            "notes": "string",
            "address": {
                "country": "USA",
                "city": "NEENAH",                
                "postalCode": "549564068",
                "state": "WI",
                "addressOne": "2001 MARATHON AVE",
                "full": "2001 MARATHON AVE, NEENAH, WI, 549564068"
            },
            "timezone": "EST",
            "stopType": "DROPOFF",
            "startTime": "2020-11-07T19:12:06.556Z",
            "endTime": "2020-11-07T19:12:06.556Z"
            }
        ]
    })

# Get data reply from API
def getData():
    # Post requests to get spot rate
    headers = {'Content-type':'application/json', 'Accept':'application/json', 'Authorization': 'Bearer ' + token}
    r = requests.post(api_endpoint, data=payload, headers=headers)
    if r.status_code == 200:        
        return r
    else:
        raise Exception("Query failed to run by returning code of {}. Payload: {} Headers {}".format(r.status_code, payload, headers))

# Pretty response
pretty_json = json.loads(getData().text)
print (json.dumps(pretty_json, indent=2))

