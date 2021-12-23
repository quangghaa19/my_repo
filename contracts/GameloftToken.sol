// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GameloftToken is ERC20 {

    /**
    * @param _name Name of the token 
    * @param _symbol Symbol of the token
    * @param _beneficiary Address hold all the tokens
    * @param _initialSupply The initial amount of token release
    * @param _decimal Total zero number after initial supply value */
    constructor(
        string memory _name,
        string memory _symbol,
        address _beneficiary,
        uint _initialSupply,
        uint _decimal) ERC20(_name, _symbol) {
            _mint(_beneficiary, 10 ** _decimal * _initialSupply);
        }
}