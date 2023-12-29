//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract EventWithIndexedParams {

    event SimpleEvent(address indexed owner, uint256 val);

    // transaction cost	    22882 gas 
    // execution cost	    1818 gas
    function emitEvent() external {
        emit SimpleEvent(msg.sender, 2);
    }
}

contract EventWithIndexedParamsYul {

    event SimpleEvent(address indexed owner, uint256 val);

    // transaction cost	    22589 gas 
    // execution cost	    1525 gas
    function emitEvent() external {
        assembly {
            // bytes32 sig = kecckak256("SimpleEvent(address,uint256)")
            let sig := 0x03c400b16b9e5104e275ada00677d083d60e9e28bd3a41589081eabe01f1b014
            mstore(0x00, 2)

            log2(0x00, 0x20, sig, caller())
            //  |---------|       |------|
            //       A                B
            // A - not indexed param
            // B - indexed param
        }
    }
}