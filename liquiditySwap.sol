// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract CustomToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol){
        _mint(msg.sender, 100000 * 10 ** 18);
    }
}

contract SimpleAMM {
    // Struct to represent reserves for each token pair
    struct PairReserve {
        uint256 reserve1;
        uint256 reserve2;
    }

    // Mapping to store reserves for each token pair
    mapping(string => mapping(string => PairReserve)) public reserves;

    // Events to notify external systems about changes in liquidity pool
    event LiquidityAdded(string CoinA, string CoinB, address indexed provider, uint256 amount1, uint256 amount2);
    event LiquidityRemoved(string CoinA, string CoinB, address indexed provider, uint256 amount1, uint256 amount2);
    event tokenSwapped(string CoinA, string CoinB, address indexed provider, uint256 amount1, uint256 amount2);

    constructor(string memory CoinA, string memory CoinB, uint256 _reserve1, uint256 _reserve2) {
        reserves[CoinA][CoinB] = PairReserve(_reserve1, _reserve2);
    }
    
    // Function to add liquidity to the pool
    function addLiquidity(string memory CoinA, string memory CoinB, uint256 amount1, uint256 amount2) external {
        require(amount1 > 0 && amount2 > 0, "Amount must be greater than 0");
        PairReserve storage pairReserve = reserves[CoinA][CoinB];
        // Check if provided liquidity maintains the ratio
        uint256 newReserve1 = pairReserve.reserve1 + amount1;
        uint256 newReserve2 = pairReserve.reserve2 + amount2;
        require((newReserve1 * pairReserve.reserve2) == (pairReserve.reserve1 * newReserve2), "Liquidity must maintain ratio");
        pairReserve.reserve1 = newReserve1;
        pairReserve.reserve2 = newReserve2;
        emit LiquidityAdded(CoinA, CoinB, msg.sender, amount1, amount2);
    }

    // Function to remove liquidity from the pool
    function removeLiquidity(string memory CoinA, string memory CoinB, uint256 liquidity) external {
        require(liquidity > 0, "Liquidity must be greater than 0");
        PairReserve storage pairReserve = reserves[CoinA][CoinB];
        // Calculate amounts of CoinA and CoinB to withdraw based on liquidity
        uint256 amount1 = (liquidity * pairReserve.reserve1) / (pairReserve.reserve1 + pairReserve.reserve2);
        uint256 amount2 = (liquidity * pairReserve.reserve2) / (pairReserve.reserve1 + pairReserve.reserve2);
        pairReserve.reserve1 -= amount1;
        pairReserve.reserve2 -= amount2;
        emit LiquidityRemoved(CoinA, CoinB, msg.sender, amount1, amount2);
    }

    // Function to calculate the amount of CoinB received for a given amount of CoinA
    function getAmountOut(string memory CoinA, string memory CoinB, uint256 amountIn) external view returns (uint256) {
        require(amountIn > 0, "Amount must be greater than 0");
        PairReserve storage pairReserve = reserves[CoinA][CoinB];
        // Calculate amount of CoinB based on constant product formula
        return (pairReserve.reserve2 * amountIn) / pairReserve.reserve1;
    }

    // Function to calculate the amount of CoinA required for a given amount of CoinB
    function getAmountIn(string memory CoinA, string memory CoinB, uint256 amountOut) external view returns (uint256) {
        require(amountOut > 0, "Amount must be greater than 0");
        PairReserve storage pairReserve = reserves[CoinA][CoinB];
        // Calculate amount of CoinA based on constant product formula
        return (pairReserve.reserve1 * amountOut) / pairReserve.reserve2;
    }

    // Function to update reserves
    function updateReserves(string memory CoinA, string memory CoinB, uint256 amountIn, uint256 amountOut, uint256 flag) external {
        PairReserve storage pairReserve = reserves[CoinA][CoinB];
        if(flag == 1){
            pairReserve.reserve1 -= amountOut;
            pairReserve.reserve2 += amountIn;
            emit tokenSwapped(CoinB, CoinA, msg.sender, amountOut, amountIn);  
        }
        else{
            pairReserve.reserve1 += amountIn;
            pairReserve.reserve2 -= amountOut;
            emit tokenSwapped(CoinA, CoinB, msg.sender, amountIn, amountOut);   
        }
}

    function getReserves(string memory CoinA, string memory CoinB) public view returns (uint256 reserve1, uint256 reserve2) {
        PairReserve storage pairReserve = reserves[CoinA][CoinB];
        return (pairReserve.reserve1, pairReserve.reserve2);
    }

}



