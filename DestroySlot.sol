//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract SameSlot {
    bytes32 public slot0;
    bytes32 public slot1;
    
    // Params: 
    // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
    // 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    // 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
    // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,1,1,1,1

    // Gas
    // transaction cost	69933 gas (- 22246)
    // execution cost	47205 gas
    function ThreeAddresses_TwoBool_TwoSlots(
        address _addr1,
        address _addr2,
        address _addr3,
        uint8 _value1,
        uint8 _value2,
        uint8 _value3,
        uint8 _value4
    ) external {
        // Slot 1
        // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 Ab8483F64d9C6d1EcF9b849A
        // <----------------------------------------> <---------------------->
        //                 Address 1                 12 bytes of Address 2

        // Slot 2
        // 0xe677dD3315835cb2 0000000000000000000000000000000000000000 00000000
        // <----------------> <--------------------------------------> <------>
        //         x                            y                          z  
        // x = last 8 bytes of address 2
        // y = address 3
        // z = uint32 (4 x uint8)
        assembly {
            let _slot0 := slot0.slot
            let _slot1 := slot1.slot

            sstore(_slot0, shl(mul(12, 8), _addr1))
            
            // We get the first 12 bytes of '_addr2' and append it to slot 0
            sstore(_slot0, or(shr(mul(8, 8), _addr2), sload(_slot0)))
            // Slot 0: 0x5b38da6a701c568545dcfcb03fcb875f56beddc4 ab8483f64d9c6d1ecf9b849a

            // We get the last 8 bytes of '_addr2' and append it to slot 1
            // 0x000000000000000000000000Ab8483F64d9C6d1EcF9b849A e677dD3315835cb2
            sstore(_slot1, shl(mul(24, 8), _addr2))

            // We store the whole '_addr3' into slot 2
            sstore(_slot1, or(shl(mul(4, 8), _addr3), sload(_slot1)))
            // Slot 1: -> 0xe677dd3315835cb2 4b20993bc481177ec7e8f571cecae8a9e22c02db 00000000

            // Store '_value1' in slot 1
            sstore(_slot1, or(shl(mul(3, 8), _value1), sload(_slot1)))

            // Store '_value2' in slot 1
            sstore(_slot1, or(shl(mul(2, 8), _value2), sload(_slot1)))

            // Store '_value2' in slot 1
            sstore(_slot1, or(shl(mul(1, 8), _value3), sload(_slot1)))

            // Store '_value4' in slot 1
            sstore(_slot1, or(_value4, sload(_slot1)))
            
            // Slot 1 -> 0xe677dd3315835cb2 4b20993bc481177ec7e8f571cecae8a9e22c02db 01 02 03 04
        }
    }

    function getAddress1() external view returns(address _res) {
        assembly {
            _res := shr(mul(12, 8), sload(slot0.slot))
        }
    }

    function getAddress2() external view returns(address _res) {
        assembly {
            let _firstPart := shl(mul(20, 8), sload(slot0.slot))
            // 0xab8483f64d9c6d1ecf9b849a0000000000000000000000000000000000000000

            let _secondPart := shr(mul(8, 8), sload(slot1.slot))
            // 0x0000000000000000e677dd3315835cb2 4b20993bc481177ec7e8f571cecae8a9

            let _clearedSecondPart := shr(mul(16, 8), _secondPart)
            // 0x000000000000000000000000000000000000000000000000 e677dd3315835cb2

            // 0xab8483f64d9c6d1ecf9b849a0000000000000000000000000000000000000000 <- 1st part
            // 0x000000000000000000000000000000000000000000000000e677dd3315835cb2 <- 2nd part
            let _firstPartShifted := shr(mul(12, 8), _firstPart)
            // 0x00000000000000000000000000000000ab8483f64d9c6d1ecf9b849a00000000

            _res := or(_clearedSecondPart, _firstPartShifted)
        }
    }

    function getAddress3() external view returns(address _res) {
        assembly {
            // 0xe677dd3315835cb2 4b20993bc481177ec7e8f571cecae8a9e22c02db 01 02 03 04 <- Slot 1
            let _value := sload(slot1.slot)

            let _shiftedLeft := shl(mul(8, 8), _value)
            // 0x4b20993bc481177ec7e8f571cecae8a9e22c02db010101010000000000000000

            let _shiftRight := shr(mul(12, 8), _shiftedLeft)
            // 0x0000000000000000000000004b20993bc481177ec7e8f571cecae8a9e22c02db
            
            _res := _shiftRight
        }
    }
}

contract SameSlot2 {
    address public addr1;
    address public addr2;
    address public addr3;

    uint8 public value1;
    uint8 public value2;
    uint8 public value3;
    uint8 public value4;
    
    // Params: 
    // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
    // 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    // 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
    // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,1,1,1,1

    // Gas
    // transaction cost	92179 gas 
    // execution cost	69451 gas
    function ThreeAddresses_TwoBool_TwoSlots(
        address _addr1,
        address _addr2,
        address _addr3,
        uint8 _value1,
        uint8 _value2,
        uint8 _value3,
        uint8 _value4
    ) external {
        addr1 = _addr1;
        addr2 = _addr2;
        addr3 = _addr3;

        value1 = _value1;
        value2 = _value2;
        value3 = _value3;
        value4 = _value4;
    }
}