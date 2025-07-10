#!/bin/bash

# ======================
# Mail Server Setup Script
# ======================
# This script installs and configures Postfix and OpenDKIM to send emails via relay.
# It assumes you are using a smarthost (mail relay) and not receiving mail.

set -e

# Install required packages
apt update && apt install -y postfix mailutils opendkim opendkim-tools

# Configure Postfix for smarthost relay (edit relayhost manually)
postconf -e "relayhost = [RELAY_SMARTHOST]"  # Replace this value after running

# Restart Postfix
systemctl restart postfix

# Configure OpenDKIM
cat <<EOF >> /etc/opendkim.conf
# === DKIM Setup ===
Mode                  sv
AutoRestart           Yes
AutoRestartRate       10/1h
Syslog                yes
LogWhy                yes
Canonicalization      relaxed/simple
ExternalIgnoreList    refile:/etc/opendkim/trustedhosts
InternalHosts         refile:/etc/opendkim/trustedhosts
SigningTable          refile:/etc/opendkim/signing.table
KeyTable              refile:/etc/opendkim/key.table
EOF

# Create configuration files
mkdir -p /etc/opendkim
touch /etc/opendkim/{signing.table,key.table,trustedhosts}

# Add trusted hosts
cat <<EOF > /etc/opendkim/trustedhosts
127.0.0.1
localhost
::1
EOF

# Set permissions
usermod -aG opendkim postfix
systemctl restart opendkim
systemctl restart postfix

echo "[✓] Mail server setup complete. Now run add_domain_config.sh to add domain-specific keys."
