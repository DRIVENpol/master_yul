//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Events {
    event SomeLog(uint256 indexed a, uint256 indexed b); // Case 1: indexed parameters
    event SomeLogV2(uint256 indexed a, bool); // Case 2: one indexed parameter and one non-indexed parameter

    function emitLog() external {
        emit SomeLog(5, 6);
    }

    function yulEmitEvents() external {
        assembly {
            // keccack256("SomeLog(uint256,uint256)") = 0xc200138117cf199dd335a2c6079a6e1be01e6592b6a76d4b5fc31b169df819cc
            let signature := 0xc200138117cf199dd335a2c6079a6e1be01e6592b6a76d4b5fc31b169df819cc
            log3(0, 0, signature, 5, 6)
        }
    }

    // For non-indexed parameters, we need to put the data into memory and pass the pointer to the log function
    function yulEmitEventsV2() external {
        assembly {
            // keccack256("SomeLog(uint256,uint256)") = 0xc200138117cf199dd335a2c6079a6e1be01e6592b6a76d4b5fc31b169df819cc
            let signature := 0xc200138117cf199dd335a2c6079a6e1be01e6592b6a76d4b5fc31b169df819cc
            mstore(0x00, 1) // Store 1 (true) at memory location 0x00
            log2(0, 0x20, signature, 5) // And we use log2 because we have 2 parameters
        }
    }
}