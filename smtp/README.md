### 1. Configure SMTP with Relay

#### 1.1. On your Server

##### 1.1.0. Login to your server

Replace `USERNAME` with your username (default: `root`) and `IP_ADDRESS` with your server's public IP address.

```bash
ssh USERNAME@IP_ADDRESS
```

##### 1.1.1. Install Postfix

- Install `postfix`:

```bash
sudo apt update
sudo apt install postfix -y
```

- Choose `Internet with smarthost` (use a relay). This documentation does not cover other options.

- Set the mail name as your domain name for the root user (E.g. If you have 3 domain names: `example.com`, `example.net` and `example.org`, you need to choose one of them as the mail name. It will be used for the root user. If you have only one domain name, set the mail name to that domain name)

- Set the smarthost to `[SMTP_RELAY]` (The square brackets disable MX record lookups — this is recommended)

- Set the following options in `/etc/postfix/main.cf` at the end of the file (Skip if you don't need tls and authentication):

Ensure that there are no duplicate lines(you can comment out the lines you don't need):

```bash
relayhost = [relay.hostup.se]
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

- Generates keypair with the selector `SELECTOR_NAME_YEAR` (replace `DOMAIN_NAME` with your domain name and `SELECTOR_NAME_YEAR` with the second-level domain name and current year):

For better security, renew the keypair every year. For that you need to have a unique selector for each year(you can use a unique selector name but it's difficult to debug).

E.g. If your domain name is `example.com` and the current year is `2025`, the selector is `example2025`.

You can reduce the length of the selector it is too long. Eg. `se2025` instead of `superexample2025` for the domain name `superexample.com`.

```bash
sudo opendkim-genkey -s SELECTOR_NAME_YEAR -d DOMAIN_NAME
```

- Add right access permissions:

```bash
sudo chown opendkim:opendkim SELECTOR_NAME_YEAR.private
sudo chmod 600 SELECTOR_NAME_YEAR.private
```

- Add the following content to the end of `/etc/opendkim/key.table` (replace `DOMAIN_NAME` with your domain name and `SELECTOR_NAME_YEAR` with the second-level domain name and current year):

```bash
SELECTOR_NAME_YEAR._domainkey.DOMAIN_NAME DOMAIN_NAME:SELECTOR_NAME_YEAR:/etc/opendkim/keys/DOMAIN_NAME/SELECTOR_NAME_YEAR.private
```

- Add the following content to the end of `/etc/opendkim/signing.table` (replace `DOMAIN_NAME` with your domain name and `SELECTOR_NAME_YEAR` with the second-level domain name and current year):

```bash
*@DOMAIN_NAME SELECTOR_NAME_YEAR._domainkey.DOMAIN_NAME
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

##### 1.2.". MX

On your DNS provider, add the following MX record:

- **Hostname**: `@` or leave blank (depending on the provider)
- **Type**: MX
- **Value**: `mail.DOMAIN_NAME` or `DOMAIN_NAME` (in case of `mail.DOMAIN_NAME` add new `A` record for `mail.DOMAIN_NAME` point to your server IP address)
- **Priority**: `10` (the default is `10`)

##### 1.2.4. DMARC(anti-spoofing)

On your DNS provider, add the following TXT record(replace `DOMAIN_NAME` with your domain name and `RECIPIENT_EMAIL_ADDRESS` with the email address to receive DMARC reports):

- **Hostname**: `_dmarc.DOMAIN_NAME`
- **Type**: TXT
- **Value**: `v=DMARC1; p=none; rua=mailto:RECIPIENT_EMAIL_ADDRESS`

##### 1.2.5. DKIM(signature)

On your DNS provider, add the following TXT record(replace `DOMAIN_NAME` with your domain name, `SELECTOR_NAME_YEAR` with the second-level domain name and current year, and `DKIM_PUBLIC_KEY` with your DKIM public key stored at `/etc/opendkim/keys/DOMAIN_NAME/SELECTOR_NAME_YEAR.txt`):

The public key is stored at `/etc/opendkim/keys/DOMAIN_NAME/SELECTOR_NAME_YEAR.txt`. You shoul only copy the vabue between parentheses `( "..." ) `without thethe trailing `"`.

E.g.

```bash
example2025._domainkey      IN      TXT     ( "v=DKIM1; h=sha256; k=rsa; "
"p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl9apPLhHMBS3rlFAzexryLgpQeeEsiimElndVmrI1Ti6osm7+lYlXQHF3buSqFfzXu3WxdtzZk3EmQUOe2qiw0fPQnwOvN+lJLUZXv6kh1bxG5/9A18nApRM6enJUi4Q5qJCzI+HeuKoHTMuaWuGxRN17Lh7un2XeKxqPVL+Y9rp+gysloK0uW22yRGby9/3oMD7Xo8f/7dCvR"
"7fkfn6jhn7WypdEUptqptoXtugHjJm7/CY4QQ/141Zy5ea1i6g3Bb4t0RA/m3hdNlezADLL0pqhhMuYivE2Eok8wuFaM52sEJCYaIKa9rcVMm//AR1TSPWAkpoxPwmNRSjuRZ5dQIDAQAB" )  ; ----- DKIM key example2025 for example.com
```

Copy only the value between the parentheses. All in one line. You will need to concat the lines(`p= with the next line`).

E.g.

```bash
v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl9apPLhHMBS3rlFAzexryLgpQeeEsiimElndVmrI1Ti6osm7+lYlXQHF3buSqFfzXu3WxdtzZk3EmQUOe2qiw0fPQnwOvN+lJLUZXv6kh1bxG5/9A18nApRM6enJUi4Q5qJCzI+HeuKoHTMuaWuGxRN17Lh7un2XeKxqPVL+Y9rp+gysloK0uW22yRGby9/3oMD7Xo8f/7dCvR7fkfn6jhn7WypdEUptqptoXtugHjJm7/CY4QQ/141Zy5ea1i6g3Bb4t0RA/m3hdNlezADLL0pqhhMuYivE2Eok8wuFaM52sEJCYaIKa9rcVMm//AR1TSPWAkpoxPwmNRSjuRZ5dQIDAQAB
```

- **Hostname**: `SELECTOR_NAME_YEAR._domainkey.DOMAIN_NAME`
- **Type**: TXT
- **Value**: `DKIM_PUBLIC_KEY`

##### 1.2.5. Test the Setup

Go to this page: [https://mxtoolbox.com/SuperTool.aspx?action=spf](https://mxtoolbox.com/SuperTool.aspx?action=spf)

- Choose `SPF Record Lookup`(for spams) and enter `DOMAIN_NAME`. Checks the results.

- Choose `TXT`(for restriction) and enter `DOMAIN_NAME`. Checks the results.

- Choose `DMARC Lookup` and enter `DOMAIN_NAME`. Checks the results.

- Choose `DKIM Lookup` and enter `DOMAIN_NAME:SELECTOR_NAME_YEAR`. Checks the results.

##### 1.2.6. Send a test email(replace `RECIPIENT_EMAIL_ADDRESS` with the email address to receive the email):

- Install `mailutils`:

```bash
sudo apt install mailutils -y
```

```bash
echo "Hi there! This is a test email" | mail -s "Welcome" -r "SENDER_USERNAME <SENDER_EMAIL_ADDRESS>" RECIPIENT_EMAIL_ADDRESS
```

E.g. `echo "Hi there! This is a test email" | mail -s "Welcome" -r "No Reply <no-reply@example.com>" receiver@example.com`

If you don’t receive the email:

- Check your spam folder

- Make sure Postfix restarted properly

- Validate that your domain’s DNS records have propagated

## ✅ Server is now ready for Kubernetes and secure operations.
