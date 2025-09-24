// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IRoyaltyFactory.sol";
import "./UniswapV2Pair.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    // Priority tokens (e.g., WETH, USDT, USDC) - if present, fee is collected in this token
    mapping(address => bool) public override isPriorityToken;

    // Address to receive trading fees
    address public override feeReceiver;
    // Address to query royalty
    address public override royaltyFactory;
    // Address external swap router
    address public override externalSwapRouter;
    // Address internal swap router
    address public override internalSwapRouter;

    address public override MB;
    address public override BGB;

    address[5] public buyBackTokens;
    address[5] public buyBackQuotes;
    uint16[5] public buyBackPcts;

    constructor(
        address _feeToSetter,
        address _feeReceiver,
        address _royaltyFactory,
        address _MB,
        address _BGB,
        address _externalSwapRouter
    ) {
        feeToSetter = _feeToSetter;
        feeReceiver = _feeReceiver;
        royaltyFactory = _royaltyFactory;
        MB = _MB;
        BGB = _BGB;
        buyBackTokens[0] = MB;
        buyBackPcts[0] = 10000;
        externalSwapRouter = _externalSwapRouter;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "TENETSWAPV2 IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "TENETSWAPV2 ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "TENETSWAPV2 PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function setPriorityToken(address token, bool isPriority) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        isPriorityToken[token] = isPriority;
    }

    function setFeeReceiver(address _feeReceiver) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        feeReceiver = _feeReceiver;
    }

    function tokenRoyalty(address token) external view returns (address) {
        return IRoyaltyFactory(royaltyFactory).getRoyalty(token);
    }

    function setRoyaltyFactory(address _royaltyFactory) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        royaltyFactory = _royaltyFactory;
    }

    function setMB(address _MB) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        MB = _MB;
    }

    function setBGB(address _BGB) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        BGB = _BGB;
    }

    function setExternalSwapRouter(address _externalSwapRouter) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        externalSwapRouter = _externalSwapRouter;
    }

    function setInternalSwapRouter(address _internalSwapRouter) external override {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");
        internalSwapRouter = _internalSwapRouter;
    }

    function setBuyBackConfig(address[5] memory _tokens, address[5] memory _quotes, uint16[5] memory _pcts) external {
        require(msg.sender == feeToSetter, "TENETSWAPV2 FORBIDDEN");

        // Validate total percentage doesn't exceed 100%
        uint16 totalPct = 0;
        for (uint256 i = 0; i < 5; i++) {
            totalPct += _pcts[i];
        }
        require(totalPct <= 10000, "TENETSWAPV2 INVALID_PERCENTAGE"); // 10000 = 100%

        buyBackTokens = _tokens;
        buyBackQuotes = _quotes;
        buyBackPcts = _pcts;
    }
}
