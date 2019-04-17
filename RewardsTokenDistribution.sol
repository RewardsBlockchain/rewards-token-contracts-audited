pragma solidity 0.5.4;

import "./RewardsToken.sol";
import "./VestingVault.sol";
import "./lib/Ownable.sol";
import "./lib/SafeMath.sol";

/**
 * @title Contract for distribution of tokens
 * Copyright 2018, Rewards Blockchain Systems (Rewards.com)
 */
contract RewardsTokenDistribution is Ownable {
    using SafeMath for uint256;

    RewardsToken public token;
    VestingVault public vestingVault;

    bool public finished;

    event TokenMinted(address indexed _to, uint _value, string _id);
    event RevokeTokens(address indexed _from, uint _value);
    event MintingFinished();

    modifier isAllowed() {
        require(finished == false, "Minting was already finished");
        _;
    }

    /**
     * @dev Constructor
     * @param _token Contract address of RewardsToken
     * @param _vestingVault Contract address of VestingVault
     */
    constructor (
        RewardsToken _token,
        VestingVault _vestingVault
    ) public {
        require(address(_token) != address(0), "Address should not be zero");
        require(address(_vestingVault) != address(0), "Address should not be zero");

        token = _token;
        vestingVault = _vestingVault;
        finished = false;
    }

    /**
     * @dev Function to allocate tokens for normal contributor
     * @param _to Address of a contributor
     * @param _value Value that represents tokens amount allocated for a contributor
     */
    function allocNormalUser(address _to, uint _value) public onlyOwner isAllowed {
        token.mint(_to, _value);
        emit TokenMinted(_to, _value, "Allocated Tokens To User");
    }

    /**
     * @dev Function to allocate tokens for vested contributor
     * @param _to Withdraw address that tokens will be sent
     * @param _value Amount to hold during vesting period
     * @param _start Unix epoch time that vesting starts from
     * @param _duration Seconds amount of vesting duration
     * @param _cliff Seconds amount of vesting cliff
     * @param _scheduleTimes Array of Unix epoch times for vesting schedules
     * @param _scheduleValues Array of Amount for vesting schedules
     * @param _level Indicator that will represent types of vesting
     */
    function allocVestedUser(
        address _to, uint _value, uint _start, uint _duration, uint _cliff, uint[] memory _scheduleTimes,
        uint[] memory _scheduleValues, uint _level) public onlyOwner isAllowed {
        _value = vestingVault.grant(_to, _value, _start, _duration, _cliff, _scheduleTimes, _scheduleValues, _level);
        token.mint(address(vestingVault), _value);
        emit TokenMinted(_to, _value, "Allocated Vested Tokens To User");
    }

    /**
     * @dev Function to allocate tokens for normal contributors
     * @param _holders Address of a contributor
     * @param _amounts Value that represents tokens amount allocated for a contributor
     */
    function allocNormalUsers(address[] memory _holders, uint[] memory _amounts) public onlyOwner isAllowed {
        require(_holders.length > 0, "Empty holder addresses");
        require(_holders.length == _amounts.length, "Invalid arguments");
        for (uint i = 0; i < _holders.length; i++) {
            token.mint(_holders[i], _amounts[i]);
            emit TokenMinted(_holders[i], _amounts[i], "Allocated Tokens To Users");
        }
    }

    /**
     * @dev Function to revoke tokens from an address
     */
    function revokeTokensFromVestedUser(address _from, uint _amount) public onlyOwner {
        vestingVault.revokeTokens(_from, _amount);
        emit RevokeTokens(_from, _amount);
    }

    /**
     * @dev Function to get back Ownership of RewardToken Contract after minting finished
     */
    function transferBackTokenOwnership() public onlyOwner {
        token.transferOwnership(owner);
    }

    /**
     * @dev Function to get back Ownership of VestingVault Contract after minting finished
     */
    function transferBackVestingVaultOwnership() public onlyOwner {
        vestingVault.transferOwnership(owner);
    }

    /**
     * @dev Function to finish token distribution
     */
    function finalize() public onlyOwner {
        token.finishMinting();
        finished = true;
        emit MintingFinished();
    }
}