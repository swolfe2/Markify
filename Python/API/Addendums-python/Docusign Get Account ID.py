from os import path

from flask import session, request

from ....consts import demo_docs_path, pattern
from ....docusign import create_api_client
from ....ds_config import DS_CONFIG


class Eg021Controller:
    @staticmethod
    def get_args():
        """Get required session and request arguments"""
        # More data validation would be a good idea here
        # Strip anything other than characters listed
        phone_number = request.form.get("phoneNumber")
        signer_email = pattern.sub("", request.form.get("signer_email"))
        signer_name = pattern.sub("", request.form.get("signer_name"))
        envelope_args = {
            "signer_email": signer_email,
            "signer_name": signer_name,
            "status": "sent",
            "phone_number": phone_number,
        }
        args = {
            "account_id": session["ds_account_id"],  # represents your {ACCOUNT_ID}
            "base_path": session["ds_base_path"],
            "access_token": session["ds_access_token"],  # represnts your {ACCESS_TOKEN}
            "envelope_args": envelope_args,
        }
        return args
