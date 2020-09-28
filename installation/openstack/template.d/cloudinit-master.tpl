#cloud-config

ssh_pwauth: True

chpasswd:
  list: |
    ${SSH_USERNAME}:${USER_PASSWORD}
  expire: False

users:
  - name: ${SSH_USERNAME}
    gecos: user ${SSH_USERNAME} (managed by terraform)
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
    - ${SSH_PUB_KEY}

runcmd:
  - curl -sL https://get.k3s.io -o /usr/local/bin/k3s-install.sh
  - chmod +x /usr/local/bin/k3s-install.sh
  - export K3S_TOKEN=${K3S_TOKEN}
  - INSTALL_K3S_EXEC="server --disable-cloud-controller --kubelet-arg=cloud-provider=external --disable=traefik,local-storage" k3s-install.sh
