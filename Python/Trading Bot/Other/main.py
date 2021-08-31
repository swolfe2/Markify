import os
import cbpro
import creds

# Comment out production run for testing; development line for prod
# run_type = "Production"
run_type = "Development"

if run_type == "Development":
    public_key = creds.dev_public_key
    secret_key = creds.dev_secret_key
    passphrase = creds.dev_passphrase
    api_url = "https://api-public.sandbox.pro.coinbase.com"
else:
    public_key = creds.prod_public_key
    secret_key = creds.prod_secret_key
    passphrase = creds.prod_passphrase
    api_url = "https://api-public.pro.coinbase.com"

# Set ticker to watch
ticker = "BTC-USD"
ticker_split = ticker.split("-")[0]

# set actions
BUY = "buy"
SELL = "sell"


class TradingSystems:
    def __init__(self, cb_pro_client):
        self.client = cb_pro_client

    def trade(self, action, limitPrice, quantity):
        if action == BUY:
            response = self.client.buy(
                price=limitPrice,
                size=quantity,
                order_type="limit",
                product_id=ticker,
                overdraft_enabled=False,
            )

        elif action == SELL:
            response = self.client.sell(
                price=limitPrice,
                size=quantity,
                order_type="limit",
                product_id=ticker,
                overdraft_enabled=False,
            )

    def viewAccounts(self, accountCurrency):
        accounts = self.client.get_accounts()
        account = list(filter(lambda x: x["currency"] == accountCurrency, accounts))[0]
        return account

    def viewOrder(self, order_id):
        pass

    def getCurrentPrice(self):
        tick = self.client.get_product_ticker(product_id=ticker)
        return tick["bid"]


if __name__ == "__main__":
    auth_client = cbpro.AuthenticatedClient(
        public_key, secret_key, passphrase, api_url=api_url
    )

    trading_systems = TradingSystems(auth_client)
    print(trading_systems.viewAccounts(ticker_split)["balance"])
    print(trading_systems.viewAccounts("USD")["balance"])

    pass
