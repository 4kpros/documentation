# Server Setup - Server Hardening & Kubernetes (k3s) Installation. Tested on Ubuntu 24.04 LTS

## Step 1: Setup server and Security

### 0. Login to your server

Replace `USERNAME` with your username (default: `root`) and `IP_ADDRESS` with your server's public IP address.

```bash
ssh USERNAME@IP_ADDRESS
```

### 1. Create users

- `bot`: for CI/CD automation
- `prosper`: personal/admin user
- Add more as needed

```bash
adduser bot
adduser prosper
usermod -aG sudo prosper
```

### 2. Configure firewall

Block all incoming traffic except SSH (22), HTTP (80), HTTPS (443), and SMTP (587). Adapt as needed.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 587
sudo ufw enable
```

Optional: view rules

```bash
sudo ufw status
```

### 3. Disable SSH password authentication

⚠️ Ensure your SSH keys are configured first!

**On your local machine:**

Generate SSH key (choose one):

(Ignore passphrase for user `bot` if used in CI/CD automation)

- Recommended: ED25519 (secure & modern)

```bash
ssh-keygen -t ed25519 -a 100
```

- Alternatively: RSA 4096 bits (for maximum compatibility)

```bash
ssh-keygen -t rsa -b 4096
```

Then copy the public key to your server(all users except `root`):

```bash
ssh-copy-id bot@IP_ADDRESS
ssh-copy-id prosper@IP_ADDRESS
```

**On the server:**

```bash
sudo nano /etc/ssh/sshd_config
```

Edit these lines:

```bash
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
```

Restart SSH:

```bash
sudo systemctl restart ssh
```

### 4. Reconnect to confirm

```bash
exit
ssh prosper@IP_ADDRESS
```

## Step 2: Install Packages & Kubernetes (k3s)

### 1. Install essential packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl wget bash git make tmux vim -y
```

### 2. Generate SSH keys for each user

Login with each user separately.

Recommended: ED25519 (secure & modern)

```bash
ssh-keygen -t ed25519 -a 100
```

Alternatively, generate RSA keys for compatibility:

```bash
ssh-keygen -t rsa -b 4096
```

### 3. Install k3s

```bash
curl -sfL https://get.k3s.io | sh -
```

Optional: enable at boot

```bash
sudo systemctl enable k3s
```

### 4. k3s group configuration

```bash
sudo groupadd k3s
sudo usermod -aG k3s bot
sudo usermod -aG k3s prosper
sudo chown -R root:k3s /etc/rancher/k3s
sudo chmod -R 640 /etc/rancher/k3s
sudo chmod ug+x /etc/rancher/k3s
```

Make Kubeconfig readable by group:

```bash
echo 'K3S_KUBECONFIG_MODE="640"' | sudo tee -a /etc/systemd/system/k3s.service.env
```

Verify installation:

```bash
kubectl get nodes
```

## Step 3: Server Data Access Groups

### 1. DevOps group for application data

```bash
sudo mkdir -p /mnt/node/data/apps
sudo groupadd devops
sudo usermod -aG devops prosper
sudo chown -R root:devops /mnt/node/data/apps
sudo find /mnt/node/data/apps -type d -exec chmod 750 {} \;
sudo find /mnt/node/data/apps -type f -exec chmod 640 {} \;
```

### 2. CI group for automation data

```bash
sudo mkdir -p /mnt/node/data/automation
sudo groupadd automation
sudo usermod -aG automation bot
sudo chown -R root:automation /mnt/node/data/automation
sudo find /mnt/node/data/automation -type d -exec chmod 770 {} \;
sudo find /mnt/node/data/automation -type f -exec chmod 660 {} \;
```

## Additionals

### 1. Configure HTTPS with Cert Manager to auto renew certificates with Let's Encrypt. Please use the latest version(the used one is `1.8.2` from 2025)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```

