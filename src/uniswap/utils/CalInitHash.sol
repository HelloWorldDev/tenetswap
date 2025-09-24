// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../core/UniswapV2Pair.sol";

contract CalInitHash {
    function getInitHash() public pure returns (bytes32) {
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }
}
