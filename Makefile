include .env


deploy-sepolia:; forge script script/DeployScript.s.sol:DeployScript --rpc-url $(SEPOLIA_RPC_URL) --interactives 1 --verify --broadcast -vvvvv