import requests
import json

"""
Documentation:
    https://api.coyote.com/docs/index.html#section/Introduction/Authentication

Sandbox:  
    Address:    https://api-sandbox.coyote.com/connect/token 
    API Key:     rORDZaG66FEa31ty
Production: 
    Address:    https://api.coyote.com/connect/token
    API Key:     ZI9Q8iKw3E67rcjb
"""

# User Credentials
client_ID = 'KCUSBANK'

# Set run type; "Production" will use production creds / anything else will use sandbox
runType = 'Sandbox'

def creds():
    if runType == 'Production':
        return 'ZI9Q8iKw3E67rcjb', 'https://api.coyote.com/connect/token'
    else:
        return 'rORDZaG66FEa31ty', 'https://api-sandbox.coyote.com/connect/token'

# Get api_key / endpoint from creds()
api_key, credEndpoint = creds()

# API Payload that will be sent to the endpoint
authPayload = {
    'client_id': client_ID,
    'client_secret': api_key,
    'grant_type': 'client_credentials',
    'scope': 'ExternalApi'
}

def getToken():
    # Make API POST for credentials
    r = requests.post(credEndpoint, data=authPayload)
    if r.status_code == 200:
        jsonResponse = r.json()
        return jsonResponse['access_token']
    else:
        raise Exception("Query failed to run by returning code of {}. {}".format(r.status_code, authPayload))

# Token used to make calls against endpoints
token = getToken()
headers = {'Content-type':'application/json', 'Accept':'application/json', 'Authorization': 'Bearer ' + token}
endpoint = credEndpoint.replace('/connect/token', '/api/v1/SpotQuotes')

# Payload requests
payload = json.dumps({
    'equipmentTypeId': 'V',
    'origin': {
        'cityName': 'Chicago',
        'stateCode': 'IL',
        'countryCode': 'US',
        'postalCode': '60647'
    },
    'destination': {
        'cityName': 'Madison',
        'stateCode': 'WI',
        'countryCode': 'US',
        'postalCode': '53703'
    },
    'pickUpDateUTC': '2020-07-05T12:41:03.6402864Z',
    'minTemperature': None,
    'maxTemperature': None,
    'weight': 100,
    'commodity': 'Sample Commodity',
    'equipmentLength': 53,
    'isHazmat': False,
    'isDropTrailer': False,
    'customerShipmentId': '123456789'
})

# Get data reply from API
def getData():
    # Post requests to get spot rate
    r = requests.post(endpoint, data=payload, headers=headers)
    if r.status_code == 200:        
        return r
    else:
        raise Exception("Query failed to run by returning code of {}. Payload: {} Headers {}".format(r.status_code, payload, headers))

# Pretty response
pretty_json = json.loads(getData().text)
print (json.dumps(pretty_json, indent=2))