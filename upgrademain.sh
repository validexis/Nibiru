#!/bin/bash
cd $HOME
rm -rf nibiru
git clone https://github.com/NibiruChain/nibiru.git
cd nibiru
git checkout v2.1.0
make install

systemctl restart nibid && journalctl -fu nibid -o cat
