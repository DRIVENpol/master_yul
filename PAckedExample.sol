//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract PackedVariables_V1 {
    uint256 public variable;

    constructor() {
        variable = (block.timestamp << 128) | uint128(125);
        // 0x000000000000000000000000659eee44 00000000000000000000000000000003
        // <--------- Block Timestamp ------> <--------- Variable ----------->
    }

    function getBlockTimestamp() public view returns(uint256 _res) {
       assembly {
            // Operations
            // 0x000000000000000000000000659eee44 [00000000000000000000000000000003]
            // 0x00000000000000000000000000000000 000000000000000000000000659eee44 <- shift right
            _res := shr(mul(16, 8), sload(variable.slot))
       }
    }

    function getOtherVariable() public view returns(uint256 _res) {
       assembly {
            // Operations
            // 0x000000000000000000000000659eee44 00000000000000000000000000000003
            // 0x00000000000000000000000000000000 ffffffffffffffffffffffffffffffff <- We mask the original value so we preserve the lower bits
            _res := and(sload(variable.slot), 0xffffffffffffffffffffffffffffffff)
       }
    }
}

contract PackedVariables_V2 {
    uint128 public variable1;
    uint128 public variable2;

    constructor() {
        variable1 = uint128(block.timestamp);
        variable2 = 125;
        // 0x000000000000000000000000659eee44 00000000000000000000000000000003
        // <--------- Block Timestamp ------> <--------- Variable ----------->
    }

    function getBlockTimestamp() public view returns(uint256 _res) {
       assembly {
            // Operations
            // 0x000000000000000000000000659eee44 [00000000000000000000000000000003]
            // 0x00000000000000000000000000000000 000000000000000000000000659eee44 <- shift right
            _res := shr(mul(16, 8), sload(variable1.slot))
       }
    }

    function getOtherVariable() public view returns(uint256 _res) {
       assembly {
            // Operations
            // 0x000000000000000000000000659eee44 00000000000000000000000000000003
            // 0x00000000000000000000000000000000 ffffffffffffffffffffffffffffffff <- We mask the original value so we preserve the lower bits
            _res := and(sload(variable2.slot), 0xffffffffffffffffffffffffffffffff)
       }
    }
}
