//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract PackedStorage {

    uint64 private paused; // Slot 0 | 1 = paused AND 2 = unpaused
    address private owner; // Also slot 0

    // Constructor
    constructor() {
        paused = 2;
        owner = msg.sender;
    }

    // Function to retrieve the value of the 'owner' variable
    function readOwner() public view returns(address res) {
        assembly {
            let value := sload(owner.slot)
            // Step 1: Load the value stored in the 'paused' variable
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002

            let ownerOffset := owner.offset
            // Step 2: Get the offset of the 'owner' variable
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc4 0000000000000002
            //                                                  ^

            let shiftedValue := shr(mul(ownerOffset, 8), value)
            // 0x0000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4

            // Mask the left bits to extract the relevant information
            // 0x0000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff -> 0xffffffffffffffffffffffffffffffffffffffff
            // Not necessary to mask in our case as we don't have left bits, but we do it for the sake of example
            res := and(0xffffffffffffffffffffffffffffffffffffffff, shiftedValue)
        }
    }

    // Function to retrieve the value of the 'paused' variable in a read-only manner
    function readPaused() public view returns(uint256 res) {
        assembly {
            let value := sload(paused.slot)
            // Step 1: Load the value stored in the 'paused' variable
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002

            let offsetPaused := paused.offset
            // Step 2: Get the offset of the 'paused' variable
            // 0
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002
            //                                                                  ^

            // Usually 'shr; and 'shl' will shift by bits, so we need to multiply 
            // the 'offset' by 8 to get the number of bits.
            // Not need to shr in our case as offset is 0, but we do it for the sake of example
            let shiftedValue := shr(mul(offsetPaused, 8), value)

            // Mask the left bits to extract the relevant information
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002
            // 0x000000000000000000000000000000000000000000000000000000000000000f -> 0xf
            res := and(0xf, shiftedValue)
        }
    }

    // Function to change the owner of the contract
    function changeOwner(address _newOwner) public {
        assembly {
            // Get the value of the slot
            let value := sload(owner.slot)

            // Delete the owner by masking (we preserve the values of other variables in the slot)
            // Value:   0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002
            // Mask:    0xffffffff0000000000000000000000000000000000000000ffffffffffffffff
            let mask := 0xffffffff0000000000000000000000000000000000000000ffffffffffffffff
            let clearedOwner := and(value, mask)
            // clearedOwner = 0x0000000000000000000000000000000000000000000000000000000000000002

            // Shift left the new value _newOwner by the offset owner
            let shiftedNewOwner := shl(mul(owner.offset, 8), _newOwner)
            // New owner address: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
            // shiftedNewOwner = 0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000000

            // OR the new value with the cleared slot
            let newValue := or(shiftedNewOwner, clearedOwner)
            // clearedOwner =       0x00000000a0000000000000000000000000000000000000000000000000000002
            // shiftedNewOwner =    0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000000
            // OR
            //                      0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000002

            // Store the new value
            sstore(owner.slot, newValue)
        }
    }
}