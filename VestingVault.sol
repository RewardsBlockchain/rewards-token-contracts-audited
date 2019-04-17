pragma solidity 0.5.4;

import './RewardsToken.sol';
/**
 * @title Contract that will hold vested tokens;
 * @notice Tokens for vested contributors will be hold in this contract and token holders
 * will claim their tokens according to their own vesting timelines.
 * Copyright 2018, Rewards Blockchain Systems (Rewards.com)
 */
contract VestingVault is Ownable {
    using SafeMath for uint256;

    struct Grant {
        uint value;
        uint vestingStart;
        uint vestingCliff;
        uint vestingDuration;
        uint[] scheduleTimes;
        uint[] scheduleValues;
        uint level;              // 1: frequency, 2: schedules
        uint transferred;
    }

    RewardsToken public token;

    mapping(address => Grant) public grants;

    uint public totalVestedTokens;
    // array of vested users addresses
    address[] public vestedAddresses;
    bool public locked;

    event NewGrant (address _to, uint _amount, uint _start, uint _duration, uint _cliff, uint[] _scheduleTimes,
        uint[] _scheduleAmounts, uint _level);
    event NewRelease(address _holder, uint _amount);
    event WithdrawAll(uint _amount);
    event BurnTokens(uint _amount);
    event LockedVault();

    modifier isOpen() {
        require(locked == false, "Vault is already locked");
        _;
    }

    constructor (RewardsToken _token) public {
        require(address(_token) != address(0), "Token address should not be zero");

        token = _token;
        locked = false;
    }

    /**
     * @return address[] that represents vested addresses;
     */
    function returnVestedAddresses() public view returns (address[] memory) {
        return vestedAddresses;
    }

    /**
     * @return grant that represents vested info for specific user;
     */
    function returnGrantInfo(address _user)
    public view returns (uint, uint, uint, uint, uint[] memory, uint[] memory, uint, uint) {
        require(_user != address(0), "Address should not be zero");
        Grant storage grant = grants[_user];

        return (grant.value, grant.vestingStart, grant.vestingCliff, grant.vestingDuration, grant.scheduleTimes,
        grant.scheduleValues, grant.level, grant.transferred);
    }

    /**
     * @dev Add vested contributor information
     * @param _to Withdraw address that tokens will be sent
     * @param _value Amount to hold during vesting period
     * @param _start Unix epoch time that vesting starts from
     * @param _duration Seconds amount of vesting duration
     * @param _cliff Seconds amount of vesting cliffHi
     * @param _scheduleTimes Array of Unix epoch times for vesting schedules
     * @param _scheduleValues Array of Amount for vesting schedules
     * @param _level Indicator that will represent types of vesting
     * @return Int value that represents granted token amount
     */
    function grant(
        address _to, uint _value, uint _start, uint _duration, uint _cliff, uint[] memory _scheduleTimes,
        uint[] memory _scheduleValues, uint _level) public onlyOwner isOpen returns (uint256) {
        require(_to != address(0), "Address should not be zero");
        require(_level == 1 || _level == 2, "Invalid vesting level");
        // make sure a single address can be granted tokens only once.
        require(grants[_to].value == 0, "Already added to vesting vault");

        if (_level == 2) {
            require(_scheduleTimes.length == _scheduleValues.length, "Schedule Times and Values should be matched");
            _value = 0;
            for (uint i = 0; i < _scheduleTimes.length; i++) {
                require(_scheduleTimes[i] > 0, "Seconds Amount of ScheduleTime should be greater than zero");
                require(_scheduleValues[i] > 0, "Amount of ScheduleValue should be greater than zero");
                if (i > 0) {
                    require(_scheduleTimes[i] > _scheduleTimes[i - 1], "ScheduleTimes should be sorted by ASC");
                }
                _value = _value.add(_scheduleValues[i]);
            }
        }

        require(_value > 0, "Vested amount should be greater than zero");

        grants[_to] = Grant({
            value : _value,
            vestingStart : _start,
            vestingDuration : _duration,
            vestingCliff : _cliff,
            scheduleTimes : _scheduleTimes,
            scheduleValues : _scheduleValues,
            level : _level,
            transferred : 0
            });

        vestedAddresses.push(_to);
        totalVestedTokens = totalVestedTokens.add(_value);

        emit NewGrant(_to, _value, _start, _duration, _cliff, _scheduleTimes, _scheduleValues, _level);
        return _value;
    }

    /**
     * @dev Get token amount for a token holder available to transfer at specific time
     * @param _holder Address that represents holder's withdraw address
     * @param _time Unix epoch time at the moment
     * @return Int value that represents token amount that is available to release at the moment
     */
    function transferableTokens(address _holder, uint256 _time) public view returns (uint256) {
        Grant storage grantInfo = grants[_holder];

        if (grantInfo.value == 0) {
            return 0;
        }
        return calculateTransferableTokens(grantInfo, _time);
    }

    /**
     * @dev Internal function to calculate available amount at specific time
     * @param _grant Grant that represents holder's vesting info
     * @param _time Unix epoch time at the moment
     * @return Int value that represents available vested token amount
     */
    function calculateTransferableTokens(Grant memory _grant, uint256 _time) private pure returns (uint256) {
        uint totalVestedAmount = _grant.value;
        uint totalAvailableVestedAmount = 0;

        if (_grant.level == 1) {
            if (_time < _grant.vestingCliff.add(_grant.vestingStart)) {
                return 0;
            } else if (_time >= _grant.vestingStart.add(_grant.vestingDuration)) {
                return _grant.value;
            } else {
                totalAvailableVestedAmount =
                totalVestedAmount.mul(_time.sub(_grant.vestingStart)).div(_grant.vestingDuration);
            }
        } else {
            if (_time < _grant.scheduleTimes[0]) {
                return 0;
            } else if (_time >= _grant.scheduleTimes[_grant.scheduleTimes.length - 1]) {
                return _grant.value;
            } else {
                for (uint i = 0; i < _grant.scheduleTimes.length; i++) {
                    if (_grant.scheduleTimes[i] <= _time) {
                        totalAvailableVestedAmount = totalAvailableVestedAmount.add(_grant.scheduleValues[i]);
                    } else {
                        break;
                    }
                }
            }
        }

        return totalAvailableVestedAmount;
    }

    /**
     * @dev Claim vested token
     * @notice this will be eligible after vesting start + cliff or schedule times
     */
    function claim() public {
        address beneficiary = msg.sender;
        Grant storage grantInfo = grants[beneficiary];
        require(grantInfo.value > 0, "Grant does not exist");

        uint256 vested = calculateTransferableTokens(grantInfo, now);
        require(vested > 0, "There is no vested tokens");

        uint256 transferable = vested.sub(grantInfo.transferred);
        require(transferable > 0, "There is no remaining balance for this address");
        require(token.balanceOf(address(this)) >= transferable, "Contract Balance is insufficient");

        grantInfo.transferred = grantInfo.transferred.add(transferable);
        totalVestedTokens = totalVestedTokens.sub(transferable);

        token.transfer(beneficiary, transferable);
        emit NewRelease(beneficiary, transferable);
    }

    /**
     * @dev Function to revoke tokens from each Accounts
     */
    function revokeTokens(address _from, uint amount) public onlyOwner {
        // finally transfer all remaining tokens to owner
        Grant storage grantInfo = grants[_from];
        require(grantInfo.value > 0, "Grant does not exist");

        uint256 revocable = grantInfo.value.sub(grantInfo.transferred);
        require(revocable > 0, "There is no remaining balance for this address");
        require(revocable >= amount, "Revocable balance is insufficient");
        require(token.balanceOf(address(this)) >= amount, "Contract Balance is insufficient");

        grantInfo.value = grantInfo.value.sub(amount);
        totalVestedTokens = totalVestedTokens.sub(amount);

        token.burn(amount);
        emit BurnTokens(amount);
    }

    /**
     * @dev Function to burn remaining tokens
     */
    function burnRemainingTokens() public onlyOwner {
        // finally transfer all remaining tokens to owner
        uint amount = token.balanceOf(address(this));

        token.burn(amount);
        emit BurnTokens(amount);
    }

    /**
     * @dev Function to withdraw remaining tokens;
     */
    function withdraw() public onlyOwner {
        // finally withdraw all remaining tokens to owner
        uint amount = token.balanceOf(address(this));
        token.transfer(owner, amount);

        emit WithdrawAll(amount);
    }

    /**
     * @dev Function to lock vault not to be able to alloc more
     */
    function lockVault() public onlyOwner {
        // finally lock vault
        require(!locked);
        locked = true;
        emit LockedVault();
    }
}