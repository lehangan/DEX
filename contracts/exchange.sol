// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "./rewardPool.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenExchange is Ownable {
    //string public exchange_name = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
    using SafeMath for uint256;

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // TODO: paste token contract address here
    Token public token = Token(tokenAddr);

    address payable rewardAddr =
        payable(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    Reward public reward = Reward(payable(rewardAddr));

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    mapping(address => uint) private lps;
    mapping(address => uint256) private fraction_lp;
    mapping(address => uint256) private lps_token;

    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);

        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        // amountETH in async function addLiquidity => amountETH => amountToken
        /******* TODO: Implement this function *******/

        // token_reserves = token.balanceOf(address(this));
        // eth_reserves = address(this).balance;
        // uint256 exchange_rate = token_reserves.div(eth_reserves);   // price of eth
        // uint256 amountETH = msg.value;
        // uint256 amountToken = amountETH.mul(exchange_rate);
        // token.transferFrom(msg.sender, address(this), amountToken);

        uint256 amountETHs = msg.value;
        lp_providers.push(msg.sender);
        lps[msg.sender] += msg.value;

        uint256 amountTokens = (amountETHs * token_reserves) / eth_reserves;

        // price of Token
        uint exchange_rate = (k * amountETHs) / amountTokens;
        uint max_exchange = k.mul(max_exchange_rate);
        uint min_exchange = k.mul(min_exchange_rate);

        
        require(exchange_rate <= max_exchange, "exchange rate is too high");
        require(exchange_rate >= min_exchange, "exchange rate is too high");

        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        eth_reserves = eth_reserves.add(amountETHs);
        token_reserves = token_reserves.add(amountTokens);

        lps_token[msg.sender] += amountTokens;
        fraction_lp[msg.sender] =
            (lps_token[msg.sender] * 100) /
            token.balanceOf(address(this));
        for (uint256 i = 0; i < lp_providers.length; i++)
            if (lp_providers[i] != msg.sender) {
                fraction_lp[lp_providers[i]] += 1;
            }

        require(
            eth_reserves == address(this).balance,
            "not enough ETH in pool"
        );
        require(
            token_reserves == token.balanceOf(address(this)),
            "not enough token in pool"
        );
        k = eth_reserves.mul(token_reserves);
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(
        uint amountETHs,
        uint max_exchange_rate,
        uint min_exchange_rate
    ) public payable {
        /******* TODO: Implement this function *******/
        require(amountETHs <= lps[msg.sender], "you not owned enough lp");

        if (swap_fee_numerator > 0) {
            uint256 reward_ETH = (address(rewardAddr).balance *
                fraction_lp[msg.sender]) / 100;
            uint256 reward_token = (token.balanceOf(rewardAddr) *
                fraction_lp[msg.sender]) / 100;
            reward.ETH_return(address(msg.sender), reward_ETH);
            reward.approveAddr(address(this), reward_token);
            token.transferFrom(rewardAddr, msg.sender, reward_token);
        }

        uint amountTokens = (amountETHs * token_reserves) / eth_reserves;
        token.approve(msg.sender, amountTokens);
        token.approve(address(this), amountTokens);
        token.transferFrom(address(this), msg.sender, amountTokens);

        eth_reserves = eth_reserves.sub(amountETHs);
        token_reserves = token_reserves.sub(amountTokens);
        require(eth_reserves > 0, "not enough ETH in pool");
        require(token_reserves > 0, "not enough token in pool");

        // price of token
        uint exchange_rate = (k * amountETHs) / amountTokens;
        uint max_exchange = k.mul(max_exchange_rate);
        uint min_exchange = k.mul(min_exchange_rate);
        require(exchange_rate <= max_exchange, "exchange rate is too high");
        require(exchange_rate >= min_exchange, "exchange rate is too high");

        (bool sent, ) = msg.sender.call{value: amountETHs}("");
        require(sent, "Failed to send Ether");
        require(address(this).balance > 0, "not enough require ETH in pool");
        require(
            token.balanceOf(address(this)) > 0,
            "not enough require token in pool"
        );

        lps[msg.sender] -= amountETHs;
        require(
            eth_reserves == address(this).balance,
            "not enough ETH in pool"
        );
        require(
            token_reserves == token.balanceOf(address(this)),
            "not enough token in pool"
        );

        fraction_lp[msg.sender] =
            (lps_token[msg.sender] * 100) /
            token.balanceOf(address(this));

        k = eth_reserves.mul(token_reserves);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        /******* TODO: Implement this function *******/
        if (swap_fee_numerator > 0) {
            uint256 reward_ETH = (address(rewardAddr).balance *
                fraction_lp[msg.sender]) / 100;
            uint256 reward_token = (token.balanceOf(rewardAddr) *
                fraction_lp[msg.sender]) / 100;
            reward.ETH_return(address(msg.sender), reward_ETH);
            reward.approveAddr(address(this), reward_token);
            token.transferFrom(rewardAddr, msg.sender, reward_token);
        }

        uint amountETHs = lps[msg.sender];
        uint amountTokens = (amountETHs * token_reserves) / eth_reserves;
        if (amountTokens >= token_reserves)
            amountTokens = token_reserves.sub(1);

        token.approve(msg.sender, amountTokens);
        token.approve(address(this), amountTokens);
        token.transferFrom(address(this), msg.sender, amountTokens);

        if (amountETHs >= eth_reserves) amountETHs = eth_reserves.sub(1);
        eth_reserves = eth_reserves.sub(amountETHs);
        token_reserves = token_reserves.sub(amountTokens);

        uint exchange_rate = (k * amountETHs) / amountTokens; // price of token
        uint max_exchange = k.mul(max_exchange_rate);
        uint min_exchange = k.mul(min_exchange_rate);
        require(exchange_rate <= max_exchange, "exchange rate is too high");
        require(exchange_rate >= min_exchange, "exchange rate is too high");

        lps[msg.sender] -= amountETHs;
        require(eth_reserves > 0, "not enough ETH in pool");
        (bool sent, ) = msg.sender.call{value: amountETHs}("");
        require(sent, "Failed to send Ether");

        require(address(this).balance > 0, "not enough ETH in pool");
        require(
            token.balanceOf(address(this)) > 0,
            "not enough token int pool"
        );

        require(
            eth_reserves == address(this).balance,
            "not enough ETH in pool"
        );
        require(
            token_reserves == token.balanceOf(address(this)),
            "not enough token in pool"
        );

        fraction_lp[msg.sender] =
            (lps_token[msg.sender] * 100) /
            token.balanceOf(address(this));

        for (uint i = 0; i < lp_providers.length; i++)
            if (lp_providers[i] == msg.sender) removeLP(i);
        k = eth_reserves.mul(token_reserves);
    }

    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(
        uint amountTokens,
        uint max_exchange_rate
    ) external payable {
        /******* TODO: Implement this function *******/
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to swap");
        require(amountTokens > 0, "Need tokens to swap.");
        //if( swap_fee_numerator >0 ) amountTokens = (amountTokens*(100-swap_fee_numerator))/swap_fee_denominator;

        uint amountReward = (amountTokens * swap_fee_numerator) / 100;
        amountTokens -= amountReward;
        token.transferFrom(msg.sender, rewardAddr, amountReward);

        token_reserves = token_reserves.add(amountTokens);
        uint eth_reserves_new = k.div(token_reserves);

        uint toETH = eth_reserves.sub(eth_reserves_new);
        eth_reserves = k.div(token_reserves);

        uint max_exchange = k * max_exchange_rate;
        uint real_exchange = (k * amountTokens) / toETH;
        require(real_exchange <= max_exchange, "exchange rate is too high");

        require(eth_reserves > 1, "not enough ETH in pool");
        require(token_reserves > 1, " not enough token in pool");
        token.transferFrom(msg.sender, address(this), amountTokens);
        (bool sent, ) = msg.sender.call{value: toETH}("");
        require(sent, "Failed to send Ether");

        require(address(this).balance == eth_reserves, "ETH isn't send enough");
        require(
            token.balanceOf(address(this)) == token_reserves,
            "token isn't send enough"
        );
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate) external payable {
        /******* TODO: Implement this function *******/
        uint amountETHs = msg.value;
        require(amountETHs > 0, "Need ETH to swap");

        uint amountReward = (amountETHs * swap_fee_numerator) / 100;
        amountETHs -= amountReward;
        (bool sent, ) = rewardAddr.call{value: amountReward}("");
        require(sent, "Failed to send Ether");
        //if( swap_fee_numerator >0 ) amountETHs = (amountETHs*(100-swap_fee_numerator))/swap_fee_denominator;

        eth_reserves = eth_reserves.add(amountETHs);
        uint token_reserves_new = k.div(eth_reserves);

        uint toToken = token_reserves.sub(token_reserves_new);
        token_reserves = k.div(eth_reserves);

        uint max_exchange = k * max_exchange_rate;
        uint real_exchange = (k * amountETHs) / toToken;
        require(real_exchange <= max_exchange, "exchange rate is too high");

        require(eth_reserves > 1, "not enough ETH in pool");
        require(token_reserves > 1, " not enough token in pool");

        require(toToken > 0, "Need tokens to create pool.");
        token.approve(msg.sender, toToken);
        token.approve(address(this), toToken);
        token.transferFrom(address(this), msg.sender, toToken);

        require(address(this).balance == eth_reserves, "ETH isn't send enough");
        require(
            token.balanceOf(address(this)) == token_reserves,
            "token isn't send enough"
        );
    }
}
