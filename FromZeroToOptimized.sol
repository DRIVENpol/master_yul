// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract OwnershipCompare1 {
    uint256 public bar;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Not owner!");

        _;
    }

    // For owner calls
    // transaction cost	    45630 gas 
    // execution cost	    24566 gas

    // For non-owner calls
    // transaction cost	    23660 gas 
    // execution cost	    2596 gas
    function foo() public onlyOwner {
        bar++;
    }
}

contract OwnershipCompare2 {
    uint256 public bar;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        assembly {
            if iszero(eq(caller(), sload(owner.slot))) {
                revert(0,0)
            }
        }

        _;
    }

    // For owner calls
    // transaction cost	    45583 gas 
    // execution cost	    24519 gas 

    // For non-owner calls
    // transaction cost	    23324 gas 
    // execution cost	    2260 gas
    function foo() public onlyOwner {
        bar++;
    }
}

contract OwnershipCompareWithUnchecked {
    uint256 public bar;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        assembly {
            if iszero(eq(caller(), sload(owner.slot))) {
                revert(0,0)
            }
        }

        _;
    }

    // For owner calls

    // Previous results
    // transaction cost	    45583 gas 
    // execution cost	    24519 gas 

    // Results (now)
    // transaction cost	    45459 gas 
    // execution cost	    24395 gas
    function foo() public onlyOwner {
        unchecked {
            ++bar;
        }
    }
}

contract OwnershipCompareWithUncheckeAndVariablePacking {
    uint64 private bar;
    address private owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        assembly {
            // Read the owner variable
            let value := sload(owner.slot)

            // Read the offset
            let ownerOffset := owner.offset

            // Shift right
            let shifted := shr(mul(ownerOffset, 8), value)
            // 0x0000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff <- mask
            // We don't do masking as we don't havy any other variables on the left side

            if iszero(eq(caller(),shifted)) {
                revert(0,0)
            }
        }

        _;
    }

    // For owner calls

    // 'OwnershipCompare1' Results
    // transaction cost	    45630 gas 
    // execution cost	    24566 gas

    // 'OwnershipCompare2' Results
    // transaction cost	    45583 gas 
    // execution cost	    24519 gas 

    // 'OwnershipCompareWithUnchecked' Results
    // transaction cost	    45459 gas 
    // execution cost	    24395 gas

    // Results now
    // transaction cost	    26406 gas 
    // execution cost	    5342 gas

    // Delta ('OwnershipCompare1' - now)
    // transaction cost: 45630 - 26406 = 19224 GAS SAVED
    // execution cost: 24566 - 5342 = 19224 GAS SAVED
    function foo() public onlyOwner {
        assembly {
            let value := sload(bar.slot)
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000001
            // 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
            // 0x000000000000000000000000000000000000000000000000ffffffffffffffff

            let prevValue := and(value, 0xffffffffffffffff)

            let mask := 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
            let clearedBar := and(value, mask)
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc0000000000000000

            let shiftedBar := shl(mul(bar.offset, 8), add(prevValue, 1))

            let newVal := or(shiftedBar, clearedBar)
            sstore(bar.slot, newVal)
        }
    }
}

contract OwnershipCompareExtraOptimized {
    uint64 private bar;
    address private owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        assembly {
            // Read the owner variable
            let value := sload(owner.slot)

            // Read the offset
            let ownerOffset := owner.offset

            // Shift right
            let shifted := shr(mul(ownerOffset, 8), value)
            // 0x0000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff <- mask
            // We don't do masking as we don't havy any other variables on the left side

            if iszero(eq(caller(),shifted)) {
                revert(0,0)
            }
        }

        _;
    }

    // For owner calls

    // 'OwnershipCompare1' Results
    // transaction cost	    45630 gas 
    // execution cost	    24566 gas

    // 'OwnershipCompare2' Results
    // transaction cost	    45583 gas 
    // execution cost	    24519 gas 

    // 'OwnershipCompareWithUnchecked' Results
    // transaction cost	    45459 gas 
    // execution cost	    24395 gas

    // 'OwnershipCompareWithUncheckeAndVariablePacking' Results
    // transaction cost	    26406 gas 
    // execution cost	    5342 gas

    // Results now
    // transaction cost	    26382 gas 
    // execution cost	    5318 gas

    // Delta ('OwnershipCompare1' - now)
    // transaction cost: 45630 - 26382 = 19248 GAS SAVED
    // execution cost: 24566 - 5318 = 19248 GAS SAVED
    function foo() external payable onlyOwner {
        assembly {
            let value := sload(bar.slot)
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000001
            // 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
            // 0x000000000000000000000000000000000000000000000000ffffffffffffffff

            let prevValue := and(value, 0xffffffffffffffff)

            let mask := 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
            let clearedBar := and(value, mask)
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc0000000000000000

            let shiftedBar := shl(mul(bar.offset, 8), add(prevValue, 1))

            let newVal := or(shiftedBar, clearedBar)
            sstore(bar.slot, newVal)
        }
    }
}
