# Step 1: Setup VPS and security

0. Login to your server. Replace `USERNAME` with your server username (default: root) and `IP_ADDRESS` with your server IP.

   ```
   ssh USERNAME@IP_ADDRESS
   ```

1. Add new users (e.g., `bot` for CI/CD automation. With `default` group). `prosper`: personal/admin user. So add personal/admin user to `sudo` group (add more as needed).

   ```
   adduser bot
   adduser prosper
   usermod -aG sudo prosper
   ```

2. Configure firewall to block all incoming traffic except SSH (22), HTTP (80), and HTTPS (443). Exclure more as needed.

   ```
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow OpenSSH
   sudo ufw allow 80
   sudo ufw allow 443
   ```

   - Optional: to show all rules
     ```
     sudo ufw show Added
     ```

   ```
   sudo ufw enable
   ```

   - Optional: to show firewall status
     ```
     sudo ufw status
     ```

3. Disable ssh login with password. Add more users as needed(prosper is an example).

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

   - Change these values(on /etc/ssh/sshd_config file) and save.
      ```
      PubkeyAuthentication yes

      PasswordAuthentication no

      PermitRootLogin no
      ```

   - Restart SSH service

   ```
   sudo systemctl restart ssh
   ```

4. Logout and reconnect to confirm changes

   ```
   exit
   ssh USERNAME@IP_ADDRESS
   ```

# Step 2: Install Packages and kubernetes k3s cluster

1. Update and install packages

   ```
   sudo apt update
   sudo apt upgrade
   sudo apt install curl wget bash git make tmux vim -y
   ```

2. Generate ssh keys(for every user including root). You'll need to login with every user separately

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

4. Create k3s group and add users to avoid using always sudo(for every user except root) and add permissions. Add more users as needed(prosper is an example).

   ```
   sudo groupadd k3s
   sudo usermod -aG k3s bot
   sudo usermod -aG k3s prosper
   sudo chown -R root:k3s /etc/rancher/k3s
   sudo chmod -R 640 /etc/rancher/k3s
   sudo chmod ug+x /etc/rancher/k3s
   ```

   ```
   echo K3S_KUBECONFIG_MODE=\"640\" >> /etc/systemd/system/k3s.service.env
   ```

   - Optional: check if k3s installation works as expected

     ```
     kubectl get nodes
     ```

   - Restart the server

# Step 3: Create devops group(to have access to server data), ci group(for automation)

1. Create devops group for server data access(the path /mnt/node/data/apps is called `NODE_APPS_DATA_PATH`). Add more users as needed(prosper is an example).

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

# Additionals

1. Get the node/cluster name: login with user who have access to the server and have `k3s` group

   ```
   kubectl get nodes -o wide
   ```

   Check the column `NAME` to get the node name

2. By default k3s comes with traefik, and it's highly recommended to use it for ingress controller since it's already configured for you

3. If you want to use Prometheus or Grafana, we recommend to install the helm chart. And also do not install it on your master node(it will overload the server and it's not recommended. It's better to install it on a separate cluster/node, or on different server or maybe on your local machine). Check the k3s documentation for more details
