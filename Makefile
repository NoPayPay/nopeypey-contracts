include .env

deploy-sepolia:; forge script script/DeployScript.s.sol:DeployScript --rpc-url $(SEPOLIA_RPC_URL) --verify --interactives 1 --broadcast -vvvvv

deploy-onrollup:; forge script script/DeployScript.s.sol:DeployScript --rpc-url http://94.131.99.79:8547/ --interactives 1 --broadcast -vvvvv
