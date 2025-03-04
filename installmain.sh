#!/bin/bash
sudo apt update && apt upgrade -y
sudo apt install -y curl git jq lz4 build-essential

sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.23.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
echo "export PATH=$PATH:/usr/local/go/bin:/usr/local/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile

cd $HOME && mkdir -p go/bin/
git clone https://github.com/NibiruChain/nibiru/
cd $HOME/nibiru/
git fetch --all
git checkout v2.1.0
make install

nibid config chain-id cataclysm-1
nibid config keyring-backend file
nibid config node tcp://localhost:26657

nibid init Node --chain-id cataclysm-1 --home $HOME/.nibid

curl -Ls https://ss.nibiru.nodestake.org/genesis.json > $HOME/.nibid/config/genesis.json 
curl -Ls https://ss.nibiru.nodestake.org/addrbook.json > $HOME/.nibid/config/addrbook.json

seed="9a9e6eab3a83b670f7f20c3f56cd0e5f7f81f46c@rpc.nibiru.nodestake.org:666"
sed -i.bak -e "s/^seed *=.*/seed = \"$seed\"/" $HOME/.nibid/config/config.toml
peers=$(curl -s https://ss.nibiru.nodestake.org/peers.txt)
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.nibid/config/config.toml

sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.025unibi\"/;" $HOME/.nibid/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.nibid/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.nibid/config/config.toml

sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.nibid/config/app.toml

CUSTOM_PORT=163

sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${CUSTOM_PORT}58\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${CUSTOM_PORT}57\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${CUSTOM_PORT}60\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}56\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${CUSTOM_PORT}66\"%" $HOME/.nibid/config/config.toml
sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://localhost:${CUSTOM_PORT}17\"%; s%^address = \":8080\"%address = \":${CUSTOM_PORT}80\"%; s%^address = \"localhost:9090\"%address = \"localhost:${CUSTOM_PORT}90\"%; s%^address = \"localhost:9091\"%address = \"localhost:${CUSTOM_PORT}91\"%; s%^address = \"0.0.0.0:8545\"%address = \"0.0.0.0:${CUSTOM_PORT}45\"%; s%^ws-address = \"0.0.0.0:8546\"%ws-address = \"0.0.0.0:${CUSTOM_PORT}46\"%" $HOME/.nibid/config/app.toml

nibid config node tcp://localhost:${CUSTOM_PORT}57

sudo tee /etc/systemd/system/nibid.service > /dev/null <<EOF
[Unit]
Description=nibid Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which nibid) start
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

LATEST_SNAPSHOT=$(curl -s https://server-1.stavr.tech/Mainnet/Nibiru/ | grep -oE 'nibiru-snap-[0-9]+\.tar\.lz4' | while read SNAPSHOT; do HEIGHT=$(curl -s "https://server-1.stavr.tech/Mainnet/Nibiru/${SNAPSHOT%.tar.lz4}-info.txt" | awk '/Block height:/ {print $3}'); echo "$SNAPSHOT $HEIGHT"; done | sort -k2 -nr | head -n 1 | awk '{print $1}')
curl -o - -L https://server-1.stavr.tech/Mainnet/Nibiru/$LATEST_SNAPSHOT | lz4 -c -d - | tar -x -C $HOME/.nibid
wget -O $HOME/.nibid/config/addrbook.json "https://server-1.stavr.tech/Mainnet/Nibiru/addrbook.json"

sudo systemctl daemon-reload
sudo systemctl enable nibid
sudo systemctl restart nibid && sudo journalctl -u nibid -fo cat
