// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRoyaltyFactory {
    function getRoyalty(address token) external view returns (address);
    function addRoyaltyFee(address token, uint256 amount) external payable returns (uint256);
}
