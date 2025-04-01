include .env


deploy-espresso:; forge script script/DeployScript.s.sol:DeployScript --rpc-url http://94.131.99.79:8547/ --interactives 1 --broadcast -vvvvv


bridge-fund:; cast send --rpc-url https://arbitrum-sepolia-rpc.publicnode.com 0x65cA021308e3Caa26f36B88bd84AECc996713522  'depositEth() external payable returns (uint256)' --interactive  --value 40000000000 -vvvv

send-fund:; cast send 0xdaFE88244735b360F26Ab97cA560853866E302E4 --rpc-url http://94.131.99.79:8547/ --interactive -vvvv

check-bal:; cast balance 0xdaFE88244735b360F26Ab97cA560853866E302E4 --rpc-url http://94.131.99.79:8547/ 