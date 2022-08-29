import SSAS as ssas_api

xmla_ep = "powerbi://api.powerbi.com/v1.0/myorg/GL%20HR%20-%20Public"
d_set = "AD User Data Flow"

ssas_api._load_assemblies()  # this uses Windows Authentication
conn = ssas_api.set_conn_string(server=xmla_ep, db_name=d_set)
