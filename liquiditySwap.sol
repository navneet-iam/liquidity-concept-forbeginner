// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CustomToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol){
        _mint(msg.sender, 100000 * 10 ** 18);
    }
}

contract SimpleAMM {
    // Reserves of token1 and token2 in the liquidity pool
    uint256 public reserve1;
    uint256 public reserve2;
    
    // Events to notify external systems about changes in liquidity pool
    event LiquidityAdded(address indexed provider, uint256 amount1, uint256 amount2);
    event LiquidityRemoved(address indexed provider, uint256 amount1, uint256 amount2);

    // Constructor to set initial reserves
    constructor(uint256 _reserve1, uint256 _reserve2) {
        reserve1 = _reserve1;
        reserve2 = _reserve2;
    }

    // Function to add liquidity to the pool
    function addLiquidity(uint256 amount1, uint256 amount2) external {
        require(amount1 > 0 && amount2 > 0, "Amount must be greater than 0");
        // Check if provided liquidity maintains the ratio
        uint256 newReserve1 = reserve1 + amount1;
        uint256 newReserve2 = reserve2 + amount2;
        require((newReserve1 * reserve2) == (reserve1 * newReserve2), "Liquidity must maintain ratio");
        reserve1 = newReserve1;
        reserve2 = newReserve2;
        emit LiquidityAdded(msg.sender, amount1, amount2);
    }

    // Function to remove liquidity from the pool
    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Liquidity must be greater than 0");
        // Calculate amounts of token1 and token2 to withdraw based on liquidity
        uint256 amount1 = (liquidity * reserve1) / (reserve1 + reserve2);
        uint256 amount2 = (liquidity * reserve2) / (reserve1 + reserve2);
        reserve1 -= amount1;
        reserve2 -= amount2;
        emit LiquidityRemoved(msg.sender, amount1, amount2);
    }

    // Function to calculate the amount of token2 received for a given amount of token1
    function getAmountOut(uint256 amountIn) external view returns (uint256) {
        require(amountIn > 0, "Amount must be greater than 0");
        // Calculate amount of token2 based on constant product formula
        return (reserve2 * amountIn) / reserve1;
    }

    // Function to calculate the amount of token1 required for a given amount of token2
    function getAmountIn(uint256 amountOut) external view returns (uint256) {
        require(amountOut > 0, "Amount must be greater than 0");
        // Calculate amount of token1 based on constant product formula
        return (reserve1 * amountOut) / reserve2;
    }
}




contract CryptoSwap {
    string[] public tokens = ["CoinA", "CoinB", "CoinC"];

    mapping(string => ERC20) public tokenInstanceMap;
    uint256 ethValue = 100000000000000;

    address public liquidityPool;

    // Constructor to set liquidity pool address
    constructor(address _liquidityPool) {
        liquidityPool = _liquidityPool;
        for (uint i=0; i<tokens.length; i++) {
            CustomToken token = new CustomToken(tokens[i], tokens[i]);
            tokenInstanceMap[tokens[i]] = token;
        }
    }

    function getBalance(string memory tokenName, address _address) public view returns (uint256) {
        return tokenInstanceMap[tokenName].balanceOf(_address);
    }

    function getTotalSupply(string memory tokenName) public view returns (uint256) {
        return tokenInstanceMap[tokenName].totalSupply();
    }

    function getName(string memory tokenName) public view returns (string memory) {
        return tokenInstanceMap[tokenName].name();
    }

    function getTokenAddress(string memory tokenName) public view returns (address) {
        return address(tokenInstanceMap[tokenName]);
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function swapEthToToken(string memory tokenName) public payable returns (uint256) {
        uint256 inputValue = msg.value;
        uint256 outputValue = (inputValue / ethValue) * 10 ** 18; 
        require(tokenInstanceMap[tokenName].transfer(msg.sender, outputValue));
        return outputValue;
    }

    function swapTokenToEth(string memory tokenName, uint256 _amount) public returns (uint256) {
        uint256 exactAmount = _amount / 10 ** 18;
        uint256 ethToBeTransferred = exactAmount * ethValue;
        require(address(this).balance >= ethToBeTransferred, "Dex is running low on balance.");

        payable(msg.sender).transfer(ethToBeTransferred);
        require(tokenInstanceMap[tokenName].transferFrom(msg.sender, address(this), _amount));
        return ethToBeTransferred;
    }

    // function swapTokenToToken(string memory srcTokenName, string memory destTokenName, uint256 _amount) public {
    //     require(tokenInstanceMap[srcTokenName].transferFrom(msg.sender, address(this), _amount));
    //     require(tokenInstanceMap[destTokenName].transfer(msg.sender, _amount));
    // }

        // function to swap token1 for token2 based on liquidity pool rates
        function swapToken1ForToken2(string memory token1, string memory token2, uint256 amountIn) external {
        uint256 amountOut = SimpleAMM(liquidityPool).getAmountOut(amountIn);
        require(tokenInstanceMap[token1].transferFrom(msg.sender, liquidityPool, amountIn), "Transfer failed");
        require(tokenInstanceMap[token2].transfer(msg.sender, amountOut), "Transfer failed");
    }
}
