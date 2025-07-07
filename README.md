# Step 1: Setup VPS, security and best practices

0. Login to the server. USERNAME is your server username(the is default: root). IP_ADDRESS is your server IP address

   ```
   ssh USERNAME@IP_ADDRESS
   ```

1. Add new users (bot for CI and automations pipeline). Add more users if needed (e.g. for my personal usage: prosper)

   ```
   adduser bot
   adduser prosper
   usermod -aG sudo prosper
   ```

2. Add firewall rules: block all ports except 22(ssh), 80(http) and 443(https), and more if needed

   ```
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow OpenSSH
   sudo ufw allow 80
   sudo ufw allow 443
   ```

   - Optional to show all rules
     ```
     sudo ufw show Added
     ```

   ```
   sudo ufw enable
   ```

   - Optional to show firewall status
     ```
     sudo ufw status
     ```

3. Disable ssh login with password. Add more users if needed (e.g. for my personal usage: prosper)

   - ------------- On personal computer(the one who will be used to login to the server via ssh) -------------

     - Optional: to remove known host with same IP/hostname. IP_ADDRESS is your server IP address
       ```
       ssh-keygen -R IP_ADDRESS
       ```
     - Important: You'll need to remove the ssh passphrase for bot user otherwise it will fail in GitHub actions

     ```
     ssh-copy-id -i ~/.ssh/id_rsa.pub bot@IP_ADDRESS
     ssh-copy-id -i ~/.ssh/id_rsa.pub prosper@IP_ADDRESS
     ...add for other users except root
     ```

   - ------------- On the server -------------

   ```
   sudo vim /etc/ssh/sshd_config
   ```

   - Change these values(on /etc/ssh/sshd_config file): `PubkeyAuthentication yes` `PasswordAuthentication no` `PermitRootLogin no` and save

   ```
   sudo systemctl restart ssh
   ```

4. Logout and login again to check if changes are applied

   ```
   exit
   ssh USERNAME@IP_ADDRESS
   ```

# Step 2: Install Packages, Kubernetes, SSH key for GitHub Actions

1. Update and install packages

   ```
   sudo apt update
   sudo apt upgrade
   sudo apt install curl wget bash git make tmux vim -y
   ```

2. Generate ssh keys(for every user including root)

   ```
   ssh-keygen -t rsa -b 4096
   ```

3. Install k3s

   ```
   curl -sfL https://get.k3s.io | sh -
   ```

   - Optional(highly recommended): to start the service on boot
     ```
     sudo systemctl enable k3s
     ```

4. Create k3s group and add users to avoid using always sudo(for every user except root) and add permissions. Add more users if needed (e.g. for my personal usage: prosper)

   ```
   sudo groupadd k3s
   sudo usermod -aG k3s bot
   sudo usermod -aG k3s prosper
   sudo chown -R root:k3s /etc/rancher/k3s
   sudo chmod -R 644 /etc/rancher/k3s
   sudo chmod ug+x /etc/rancher/k3s
   ```

   ```
   echo K3S_KUBECONFIG_MODE=\"644\" >> /etc/systemd/system/k3s.service.env
   ```

   - Restart the server


# Step 3: Create devops group, ci(for automation) group and data folder

1. Create devops group for server data access(the path /mnt/node/data/apps is called `NODE_APPS_DATA_PATH`). Add more users if needed (e.g. and for my personal usage: prosper as example)

   ```
   sudo mkdir -p /mnt/node/data/apps
   sudo groupadd devops
   sudo usermod -aG devops prosper
   sudo chown -R root:devops /mnt/node/data/apps
   sudo find /mnt/node/data/apps -type d -exec chmod 750 {} \;
   sudo find /mnt/node/data/apps -type f -exec chmod 640 {} \;
   ```

1. Create ci group for server data access(the path /mnt/node/data/ci is called `NODE_CI_DATA_PATH`).

   ```
   sudo mkdir -p /mnt/node/data/ci
   sudo groupadd ci
   sudo usermod -aG ci bot
   sudo chown -R root:ci /mnt/node/data/ci
   sudo find /mnt/node/data/ci -type d -exec chmod 770 {} \;
   sudo find /mnt/node/data/ci -type f -exec chmod 660 {} \;
   ```
