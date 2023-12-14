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
    address public caller;

    mapping(uint256 => uint256) public mappingUint256;
    mapping(address => uint256) public mappingAddressUint256;
    mapping(uint256 => mapping(uint256 => uint256)) public nestedMapping;
    mapping(address => mapping(uint256 => uint256)) public nestedMappingAddress;

    constructor() {
        mappingUint256[18] = 246;
        mappingAddressUint256[msg.sender] = 123;

        nestedMapping[2][4] = 7;

        nestedMappingAddress[msg.sender][2] = 8;
 
        caller = msg.sender;
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

    // Get value of mapping at index
    function getValueOfAddressUint256(address key) public view returns(uint256 res) {
        uint256 slot;

        assembly {
            slot := mappingAddressUint256.slot
        }

        bytes32 location = keccak256(abi.encode(key, slot));

        assembly {
            res := sload(location)
        }
    }

    // Get element of nested mapping
    function getNestedMapping(uint256 x, uint256 y) external view returns (uint256 ret) {
        uint256 slot;
        assembly {
            slot := nestedMapping.slot
        }

        // We look at the location of the mapping at index x and y (from inside to outside)
        bytes32 location = keccak256(
            abi.encode(
                uint256(y),
                keccak256(abi.encode(uint256(x), uint256(slot)))
            )
        );
        assembly {
            ret := sload(location)
        }
    }

    // Get element of nested mapping
    function getNestedMappingAddress(address x, uint256 y) external view returns (uint256 ret) {
        uint256 slot;
        assembly {
            slot := nestedMappingAddress.slot
        }

        // We look at the location of the mapping at index x and y (from inside to outside)
        bytes32 location = keccak256(
            abi.encode(
                uint256(y),
                keccak256(abi.encode(x, uint256(slot)))
            )
        );
        assembly {
            ret := sload(location)
        }
    }
}