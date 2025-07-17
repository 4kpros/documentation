#!/bin/bash

# ================================
# Remove ALL DKIM selectors for a domain
# ================================

set -e

echo "Checking requirements..."
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script should be executed as root(sudo) user!"
    exit 1
fi

CONFIG_FILE="./config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Missing config file: $CONFIG_FILE"
    exit 1
fi

# Load variables from config file
source "$CONFIG_FILE"

# Check required values
if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ Error: DOMAIN_NAME is missing in config file"
    exit 1
fi

# Remove any trailing carriage returns
DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr -d '\r')

echo ""
echo "🗑️  Removing ALL DKIM selectors for domain: $DOMAIN_NAME"

# Backup config files before modification
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cp /etc/opendkim/key.table /etc/opendkim/key.table.backup.$TIMESTAMP
cp /etc/opendkim/signing.table /etc/opendkim/signing.table.backup.$TIMESTAMP
cp /etc/opendkim/trustedhosts /etc/opendkim/trustedhosts.backup.$TIMESTAMP

# Find and display all selectors for this domain
echo ""
echo "📝 Finding all selectors for $DOMAIN_NAME..."
SELECTORS_FOUND=$(grep "_domainkey\.$DOMAIN_NAME " /etc/opendkim/key.table 2>/dev/null | wc -l || echo "0")
echo "Found $SELECTORS_FOUND selector(s) for $DOMAIN_NAME"

if [ "$SELECTORS_FOUND" -gt 0 ]; then
    echo "Selectors to be removed:"
    grep "_domainkey\.$DOMAIN_NAME " /etc/opendkim/key.table | awk '{print "  - " $1}' || true
    echo ""
fi

# Remove ALL entries for this domain from OpenDKIM config files
echo ""
echo "📝 Removing ALL entries for $DOMAIN_NAME from OpenDKIM configuration files..."

# Remove ALL selectors for this domain from key.table
sed -i "/_domainkey\.$DOMAIN_NAME /d" /etc/opendkim/key.table

# Remove ALL entries for this domain from signing.table
sed -i "/@$DOMAIN_NAME /d" /etc/opendkim/signing.table

# Remove from trustedhosts
sed -i "/^$DOMAIN_NAME$/d" /etc/opendkim/trustedhosts

# Remove ENTIRE DKIM keys directory for this domain
KEY_DIR="/etc/opendkim/keys/$DOMAIN_NAME"
if [ -d "$KEY_DIR" ]; then
    echo "🗂️  Removing ENTIRE DKIM keys directory: $KEY_DIR"
    rm -rf "$KEY_DIR"
else
    echo "ℹ️  DKIM keys directory not found: $KEY_DIR"
fi

# Restart services
echo ""
echo "🔄 Restarting services..."
systemctl restart opendkim
systemctl restart postfix

# Verify services are running
if ! systemctl is-active --quiet opendkim; then
    echo "❌ Error: OpenDKIM does not appear to be running"
    exit 1
fi

if ! systemctl is-active --quiet postfix; then
    echo "❌ Error: Postfix does not appear to be running"
    exit 1
fi

echo ""
echo "=== ✅ DOMAIN COMPLETE REMOVAL COMPLETED ==="
echo ""
echo "📌 Actions performed:"
echo "  • Removed ALL selectors for $DOMAIN_NAME from key.table"
echo "  • Removed ALL entries for $DOMAIN_NAME from signing.table"
echo "  • Removed $DOMAIN_NAME from trustedhosts"
echo "  • Deleted ENTIRE DKIM keys directory"
echo "  • Restarted OpenDKIM and Postfix"
echo ""
echo "📌 Next steps:"
echo "  • Remove ALL DNS records for $DOMAIN_NAME:"
echo "    - ALL DKIM TXT records: *._domainkey.$DOMAIN_NAME"
echo "    - SPF TXT record: @ (if not used by other domains)"
echo "    - DMARC TXT record: _dmarc (if not used by other domains)"
echo "    - MX record: @ (if not used by other domains)"
echo ""
echo "📂 Config backups created in /etc/opendkim/ with timestamp: $TIMESTAMP"
echo ""
echo "[✓] Domain $DOMAIN_NAME and ALL its selectors removed successfully."