To check if the installation is ok, please refer to the official page: [https://cert-manager.io/docs/installation/kubectl/#2-optional-end-to-end-verify-the-installation](https://cert-manager.io/docs/installation/kubectl/#2-optional-end-to-end-verify-the-installation)

### 3. k3s uses **Traefik** as the default Ingress Controller. Recommended to keep it for simplicity.

### 4. For monitoring (Prometheus/Grafana), use Helm charts.

Avoid installing heavy monitoring on the master node.
Prefer separate clusters or nodes for observability.

- Optional: to install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Configure SMTP with Relay

#### 1.1. On your Server

##### 1.1.1. Install Postfix and mailutils

- Install `postfix`:

```bash
sudo apt update
sudo apt install postfix mailutils -y
```

- Choose `Internet with smarthost` (use a relay). This documentation does not cover other options.

- Set the mail name as your domain name for the root user (E.g. If you have 3 domain names: `example.com`, `example.net` and `example.org`, you need to choose one of them as the mail name. It will be used for the root user. If you have only one domain name, set the mail name to that domain name)

- Set the smarthost to `[SMTP_RELAY]:587` (The square brackets disable MX record lookups — this is recommended)

- Check `/etc/postfix/main.cf` by adding or modifying the following line:

```bash
relayhost = [SMTP_RELAY]:587
```

- Restart Postfix:

```bash bash
sudo systemctl restart postfix
```

##### 1.1.2. Install DKIM

- Install `opendkim` and `opendkim-tools`:

```bash
sudo apt update
sudo apt install opendkim opendkim-tools -y
```

- Add the following lines at the end of OpenDKIM configuration file `/etc/opendkim.conf`:

```bash
# === Multi-domain configuration with mapping ===

# Enables automatic signing
Mode                    sv

# List of IPs/domains to sign for (your server and your domain)
ExternalIgnoreList      refile:/etc/opendkim/trustedhosts
InternalHosts           refile:/etc/opendkim/trustedhosts

# DKIM configuration tables
SigningTable            refile:/etc/opendkim/signing.table
KeyTable                refile:/etc/opendkim/key.table
```

- Create the three files `/etc/opendkim/key.table`, `/etc/opendkim/signing.table` and `/etc/opendkim/trustedhosts`:

- Add permissions and Restart OpenDKIM:

```bash
sudo systemctl restart opendkim
sudo usermod -aG opendkim postfix
sudo systemctl restart postfix
```

##### 1.1.3. Configure DKIM: for every domain you want to use for mail you need to do thise steps

- Generates keypair for the domain name (replace `DOMAIN_NAME` with your domain name):

```bash
sudo mkdir -p /etc/opendkim/keys/DOMAIN_NAME
cd /etc/opendkim/keys/DOMAIN_NAME
```

- Generates keypair with the selector `default` (replace `DOMAIN_NAME` with your domain name):

```bash
sudo opendkim-genkey -s default -d DOMAIN_NAME
```

- Add right access permissions:

```bash
sudo chown opendkim:opendkim default.private
```

- Add the following content to the end of `/etc/opendkim/key.table` (replace `DOMAIN_NAME` with your domain name):

```bash
default._domainkey.DOMAIN_NAME DOMAIN_NAME:default:/etc/opendkim/keys/DOMAIN_NAME/default.private
```

- Add the following content to the end of `/etc/opendkim/signing.table` (replace `DOMAIN_NAME` with your domain name):

```bash
*@DOMAIN_NAME default._domainkey.DOMAIN_NAME
```

- Add the following content to the end of `/etc/opendkim/trustedhosts` (replace `DOMAIN_NAME` with your domain name):

```bash
127.0.0.1
localhost
::1
DOMAIN_NAME
```

- Restart OpenDKIM and Postfix:

```bash
sudo systemctl restart opendkim
sudo systemctl restart postfix
```

#### 1.2. On your domain registrar: for every domain you want to use for mail you need to do thise steps

##### 1.2.1. SPF (to reduce spam risk)

On your DNS provider, add the following TXT record to authorize Hostup’s relay to send emails for your domain:

- **Hostname**: `@` or leave blank (depending on the provider)
- **Type**: TXT
- **Value**: `v=spf1 a mx include:spf.hostup.se ~all`

##### 1.2.2. Restrict Relay Access to your server IP address only (optional but recommended)

To ensure that only your server can send emails through Hostup's relay, add this TXT record(replace `DOMAIN_NAME` with your domain name and `IP_ADDRESS` with your with your server public IP address):

- **Hostname**: `_hostup.DOMAIN_NAME`
- **Type**: TXT
- **Value**: `v=mc1 auth=IP_ADDRESS`

##### 1.2.3. DMARC(anti-spoofing)

On your DNS provider, add the following TXT record(replace `DOMAIN_NAME` with your domain name and `RECIPIENT_EMAIL_ADDRESS` with the email address to receive DMARC reports):

- **Hostname**: `_dmarc.DOMAIN_NAME`
- **Type**: TXT
- **Value**: `v=DMARC1; p=none; rua=mailto:RECIPIENT_EMAIL_ADDRESS`

##### 1.2.4. DKIM(signature)

On your DNS provider, add the following TXT record(replace `DOMAIN_NAME` with your domain name and `DKIM_PUBLIC_KEY` with your DKIM public key stored at `/etc/opendkim/keys/DOMAIN_NAME/default.txt`):

The public key is stored at `/etc/opendkim/keys/DOMAIN_NAME/default.txt`. You shoul only copy the vabue of `p="..."` without the leading `p="` and the trailing `"`.

- **Hostname**: `default._domainkey.DOMAIN_NAME`
- **Type**: TXT
- **Value**: `DKIM_PUBLIC_KEY`

##### 1.2.5. Test the Setup

Go to this page: [https://mxtoolbox.com/SuperTool.aspx?action=spf](https://mxtoolbox.com/SuperTool.aspx?action=spf)

- Choose `SPF Record Lookup`(for spams) and enter `DOMAIN_NAME`. Checks the results.

- Choose TXT(for restriction) and enter `_hostup.DOMAIN_NAME`. Checks the results.

- Choose `MX Record Lookup` and enter `DOMAIN_NAME`. Checks the results.

##### 1.2.6. Send a test email(replace `RECIPIENT_EMAIL_ADDRESS` with the email address to receive the email):

```bash
echo "Hi there! This is a test email" | mail -s "Subject of the email" RECIPIENT_EMAIL_ADDRESS
```

If you don’t receive the email:

- Check your spam folder

- Make sure Postfix restarted properly

- Validate that your domain’s DNS records have propagated

## ✅ Server is now ready for Kubernetes and secure operations.
