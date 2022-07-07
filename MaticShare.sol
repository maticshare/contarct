// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Libraries/SafeMath.sol";
import "./Libraries/Math.sol";

contract MaticShare is Math {

    using SafeMath for uint;

    struct Data {
        uint sellPrice;
        uint totalChair;
        uint tableCapacity;
        uint tableCount;
        uint sharePrice;
        uint pickPrice;
        uint chairPrice;
        uint sitPrice;
        uint txCount;
        uint totalVolume;
        address mostShared;
        address owner;
        address income;
        address[] accounts;
    }

    struct AccountData {
        uint chairCount;
        uint pickCount;
    }

    address private _owner = msg.sender;

    address private _income = msg.sender;

    address private _mostSharedAccount = msg.sender;

    uint private constant _tableCapacity = 6;

    uint private constant _sharePrice = 6 ether;

    uint private constant _pickPrice = _tableCapacity * _sharePrice;

    uint private _chairPrice = 0.6 ether;

    uint private _sitPrice = _sharePrice + _chairPrice;

    uint private _sellPrice = 0;

    uint private _totalChair = 0;

    uint private _tableCount = 0;

    uint private _txCount = 0;

    uint private _totalVolume = 0;

    uint8 private _mostSharedGiftPercent = 3;

    uint private _lunchTime;

    uint private _giftTime;

    address[] private _accounts;

    mapping(uint => address[]) private _tables;

    mapping(uint => address) private _tablePicker;

    mapping(uint => bool) private _isShared;

    mapping(address => uint) private _userChairCount;

    mapping(address => uint) private _userPickCount;

    mapping(address => bool) private _isRegistered;
    
    mapping(address => uint) private _accountTotalShare;

    mapping(uint => uint) private _dailyVolume;

    mapping(uint => uint) private _dailyUser;

    mapping(uint => uint) private _dailySit;

    constructor() {
        _lunchTime = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "caller is not the owner");
        _;
    }

    modifier exceptOwner() {
        require(msg.sender != _owner, "caller is the owner");
        _;
    }

    function data() public view returns (Data memory) {
        return Data(_sellPrice, _totalChair, _tableCapacity, _tableCount, _sharePrice, _pickPrice, _chairPrice, _sitPrice, _txCount, _totalVolume, _mostSharedAccount, _owner, _income, _accounts);
    }

    function accountData(address account) public view returns (AccountData memory)  {
        return AccountData(_userChairCount[account], _userPickCount[account]);
    }

    function getTable(uint index) public view returns (address[] memory) {
        return _tables[index];
    }

    function getTablePicker(uint index) public view returns (address) {
        return _tablePicker[index];
    }

    function getDailyVolume(uint day) public view returns (uint) {
        return _dailyVolume[day];
    }

    function getDailyUser(uint day) public view returns (uint) {
        return _dailyUser[day];
    }

    function getDailySit(uint day) public view returns (uint) {
        return _dailySit[day];
    }

    function getTotalShare(address account) public view returns (uint) {
        return _accountTotalShare[account];
    }

    function setChairPrice(uint price) public onlyOwner {
        require(price % 0.1 ether == 0, "price must be module of 0.1 matic");
        _chairPrice = price;
        _sitPrice = _chairPrice.add(_sharePrice);
    }

    function setIncome(address account) public onlyOwner {
        _income = account;
    }

    function setMostSharedGiftPercent(uint8 percent) public onlyOwner {
        require(percent < 6, "percent most less than 6");
        _mostSharedGiftPercent = percent;
    }

    function _inTable(uint index, address account) private view returns (bool) {
        for (uint i = 0; i < _tables[index].length; i = i.inc()) {
            if (_tables[index][i] == account) return true;
        }
        return false;
    }

    function _isFull(uint index) private view returns (bool) {
        return _tables[index].length == _tableCapacity;
    }

    function isShared(uint index) public view returns (bool) {
        return _isShared[index];
    }

    function getDay() public view returns (uint) {
        uint during = block.timestamp - _lunchTime;
        uint remind = during % 1 days;
        uint time = block.timestamp - remind;
        return (time - _lunchTime) / 1 days;
    }

    function sit(uint count) public payable {
        require(count > 0, "You can not sit around 0 table");
        require(msg.value == count * _sitPrice, "Send wrong value");
        uint incomeValue = count * _chairPrice;
        uint shareValue = count * _sharePrice;
        uint day = getDay();
        uint8 giftPercent = _mostSharedGiftPercent;
        if(_giftTime < block.timestamp - 12 hours)
            giftPercent = 0;
        _txCount = _txCount.inc();
        _totalVolume = _totalVolume.add(msg.value);
        _dailyVolume[day] = _dailyVolume[day].add(msg.value);
        _dailySit[day] = _dailySit[day].add(count);
        _accountTotalShare[msg.sender] =_accountTotalShare[msg.sender].add(shareValue);
        if(_giftTime < block.timestamp - 12 hours && _accountTotalShare[msg.sender] > _accountTotalShare[_mostSharedAccount])
            _mostSharedAccount = msg.sender;
        if (!_isRegistered[msg.sender]) {
            _accounts.push(msg.sender);
            _dailyUser[day] = _dailyUser[day].inc();
            _isRegistered[msg.sender] = true;
        }
        if(giftPercent > 0)
            payable(_mostSharedAccount).transfer(incomeValue.percent(giftPercent));
        payable(_income).transfer(incomeValue.percent(100 - giftPercent));
        _userChairCount[msg.sender] = _userChairCount[msg.sender].add(count);
        _totalChair = _totalChair.add(count);
        for (uint i = 0; i < _tableCount; i = i.inc()) {
            if (!_inTable(i, msg.sender) && !_isFull(i)) {
                _tables[i].push(msg.sender);
                count = count.dec();
            }
            if (count == 0) return;
        }
        while (count > 0) {
            _tables[_tableCount].push(msg.sender);
            _tableCount = _tableCount.inc();
            count = count.dec();
        }
    }

    function share(uint8 nonce) public payable {
        uint day = getDay();
        _txCount = _txCount.inc();
        for (uint i = 0; i < _tableCount; i = i.inc()) {
            if (_isShared[i] || !_isFull(i)) continue;
            _totalChair = _totalChair.sub(_tableCapacity);
            for (uint j = 0; j < _tableCapacity; j = j.inc()) {
                _userChairCount[_tables[i][j]] = _userChairCount[_tables[i][j]].dec();
            }
            uint pickerId = _random(++nonce) % _tableCapacity.dec();
            address piker = _tables[i][pickerId];
            _userPickCount[piker] = _userPickCount[piker].inc();
            payable(piker).transfer(_pickPrice);
            _totalVolume = _totalVolume.add(_pickPrice);
            _dailyVolume[day] = _dailyVolume[day].add(msg.value);
            _isShared[i] = true;
            _tablePicker[i] = piker;
        }
    }

    function activeDappTransfer(uint price) public onlyOwner {
        _txCount = _txCount.inc();
        require(_sellPrice == 0, "Sell is active");
        require(price % 1 ether == 0, "Price must be in wei");
        require(price >= 10000 ether, "Price must be more than 10000 matic");
        _sellPrice = price;
    }

    function transferDapp() public payable exceptOwner {
        require(_sellPrice > 0, "Sell is not active");
        require(msg.value == _sellPrice, "Send wrong value");
        uint day = getDay();
        _txCount = _txCount.inc();
        _totalVolume = _totalVolume.add(msg.value);
        _dailyVolume[day] = _dailyVolume[day].add(msg.value);
        payable(_income).transfer(_sellPrice);
        _owner = msg.sender;
        _income = msg.sender;
        _sellPrice = 0;
    }

    function activeMostSharedGift() public onlyOwner {
        _giftTime = block.timestamp;
    }

}