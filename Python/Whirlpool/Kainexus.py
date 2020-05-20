import requests

params = (
    ('id', '32064'),
)

response = requests.get('https://api.kainexus.com/api/public/v1/excel/ideaList', data={'key': 'value'}, stream=True, params=params,
                        auth=('api', 'NjYyMDMtM2M2NmIyNzYtMjc0Yi00ODhlLTk2NDAtMGM5ZjI0YTFjOWNi'))
print(response)
