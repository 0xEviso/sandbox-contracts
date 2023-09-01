#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo "Usage: ./script/give_me_lsd.sh 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    exit 1
fi

export MY_ADDRESS=$1
# 100 * 1e18
AMOUNT=100000000000000000000

# reth transfer
export RETH=0xae78736Cd615f374D3085123A210448E74Fc6393
export RETH_WHALE=0x5fEC2f34D80ED82370F733043B6A536d7e9D7f8d
# this allows us to impersonate our whales
cast rpc anvil_impersonateAccount $RETH_WHALE
cast send $RETH --unlocked --from $RETH_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

# wsteth transfer
export WSTETH=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
export WSTETH_WHALE=0x0E774BBed46B477538f5b34c8618858d3d86e530
cast rpc anvil_impersonateAccount $WSTETH_WHALE
cast send $WSTETH --unlocked --from $WSTETH_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

# sfrxeth transfer
export SFRXETH=0xac3E018457B222d93114458476f3E3416Abbe38F
export SFRXETH_WHALE=0x40093c0156cD8d1DAEFb5A5465D17FcC6467Aa31
cast rpc anvil_impersonateAccount $SFRXETH_WHALE
cast send $SFRXETH --unlocked --from $SFRXETH_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

# crvusd transfer
export CRVUSD=0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E
export CRVUSD_WHALE=0x3aB9Dc749E4490004419759427f8d5521CE30e60
cast rpc anvil_impersonateAccount $CRVUSD_WHALE
cast send $CRVUSD --unlocked --from $CRVUSD_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT

# crvusd transfer
export TBTC=0x18084fbA666a33d37592fA2633fD49a74DD93a88
export TBTC_WHALE=0xF8aaE8D5dd1d7697a4eC6F561737e68a2ab8539e
cast rpc anvil_impersonateAccount $TBTC_WHALE
cast send $TBTC --unlocked --from $TBTC_WHALE "transfer(address,uint256)(bool)" $MY_ADDRESS $AMOUNT


# # check user balance
# echo "$MY_ADDRESS ETH balance:"
# cast balance $MY_ADDRESS

# echo "$MY_ADDRESS RETH balance:"
# cast call $RETH "balanceOf(address)(uint256)" $MY_ADDRESS

# echo "$MY_ADDRESS WSTETH balance:"
# cast call $WSTETH "balanceOf(address)(uint256)" $MY_ADDRESS

# echo "$MY_ADDRESS SFRXETH balance:"
# cast call $SFRXETH "balanceOf(address)(uint256)" $MY_ADDRESS

