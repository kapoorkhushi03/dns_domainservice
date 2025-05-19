# Domain Name service on SUI network

## About
in simple words , making a address book and a marketplace for domains which register on blockchain which is not tamperable 

## deployment

### smart contract
- the smart contract is written in move language which is used by sui network
- move takes the example from rust , both are similar
- the dependencies we need ```c++ toolchain,rustup(for rust),nightly rust(move compatible),nvm(for latest npm),sui dependencies```

### for Linux
```bash
git clone https://github.com/kapoorkhushi03/dns_domainservice
cd dns_domainservice/
chmod +x enviroment.sh && ./enviroment.sh
```
### for macOS/UNIX based systems
replace ```sudo apt``` with ```brew``` in [enviroment.sh](enviroment.sh)

then
```bash
chmod +x enviroment.sh && ./enviroment.sh
```
### for Windows
use a wsl and then follow the linux 

### Deploying the contract
- after the enviroment is set we deploy the smart contract
```bash
sui move build
sui client publish --gas-budget 100000000
```
- we set the max gas budget as 0.1 sui
- the sui move build for default will make a  new sui wallet for you and its address can be retrived by ```sui client active-address```
- we can add the faucet money to this address directly or add or own address by
```bash
sui client new-address ed25519 --import #paste your private key wehn prompted
sui client switch --address <your_slush_address> #switch
sui client active-address #confirm
```
- we have the config files in ```~/.sui/sui_config/```