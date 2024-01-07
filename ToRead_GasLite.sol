pragma solidity 0.8.19;

/**
                                                                                                                   
                                                          bbbbbbbb                                         dddddddd
                                                          b::::::b                                         d::::::d
                                                          b::::::b                                         d::::::d
                                                          b::::::b                                         d::::::d
                                                           b:::::b                                         d:::::d 
   ggggggggg   ggggg aaaaaaaaaaaaa      ssssssssss         b:::::bbbbbbbbb      aaaaaaaaaaaaa      ddddddddd:::::d 
  g:::::::::ggg::::g a::::::::::::a   ss::::::::::s        b::::::::::::::bb    a::::::::::::a   dd::::::::::::::d 
 g:::::::::::::::::g aaaaaaaaa:::::ass:::::::::::::s       b::::::::::::::::b   aaaaaaaaa:::::a d::::::::::::::::d 
g::::::ggggg::::::gg          a::::as::::::ssss:::::s      b:::::bbbbb:::::::b           a::::ad:::::::ddddd:::::d 
g:::::g     g:::::g    aaaaaaa:::::a s:::::s  ssssss       b:::::b    b::::::b    aaaaaaa:::::ad::::::d    d:::::d 
g:::::g     g:::::g  aa::::::::::::a   s::::::s            b:::::b     b:::::b  aa::::::::::::ad:::::d     d:::::d 
g:::::g     g:::::g a::::aaaa::::::a      s::::::s         b:::::b     b:::::b a::::aaaa::::::ad:::::d     d:::::d 
g::::::g    g:::::ga::::a    a:::::assssss   s:::::s       b:::::b     b:::::ba::::a    a:::::ad:::::d     d:::::d 
g:::::::ggggg:::::ga::::a    a:::::as:::::ssss::::::s      b:::::bbbbbb::::::ba::::a    a:::::ad::::::ddddd::::::dd
 g::::::::::::::::ga:::::aaaa::::::as::::::::::::::s       b::::::::::::::::b a:::::aaaa::::::a d:::::::::::::::::d
  gg::::::::::::::g a::::::::::aa:::as:::::::::::ss        b:::::::::::::::b   a::::::::::aa:::a d:::::::::ddd::::d
    gggggggg::::::g  aaaaaaaaaa  aaaa sssssssssss          bbbbbbbbbbbbbbbb     aaaaaaaaaa  aaaa  ddddddddd   ddddd
            g:::::g                                                                                                
gggggg      g:::::g                                                                                                
g:::::gg   gg:::::g                                                                                                
 g::::::ggg:::::::g                                                                                                
  gg:::::::::::::g                                                                                                 
    ggg::::::ggg                                                                                                   
       gggggg                                                                                                      
 */

/**
 * @title GasliteDrop
 * @notice Turbo gas optimized bulk transfers of ERC20, ERC721, and ETH
 * @author Harrison (@PopPunkOnChain)
 * @author Gaslite (@GasliteGG)
 * @author Pop Punk LLC (@PopPunkLLC)
 */
