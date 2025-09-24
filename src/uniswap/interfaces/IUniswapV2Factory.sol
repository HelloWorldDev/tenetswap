// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    // Priority token management
    function isPriorityToken(address token) external view returns (bool);
    function setPriorityToken(address token, bool isPriority) external;

    // Fee receiver management
    function feeReceiver() external view returns (address);
    function setFeeReceiver(address) external;

    function tokenRoyalty(address token) external view returns (address);
    function royaltyFactory() external view returns (address);
    function setRoyaltyFactory(address) external;

    function MB() external view returns (address);
    function setMB(address) external;

    function BGB() external view returns (address);
    function setBGB(address) external;

    function externalSwapRouter() external view returns (address);
    function setExternalSwapRouter(address) external;

    function internalSwapRouter() external view returns (address);
    function setInternalSwapRouter(address) external;
}
