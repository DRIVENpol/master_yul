//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract IsPrime {
    function isPrime(uint256 x) public pure returns(bool p) {
        p = true;

        assembly {
            // halfX := x / 2 + 1
            let halfX := add(div(x, 2), 1)

            // for(uint256 i = 2; i < halfX; i++)
            for { let i := 2} lt(i, halfX) { i := add(i, 1)} 
            {
                // if(x % i == 0) {
                if iszero(mod(x, i)) {

                    // p = 0 which is false ecause we declared p as bool
                    p := 0
                    break
                }
            }


        }
    }

    function testPrime(uint256 x) public pure returns(bool) {
        return isPrime(x);
    } 
}