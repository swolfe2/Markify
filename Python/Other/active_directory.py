from gssapi.exceptions import GSSError
from ldap3 import ALL, SUBTREE, Connection, Server
from ldap3.core.exceptions import LDAPException
from pyasn1.codec.ber import decoder, encoder
from pyasn1.type.univ import noValue

import pandas as pd

server = Server("kccldap.kcc.com")
c = Connection(server, authentication="GSSAPI", auto_bind=True)

page_size = 500
groups = ["TAB_*", "PBI_*"]
members = {}
for group in groups:
    members[group] = []
    base_dn = "DC=kcc,DC=com"
    search_filter = f"(&(sAMAccountName={group})(objectCategory=group))"
    attributes = ["member"]

    try:
        c.search(
            search_base=base_dn,
            search_filter=search_filter,
            attributes=attributes,
            paged_size=page_size,
            paged_cookie=None,
            search_scope=SUBTREE,
        )

        for entry in c.response:
            if "attributes" in entry:
                for member in entry["attributes"]["member"]:
                    members[group].append(member)

    except (LDAPException, GSSError):
        pass

# Get email addresses and user IDs for each member
results = []
for group in groups:
    for member in members[group]:
        search_filter = f"(&(objectCategory=person)(objectClass=user)(sAMAccountName={member.split(',')[0][3:]}))"
        try:
            c.search(
                search_base=base_dn,
                search_filter=search_filter,
                attributes=["sAMAccountName", "mail"],
            )

            for entry in c.response:
                if "attributes" in entry:
                    result = {
                        "group": group,
                        "user_id": entry["attributes"]["sAMAccountName"][0].decode(),
                        "email_address": entry["attributes"]["mail"][0].decode(),
                    }
                    results.append(result)
        except (LDAPException, GSSError):
            pass

# Load results into Pandas dataframe
df = pd.DataFrame(results, columns=["group", "user_id", "email_address"])
