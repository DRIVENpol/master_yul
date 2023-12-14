//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract PackedStorage {
    // 128 + 96 + 16 + 8 = 248 bits -> 31 bytes -> all in one slot
    uint128 public a = 4;
    uint96 public b = 5;
    uint16 public c = 6;
    uint8 public d = 7;

    // Returns 12368091213128693210921850507290953429988263705688185267159167189550891012
    function readBySlot_uintReturn(uint256 _s) public view returns(uint256 res) {
        assembly {
            res := sload(_s)
        }
    }

    // Returns 0x0007000600000000000000000000000500000000000000000000000000000004
    //              d   c                       b                               a
    function readBySlot_bytes32Return(uint256 _s) public view returns(bytes32 res) {
        assembly {
            res := sload(_s)
        }
    }


    // uint256: slot 0
    // uint256: offset 28 -> If you go 28 bytes down (from the end), you will find it
    // 0x0007000600000000000000000000000500000000000000000000000000000004
    //          |<-------------------- 28 bytes ----------------------->|
    function getOffsetC() external pure returns(uint256 slot, uint256 offset) {
        assembly {
            offset := c.offset
            slot := c.slot
        }
    }

    // How to properly fetch the value of C from a packed storage slot
    function readC() public view returns(uint256 res) {
        assembly {
            // Get the value in the slot
            // 0x0007000600000000000000000000000500000000000000000000000000000004
            let value := sload(c.slot)

            // Get the offset of c
            let offset := c.offset

            // Shift the value in the slot 'value' right by offset
            // Shift will shift by bits, so we need to multiply the 'offset' by 8 to get the number of bits
            res := shr(mul(offset, 8), value)
            //    0x0007000600000000000000000000000500000000000000000000000000000004
            // => 0x00070006 [00000000000000000000000500000000000000000000000000000004 - deleted bits]
            // => 0x [00000000000000000000000000000000000000000000000000000000 - added bits on the left] 00070006
            // => 0x0000000000000000000000000000000000000000000000000000000000070006
            // => 0x000000000000000000000000000000000000000000000000000000000000ffff
            // => we mask it with 0xffff to get rid of the left bits (d variable)

            // Because we shifted right, we need to mask the value to get rid of the left bits
            // We do this by ANDing with a mask of 0xffff (16 bits) 
            res := and(0xffff, res)
        }
    }

    // WRITING TO PACKED STORAGE
    // We will use bitmasking and bitshifting

    // Theory:
    // value AND 00 = 00
    // value OR 00 = value
    // value AND ff = value
    // masks can be hardcoded because storage slots nd offsets are fixed

    // Even if _c is declared as uint16, it's 32 bytes long under the hood
    function writeC(uint16 _c) public {
        assembly {
            // 1. Get the value from the slot
            let value := sload(c.slot)
            // => value = 0x0007000600000000000000000000000500000000000000000000000000000004

            // 2. Delete the c by masking
            // Where we have f's, we preserve the value
            // Where we have 0's, we delete the value
            // value = 0x0007000600000000000000000000000500000000000000000000000000000004
            // mask  = 0xffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            let clearedC := and(value, 0xffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            // =>      0x0007000000000000000000000000000500000000000000000000000000000004

            // 3. Shift left the new value _c by the offset c
            let shiftedValue := shl(mul(c.offset, 8), _c)
            // => shiftedValue: 0x0000000a00000000000000000000000000000000000000000000000000000000

            // 4. OR the shifted value with the cleared value in order to introduce the new value
            let newValue := or(shiftedValue, clearedC)
            // 0x0000000a00000000000000000000000000000000000000000000000000000000
            // OR
            // 0x0007000a00000000000000000000000500000000000000000000000000000004

            // 5. Store the new value
            sstore(c.slot, newValue)
        }
    }
}