#!/bin/bash

# One-click Installer for Story Geth and Story Node

# Function to display messages
function info {
  echo -e "\033[1;34m[INFO]\033[0m $1"
}

function error {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
  exit 1
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run this script as root (use sudo)"
   exit 1
fi

# Prompt user for moniker name
read -p "Enter your moniker name: " MONIKER_NAME
if [[ -z "$MONIKER_NAME" ]]; then
  error "Moniker name cannot be empty!"
fi

# Update system and install required dependencies
info "Updating system and installing dependencies..."
sudo apt update && sudo apt-get update
sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y || error "Failed to install required packages"

# Download and install Geth binary
info "Downloading and installing Story Geth binary..."
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3-b224fdf.tar.gz
tar -xzvf geth-linux-amd64-0.9.3-b224fdf.tar.gz || error "Failed to extract Geth binary"
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> $HOME/.bash_profile
fi
sudo cp geth-linux-amd64-0.9.3-b224fdf/geth $HOME/go/bin/story-geth || error "Failed to copy Geth binary"
source $HOME/.bash_profile
story-geth version || error "Story Geth version command failed"

# Download and install Story binary
info "Downloading and installing Story Consensus binary..."
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1-57567e5.tar.gz
tar -xzvf story-linux-amd64-0.10.1-57567e5.tar.gz || error "Failed to extract Story binary"
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> $HOME/.bash_profile
fi
cp $HOME/story-linux-amd64-0.10.1-57567e5/story $HOME/go/bin || error "Failed to copy Story binary"
source $HOME/.bash_profile
story version || error "Story version command failed"

# Initialize the Story Node with user-provided moniker
info "Initializing Story Node with moniker: $MONIKER_NAME..."
story init --network iliad --moniker "$MONIKER_NAME" || error "Failed to initialize Story node"

# Setup the systemd service for Story Geth
info "Setting up Story Geth systemd service..."
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Setup the systemd service for Story
info "Setting up Story Consensus systemd service..."
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Reload the systemd daemon and start services
info "Starting Story Geth and Story services..."
sudo systemctl daemon-reload
sudo systemctl start story-geth
sudo systemctl enable story-geth || error "Failed to start or enable Story Geth service"
sudo systemctl status story-geth

sudo systemctl start story
sudo systemctl enable story || error "Failed to start or enable Story Consensus service"
sudo systemctl status story

info "Story Geth and Story node installation and setup completed successfully!"
