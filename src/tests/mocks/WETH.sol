// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

// import {IWETH} from "../../interfaces/IWETH.sol";

// from https://ethereum.stackexchange.com/questions/27101/what-does-wadstand-for
// A wad is a decimal number with 18 digits of precision that is being represented as an integer.
contract WETH is ERC20 {
    event Deposit(address indexed from, uint256 amount);

    event Withdrawal(address indexed to, uint256 amount);

    constructor() ERC20("Wrapped Ether", "WETH", 18) {}

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
