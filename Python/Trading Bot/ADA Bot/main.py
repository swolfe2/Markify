import pandas as pd
import cbpro
import creds

# Comment out production run for testing; development line for prod
# run_type = "Production"
run_type = "Development"

if run_type == "Development":
    public_key = creds.dev_public_key
    secret_key = creds.dev_secret_key
    passphrase = creds.dev_passphrase
    api_url = creds.dev_app_url
    wss_feed = "wss://ws-feed-public.sandbox.pro.coinbase.com"
else:
    public_key = creds.prod_public_key
    secret_key = creds.prod_secret_key
    passphrase = creds.prod_passphrase
    api_url = creds.prod_app_url
    wss_feed = "wss://ws-feed-public.pro.coinbase.com"

# Get live data
class TextWebsocketClient(cbpro.WebsocketClient):
    def on_open(self):
        self.url = wss_feed
        self.message_count = 0
        pass

    def on_message(self, msg):
        self.message_count += 1
        msg_type = msg.get("type", None)
        if msg_type == "ticker":
            time_val = msg.get("time", ("-" * 27))
            price_val = msg.get("price", None)
            price_val = float(price_val) if price_val is not None else "None"
            product_id = msg.get("product_id", None)

            print(
                f"{time_val:30} {price_val:.3f} {product_id}\tchannel type:{msg_type}"
            )

    def on_close(self):
        print(
            f"<---Websocket connection closed--->\n\tTotal Messages: {self.message_count}"
        )
