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

            // receivers.offset // 0x0000000000000000000000000000000000000000000000000000000000000064
            // _res := amounts.offset // 0x0000000000000000000000000000000000000000000000000000000000000184

            // shl(5, receivers.length) = receivers.length * 2 ** 5
            // = receivers.length * 32

            // add(receivers.offset, shl(5, receivers.length)) = 
            // = start slot of receivers + (length * 32 bytes)
            // = the end slot of receivers array
            // in our case, 0x64 + (8 * 0x20) = 
            // = 0x64 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20
            // = 0x164

            let end := add(receivers.offset, shl(5, receivers.length))

            // Let's check it
            // _res := end
            // 0x0000000000000000000000000000000000000000000000000000000000000164
            // Exacly what we computed: 0x64 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20 + 0x20

            let diff := sub(receivers.offset, amounts.offset)
            // _res := diff
            // so diff : 100 - 388 = -288
            // diff : 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffee0
            // diff : 0xee0

            _res := sub(add(receivers.offset, 0x20), diff)
            // 0x184
            // sub(add(receivers.offset, 0x20), diff) -> 0x1a4
        }    
    }
}

// ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",  "0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB", "0x17F6AD8Ef982297579C203069C1DbfFE4348c372", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db", "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db" ]
// ["123", "456", "789", "987", "654", "123", "456", "789"]
// 0x67243482 <- function selectore 0x00
// 0000000000000000000000000000000000000000000000000000000000000040 0x04 <- where the data about the address array starts 0x40
// 0000000000000000000000000000000000000000000000000000000000000160 0x24 <- where the data about the amounts array starts 0x160
// 0000000000000000000000000000000000000000000000000000000000000008 0x44 <- the length of the address array
// 000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2 0x64 <- address 0
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db 0x84 <- address 1
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db 0xa4 <- address 2
// 00000000000000000000000078731d3ca6b7e34ac0f824c42a7cc18a495cabab 0xc4 <- address 3
// 00000000000000000000000017f6ad8ef982297579c203069c1dbffe4348c372 0xe4 <- address 4
// 000000000000000000000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb2 0x104 <- address 5
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db 0x124 <- address 6
// 0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db 0x144 <- address 7
// 0000000000000000000000000000000000000000000000000000000000000008 0x164 <- the length of the array address
// 000000000000000000000000000000000000000000000000000000000000007b 0x184 <- amount 0
// 00000000000000000000000000000000000000000000000000000000000001c8 0x1a4 <- amount 1
// 0000000000000000000000000000000000000000000000000000000000000315 0x1c4 <- amount 2
// 00000000000000000000000000000000000000000000000000000000000003db 0x1e4 <- amount 3
// 000000000000000000000000000000000000000000000000000000000000028e 0x204 <- amount 4
// 000000000000000000000000000000000000000000000000000000000000007b 0x224 <- amount 5
// 00000000000000000000000000000000000000000000000000000000000001c8 0x244 <- amount 6
// 0000000000000000000000000000000000000000000000000000000000000315 0x264 <- amount 7
