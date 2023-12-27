//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract TestContract {
    // 1st MSTORE 0x0000000000000000000000000000000000000000000000000000000023b872dd
    // 2nd MSTORE 0x000000000000000000000000000000005b38da6a701c568545dcfcb03fcb875f
    //                                              |------------------------------|
    //                                                         caller address
    // It overwrites the '0x023b872dd' with the caller address
    // 0x23b872dd is the selector of 'transferFrom' function in ERC20
    function getMemorySlot() public view returns(bytes32 _res) {
        assembly {
            mstore(0x00, 0x23b872dd)
            mstore(0x04, caller())

            _res := mload(0x00)
        }
    }

    // Returns 0x23b872dd0000000000000000000000005b38da6a701c568545dcfcb03fcb875f
    //           |------|                        |------------------------------|
    //           selector                                  caller address
    // No overwrites
    // 0x23b872dd is the selector of 'transferFrom' function in ERC20
    function getMemorySlot2() public view returns(bytes32 _res) {
        assembly {
            mstore(0x00, hex'23b872dd')
            mstore(0x04, caller())

            _res := mload(0x00)
        }
    }
}