#!/bin/bash

# ================================
# Add DKIM & DNS config per domain
# ================================

set -e

echo "Checking requirements..."
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script should be executed as root(sudo) user!"
    exit 1
fi

CONFIG_FILE="./config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing config file: $CONFIG_FILE"
    exit 1
fi

# Load variables from config file
source "$CONFIG_FILE"

# Check required values
if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ Error: DOMAIN_NAME is missing in config file"
    exit 1
fi
if [ -z "$SELECTOR" ]; then
    echo "❌ Error: SELECTOR is missing in config file"
    exit 1
fi
if [ -z "$DMARC_REPORT_EMAIL" ]; then
    echo "❌ Error: DMARC_REPORT_EMAIL is missing in config file"
    exit 1
fi

# Remove any trailing carriage returns
DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr -d '\r')
SELECTOR=$(echo "$SELECTOR" | tr -d '\r')
DMARC_REPORT_EMAIL=$(echo "$DMARC_REPORT_EMAIL" | tr -d '\r')

echo ""
echo "Configuring DKIM..."
KEY_DIR="/etc/opendkim/keys/$DOMAIN_NAME"
mkdir -p "$KEY_DIR"
ORIGINAL_DIR="$(pwd)"
cd "$KEY_DIR"

# Generate DKIM keypair
opendkim-genkey -s "$SELECTOR" -d "$DOMAIN_NAME"

# Secure the private key
chown opendkim:opendkim "${SELECTOR}.private"
chmod 600 "${SELECTOR}.private"

# Update OpenDKIM config files
if ! grep -q "$SELECTOR._domainkey.$DOMAIN_NAME" /etc/opendkim/key.table; then
    echo "$SELECTOR._domainkey.$DOMAIN_NAME $DOMAIN_NAME:$SELECTOR:$KEY_DIR/${SELECTOR}.private" >> /etc/opendkim/key.table
fi
sed -i "/^\*@$DOMAIN_NAME /d" /etc/opendkim/signing.table
echo "*@$DOMAIN_NAME $SELECTOR._domainkey.$DOMAIN_NAME" >> /etc/opendkim/signing.table
if ! grep -q "^$DOMAIN_NAME$" /etc/opendkim/trustedhosts; then
    echo "$DOMAIN_NAME" >> /etc/opendkim/trustedhosts
fi

# Back to the original directory
cd "$ORIGINAL_DIR"

# Restart services
echo ""
echo "Restarting services..."
systemctl restart opendkim
systemctl restart postfix
if ! systemctl is-active --quiet opendkim; then
    echo "❌ Error: OpenDKIM does not appear to be running"
    exit 1
fi
if ! systemctl is-active --quiet postfix; then
    echo "❌ Error: Postfix does not appear to be running"
    exit 1
fi

# Output DNS records
echo ""
echo "Generating DNS records..."
cat > output.txt <<EOF
=== ✅ DNS CONFIGURATION FOR $DOMAIN_NAME ===

📌 DKIM TXT Record:
Name: $SELECTOR._domainkey.$DOMAIN_NAME
Value: $(awk '/^[^-]/ {gsub(/["\t\r ]/, ""); printf "%s", $0}' "$KEY_DIR/$SELECTOR.txt")

📌 SPF TXT Record:
Name: @
Value: v=spf1 a mx ~all

📌 DMARC TXT Record:
Name: _dmarc
Value: v=DMARC1; p=none; rua=mailto:$DMARC_REPORT_EMAIL

📌 MX Record:
Name: @
Value: mail.$DOMAIN_NAME
Priority: 10

EOF

# Check if output.txt was created successfully
if [ -f output.txt ]; then
    echo "✅ DNS records saved to output.txt"
    echo "File size: $(wc -c < output.txt) bytes"
else
    echo "❌ ERROR: output.txt was not created"
    echo "Permissions: $(ls -ld .)"
fi
