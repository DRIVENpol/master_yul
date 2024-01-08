//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Arrays_NotOptimized {

    uint256 public result;

    // Params: ["10", "50", "100", "200", "300"]
    // transaction cost	47683 gas 
    // execution cost	25627 gas
    function sumOfTheArray(uint256[] calldata array) external {
        for (uint256 i = 0; i < array.length; i++) {
            result += array[i];
        }
    }
}

contract Arrays_0 {

    uint256 public result;

    // Params: ["10", "50", "100", "200", "300"]
    // transaction cost	46163 gas 
    // execution cost	24107 gas
    function sumOfTheArray(uint256[] calldata array) external {
        for (uint256 i = 0; i < array.length; i++) {
            unchecked {
                result += array[i];
            }
        }
    }
}

contract Arrays_1 {

    uint256 public result;

    // Params: ["10", "50", "100", "200", "300"]
    // transaction cost	45298 gas 
    // execution cost	23242 gas
    function sumOfTheArray(uint256[] calldata array) external {
        uint256 _result;

        for (uint256 i = 0; i < array.length; i++) {
            unchecked {
                _result += array[i];
            }
        }

        result = _result;
    }
}

contract Arrays_2 {

    uint256 public result;

    // Params: ["10", "50", "100", "200", "300"]
    // transaction cost	45263 gas 
    // execution cost	23207 gas 
    function sumOfTheArray(uint256[] calldata array) external {
        uint256 _result;
        uint256 _len = array.length;

        for (uint256 i = 0; i < _len; i++) {
            unchecked {
                _result += array[i];
            }
        }

        result = _result;
    }
}

contract Arrays_3 {

    uint256 public result;

    // Params: ["10", "50", "100", "200", "300"]
    // transaction cost	45007 gas 
    // execution cost	22951 gas
    function sumOfTheArray(uint256[] calldata array) external {
        assembly {
            let _end := add(array.offset, shl(5, array.length))

            let _result := 0

            for { let i := array.offset } 1 {} {
                _result := add(_result, calldataload(i))

                i := add(i, 0x20)

                if eq(i, _end) {
                    break
                }
            }

            // Store the result
            sstore(result.slot, _result)
        }
    }
}