contract GasliteDrop {

    // @article: Function to airdrop ERC721 tokens
    // @article _nft - the NFT collection address
    // @article _addresses - the array of addresses to airdrop to  
    // @article _tokenIds - the array of nft ids to airdrop
    function airdropERC721(
        address _nft, 
        address[] calldata _addresses, 
        uint256[] calldata _tokenIds
    ) external payable {
        assembly {
            // @article Check that the number of addresses matches the number of tokenIds
            // If not, revert
            if iszero(eq(_tokenIds.length, _addresses.length)) {
                revert(0, 0)
            }
            // @article We store the function selector at memory location 0x00
            // @article This will take only the first 4 bytes of the hash of the function signature
            // @article The function selector can be computed like so in Soilidity:
            // @article bytes4(keccak256("transferFrom(address,address,uint256)"))
            // transferFrom(address from, address to, uint256 tokenId)
            mstore(0x00, hex"23b872dd")
            
            // @article We store the caller address (msg.sender) on the memory at 0x04
            // @article Because the address is 20 bytes, the next free memory slot is 0x24
            mstore(0x04, caller())

            // @article In order to find the end of the array, we need to know the offset of the array (which is _addresses.offset)
            // @article shl(5, _addresses.length) is equivalent to _addresses.length * (2 ** 5) = _addresses.length * 32: An address will take 32 bytes (one full slot) 
            // @article So the end of the array is: the start of the array + the number of addresses * 32
            // @article This can be computed as well as let end := sub(amounts.offset, 0x20) but will cost more gas 
            
            // sub(amounts.offset, 0x20)
            // transaction cost	68397 gas 
            // execution cost	45249 gas

            // add(addresses.offset, shl(5, addresses.length))
            // transaction cost	68403 gas 
            // execution cost	45255 gas
            let end := add(_addresses.offset, shl(5, _addresses.length))
            // diff = _addresses.offset - _tokenIds.offset

            // @article Now, in order to find the distance from an element in the array A (addresses) 
            // to the corresponding element in the array B (tokenIds)
            // We substract the offset of the array B from the offset of the array A
            // @article I will attach a picture to illustrate this
            let diff := sub(_addresses.offset, _tokenIds.offset)

            // @article Now we will loop through the array of the addresses
            for { let addressOffset := _addresses.offset } 1 {} {
                // @article We store the address at the current index [addressOffset]
                // @article This is equivalent to _addresses[i] in Solidity
                mstore(0x24, calldataload(addressOffset))
                
                // @article We store the tokenId at the same index BUT in the array of tokenIds
                // Which is current index of the addresses array - the difference between the two arrays
                // @article As I explained in the image
                mstore(0x44, calldataload(sub(addressOffset, diff)))
                
                // @article We send a transaction to the NFT contract with the data stored in memory
                // Function selector + from address + to address + tokenId
                // This data is located from memory location 0x00 to 0x64
                // @article If the transaction fails, revert
                // and we don't store the return data because we don't care about it (that's why
                // the last two arguments are 0)
                if iszero(call(gas(), _nft, 0, 0x00, 0x64, 0, 0)){
                    revert(0, 0)
                }
                
                // @article We increment the address offset by 32 bytes (the size of an address)
                // @article In Solidity, it's like we increase the idex by 1
                addressOffset := add(addressOffset, 0x20)

                // @article If we reached the end of the array, we break the loop
                if iszero(lt(addressOffset, end)) { break }
            }
        }
    }

    // @article Now, the airdropERC20 function is very similar to the airdropERC721 function
    // but we have a new extra parameter which is the total amount of tokens to transfer
    // Why this parameter is a big deal?
    // Because it allows the user to compute the total amout of tokens that will be transfered
    // offchain and send it to the contract instead of computing the total amount onchain (which is expensive)
    function airdropERC20(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _totalAmount
    ) external payable {
        assembly {
            // Check that the number of addresses matches the number of amounts
            if iszero(eq(_amounts.length, _addresses.length)) {
                revert(0, 0)
            }

            // transferFrom(address from, address to, uint256 amount)
            mstore(0x00, hex"23b872dd")
            // from address
            mstore(0x04, caller())
            // to address (this contract)
            mstore(0x24, address())
            // total amount
            mstore(0x44, _totalAmount)

            // transfer total amount to this contract
            if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)){
                revert(0, 0)
            }

            // transfer(address to, uint256 value)
            mstore(0x00, hex"a9059cbb")

            // end of array
            let end := add(_addresses.offset, shl(5, _addresses.length))
            // diff = _addresses.offset - _amounts.offset
            let diff := sub(_addresses.offset, _amounts.offset)

            // Loop through the addresses
            for { let addressOffset := _addresses.offset } 1 {} {
                // to address
                mstore(0x04, calldataload(addressOffset))
                // amount
                mstore(0x24, calldataload(sub(addressOffset, diff)))
                // transfer the tokens
                if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)){
                    revert(0, 0)
                }
                // increment the address offset
                addressOffset := add(addressOffset, 0x20)
                // if addressOffset >= end, break
                if iszero(lt(addressOffset, end)) { break }
            }
        }
    }

    /**
     * @notice Airdrop ETH to a list of addresses
     * @param _addresses The addresses to airdrop to
     * @param _amounts The amounts to airdrop
     */
    function airdropETH(
        address[] calldata _addresses,
        uint256[] calldata _amounts
    ) external payable {
        assembly {
            // @article Check that the number of addresses matches the number of amounts
            if iszero(eq(_amounts.length, _addresses.length)) {
                revert(0, 0)
            }

            // @article i is the index of the address in the array
            let i := _addresses.offset
            
            // @article end and dif is the same as the other functions
            let end := add(i, shl(5, _addresses.length))
            let diff := sub(_amounts.offset, _addresses.offset)

            // Loop through the addresses
            for {} 1 {} {
                // transfer the ETH
                if iszero(
                    // @article, now we will call the address at location i
                    // with the value stored at location i + diff
                    call(gas(), calldataload(i), calldataload(add(i, diff)), 0x00, 0x00, 0x00, 0x00)
                    // The second argument is the address of the recipient
                    // The third argument is the amount to send
                    // the next two arguents are pointing to the memory at 0x00 (no parameters and functions that we are calling)
                    // The last two arguments are 0 because we don't care about the return data
                    // This is equivalent to, in Solidity:
                    // (bool success, ) = address(i).call{value: amounts[i]}("")
                ) { revert(0x00, 0x00) }
                // increment the iterator
                i := add(i, 0x20)
                // if i >= end, break
                if eq(end, i) { break }
            }
        }
    }
}