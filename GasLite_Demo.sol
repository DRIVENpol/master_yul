//SPDX-License-Identifier: MIT

// Arrays to test
// ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", 
// "0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB", "0x17F6AD8Ef982297579C203069C1DbfFE4348c372",
// "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
// ]
// ["123", "456", "789", "987", "654", "123", "456", "789"]

pragma solidity ^0.8.0;

contract Memory {

    function airdrop(
        // address token,
        address[] calldata receivers,
        uint256 [] calldata amounts
    ) external view returns(bytes32 _res) {
        assembly {
            if iszero(eq(receivers.length, amounts.length)) {
                revert(0, 0)
            }

            mstore(0x00, hex"23b872dd")

            mstore(0x04, caller())

            // receivers.offset
            // 0x0000000000000000000000000000000000000000000000000000000000000064
            // 0x64 = 100 (uint256)
            // Now, why it's 0x64?
            // Because 
            // 0x00 - function selector
            // 0x04 - caller
            // 0x24 - where the data of the addresses arrays starts
            // 0x44 - where the data of the amounts starts
            // 0x64 - the length of the address array

            // amounts.offset
            // 0x0000000000000000000000000000000000000000000000000000000000000184
            // 0x184
            // Now why 0x184?
            // Because
            // 0x00 - function selector
            // 0x04 - caller
            // 0x24 - where the data of the addresses arrays starts
            // 0x44 - where the data of the amounts starts
            // 0x64 - the length of the address array
            // 0x84-0xa4, 0xa4-0xc4, 0xc4-0xe4, 0xe4-0x104, 0x104-0x124, 0x124-0x144, 0x144-0x164, 0x164-0x184 - the address array content
            // 0x184 - start of the uint256 array

            // [array].offset = the location where the data about the array starts
            // 1st element: length
            // 2nd element - 2ndelement + length: thet content of the array

            // let v0 := shl(5, receivers.length)
            // 0x0000000000000000000000000000000000000000000000000000000000000060
            // shifting receivers.length by 5 = receiver.length * 2^5 = receivers.length * 32
            // 32 bytes: a full memory slot
            // so shl(5, receivers.length) will give us the end slot for the content of the address array
            // or the slot where the last value starts

            let end := add(receivers.offset, shl(5, receivers.length))
            // end : receivers.offset + receivers.length * 32 
            // end : the beginnign of the receivers array + the content of the receivers array
            // end : the last slot of the receiver array content
            // in our case, end : 0x64 + (8 * 32)
            // end : 0x64 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20
            // end : 0x164

            // Let's check it
            // _res := end
            // 0x0000000000000000000000000000000000000000000000000000000000000164
        }    
    }
}

// ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",  "0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB", "0x17F6AD8Ef982297579C203069C1DbfFE4348c372", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db" ]
// ["123", "456", "789", "987", "654", "123", "456", "789"]
// 0x67243482 <- function selector
// 0000000000000000000000000000000000000000000000000000000000000040 : 0x00 <- where the data of the addresses array starts: 0x40 (x)
// 0000000000000000000000000000000000000000000000000000000000000160 : 0x20 <- where the data of the amounts starts: 0x160 (y)
// 0000000000000000000000000000000000000000000000000000000000000008 : 0x40 <- the length of the addresse array (x)
// 000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2 : 0x60 <- start of the addresses array: offset
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db : 0x80
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db : 0xa0
// 00000000000000000000000078731d3ca6b7e34ac0f824c42a7cc18a495cabab : 0xc0
// 00000000000000000000000017f6ad8ef982297579c203069c1dbffe4348c372 : 0xe0
// 000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2 : 0x100
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db : 0x120
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db : 0x140 <- end of the addresses array
// 0000000000000000000000000000000000000000000000000000000000000008 : 0x160 <- the length of the uint256 array (y)
// 000000000000000000000000000000000000000000000000000000000000007b : 0x180 <- start of the uint256 array: offset
// 00000000000000000000000000000000000000000000000000000000000001c8 : 0x1a0
// 0000000000000000000000000000000000000000000000000000000000000315 : 0x1c0
// 00000000000000000000000000000000000000000000000000000000000003db : 0x1e0
// 000000000000000000000000000000000000000000000000000000000000028e : 0x200
// 000000000000000000000000000000000000000000000000000000000000007b : 0x220
// 00000000000000000000000000000000000000000000000000000000000001c8 : 0x240
// 0000000000000000000000000000000000000000000000000000000000000315 : 0x260 <- end of the uint256 array
