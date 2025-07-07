# Server Setup - VPS Hardening & Kubernetes (k3s) Installation

## Step 1: Setup VPS and Security

### 0. Login to your server

Replace `USERNAME` with your username (default: `root`) and `IP_ADDRESS` with your server's public IP.

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

Block all incoming traffic except SSH (22), HTTP (80), and HTTPS (443). Adapt as needed.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
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

(Ignore passphrase for `bot` if used in CI/CD)

- Recommended: ED25519 (secure & modern)

```bash
ssh-keygen -t ed25519 -a 100
```

- Alternatively: RSA 4096 bits (for maximum compatibility)

```bash
ssh-keygen -t rsa -b 4096
```

Then copy the public key to your server:

```bash
ssh-copy-id bot@IP_ADDRESS
ssh-copy-id prosper@IP_ADDRESS
```

**On the server:**

```bash
sudo vim /etc/ssh/sshd_config
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

---

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

---

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
sudo mkdir -p /mnt/node/data/ci
sudo groupadd ci
sudo usermod -aG ci bot
sudo chown -R root:ci /mnt/node/data/ci
sudo find /mnt/node/data/ci -type d -exec chmod 770 {} \;
sudo find /mnt/node/data/ci -type f -exec chmod 660 {} \;
```

---

## Additionals

- Get node/cluster name:

```bash
kubectl get nodes -o wide
```

Check the `NAME` column for your node name.

- k3s uses **Traefik** as the default Ingress Controller. Recommended to keep it for simplicity.

- For monitoring (Prometheus/Grafana), use Helm charts.
  Avoid installing heavy monitoring on the master node.
  Prefer separate clusters or nodes for observability.

---

## ✅ Server is now ready for Kubernetes and secure operations.

---
