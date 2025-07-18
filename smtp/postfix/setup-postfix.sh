#!/bin/bash

# ======================
# Mail Server Setup Script
# ======================
# This script installs and configures Postfix and OpenDKIM to send emails via relay.
# It assumes you are using a smarthost (mail relay) and not receiving emails.

set -e

echo "Checking requirements..."
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root (use sudo)"
    exit 1
fi

CONFIG_FILE="./config.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Missing config file: $CONFIG_FILE"
    echo "Please create config.txt with:"
    echo "RELAY_SMARTHOST=your.relay.server:587"
    echo "DOMAIN_NAME=yourdomain.com"
    exit 1
fi

# Load variables from config file
source "$CONFIG_FILE"

# Check required values
if [ -z "$RELAY_SMARTHOST" ]; then
    echo "❌ Error: RELAY_SMARTHOST is missing in config file"
    exit 1
fi
if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ Error: DOMAIN_NAME is missing in config file"
    exit 1
fi

# Remove any trailing carriage returns
DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr -d '\r')
RELAY_SMARTHOST=$(echo "$RELAY_SMARTHOST" | tr -d '\r')

echo ""
echo "Setting up mail server for domain: $DOMAIN_NAME"
echo "Using relay: $RELAY_SMARTHOST"

# Preseed Postfix to avoid interactive prompts
echo "postfix postfix/main_mailer_type select Internet with smarthost" | debconf-set-selections
echo "postfix postfix/relayhost string $RELAY_SMARTHOST" | debconf-set-selections
echo "postfix postfix/mailname string $DOMAIN_NAME" | debconf-set-selections

# Install required packages
echo ""
echo "Installing packages..."
apt update
apt install -y postfix mailutils opendkim opendkim-tools

# Configure Postfix
echo ""
echo "Configuring Postfix..."
postconf -e "relayhost = $RELAY_SMARTHOST"
postconf -e "myhostname = $DOMAIN_NAME"
postconf -e "mydestination = \$myhostname, localhost"

# Restart Postfix
echo "Restarting Postfix..."
systemctl restart postfix
if ! systemctl is-active --quiet postfix; then
    echo "❌ Error: Postfix failed to start"
    exit 1
fi
echo "Postfix is running."

# Configure OpenDKIM
echo ""
echo "Configuring OpenDKIM..."
# Backup original config if exists
if [ -f /etc/opendkim.conf ] && [ ! -f /etc/opendkim.conf.backup ]; then
    cp /etc/opendkim.conf /etc/opendkim.conf.backup
fi
# Load default OpenDKIM configuration
cp -f /etc/opendkim.conf.backup /etc/opendkim.conf
# Update OpenDKIM configuration
cat <<EOF >> /etc/opendkim.conf
# Basic OpenDKIM configuration
Mode                  sv
ExternalIgnoreList    refile:/etc/opendkim/trustedhosts
InternalHosts         refile:/etc/opendkim/trustedhosts
SigningTable          refile:/etc/opendkim/signing.table
KeyTable              refile:/etc/opendkim/key.table
EOF

# Create DKIM directories
mkdir -p /etc/opendkim

# Create DKIM configuration files
touch /etc/opendkim/signing.table
touch /etc/opendkim/key.table
touch /etc/opendkim/trustedhosts

# Add trusted hosts
cat <<EOF > /etc/opendkim/trustedhosts
127.0.0.1
localhost
::1
$DOMAIN_NAME
EOF

# Restart OpenDKIM
echo "Restarting OpenDKIM..."
systemctl restart opendkim
if ! systemctl is-active --quiet opendkim; then
    echo "❌ Error: OpenDKIM failed to start"
    systemctl status opendkim
    exit 1
fi
echo "OpenDKIM is running."

# Set proper permissions
echo ""
echo "Setting permissions..."
chown -R opendkim:opendkim /etc/opendkim
chmod 750 /etc/opendkim
chmod 640 /etc/opendkim/signing.table /etc/opendkim/key.table /etc/opendkim/trustedhosts
# Add postfix user to opendkim group
usermod -aG opendkim postfix

# Enable and start services
echo ""
echo "Enabling services..."
systemctl enable postfix
systemctl enable opendkim

# Restart services
echo ""
echo "Restarting services..."
echo "🔄 Restarting Postfix..."
systemctl restart opendkim
if ! systemctl is-active --quiet opendkim; then
    echo "❌ Error: OpenDKIM failed to start"
    systemctl status opendkim
    exit 1
fi
echo "🔄 Restarting Postfix..."
systemctl restart postfix
if ! systemctl is-active --quiet postfix; then
    echo "❌ Error: Postfix failed to start"
    systemctl status postfix
    exit 1
fi
echo "Services status:"
systemctl is-active postfix && echo "  Postfix: ✅ Running" || echo "  Postfix: ❌ Not running"
systemctl is-active opendkim && echo "  OpenDKIM: ✅ Running" || echo "  OpenDKIM: ❌ Not running"

echo ""
echo "✅ Mail server setup complete!"
echo ""
echo "Next steps:"
echo "1. Add domain-specific DKIM keys"
echo "2. Configure your relay authentication if needed"
echo "3. Test email sending with: echo 'Test' | mail -s 'Test Subject' test@example.com"
echo ""
