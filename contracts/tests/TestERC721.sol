// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol){
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
