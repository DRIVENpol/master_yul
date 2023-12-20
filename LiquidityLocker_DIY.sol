// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @note Liquidity Locker / ERC20 Token Locker Created for Rev3al
* @author Paul Socarde
*/                                     

contract Rev3al_Locker {
    /**
     * 'paused' and 'owner' can be packed in a single slot
     * (uint64 + address = 64 + 160 = 224 bits = 28 bytes) out of 32.
     */
    uint64 private paused; // Slot v | 1 = paused AND 2 = unpaused
    address private owner; // Slot v

    address private pendingOwner; // Slot w;

    /** Lock Fee
     * lockFee (uint128) can be packed with lockId (uint128) in a single slot (uint256)
     */
    uint128 private lockFee; // Slot x | Max value: uint128(-1) = 340282366920938463463374607431768211455 = 340,282,366,920,938,463,463 eth
    uint128 private lockId; // Slot x  | Max value: uint128(-1) = 340282366920938463463374607431768211455 = 340,282,366,920,938,463,463 eth

    struct LockInfo {
        /**
         * 'lockTime' and 'token' can be packed in a single slot
         * (uint64 + address = 64 + 160 = 224 bits = 28 bytes) out of 32.
         */
        address token; // Slot y
        uint64 lockTime; // Slot y

        /**
         * 'amount' and 'locked' can be packed in a single slot
         * (uint128 + uint128 = 128 + 128 = 256 bits = 32 bytes) out of 32.
         */
        uint128 amount; // Slot z | Max value: uint128(-1) = 340282366920938463463374607431768211455 = 340,282,366,920,938,463,463 eth
        uint128 locked; // Slot z | 1 - Locked AND 0 - Unlocked | Max value: uint128(-1) = 340282366920938463463374607431768211455 = 340,282,366,920,938,463,463 eth

        address owner; // 160 bits = 20 bytes
    }

    /**
     * Id => LockInfo
     * We don't use an array here to avoid length checks.
     */
    mapping(uint128 => LockInfo) public locks;

    /** User => local id */
    mapping(address => uint128) public userId;

    /** Token => local id */
    mapping(address => uint128) public tokenId;

    /** User => local id => token lock */
    mapping(address => mapping(uint128 => uint128)) public userLock;

    /** Token => local id => token lock */
    mapping(address => mapping(uint128 => uint128)) public tokenLock;

    /** Token => total locked for token */
    mapping(address => uint128) public totalLocked;

    /** EMERGENCY WITHDRAWAL 
     * Users requiring early token withdrawal can notify the contract.
     * Proof of their community announcement regarding the intent to withdraw off-chain is mandatory.
     * Upon contract notification, we will initiate the transfer of locked tokens to their address.
     */
    mapping(uint128 => uint8) public pinged;

    /** Events */
    event Pinged(uint128 indexed lockId);
    event SetPendingAdmin(address indexed admin);
    event LockFeeChanged(uint128 indexed newLockFee);
    event Unlock(uint128 indexed lockId, address indexed token, uint128 amount);
    event NewLock(address indexed owner, uint128 indexed lockId, address indexed token, uint128 amount, uint64 lockTime);

    /** Errors */
    error NotOwner();
    error FeeNotPaid();
    error CantUnlock();
    error OutOfRange();
    error InvalidAmount();
    error InvalidAddress();
    error ContractPaused();
    error NotPendingOwner();
    error InvalidLockTime();

    /** Modifiers */
    modifier onlyOwner() {
        // if(msg.sender != owner) revert NotOwner();
        address _owner = readOwner();

        assembly {
            if iszero(eq(caller(), _owner)) {
                revert (0,0)
            }
        }
        
        _;
    }

    modifier isPaused() {
        // if(paused == 1) revert ContractPaused();
        uint64 _paused = readPaused();

        assembly {
            if eq(_paused, 1) {
                revert(0, 0)
            }
        }

        _;
    }

    /** Constructor 
     * @dev We make the constructor payable to reduce the gas fees;
     */
    constructor() payable {
        _isValidAddress(msg.sender);

        owner = msg.sender;

        lockFee = 1;
        paused = 2; // Unpaused
    }

    /** Receive function */
    receive() external payable {}

    /** Owner Functions */
    // function transferOwnership(address _pendingOwner) external payable onlyOwner {
    //     _isValidAddress(_pendingOwner);
    //     pendingOwner = _pendingOwner;

    //     emit SetPendingAdmin(_pendingOwner);
    // }

    // function acceptOwnership() external payable {
    //     if(msg.sender != pendingOwner) {
    //         revert NotPendingOwner();
    //     }

    //     owner = pendingOwner;
    //     pendingOwner = address(0);
    // }

    function changeLockFee(uint128 _lockFee) external payable onlyOwner {
        lockFee = _lockFee;

        emit LockFeeChanged(_lockFee);
    }

    function pause() external payable onlyOwner {
        paused = 1; // Paused
    }

    function unpause() external payable onlyOwner {
        paused = 2; // Unpaused
    }

    // function withdrawERC20(address token) external payable onlyOwner {
    //     // Check token balance
    //     uint256 _balance = IERC20(token).balanceOf(address(this));

    //     // If token balanace > total locked, we can withdraw
    //     uint256 _delta = _balance - uint256(totalLocked[token]);

    //     if(_delta == 0) {
    //         revert InvalidAmount();
    //     }

    //     // The owner can withdraw only the extra amount of any ERC20 token OR 
    //     // any ERC20 token that was sent by mistake to the smart contract
    //     safeTransfer(token, msg.sender, _delta);
    // }

    // 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2

    function withdrawFromPinged(uint128 _lockId, address _receiver) external payable onlyOwner {
        if(_lockId >= lockId) {
            revert OutOfRange();
        }

        if(pinged[_lockId] == 0) {
            revert CantUnlock();
        }

        pinged[_lockId] = 1;

        LockInfo storage _lock = locks[_lockId];

        if(_lock.locked != 1) {
            revert CantUnlock();
        }

        if(_lock.amount == 0) {
            revert CantUnlock();
        }

        uint128 _amount = _lock.amount;

        _lock.amount = 0;
        _lock.locked = 2;

        safeTransfer(_lock.token, _receiver, _amount);

        unchecked {
            totalLocked[_lock.token] -= _amount;
        }

        emit Unlock(lockId, _lock.token, _amount);
    }

    function withdrawFees() external onlyOwner {
        safeTransferAllETH(owner);
    }

    /** User functions */
    function lock(uint64 daysToLock) external payable isPaused {
        // if(msg.value != lockFee) {
        //     revert("FeeNotPaid");
        // }

        // _isValidAddress(address(token));

        // if(daysToLock < 1) {
        //     revert InvalidLockTime();
        // }

        // if(daysToLock > 1825) { // 1825 days = 5 years | To avoid overflows
        //     revert InvalidLockTime();
        // }

        // if(amount == 0) {
        //     revert InvalidAmount();
        // }

        // // Check balance before
        // uint256 _balanceBefore = IERC20(token).balanceOf(address(this));

        // safeTransferFrom(token, msg.sender, address(this), amount);

        // // Check balance after
        // uint256 _balanceAfter = IERC20(token).balanceOf(address(this));

        // // Compute the delta to support tokens wiht transfer fees
        // uint256 _delta = _balanceAfter - _balanceBefore;

        // // Check if delta <= type(uint64).max | To avoid overflows
        // if(_delta > type(uint128).max) {
        //     revert InvalidAmount();
        // }

        // // Check if delta > 0 | To avoid zero value locks
        // if(_delta == 0) {
        //     revert InvalidAmount();
        // }

        // // Check if we can compute total tokens locked safely
        // if(uint256(totalLocked[address(token)]) + _delta > type(uint128).max) {
        //     revert InvalidAmount();
        // }

        address token = 0x5A86858aA3b595FD6663c2296741eF4cd8BC4d01;

        LockInfo memory newLock = LockInfo({
            token: msg.sender,
            lockTime: uint64(block.timestamp + (daysToLock * 1 days)),
            amount: 10 ** 18,
            locked: 1,
            owner: msg.sender
        });

        locks[lockId] = newLock;
        userLock[msg.sender][userId[msg.sender]] = lockId;
        tokenLock[address(token)][tokenId[address(token)]] = lockId;

        unchecked {
            ++lockId;
            ++userId[msg.sender];
            ++tokenId[address(token)];

            totalLocked[msg.sender] += 10 ** 18;
        }

        emit NewLock(msg.sender, lockId - 1, msg.sender, 10 ** 18, uint64(block.timestamp + (daysToLock * 1 days)));
    }

    function unlock(uint128 _lockId) external payable isPaused {
        if(_lockId >= lockId) {
            revert OutOfRange();
        }

        LockInfo storage _lock = locks[_lockId];

        if(_lock.locked != 1) {
            revert CantUnlock();
        }

        if(_lock.owner != msg.sender) {
            revert CantUnlock();
        }

        if(_lock.lockTime < uint64(block.timestamp)) {
            revert CantUnlock();
        }

        if(_lock.amount == 0) {
            revert CantUnlock();
        }

        uint128 _amount = _lock.amount;

        _lock.amount = 0;
        _lock.locked = 0;

        safeTransfer(_lock.token, msg.sender, _amount);

        unchecked {
            totalLocked[_lock.token] -= _amount;
        }

        emit Unlock(lockId, _lock.token, _amount);
    }

    function pingContract(uint128 _lockId) external payable {
        if(_lockId >= lockId) {
            revert OutOfRange();
        }

        // We read from storag instead of memory because it's cheaper
        // Read from storage => direct read
        // Read from memory => read from storage + copy to memory
        LockInfo storage _lock = locks[_lockId];

        if(_lock.owner != msg.sender) {
            revert NotOwner();
        }

        pinged[lockId] = 1;

        emit Pinged(lockId);
    }

    /** Only owner functions */
    function transferOwnership(address _newOwner) external payable onlyOwner {
        _isValidAddress(_newOwner);

        assembly {
            sstore(pendingOwner.slot, _newOwner)
        }
    }

    function acceptOwnership() external payable {
        address _zero = address(0);

        assembly {
            let _pending := sload(pendingOwner.slot)
            if iszero(eq(caller(), _pending)) {
                revert(0, 0)
            }

            // Get the value of the owner
            let value := sload(owner.slot)

            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002
            // 0xffffffff0000000000000000000000000000000000000000ffffffffffffffff

            // We clear the slot
            let mask := 0xffffffff0000000000000000000000000000000000000000ffffffffffffffff
            let clearedOwner := and(value, mask)

            let newShiftedOwner := shl(mul(owner.offset, 8), _pending)

            let newValue := or(newShiftedOwner, clearedOwner)

            sstore(pendingOwner.slot, _zero)
            sstore(owner.slot, newValue)
        }
    }

    /** Public view functions */
    function readPaused() public view returns(uint64 _res) {
        assembly {
            // Get the value from the slot
            let pausedValue := sload(paused.slot)

            // Get the offset
            let pausedOffset := paused.offset

            // Shift right
            let shiftedPaused := shr(mul(pausedOffset, 8), pausedValue)
            // 0x000000005b38da6a701c568545dcfcb03fcb875f56beddc40000000000000002
            // 0x0000000000000000000000000000000000000000000000000000000000000000f <- mask

            let mask := 0xf

            _res := and(mask, shiftedPaused)
        }
    }

    function readOwner() public view returns(address _res) {
        assembly {
            // Get the value from the slot
            let ownerValue := sload(owner.slot)

            // Get the offset
            let ownerOffset := owner.offset

            // Shift right
            let shiftedOwner := shr(mul(ownerOffset, 8), ownerValue)
            // 0x0000000000000000000000005b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff <- mask

            let mask := 0xffffffffffffffffffffffffffffffffffffffff

            _res := and(mask, shiftedOwner)
        }
    }

    function readPendingOwner() public view returns(address _res) {
        assembly {
            _res := sload(pendingOwner.slot)
        }
    }

    function readLockFee() public view returns(uint128 _res) {
        assembly {
            // Get the value from the slot
            let lockFeeValue := sload(lockFee.slot)

            // Get the offset
            let lockFeeOffset := lockFee.offset

            // Shift right
            let shiftedLockFee := shr(mul(lockFeeOffset, 8), lockFeeValue)
            // 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff (max)
            // 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff <- mask

            let mask := 0xffffffffffffffffffffffffffffffff

            _res := and(mask, shiftedLockFee)
        }
    }

    function readLockId() public view returns(uint128 _res) {
        assembly {
            // Get the value from the slot
            let lockIdValue := sload(lockId.slot)

            // Get the offset
            let lockIdOffset := lockId.offset

            // Shift right
            let shiftedLockId := shr(mul(lockIdOffset, 8), lockIdValue)
            // 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
            // 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000 <- mask


            let mask := 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000

            _res := and(mask, shiftedLockId)
        }
    }

    function readLockAtIndex(uint128 index) public view returns(
        address token,
        uint64 lockTime,
        uint128 amount,
        uint128 locked,
        address theOwner
    ) {
            // The slot of the mapping
        uint256 slot;
        assembly {
            slot := locks.slot
        }

        // Get the location
        bytes32 location = keccak256(abi.encode(index, slot));

        assembly {
            // Slot 0
            // 0x00000000000000006591f35c 5b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000 ffffffffffffffffffffffffffffffffffffffff
            let slot0 := sload(location)
            token := and(0xffffffffffffffffffffffffffffffffffffffff, slot0)
            lockTime := shr(mul(20, 8), slot0)

            // Slot 1
            // 0x00000000000000000000000000000001 00000000000000000de0b6b3a7640000
            // 0x00000000000000000000000000000000 ffffffffffffffffffffffffffffffff
            // 0xffffffffffffffffffffffffffffffff 00000000000000000000000000000000
            let slot1 := sload(add(location, 1))
            amount := and(0xffffffffffffffffffffffffffffffff, slot1)
            locked := shr(mul(16, 8), slot1)

            // Slot 2
            // 0x000000000000000000000000 5b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000 ffffffffffffffffffffffffffffffffffffffff
            let slot2 := sload(add(location, 2))
            theOwner := and(0xffffffffffffffffffffffffffffffffffffffff, slot2)
        }
    }

    function readUserId(address user) public view returns(uint128 _id) {
        uint256 slot;

        assembly {
            slot := userId.slot
        }

        bytes32 location = keccak256(abi.encode(user, slot));

        assembly {
            _id := sload(location)
        }
    }

    function readTokenId(address token) public view returns(uint128 _id) {
        uint256 slot;

        assembly {
            slot := tokenId.slot
        }

        bytes32 location = keccak256(abi.encode(token, slot));

        assembly {
            _id := sload(location)
        }
    }

    function readTotalLocked(address token) public view returns(uint128 _id) {
        uint256 slot;

        assembly {
            slot := totalLocked.slot
        }

        bytes32 location = keccak256(abi.encode(token, slot));

        assembly {
            _id := sload(location)
        }
    }

    function readPinged(address token) public view returns(uint8 _pinged) {
        uint256 slot;

        assembly {
            slot := pinged.slot
        }

        bytes32 location = keccak256(abi.encode(token, slot));

        assembly {
            _pinged := sload(location)
        }
    }

    function getUserLock(address user, uint128 localId) public view returns(uint128 _userLock) {
        uint256 slot;

        assembly {
            slot := userLock.slot
        }

        bytes32 location = keccak256(
            abi.encode(
                localId,
                keccak256(abi.encode(user, slot))
            )
        );

        assembly {
            _userLock := sload(location)
        }
    }

    function getTokenLock(address token, uint128 localId) public view returns(uint128 _tokenLock) {
        uint256 slot;

        assembly {
            slot := tokenLock.slot
        }

        bytes32 location = keccak256(
            abi.encode(
                localId,
                keccak256(abi.encode(token, slot))
            )
        );

        assembly {
            _tokenLock := sload(location)
        }
    }    

    /** Internal functions */

    /**
    * IMPORTED FROM: https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol
    * NO ADDITIONAL EDITS HAVE BEEN MADE
    */
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            mstore(0x0c, 0x23b872dd000000000000000000000000) // `transferFrom(address,address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424) // `TransferFromFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /**
    * IMPORTED FROM: https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol
    * NO ADDITIONAL EDITS HAVE BEEN MADE
    */
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            mstore(0x00, 0xa9059cbb000000000000000000000000) // `transfer(address,uint256)`.
            // Perform the transfer, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    or(eq(mload(0x00), 1), iszero(returndatasize())), // Returned 1 or nothing.
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x34, 0) // Restore the part of the free memory pointer that was overwritten.
        }
    }

    /**
    * IMPORTED FROM: https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol
    * NO ADDITIONAL EDITS HAVE BEEN MADE
    */
    /// @dev Sends all the ETH in the current contract to `to`.
    function safeTransferAllETH(address to) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer all the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, selfbalance(), codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    function _isValidAddress(address wallet) internal pure returns(bool _status) {
        address _zero = address(0);
        address _dead = address(0xdead);

        _status = true;

        assembly {
            if eq(wallet, _zero) {
                _status := false
            }

            if eq(wallet, _dead) {
                _status := false
            }
        }
    }
}
