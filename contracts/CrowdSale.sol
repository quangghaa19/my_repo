// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract CrowdSale is Ownable, ReentrancyGuard {
    
    IERC20 public token;// The token being sold
    uint public rate; // Units of token per wei
    address public collector; // Collected funds address

    uint public distributedPercent; // Percent of token distributed
    uint public totalWeiRaised; // Total wei raised
    uint public totalTokenSold; // Total token sold

    mapping(string => Pool) public poolInfo; // Infomation of a round
    mapping(string => mapping(address => bool)) public investors; // Investors in a round
    mapping(address => bool) public isAdmin; // List of administrators

    /**
    * @param _token Address of token to sold
    * @param _collector Address hold collected funds
    * @param _rate How many token per wei
    */
    constructor(IERC20 _token, address _collector, uint _rate) payable {

        require(address(_token) != address(0), "Token address is invalid");
        require(_collector != address(0), "Collector address is invalid");
        require(_rate != 0, "Rate must not be zero");

        token = _token;
        collector = _collector;
        rate = _rate;
        isAdmin[msg.sender] = true; // Set admin role to deployer
    }

    /**
    * Define round infomation
     */
    struct Pool{

        string name; // Round name
        uint totalPercent; // Percent of token released
        uint totalSupply; // Amount of token released
        uint remaining; // Token left to sold
        uint weiReceived; // Total wei raised
        uint[] timestamps; // Different periods in a round
        uint[] ratios; // Rate corresponds to timestamps
        uint[] periodRemainingToken; // Token remain in each period of time
    }

    /**
    * Define Events
     */
    event PoolCreated(
        address indexed creator, 
        string poolId
    );

    event PoolUpdated(
        address indexed updatedBy,
        string poolId,
        uint[] newTimestamps,
        uint[] newRatios
    );

    event TokenPurchase(
        address indexed purchaser,
        address indexed beneficiary,
        uint value,
        uint amount
    );

    /**
    * Define Modifiers 
    */
    modifier onlyAdmin() {

        require(isAdmin[msg.sender], "Only admin can do");
        _;
    }

    modifier onlyInvestor(string memory _poolId) {

        require(investors[_poolId][msg.sender], "Only investor can do");
        _;
    }

    modifier poolExist(string memory poolId) {
        
        require(poolInfo[poolId].totalPercent != 0, "Round does not exist");
        _;
    }

    modifier poolNotExist(string memory poolId) {

        require(poolInfo[poolId].totalPercent == 0, "Round is already exist");
        _;
    }

    /**
    * Define Owner functions
     */
    function setRate(uint _newRate) external onlyOwner {

        require(_newRate != 0, "New rate must not be zero");
        rate = _newRate;
    }

    function setAdmin(address _address, bool _value) external onlyOwner {
        
        require(_address != address(0), "Address is invalid");
        isAdmin[_address] = _value;
    }

    function withdrawToken(address payable _address, uint _amount) external onlyOwner {

        require(_address != address(0), "Address is invalid");
        _address.transfer(_amount);
    } 

    /**
    * Define Administrator functions
     */
    function createPool(
        string memory _poolId,
        string memory _name,
        uint _totalPercent,
        uint[] memory _timestamps,
        uint[] memory _ratios
        ) external poolNotExist(_poolId) onlyAdmin {

        require(bytes(_poolId).length > 0, "Pool id must not be empty");
        require(bytes(_name).length > 0, "Pool name must not be empty");
        require(_totalPercent != 0 && _totalPercent + distributedPercent <= 1e6, "Distributed percent of token must not be zero or greater than 100%");
        require(_timestamps.length != 0, "Period array must not be empty");
        require(_timestamps[0] > block.timestamp, "Start date must not be the past");
        require(_ratios.length != 0, "Rate array corresponds to timestamp must not be empty");
        require(_timestamps.length == _ratios.length, "Every periods have to have correspond rate");

        uint totalSupply = token.totalSupply() * _totalPercent / 1e6;
        uint periodLength = _ratios.length;
        uint[] memory periodRemainingToken = new uint[](periodLength);
        for(uint i = 0; i < periodLength; i++) {
            periodRemainingToken[i] = totalSupply * _ratios[i] / 1e6;
        }

        Pool memory pool = Pool(_name, _totalPercent, totalSupply, totalSupply, 0, _timestamps, _ratios, periodRemainingToken);
        poolInfo[_poolId] = pool;

        console.log("Check percent: ", pool.totalPercent);
        console.log("Check percent 2: ", poolInfo[_poolId].totalPercent);

        distributedPercent += _totalPercent;

        emit PoolCreated(msg.sender, _poolId);
    }

    function updatePool(
        string memory _poolId, 
        uint[] memory _timestamps, 
        uint[] memory _ratios
        ) external onlyAdmin {
        
        require(bytes(_poolId).length > 0, "Pool id must not be empty");
        require(_timestamps.length != 0, "Period array must not be empty");
        require(_timestamps[0] > block.timestamp, "Start date must not be the past");
        require(_ratios.length != 0, "Rate array corresponds to timestamp must not be empty");
        require(_timestamps.length == _ratios.length, "Every periods have to have correspond rate");

        Pool storage pool = poolInfo[_poolId];
        pool.timestamps = _timestamps;
        pool.ratios = _ratios;

        emit PoolUpdated(msg.sender, _poolId, _timestamps, _ratios);
    }

    function setInvestor(string memory _poolId, address _investor, bool _value) external onlyAdmin {

        require(bytes(_poolId).length > 0, "PoolId must not be empty");
        require(_investor != address(0), "Investor address is not valid");

        investors[_poolId][_investor] = _value;
    }

    /**
    * Define Main functions
     */
    
    /** Buy token
    * @param _poolId ID of the round 
    * @param _beneficiary Address receive the token
    */
    function buyToken(string memory _poolId, address _beneficiary) 
        public payable onlyInvestor(_poolId) poolExist(_poolId) nonReentrant {
        
        _checkTimeBuy(_poolId); // Validate the time investors buy token

        uint weiAmount = msg.value;
        _validatePurchase(_beneficiary, weiAmount); // Validate data

        uint tokenAmount = _getTokenAmount(weiAmount); // Calculate amount of token to buy

        _processPayment(_poolId, _beneficiary, weiAmount, tokenAmount);
    }

    /** Buy a specific amount of token 
    * @param _poolId ID of the round 
    * @param _beneficiary Address receive the token
    * @param _tokenAmount Amount of token want to buy
    */
    function buySpecificAmountOfToken(string memory _poolId, address _beneficiary, uint _tokenAmount)
        public payable poolExist(_poolId) onlyInvestor(_poolId) nonReentrant {
        
        _checkTimeBuy(_poolId); // Validate the time investors buy token

        uint weiAmount = msg.value;
        _validatePurchase(_beneficiary, weiAmount); // Validate data

        uint weiToPay = _getWeiAmount(_tokenAmount); // Calculate amount of wei to pay
        require(weiAmount >= weiToPay, "Not enough wei to buy");

        _processPayment(_poolId, _beneficiary, weiAmount, _tokenAmount);
    }

    /**
    * Define Private functions
     */
    function _checkTimeBuy(string memory _poolId) internal view {
        Pool memory pool = poolInfo[_poolId];
        require(block.timestamp >= pool.timestamps[0], "Round has not been started");
        require(block.timestamp <= pool.timestamps[pool.timestamps.length], "Round has been finished");
    }

    function _validatePurchase(address _beneficiary, uint _weiAmount) internal pure {
        require(_beneficiary != address(0), "Received address is invalid");
        require(_weiAmount != 0, "Amount of wei must not be zero");
    }

    function _getTokenAmount(uint _weiAmount) internal view returns(uint) {
        return _weiAmount * rate;
    }

    function _getWeiAmount(uint _tokenAmount) internal view returns(uint) {
        return _tokenAmount / rate;
    }

    function _processPayment(string memory _poolId, address _beneficiary, uint _weiAmount, uint _tokenAmount) internal {
        
        Pool storage pool = poolInfo[_poolId];

        uint index = getIndexOfPeriod(_poolId); 
        require(_tokenAmount <= pool.periodRemainingToken[index], "Not enough token available");

        totalWeiRaised += _weiAmount;
        totalTokenSold += _tokenAmount;

        pool.weiReceived += _weiAmount;
        pool.remaining -= _tokenAmount;
        pool.periodRemainingToken[index] -= _tokenAmount;

        payable(collector).transfer(_weiAmount); // Forward fund

        token.transfer(_beneficiary, _tokenAmount); // Forward token

        emit TokenPurchase(msg.sender, _beneficiary, _weiAmount, _tokenAmount);
    }

    /**
    * @param _poolId Id of pool
    * @param index Index to ...
     */
    function totalTokenCanBuy(string memory _poolId, uint index) public view returns(uint) {
        
        Pool memory pool = poolInfo[_poolId];
        return pool.periodRemainingToken[index];
    }

    function getIndexOfPeriod(string memory _poolId) public view returns(uint) {
        
        Pool memory pool = poolInfo[_poolId];
        uint currentTimestamp = block.timestamp;

        require(block.timestamp >= pool.timestamps[0], "Round has not been started");
        require(block.timestamp <= pool.timestamps[pool.timestamps.length], "Round has been finished");

        for(uint i=1; i < pool.timestamps.length; i++) {
            if(currentTimestamp >= pool.timestamps[i-1] && currentTimestamp < pool.timestamps[i]) {
                return i-1;
            }
        }
        return 0;
    }
}   