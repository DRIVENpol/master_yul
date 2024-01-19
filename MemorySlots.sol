//SPDX-License-Identifier: MIT

contract DifferentSlot {
    uint256 public val; // Public variable

    // keccak256(bytes("ChangedVal(uint256)"))
    bytes32 public constant EVENT_SIG = 0x264568dbfbd87f9f25499af4318605c0c9d70d42e8af54a396b1c09f58223f77;

    event ChangedVal(uint256 indexed _newVal);

    // transaction cost	44484 gas 
    // execution cost	23420 gas
    function writeVal() external {
        assembly {
            mstore(0x00, 1)

            // Add 1
            sstore(val.slot, add(mload(0x00), 1))

            // Emit the event
            mstore(0x20, EVENT_SIG)
            log2(0, 0, mload(0x20), add(mload(0x00), 1))
        }
    }
}

pragma solidity ^0.8.0;

contract SameSlot {
    uint256 public val; // Public variable

    // keccak256(bytes("ChangedVal(uint256)"))
    bytes32 public constant EVENT_SIG = 0x264568dbfbd87f9f25499af4318605c0c9d70d42e8af54a396b1c09f58223f77;

    event ChangedVal(uint256 indexed _newVal);

    // transaction cost	44482 gas 
    // execution cost	23418 gas
    function writeVal() external {
        assembly {
            mstore(0x00, 1)

            // Add 1
            sstore(val.slot, add(mload(0x00), 1))

            // Emit the event
            mstore(0x00, EVENT_SIG)
            log2(0, 0, mload(0x00), add(mload(0x00), 1))
        }
    }
}
