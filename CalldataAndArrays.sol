// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Yul_Arrays {
    address public lastAddress;
    uint256 public lastAmount;

    function IterateThroughArrays(address[] calldata addresses, uint256[] calldata amounts) external {
        assembly {
            // Arrays should have equal length
            if iszero(eq(addresses.length, amounts.length)) {
                revert(0, 0)
            }

            // Compute the end of the addresses array
            let endOfArray := add(addresses.offset, shl(5, addresses.length))

            // Compute the distance from element 'i' in the addresses array to the element 'i' in the amounts array
            let distance := sub(amounts.offset, addresses.offset)

            for { let i := addresses.offset } lt(i, endOfArray) { i := add(i, 0x20) } {

                // If we are at the last index on both arrays, we save the values to storage
                if eq(i, sub(endOfArray, 0x20)) {
                    sstore(lastAddress.slot, calldataload(i))
                    sstore(lastAmount.slot, calldataload(add(i, distance)))
                }

            }
        }
    }
}

// Arguments
// ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
// ["10", "20", "30"]

// Calldata
// 0x797f574f <- 0x00
// 0000000000000000000000000000000000000000000000000000000000000040 <- 0x04 (where the addresses start)
// 00000000000000000000000000000000000000000000000000000000000000c0 <- 0x24 (where the amounts start)
// 0000000000000000000000000000000000000000000000000000000000000003 <- 0x44 (the addresses length)
// 0000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4 <- 0x64 (addr 1)
// 000000000000000000000000Ab8483F64d9C6d1EcF9b849Ae677dD3315835cb2 <- 0x84 (addr 2)
// 0000000000000000000000004B20993Bc481177ec7E8f571ceCaE8A9e22C02db <- 0xa4 (addr 3)
// 0000000000000000000000000000000000000000000000000000000000000003 <- 0xc4 (the amounts length)
// 000000000000000000000000000000000000000000000000000000000000000a <- 0xe4 (amount 1)
// 0000000000000000000000000000000000000000000000000000000000000014 <- 0x104 (amount 2)
// 000000000000000000000000000000000000000000000000000000000000001e <- 0x124 (amount 3)
//
//
// End of the array: 0xc4
// Distance: amounts.offset - addresses.offset = 0xe4 - 0x64 = 0x80
//
// For loop
// From i = start of the addresses until end of the array
