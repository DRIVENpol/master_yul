//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract IsMax {
    function isMax(uint256 x, uint256 y) public pure returns(uint256 p) {
        assembly {
            if lt(x, y) {
                p := y
            }

            if iszero(lt(x, y)) { // There is not 'else' in assembly. To get the negation, you check iszero(condition)
                p := x
            }
        }
    }

    function testMax(uint256 x, uint256 y) public pure returns(uint256) {
        return isMax(x, y);
    } 
}