//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract TransferOfValue_V1 {

    function withdraw() external {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}

contract TransferOfValue_V2 {

    function withdraw() external {
        assembly {
            let s := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
            // First two zero - function selectors and encoded arguments
            // Last two zeros - the return value
            if iszero(s) { revert(0 , 0)}
        }
    }
}