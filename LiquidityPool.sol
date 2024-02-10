// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TokenPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract LiquidityPool is Ownable, TokenPool {
    IERC20 public token0;
    IERC20 public token1;

    uint private reserve0;
    uint private reserve1;
    
    bool public initialized;
    
    modifier onlyTokenInPool(address _tokenIn) {
        require(
            _tokenIn == address(token0) || _tokenIn == address(token1),
            "token is not supported!"
        );
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner){}

    function initPool(address _token0, address _token1)
        external 
    {
        require(!initialized, 'initialization not allowed!');
        require(_token0 != address(0) && _token1 != address(0), "zero address not allowed!");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);

        initialized = true;
    }

    function getLatestReserves() 
        public 
        view 
        returns (uint _reserve0, uint _reserve1) 
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _updateReserves(uint _reserve0, uint _reserve1) 
        private
    {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function swap(uint _amountOut, address _to, address _tokenIn)
        external
    {
        require(_amountOut > 0, "amountOut should be greater than zero!");
        
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = getReserves(_tokenIn);
        
        require(_amountOut < reserveOut, "not enough reserveOut!");
        
        IERC20(tokenOut).transfer(_to, _amountOut);
        
        uint balance0 = tokenIn.balanceOf(address(this));
        uint balance1 = tokenOut.balanceOf(address(this));
        
        ( uint newReserve0, uint newReserve1 ) = 
            _tokenIn == address(token0) ? (balance0, balance1) : (balance1, balance0);

        _updateReserves(newReserve0, newReserve1);        

        require(newReserve0 * newReserve1 >= reserveIn * reserveOut, "swap failed!");
    }

    function getReserves(address _tokenIn) 
        public
        view
        returns (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) 
    {
        bool isToken0 = _tokenIn == address(token0);
        (   
            tokenIn, tokenOut, reserveIn,  reserveOut
        ) = isToken0
            ? (token0, token1, reserve0, reserve1)
            : (token1, token0, reserve1, reserve0);
    }

    function getTokensOutAmount(address _tokenIn, uint _amountIn)
        external
        view
        onlyTokenInPool(_tokenIn)
        returns (uint amountOut)
    {       
        (,, uint reserveIn, uint reserveOut) = getReserves(_tokenIn);
        amountOut = (reserveOut * _amountIn)/(reserveIn + _amountIn);
    }

    function getTokenPairRatio(address _tokenIn, uint _amountIn)
        external
        view
        onlyTokenInPool(_tokenIn)
        returns (uint tokenOut)
    {
        (,, uint reserveIn, uint reserveOut) = getReserves(_tokenIn);

        tokenOut = (reserveOut * _amountIn) / reserveIn;
    }

    function addLiquidity(address _to)
        external
        returns (uint shares)
    {
        (uint _reserve0, uint _reserve1) = getLatestReserves();

        uint _balance0 = token0.balanceOf(address(this));
        uint _balance1 = token1.balanceOf(address(this));

        uint _amount0 = _balance0 - _reserve0;
        uint _amount1 = _balance1 - _reserve1;

        require(_amount0 != 0 && _amount1 != 0, "Liquidity amount should not be zero!");

        if(totalSupply == 0) {
            shares = Math.sqrt(_amount0 * _amount1);
        }
        else {
            shares = Math.min(
                (_amount0 * totalSupply) / _reserve0, 
                (_amount1 * totalSupply) / _reserve1
            );
        }
        
        require(shares > 0, "shares equals 0");
        _mint(_to, shares);

        _updateReserves(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
        
        (_reserve0, _reserve1) = getLatestReserves();
    }

    function removeLiquidity(address _to)
        external
        returns (uint amount0, uint amount1)
    {
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        uint shares = balanceOf(address(this));

        amount0 = (shares * balance0) / totalSupply;
        amount1 = (shares * balance1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");

        _burn(address(this), shares);

        _updateReserves(balance0 - amount0, balance1 - amount1);

        token0.transfer(_to, amount0);
        token1.transfer(_to, amount1);
    }
}