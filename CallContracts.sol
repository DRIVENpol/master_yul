//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract TestContract {
    uint256 public a;

    // Selector: 0xd46300fd
    function getA() external view returns(uint256) {
        return a;
    }

    // Selector: 0x165c4a16
    function multiply(uint256 _a, uint256 _b) external pure returns(uint256) {
        return _a * _b;
    }

    function getSelectorOf_getA() external pure returns(bytes4) {
        return this.getA.selector;
    }

    function getSelectorOf_multiply() external pure returns(bytes4) {
        return this.multiply.selector;
    }
}

contract CallContracts {
    // External view call
    function externalViewCallWithoutArgs(address _target) external view returns(uint256) {
        assembly {
            // 0xd46300fd is the selector of getA()
            mstore(0x00, 0xd46300fd) // Store getA() selector into memory

            let success := staticcall(gas(), _target, 28, 32, 0x00, 0x20)
            // 28 and 32 are the offset and length of the selector / transaction data
            // 0x00 is the location of the selector in memory
            // 0x20 is the length of the return value
            // on success will overwrite the memory at 0x00 with the return value
            if iszero(success) {
                revert(0, 0)
            }

            return(0x00, 0x20)
        }
    }

    // Call multiply - with arguments
    function callMultiply(address _target) external view returns(uint256 result) {
        assembly {
            let mptr := mload(0x40) // 0x40 is the location of the free memory pointer
            let oldMptr := mptr // Store the old memory pointer location

            mstore(mptr, 0x165c4a16) // Store the selector of multiply into memory | 0x40 to 0x60 = mptr + 0
            mstore(add(mptr, 0x20), 3) // The first argument | 0x60 to 0x80 = mptr + 0x20
            mstore(add(mptr, 0x40), 4) // The second argument | 0x80 to 0xa0 = mptr + 0x40
            // => the next memory poiter will start from mptr + 0x60
            // so we store the value of mptr + 0x60 into 0x40 (the start of the memory pointer)

            // Advance the memory pointer by 0x60
            mstore(0x40, add(mptr, 0x60))

            // Call the contract
            let success := staticcall(gas(), _target, add(oldMptr, 28), mload(0x40), 0x00, 0x20)
            // add(oldMptr, 28) -> add the old memory pointer with 28 to get the location of the selector
            // because the selector is stored at the old memory pointer in the last 4 bytes
            // mload(0x40) -> get the length of the transaction data
            if iszero(success) {
                revert(0, 0)
            }

            // Get the return value
            result := mload(0x00)
        }

        // When calling a function with unknown return size, we need to use the calldatacopy function
        // returndatacopy(0, 0, returndatasize()) - which will copy the return data from 0 to returndatasize() to memory location 0
        // into the memory slot 0, copy the data from 0 to returndatasize()
    }
}