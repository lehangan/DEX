// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./token.sol";
contract Reward {
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;                                  // TODO: paste token contract address here
    Token public token = Token(tokenAddr);  
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function ETH_getBalance() public view returns (uint) {
        return address(this).balance;
    }
    function Token_getBalance() public view returns (uint){
        return token.balanceOf(address(this));
    }

    function approveAddr(address dex, uint amount) public {
        token.approve(dex, amount);
    }
    
    function ETH_return( address _to, uint ETHreward ) public {
        (bool sent, ) = _to.call{value: ETHreward}("");
        require(sent, "Failed to send Ether");
    }
}