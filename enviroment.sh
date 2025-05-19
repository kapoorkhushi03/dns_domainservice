#!/bin/bash



echo "updating"
sudo apt update 
sudo apt autoclean 


echo "Installing cpp tools"
sudo apt install -y build-essential pkg-config libssl-dev libclang-dev cmake #cpp toolchain



echo "installing rustup"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y #rust


source "$HOME/.cargo/env" #set enviroment variable of rust



echo "changing rust version to nightly for compatiblity"
rustup install nightly #nightly
rustup default nightly 


echo "installing sui"
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui -v #sui dependencies



echo "installing nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash #nvm
export NVM_DIR="$HOME/.nvm" #sourcing it and relading
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"


echo "installing  latest nodejs"
nvm install --lts 
nvm use --lts 


echo "installing move-analyzer"
cargo install --git https://github.com/movebit/move --branch move-analyzer2 move-analyzer 


echo "all done , check by typing sui "