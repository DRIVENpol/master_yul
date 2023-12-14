//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MappingsAndArrays_FixedSizeArrays {
    // Hardcoded array of uint256
    uint256[5] public arrayUint256;

    constructor() {
        arrayUint256 = [1, 2, 3, 4, 5];
    }

    // Read variable at index
    function readArray(uint256 index) public view returns(uint256 res) {
       assembly {
            res := sload(add(arrayUint256.slot, index))
       }
    }
}

contract MappingsAndArrays_DynamicSizeArrays {
    // Hardcoded array of uint256
    uint256[] arrayUint256;

    constructor() {
        arrayUint256 = [1, 2, 3, 4, 5];
    }

    // Get the length of the array
    function getArrayLength() public view returns(uint256 res) {
       assembly {
            res := sload(arrayUint256.slot)
       }
    }

    // Notes: for dynamic length arrays, the items are not stored sequentially because it could overrun and crash the next variables
    // The values of the dynamic arrays are stored at a very high slot so there is no collision with other variables
    function readDynamicArray(uint256 index) public view returns(uint256 res) {
        uint256 slot;

        assembly {
                // We get the slot
                slot := arrayUint256.slot
        }

        // We get the location of the slot (very high slot)
        bytes32 location = keccak256(abi.encode(slot));

        assembly {
            res := sload(add(location, index))
        }
    }
}

contract MappingsAndArrays_Mappings {
    mapping(uint256 => uint256) public mappingUint256;

    constructor() {
        mappingUint256[18] = 246;
 
    }

    function readMappingValueAtIndex(uint256 index) public view returns(uint256 res) {
        uint256 slot;

        assembly {
                // We get the slot
                slot := mappingUint256.slot
        }

        // We get the location of the slot by hashing the index with the slot
        bytes32 location = keccak256(abi.encode(index, slot));

        assembly {
            res := sload(location)
        }
    }
}