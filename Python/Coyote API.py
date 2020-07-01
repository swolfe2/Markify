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

# Production credentials
api_key = 'ZI9Q8iKw3E67rcjb'
credEndpoint = 'https://api.coyote.com/connect/token'

# Sandbox credentials
"""
COMMENT OUT BELOW TO ENABLE PRODUCTION CALLS!
"""
api_key = 'rORDZaG66FEa31ty'
credEndpoint = 'https://api-sandbox.coyote.com/connect/token'

# API Payload
authPayload = {
    'client_id': client_ID,
    'client_secret': api_key,
    'grant_type': 'client_credentials',
    'scope': 'ExternalApi'
}

# Make API POST for credentials
r = requests.post(credEndpoint, data=authPayload)
jsonResponse = r.json()

# Token used to make calls against endpoints
token = jsonResponse['access_token']
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

#Post requests to get spot rate
r = requests.post(endpoint, data=payload, headers=headers)

#Pretty response
pretty_json = json.loads(r.text)
print (json.dumps(pretty_json, indent=2))