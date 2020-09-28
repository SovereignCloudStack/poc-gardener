#cloud-config

ssh_pwauth: True

chpasswd:
  list: |
    ${SSH_USERNAME}:${USER_PASSWORD}
  expire: False

# users
users:
  - name: ${SSH_USERNAME}
    gecos: user ${SSH_USERNAME} (managed by terraform)
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, docker
    shell: /bin/bash
    ssh_authorized_keys:
    - ${SSH_PUB_KEY}

# update repository/deb sources
repo_update: true

# install packages
packages:
  - docker.io
  - jq

runcmd:
  - systemctl enable --now docker
