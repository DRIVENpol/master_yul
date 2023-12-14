//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Memory {
    struct Point {
        uint256 x;
        uint256 y;
    }

    event MemoryPointer(bytes32);
    event MemoryPointerMsize(bytes32, bytes32);
    event Debug(bytes32 location, bytes32 length, bytes32 valueAtIndex0, bytes32 valueAtIndex1);

    function memPointer() external {
        bytes32 x40;

        assembly {
            x40 := mload(0x40)
        }

        emit MemoryPointer(x40);
        // Logs "0x0000000000000000000000000000000000000000000000000000000000000080"
        // 0x80 - free memory pointer [where the action begins]

        Point memory p = Point(1, 2);
        
        assembly {
            x40 := mload(0x40)
        }

        emit MemoryPointer(x40);
        // Logs "0x00000000000000000000000000000000000000000000000000000000000000c0"
        // 0xc0 - 0x80 = 64 = to sets of 32 - x and y
    }

    function memPointerV2() external {
        bytes32 x40;
        bytes32 _msize;

        assembly {
            x40 := mload(0x40)
            _msize := msize()
        }
    }

    function args(uint256[] memory arr) external {
        bytes32 location;
        bytes32 length;
        bytes32 valueAtIndex0;
        bytes32 valueAtIndex1;

        assembly {
            location := arr // Get the location of the array
            length := mload(arr) // Get the length of the array
            valueAtIndex0 := mload(add(arr, 0x20)) // Get the value at index 0 by adding 0x20 to the location | uint256(valueAtIndex0) -> the get the actual value
            valueAtIndex1 := mload(add(arr, 0x40)) // Get the value at index 1 by adding 0x40 to the location
        }

        emit Debug(location, length, valueAtIndex0, valueAtIndex1);
    }

    function returnInMemory() public pure returns(uint256, uint256) {
        assembly {
            mstore(0x00, 5) // Store 5 at 0x00
            mstore(0x20, 8) // Store 8 at 0x20
            return(0x00, 0x40) // 0x40 because there are two slots: from 0x00 to 0x20 and from 0x20 to 0x40
        }
    }

    function requireV1() external view {
        require(msg.sender == 0x35c1ee3d7A1e2E1CA647bc6193135A67C06E8362);
    }

    function requireV2() external view {
        assembly {
            if iszero(eq(caller(), 0x35c1ee3d7A1e2E1CA647bc6193135A67C06E8362)) {
                revert(0, 0)
            }
        }
    }

    function hashV1() external pure returns(bytes32) {
        bytes memory toBeHashed = abi.encode(1,2,3);

        return keccak256(toBeHashed); // 0x6e0c627900b24bd432fe7b1f713f1b0744091a646a9fe4a65a18dfed21f2949c
    }

    function hashV2() external pure returns(bytes32) {
        assembly {
            // Load up the memory pointer (to not create collisions with other variables)
            let freeMemoryPointer := mload(0x40) // 0x40

            // Store 1,2,3 in memory
            mstore(freeMemoryPointer, 1) // Store 1  to the memory pointer | 0x40 | From 0x40 to 0x60
            mstore(add(freeMemoryPointer, 0x20), 2) // Store 2 to the memory pointer + 0x20 | 0x60 | From 0x60 to 0x80
            mstore(add(freeMemoryPointer, 0x40), 3) // Store 3 to the memory pointer + 0x40 | 0x80 | From 0x80 to 0xa0

            // Notes
            // 0x40 - free memory pointer (start)
            // 1 is stored from 0x40 to 0x60 (0x40 + 0)
            // 2 is stored from 0x60 to 0x80 (0x40 + 0x20)
            // 3 is stored from 0x80 to 0xa0 (0x40 + 0x40)
            // The next memory slot is from 0x40 (1) + 0x20 (2) + 0x20(3) + 0x20 (next slot) = 0x40 + 0x60 = add(freeMemoryPointer, 0x60)

            // Move up the free memory pointer
            mstore(0x40, add(freeMemoryPointer, 0x60)) // Store 'freeMemoryPointer + 0x60' to 0x40


            mstore(0x00, keccak256(freeMemoryPointer, 0x60)) // Store the hash of the memory pointer and 0x60 to 0x00
            // We do keccack256 only in this specific case because we want to return a bytes32 value
            return(0x00, 0x20) // Return the data from 0x00 to 0x20
        }
    }
}