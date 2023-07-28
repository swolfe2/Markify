import os
import ssl

from ldap3 import ALL, SASL, Connection, Server, Tls


def connect():
    # Create TLS connection
    tls = Tls(validate=ssl.CERT_NONE)

    # Create server object with TLS
    server = Server("kcc.com", get_info=ALL)

    # Construct user with domain
    user = "KCUS\\" + os.getenv("USERNAME")

    # Create LDAP connection
    conn = Connection(server, sasl_mechanism="EXTERNAL")

    # Perform bind
    conn.bind()

    return conn


def get_ad_groups(conn):
    # Search for TAB and PBI groups
    search_filter = "(&(objectClass=group)(|(name=TAB_*)(name=PBI_*)))"

    # Hold group info
    groups = []

    # Search AD and loop through results
    conn.search(
        "ou=Groups,dc=company,dc=com",
        search_filter,
        attributes=["managedBy", "memberOf"],
    )

    for entry in conn.entries:
        groups.append(
            {
                "name": entry["name"].value,
                "owners": entry["managedBy"].value,
                "authorizers": entry["memberOf"].value,
            }
        )

    return groups


if __name__ == "__main__":
    # Get Active Directory connection
    conn = connect()

    # Get list of groups
    groups = get_ad_groups(conn)

    print(groups)
