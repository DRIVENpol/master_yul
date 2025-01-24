// This Locker : lock function
// transaction cost	130484 gas 
// execution cost	113572 gas

// Classic Locker : lock function
// transaction cost	215686 gas 
// execution cost	201574 gas

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @note Liquidity Locker / ERC20 Token Locker
* @author Paul Socarde
*/                                     

contract Locker {
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


    /** User functions */
    function lock(address token, uint128 amount, uint64 daysToLock) external payable {
        require(_isValidAddress(token), "Invalid Address!");

        assembly {
            let _lf := and(0xffffffffffffffffffffffffffffffff, shr(mul(lockFee.offset, 8), sload(lockFee.slot)))

            // If msg.value != lockFee, we revert
            if iszero(eq(callvalue(), _lf)) {
                revert(0, 0)
            }

            if lt(daysToLock, 1) {
                revert(0, 0)
            }

            if gt(daysToLock, 1825) {
                revert(0, 0)
            }

            if eq(amount, 0) {
                revert(0, 0)
            }

            mstore(0x00, hex'70a08231')
            mstore(0x04, address())

            if iszero(staticcall(gas(), token, 0x00, 0x24, 0x24, 0x44)) {
                revert(0, 0)
            }

            let _bBefore := mload(0x24)

            mstore(0x44, hex'23b872dd')
            mstore(0x48, caller())
            mstore(0x68, mload(0x04))
            mstore(0x88, amount)

            if iszero(call(gas(), token, 0, 0x44, 0xa8, 0, 0)) {
                revert(0, 0)
            }

            if iszero(staticcall(gas(), token, 0x00, 0x24, 0x24, 0x44)) {
                revert(0, 0)
            }

            let _bAfter := mload(0x24)

            // _balanceAfter should be greater than _balanceBefore
            if lt(_bAfter, _bBefore) {
                revert(0, 0)
            }

            let delta := sub(_bAfter, _bBefore)

            // delta should be greater than 0
            if eq(delta, 0) {
                revert(0, 0)
            }

            // Get the lock Id (next lock)
            mstore(0x00, and(shr(mul(lockId.offset, 8), sload(lockId.slot)), 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000))
            mstore(0x20, locks.slot)
            mstore(0x40, keccak256(0x00, 0x40))

            // Write the new token to the empty slot
            let newToken := token
            sstore(mload(0x40), newToken)

            // Get the location of the struct (which is have only the address)
            let slot0 := sload(mload(0x40))
            // 0x00000000000000006591f35c 5b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000 ffffffffffffffffffffffffffffffffffffffff

            let shiftedEndDate := shl(mul(20, 8), add(timestamp(), mul(daysToLock, 86400)))

            let newValue := or(shiftedEndDate, slot0)
            sstore(mload(0x40), newValue)

            // Go to the next slot and modify the amount and locked variable
            // Both 128 bits
            // 0x00000000000000000000000000000000 00000000000000000000000000000000 <- empty slot
            // 0x00000000000000000000000000000001 00000000000000000000000000000000 <- we add 'locked' which is 0 or 1
            // 0x00000000000000000000000000000000 00000000000000000000000000000020 <- we add the amount
            // The result
            // 0x00000000000000000000000000000001 00000000000000000000000000000020
            let slot1 := sload(add(mload(0x40), 1))
            // Locked: 0x0000000000000000000000000000000100000000000000000000000000000000
            let newValueSlot1 := or(0x0000000000000000000000000000000100000000000000000000000000000000, delta)

            sstore(add(mload(0x40), 1), newValueSlot1)
            sstore(add(mload(0x40), 2), caller())

            // userLock[msg.sender][userId[msg.sender]] = lockId;
            // Read userId of msg.sender
            mstore(0x00, caller())
            mstore(0x20, userId.slot)
            // userId[msg.sender] location
            let userIdLocation := keccak256(0x00, 0x40)

            mstore(0x20, userLock.slot)
            let hash1 := keccak256(0x00, 0x40)

            mstore(0x40, userIdLocation)
            mstore(0x60, hash1)
            let location := keccak256(0x40, 0x40)

            sstore(location, add(sload(location), 1))
            //     tokenLock[address(token)][tokenId[address(token)]] = lockId;

            // unchecked {
            //   ++lockId;
            // }
            sstore(lockId.slot, or(shl(mul(lockId.offset, 8), add(shr(mul(lockId.offset, 8), sload(lockId.slot)), 1)), and(sload(lockId.slot), 0xffffffffffffffffffffffffffffffff)))

            //         ++userId[msg.sender];
            //         ++tokenId[address(token)];

            //         totalLocked[address(token)] += uint128(_delta);
            //     }
        }
    }

    function unlock(uint128 _lockId) external payable isPaused {
        assembly {
            // 1) Read the current lockId from storage.
            let currentLockId := shr(mul(lockId.offset, 8), sload(lockId.slot))
            // if(_lockId >= lockId) revert OutOfRange();
            if iszero(lt(_lockId, currentLockId)) {
                // revert(0, 0) => OutOfRange();
                revert(0, 0)
            }
    
            // 2) Compute where LockInfo is stored: locks[_lockId].
            //    That structure spans 3 slots: (slot0 => token + lockTime), (slot1 => amount + locked), (slot2 => owner).
            mstore(0x80, _lockId)
            mstore(0xa0, locks.slot)
            // keccak256(_lockId, locks.slot)
            let structSlot := keccak256(0x80, 0x40)
    
            // 3) Load slot0 => [ upper 64 bits = lockTime | lower 160 bits = token ]
            let slot0 := sload(structSlot)
            // Extract token address (lowest 160 bits).
            let tokenAddress := and(slot0, 0xffffffffffffffffffffffffffffffffffffffff)
            // Extract lockTime (upper 64 bits).
            let lockTime := shr(160, slot0)
    
            // 4) Load slot1 => [ upper 128 bits = locked | lower 128 bits = amount ]
            let slot1 := sload(add(structSlot, 1))
            // amount = lower 128 bits
            let amount := and(slot1, 0xffffffffffffffffffffffffffffffff)
            // locked = upper 128 bits
            let locked := shr(128, slot1)
    
            // 5) Load slot2 => [ owner in lower 160 bits ]
            let slot2 := sload(add(structSlot, 2))
            let lockOwner := and(slot2, 0xffffffffffffffffffffffffffffffffffffffff)
    
            // 6) Replicate your Solidity checks:
            // if(_lock.locked != 1) revert CantUnlock();
            if iszero(eq(locked, 1)) {
                revert(0, 0)
            }
            // if(_lock.owner != msg.sender) revert CantUnlock();
            if iszero(eq(lockOwner, caller())) {
                revert(0, 0)
            }
            // if(_lock.lockTime < uint64(block.timestamp)) revert CantUnlock();
            // (Note this means you CANNOT unlock if lockTime is already in the past.)
            if lt(lockTime, timestamp()) {
                revert(0, 0)
            }
            // if(_lock.amount == 0) revert CantUnlock();
            if iszero(amount) {
                revert(0, 0)
            }
    
            // 7) Zero out slot1 so that `amount=0` and `locked=0`.
            sstore(add(structSlot, 1), 0)
    
            // 8) Transfer the tokens to `msg.sender`.
            //    We'll manually inline a minimal `safeTransfer` call.
            //    function signature: transfer(address,uint256) => 0xa9059cbb
            //    Layout in memory for the call:
            //       0x00: 4-byte signature, plus 28 zero bytes
            //       0x04: to (address)
            //       0x24: amount (uint256)
            mstore(0x00, 0xa9059cbb000000000000000000000000)
            mstore(0x04, caller())
            mstore(0x24, amount)
            let success := call(gas(), tokenAddress, 0, 0x00, 0x44, 0x00, 0x20)
            // Check return data to see if it returned true or had no return (standard)
            if iszero(
                and(
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    success
                )
            ) {
                mstore(0x00, 0x90b8ec18) // `TransferFailed()`
                revert(0x1c, 0x04)
            }
    
            // 9) totalLocked[token] -= amount
            //    We'll load totalLocked[token], subtract, then store.
            mstore(0x80, tokenAddress)
            mstore(0xa0, totalLocked.slot)
            let totalLockedLocation := keccak256(0x80, 0x40)
            let oldLockedVal := sload(totalLockedLocation)
            let newLockedVal := sub(oldLockedVal, amount)
            sstore(totalLockedLocation, newLockedVal)
    
            // 10) Emit the Unlock event:
            //     event Unlock(uint128 indexed lockId, address indexed token, uint128 amount);
            //     The topic0 = keccak256("Unlock(uint128,address,uint128)")
            //     topic1 = lockId
            //     topic2 = token
            //     data = [ amount (32 bytes) ]
            //
            // keccak256("Unlock(uint128,address,uint128)") = 
            //   0x54437dfd46f29d42d065b354acb49136c32d66bd0fd557eb1c0f978a4f5e3300
            mstore(0xe0, amount)
            log3(
                0xe0,       // data start
                0x20,       // data size (just 1 word for `amount`)
                0x54437dfd46f29d42d065b354acb49136c32d66bd0fd557eb1c0f978a4f5e3300, // event signature
                _lockId,    // topic1
                tokenAddress // topic2
            )
        }
    }


    function pingContract(uint128 _lockId) external payable {
        uint256 _cachedLockId = lockId;

        assembly {
            if gt(_lockId, _cachedLockId) {
                revert(0, 0)
            }

            // Get the details of the struct
            mstore(0x80, _lockId)
            mstore(0xa0, locks.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            // We only care about slot 1 and 2, where 'owner', 'amount' and 'locked' are located
            let slot1 := sload(add(mload(0xc0), 1))
            let amount := and(0xffffffffffffffffffffffffffffffff, slot1)
            let locked := shr(mul(16, 8), slot1)

            // 0x000000000000000000000000 5b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000 ffffffffffffffffffffffffffffffffffffffff
            let slot2 := sload(add(mload(0xc0), 2))
            let theOwner := and(0xffffffffffffffffffffffffffffffffffffffff, slot2)

            if iszero(eq(caller(), theOwner)) {
                revert(0,0)
            }

            if eq(amount, 0) {
                revert(0, 0)
            }

            if eq(locked, 0) {
                revert(0, 0)
            }

            // Read 'pinged' variable
            mstore(0x80, _lockId)
            mstore(0xa0, pinged.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            let _pinged := sload(mload(0xc0))
            // 0x0000000000000000000000000000000000000000000000000000000000000001

            if eq(_pinged, 1) {
                revert(0, 0)
            }

            sstore(mload(0xc0), 0x1)
        }
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

    function changeLockFee(uint128 _lockFee) external payable onlyOwner {
        assembly {
            let value := sload(lockFee.slot)

            // 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff (max)
            // 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff <- mask

            let mask := 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
            let clearedLockFee := and(value, mask)

            let shiftedLockFee := shl(mul(lockFee.offset, 8), _lockFee)

            let newLockFee := or(shiftedLockFee, clearedLockFee)

            sstore(lockFee.slot, newLockFee)
        }
    }

    function pause() external payable onlyOwner {
        assembly {
            let value := sload(paused.slot) 
            // 0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000002
            // 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000

            let mask := 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
            let clearedPause := and(value, mask)

            let shiftedPause := shl(mul(paused.offset, 8), 1)

            let newPaused := or(shiftedPause, clearedPause)

            sstore(paused.slot, newPaused)
        }
    }

    function unpause() external payable onlyOwner {
        assembly {
            let value := sload(paused.slot) 
            // 0x00000000ab8483f64d9c6d1ecf9b849ae677dd3315835cb20000000000000002
            // 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000

            let mask := 0xffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000
            let clearedPause := and(value, mask)

            let shiftedPause := shl(mul(paused.offset, 8), 2)

            let newPaused := or(shiftedPause, clearedPause)

            sstore(paused.slot, newPaused)
        }
    }

    function withdrawFees() external onlyOwner {
        safeTransferAllETH(owner);
    }

    function withdrawFromPinged(uint128 _lockId, address _receiver) external onlyOwner {
        _isValidAddress(_receiver);

        uint128 _cachedLockId = lockId;
        uint8 _cachedPinged = readPinged(_lockId);

        assembly {

            if lt(_cachedLockId, _lockId) {
                revert(0,0)
            }

            if eq(_cachedPinged, 0) {
                revert(0,0)
            }

            // _pingedSlot := pinged.slot

            mstore(0x80, _lockId)
            mstore(0xa0, pinged.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            // pinged[_lockId] = 0
            sstore(mload(0xc0), 0) 

            // Lock slot
            // _lockSlot := locks.slot

            mstore(0xa0, locks.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            // Slot 0 of struct: token & lock time (we need only the token address)
            let slot0 := sload(mload(0xc0))
            // _cachedToken := and(0xffffffffffffffffffffffffffffffffffffffff, slot0)
            mstore(0x80, and(0xffffffffffffffffffffffffffffffffffffffff, slot0))

            // Slot 1 of struct: amount & locked
            let slot1 := sload(add(mload(0xc0), 1))
            let amount := and(0xffffffffffffffffffffffffffffffff, slot1)
            let locked := shr(mul(16, 8), slot1)

            if iszero(eq(locked, 1)) {
                revert(0, 0)
            }

            if eq(amount, 0) {
                revert(0, 0)
            }

            // _cachedAmount := amount
            mstore(0xe0, amount)

            // _lock.amount = 0 && locked = 0
            // 0x00000000000000000000000000000001 00000000000000000de0b6b3a7640000
            // 0x00000000000000000000000000000000 00000000000000000000000000000000
            let newValue := 0x0000000000000000000000000000000000000000000000000000000000000000
            sstore(slot1, newValue)

            // totalLocked[_lock.token] -= _amount;
            // _totalLockedSlot := totalLocked.slot

            mstore(0xa0, totalLocked.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            let _totalAmount := sload(mload(0xc0))
            sstore(mload(0xc0), sub(_totalAmount, mload(0xe0)))
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
            _res := shr(mul(lockId.offset, 8), sload(lockId.slot))
        }
    }

    function readLockAtIndex(uint128 index) public view returns(
        address token,
        uint64 lockTime,
        uint128 amount,
        uint128 locked,
        address theOwner
    ) {
        assembly {
            mstore(0x80, index)
            mstore(0xa0, locks.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            // Slot 0
            // 0x00000000000000006591f35c 5b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000 ffffffffffffffffffffffffffffffffffffffff
            let slot0 := sload(mload(0xc0))
            token := and(0xffffffffffffffffffffffffffffffffffffffff, slot0)
            lockTime := shr(mul(20, 8), slot0)

            // Slot 1
            // 0x00000000000000000000000000000001 00000000000000000de0b6b3a7640000
            // 0x00000000000000000000000000000000 ffffffffffffffffffffffffffffffff
            // 0xffffffffffffffffffffffffffffffff 00000000000000000000000000000000
            let slot1 := sload(add(mload(0xc0), 1))
            amount := and(0xffffffffffffffffffffffffffffffff, slot1)
            locked := shr(mul(16, 8), slot1)

            // Slot 2
            // 0x000000000000000000000000 5b38da6a701c568545dcfcb03fcb875f56beddc4
            // 0x000000000000000000000000 ffffffffffffffffffffffffffffffffffffffff
            let slot2 := sload(add(mload(0xc0), 2))
            theOwner := and(0xffffffffffffffffffffffffffffffffffffffff, slot2)
        }
    }

    function readUserId(address user) public view returns(uint128 _id) {
        assembly {
            mstore(0x80, user)
            mstore(0xa0, userId.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            _id := sload(mload(0xc0))
        }       
    }

    function readTokenId(address token) public view returns(uint128 _id) {
        assembly {
            mstore(0x80, token)
            mstore(0xa0, tokenId.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            _id := sload(mload(0xc0))
        }       
    }

    function readTotalLocked(address token) public view returns(uint128 _amount) {
        assembly {
            mstore(0x80, token)
            mstore(0xa0, totalLocked.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            _amount := sload(mload(0xc0))
        }
    }

    function readPinged(uint128 deposit) public view returns(uint8 _pinged) {
        assembly {
            mstore(0x80, deposit)
            mstore(0xa0, pinged.slot)
            mstore(0xc0, keccak256(0x80, 0x40))

            _pinged := sload(mload(0xc0))
        }
    }

    function getUserLock(address user, uint128 localId) public view returns(uint128 _userLock) {
        assembly {
            mstore(0x80, user)
            mstore(0xa0, userLock.slot)
            let hash1 := keccak256(0x80, 0x40) // Hash of user and userLock.slot

            mstore(0x80, localId)
            mstore(0xa0, hash1)
            let location := keccak256(0x80, 0x40) // Hash of localId and hash1

            _userLock := sload(location)
        }

    }

    function getTokenLock(address token, uint128 localId) public view returns(uint128 _tokenLock) {
        assembly {
            mstore(0x80, token)
            mstore(0xa0, tokenLock.slot)

            let hash1 := keccak256(0x80, 0x40)

            mstore(0x80, localId)
            mstore(0xa0, hash1)

            let hash2 := keccak256(0x80, 0x40)

            _tokenLock := sload(hash2)
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
