//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Storage {
    // transaction cost	43715 gas 
    // execution cost	22511 gas
    uint256 public x;

    // Set x
    function setX(uint256 _x) public {
        assembly {
            // Get the slot of x
            let slot := sload(x.slot)

            // Set the value of x
            sstore(slot, _x)
        }
    }

    // Read x
    function getX() public view returns(uint256 _x) {
        assembly {

            // Get the value at [x.slot]
            _x := sload(x.slot)
        }
    }
}

contract NoStorage {
    // transaction cost	43718 gas 
    // execution cost	22514 gas
    uint256 public x;

    // Set x
    function setX(uint256 _x) public {
        x = _x;
    }

    // Read x
    function getX() public view returns(uint256 _x) {
        _x = x;
    }
}

contract WeirdStorage {
    uint64 x = 1;
    uint64 y = 2;

    // Set x
    function setX(uint256 _x) public {
        assembly {
            // Get the slot of x
            let slot := sload(x.slot)

            // Set the value of x
            sstore(slot, _x)
        }
    }

    // Set y
    function setY(uint256 _y) public {
        assembly {
            // Get the slot of x
            let slot := sload(y.slot)

            // Set the value of x
            sstore(slot, _y)
        }
    }

    // Read x
    function getX() public view returns(uint256 _x) {
        assembly {

            // Get the value at [x.slot]
            _x := sload(x.slot)
        }
    }

    // Read y
    function getY() public view returns(uint256 _x) {
        assembly {

            // Get the value at [x.slot]
            _x := sload(y.slot)
        }
    }

    
    function getSlot(uint256 _slot) public view returns (bytes32 res) {
        assembly {
            res := sload(_slot)
        }
    }
}