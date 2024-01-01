// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
  uint256 public value;

  function setMax() external {
    // transaction cost	  43298 gas 
    // execution cost	    22234 gas
    value = type(uint256).max;
  }
}

contract Vault2 {
  uint256 public value;

  // transaction cost	  43298 gas 
  // execution cost	    22234 gas
  function setMax() external {
    value = 2 ** 256 - 1;
  }
}

contract Vault3 {
  uint256 public value;

  // transaction cost	43300 gas 
  // execution cost	22236 gas
  function setMax() external {
    value = ~uint256(0);
  }
}

contract Vault4 {
  uint256 public value;
  uint256 public constant MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

  // transaction cost	  43298 gas 
  // execution cost	    22234 gas
  function setMax() external {
    value = MAX;
  }
}

contract Vault5 {
  uint256 public value;

  // transaction cost	  43292 gas 
  // execution cost	    22228 gas
  function setMax() external {
    assembly {
      sstore(value.slot, not(0))
    }
  }
}