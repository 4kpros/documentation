#!/bin/bash

# ===========================
# Add Domain DKIM Configuration
# ===========================

set -e

CONFIG_FILE="conf.cnf"
# Load config
if [[ ! -f $CONFIG_FILE ]]; then
    echo "Missing config.txt!"
    exit 1
fi
# Read config
while IFS='=' read -r key value; do
    if [[ $key && $value ]]; then
        export "$key"="$(echo $value | xargs)"
    fi
done <"$CONFIG_FILE"
# Validate inputs
if [[ -z "$DOMAIN_NAME" || -z "$SELECTOR_NAME_YEAR" || -z "$SERVER_IP" || -z "$DMARC_REPORT_EMAIL" ]]; then
    echo "One or more variables are missing in config.txt"
    exit 1
fi

KEY_DIR="/etc/opendkim/keys/${DOMAIN_NAME}"
mkdir -p "$KEY_DIR"
cd "$KEY_DIR"

# Generate keypair
opendkim-genkey -s "$SELECTOR_NAME_YEAR" -d "$DOMAIN_NAME"
chown opendkim:opendkim "$SELECTOR_NAME_YEAR.private"
chmod 600 "$SELECTOR_NAME_YEAR.private"

# KeyTable
echo "$SELECTOR_NAME_YEAR._domainkey.${DOMAIN_NAME} ${DOMAIN_NAME}:${SELECTOR_NAME_YEAR}:${KEY_DIR}/${SELECTOR_NAME_YEAR}.private" >>/etc/opendkim/key.table

# SigningTable
echo "*@${DOMAIN_NAME} ${SELECTOR_NAME_YEAR}._domainkey.${DOMAIN_NAME}" >>/etc/opendkim/signing.table

# Trusted Hosts
echo "$DOMAIN_NAME" >>/etc/opendkim/trustedhosts

# Restart services
systemctl restart opendkim
systemctl restart postfix

# Extract DKIM public key
DKIM_PUBLIC_KEY=$(sed 's/.*p=//;s/"//g' "${SELECTOR_NAME_YEAR}.txt" | tr -d '\n')

# Generate DNS records
cat <<EOF >./dns_records.txt

🔧 DNS Records for ${DOMAIN_NAME}

1. SPF:
---------
Type: TXT
Name: @
Value: v=spf1 a mx ~all

2. MX:
-------
Type: MX
Name: @
Value: mail.${DOMAIN_NAME}
Priority: 10

Type: A
Name: mail.${DOMAIN_NAME}
Value: ${SERVER_IP}

3. DKIM:
---------
Type: TXT
Name: ${SELECTOR_NAME_YEAR}._domainkey.${DOMAIN_NAME}
Value: v=DKIM1; h=sha256; k=rsa; p=${DKIM_PUBLIC_KEY}

4. DMARC:
----------
Type: TXT
Name: _dmarc.${DOMAIN_NAME}
Value: v=DMARC1; p=none; rua=mailto:${DMARC_REPORT_EMAIL}

EOF

echo "[✓] Domain configured. DNS records available in ${KEY_DIR}/dns_records.txt"
