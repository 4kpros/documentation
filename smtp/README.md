### 1. Configure SMTP with Relay

#### 1.1. On your Server

##### 1.1.0. Login to your server

Replace `USERNAME` with your username (default: `root`) and `IP_ADDRESS` with your server's public IP address.

```bash
ssh USERNAME@IP_ADDRESS
```

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