contract CryptoSwap {
    // Mapping to store liquidity pool addresses for different token pairs
    mapping(string => mapping(string => address)) public liquidityPools;
    
    // Mapping to store token instances
    mapping(string => ERC20) public tokenInstanceMap;

    uint256 ethValue = 100000000000000;
    event LiquidityPoolCreated(string indexed token1, string token2, address poolAddress, uint256 initialAmountToken1, uint256 initialAmountToken2);

    constructor() {
        // Initialize token instances and liquidity pool addresses
        tokenInstanceMap["CoinA"] = new CustomToken("CoinA", "CoinA");
        tokenInstanceMap["CoinB"] = new CustomToken("CoinB", "CoinB");
        tokenInstanceMap["CoinC"] = new CustomToken("CoinC", "CoinC");
        
        // Create liquidity pools for different token pairs
        createLiquidityPool("CoinA", "CoinB", 1000, 8000);
        createLiquidityPool("CoinB", "CoinC", 2000, 5000);
        createLiquidityPool("CoinA", "CoinC", 5000,11000);
    }
    
    // Function to create a liquidity pool for a token pair
    function createLiquidityPool(string memory token1, string memory token2, uint256 amountToken1, uint256 amountToken2) internal {

        SimpleAMM newPool = new SimpleAMM(token1, token2, amountToken1 * 10 ** 18, amountToken2 * 10 ** 18); // Pass initial reserve values
    
    // Store liquidity pool address in mapping
    liquidityPools[token1][token2] = address(newPool);
    
    // Emit event to log liquidity pool creation
    emit LiquidityPoolCreated(token1, token2, address(newPool), amountToken1, amountToken2);
    }
    
    // Function to get balance of a token for an address
    function getBalance(string memory tokenName, address _address) public view returns (uint256) {
        return tokenInstanceMap[tokenName].balanceOf(_address);
    }
    
    // Function to get total supply of a token
    function getTotalSupply(string memory tokenName) public view returns (uint256) {
        return tokenInstanceMap[tokenName].totalSupply();
    }
    
    // Function to get name of a token
    function getName(string memory tokenName) public view returns (string memory) {
        return tokenInstanceMap[tokenName].name();
    }
    
    // Function to get address of a token
    function getTokenAddress(string memory tokenName) public view returns (address) {
        return address(tokenInstanceMap[tokenName]);
    }
    
    // Function to get address of a liquidity pool
    function getLiquidityPool(string memory CoinA, string memory CoinB) public view returns (address) {
        return liquidityPools[CoinA][CoinB];
    }
    
    // Function to get ETH balance of the contract
    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    // Function to add liquidity to a pool
    function addLiquidity(string memory CoinA, string memory CoinB, uint256 amount1, uint256 amount2) public {
        require(amount1 > 0 && amount2 > 0, "Amount must be greater than 0");
        address liquidityPool = liquidityPools[CoinA][CoinB];
        require(liquidityPool != address(0), "Liquidity pool does not exist");
        SimpleAMM(liquidityPool).addLiquidity(CoinA, CoinB, amount1, amount2);
    }
    
    // Function to remove liquidity from a pool
    function removeLiquidity(string memory CoinA, string memory CoinB, uint256 liquidity) public {
        require(liquidity > 0, "Liquidity must be greater than 0");
        address liquidityPool = liquidityPools[CoinA][CoinB];
        require(liquidityPool != address(0), "Liquidity pool does not exist");
        SimpleAMM(liquidityPool).removeLiquidity(CoinA, CoinB, liquidity);
    }
    
function swapTokens(string memory CoinA, string memory CoinB, uint256 amountIn) public {
    require(amountIn > 0, "Amount must be greater than 0");

    address liquidityPool = liquidityPools[CoinA][CoinB];
    address reverseLiquidityPool = liquidityPools[CoinB][CoinA];

    require(liquidityPool != address(0) || reverseLiquidityPool != address(0), "Liquidity pool does not exist");

    uint256 amountOut;
    if (liquidityPool != address(0)) {
        amountOut = SimpleAMM(liquidityPool).getAmountOut(CoinA, CoinB, amountIn);
        require(amountOut > 0, "Insufficient liquidity for the swap");
        require(tokenInstanceMap[CoinA].transferFrom(msg.sender, liquidityPool, amountIn), "Transfer failed");
        require(tokenInstanceMap[CoinB].transfer(msg.sender, amountOut), "Transfer failed");

        SimpleAMM(liquidityPool).updateReserves(CoinA, CoinB, amountIn, amountOut, 0);
    } else {
        require(reverseLiquidityPool != address(0), "Reverse liquidity pool does not exist");
        amountOut = SimpleAMM(reverseLiquidityPool).getAmountIn(CoinB, CoinA, amountIn);
        require(amountOut > 0, "Insufficient liquidity for the swap");
        require(tokenInstanceMap[CoinA].transferFrom(msg.sender, reverseLiquidityPool, amountIn), "Transfer failed");
        require(tokenInstanceMap[CoinB].transfer(msg.sender, amountOut), "Transfer failed");

        SimpleAMM(reverseLiquidityPool).updateReserves(CoinB, CoinA, amountIn, amountOut, 1);
    }
}


        // Function to swap ETH for a token
    function swapEthToToken(string memory tokenName) public payable returns (uint256) {
        uint256 inputValue = msg.value;
        uint256 outputValue = (inputValue / ethValue) * 10 ** 18; 
        require(tokenInstanceMap[tokenName].transfer(msg.sender, outputValue));
        return outputValue;
    }
    
    // Function to swap a token for ETH
    function swapTokenToEth(string memory tokenName, uint256 _amount) public returns (uint256) {
        uint256 exactAmount = _amount / 10 ** 18;
        uint256 ethToBeTransferred = exactAmount * ethValue;
        require(address(this).balance >= ethToBeTransferred, "Dex is running low on balance.");

        payable(msg.sender).transfer(ethToBeTransferred);
        require(tokenInstanceMap[tokenName].transferFrom(msg.sender, address(this), _amount));
        return ethToBeTransferred;
    }

    // Function to get allowance for all three coins
    function getAllowance() public view returns (uint256 allowance1, uint256 allowance2, uint256 allowance3) {
        allowance1 = tokenInstanceMap["CoinA"].allowance(msg.sender, address(this));
        allowance2 = tokenInstanceMap["CoinB"].allowance(msg.sender, address(this));
        allowance3 = tokenInstanceMap["CoinC"].allowance(msg.sender, address(this));
    }

    // Function to calculate the amount of CoinB received for a given amount of CoinA
    function getAmountOut(string memory CoinA, string memory CoinB, uint256 amountIn) public view returns (uint256) {
        require(amountIn > 0, "Amount must be greater than 0");
        address liquidityPool = liquidityPools[CoinA][CoinB];
        require(liquidityPool != address(0), "Liquidity pool does not exist");
        return SimpleAMM(liquidityPool).getAmountOut(CoinA, CoinB, amountIn);
    }

    // Function to calculate the amount of CoinA required for a given amount of CoinB
    function getAmountIn(string memory CoinA, string memory CoinB, uint256 amountOut) public view returns (uint256) {
        require(amountOut > 0, "Amount must be greater than 0");
        address liquidityPool = liquidityPools[CoinA][CoinB];
        require(liquidityPool != address(0), "Liquidity pool does not exist");
        return SimpleAMM(liquidityPool).getAmountIn(CoinA, CoinB, amountOut);
    }

    function getReserves(string memory CoinA, string memory CoinB) public view returns (uint256 reserve1, uint256 reserve2) {
        address liquidityPool = liquidityPools[CoinA][CoinB];
        require(liquidityPool != address(0), "Liquidity pool does not exist");
        return SimpleAMM(liquidityPool).getReserves(CoinA, CoinB);
    }

}
