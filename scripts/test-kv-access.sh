#!/bin/bash
# Tests whether this VM's managed identity can read db-password from Key Vault.
# Prints only the HTTP status and metadata. Never prints the token or the secret.
set -euo pipefail

VAULT_NAME="kv-securenet-dev-eus-001"
SECRET_NAME="db-password"

# 1. Get a token for Key Vault from the Instance Metadata Service (IMDS)
TOKEN=$(curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
echo "Token obtained (length: ${#TOKEN})"

# 2. Request the secret, keeping the response body and the HTTP status apart
RESPONSE=$(curl -s -w '\n%{http_code}' -H "Authorization: Bearer ${TOKEN}" \
  "https://${VAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME}?api-version=7.4")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')
echo "HTTP status: ${HTTP_CODE}"

# 3. Report the result without exposing the secret
if [ "$HTTP_CODE" = "200" ]; then
  echo "$BODY" | python3 -c 'import sys,json; print("Secret read. Value length:", len(json.load(sys.stdin)["value"]))'
else
  echo "$BODY" | python3 -c 'import sys,json; e=json.load(sys.stdin)["error"]; print("Error:", e["code"], "/", e.get("innererror",{}).get("code","-"))'
fi