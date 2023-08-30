#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo "Usage: ./script/give_me_lsd.sh 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    exit 1
fi

export MY_ADDRESS=$1

export RETH=0xae78736Cd615f374D3085123A210448E74Fc6393
export RETH_WHALE=0x5fEC2f34D80ED82370F733043B6A536d7e9D7f8d
export WSTETH=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
export WSTETH_WHALE=0x0E774BBed46B477538f5b34c8618858d3d86e530
export SFRXETH=0xac3E018457B222d93114458476f3E3416Abbe38F
export SFRXETH_WHALE=0x40093c0156cD8d1DAEFb5A5465D17FcC6467Aa31

# # 100 * 1e18
AMOUNT=100000000000000000000

# this allows us to impersonate our whales
cast rpc anvil_impersonateAccount $RETH_WHALE
cast send $RETH --unlocked --from $RETH_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

cast rpc anvil_impersonateAccount $WSTETH_WHALE
cast send $WSTETH --unlocked --from $WSTETH_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

cast rpc anvil_impersonateAccount $SFRXETH_WHALE
cast send $SFRXETH --unlocked --from $SFRXETH_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

# check user balance
echo "$MY_ADDRESS ETH balance:"
cast balance $MY_ADDRESS

echo "$MY_ADDRESS RETH balance:"
cast call $RETH "balanceOf(address)(uint256)" $MY_ADDRESS

echo "$MY_ADDRESS WSTETH balance:"
cast call $WSTETH "balanceOf(address)(uint256)" $MY_ADDRESS

echo "$MY_ADDRESS SFRXETH balance:"
cast call $SFRXETH "balanceOf(address)(uint256)" $MY_ADDRESS

