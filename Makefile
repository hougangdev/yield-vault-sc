# ! NOTE: The Private Key use here is only for testing purposes. Not for production.

-include .env

.PHONY: all clean remove install update build test fmt

all : clean remove install update build

clean :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install

update :; forge update

build :; forge build

test :; forge test

fmt :; forge fmt

deploy-all:; forge script script/DeployAll.s.sol:DeployAll --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv