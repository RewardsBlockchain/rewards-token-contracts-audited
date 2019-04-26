### TokenContracts-Audited
Final Audited Rewards Cash token contracts


#### RewardsToken contract overview
RewardsToken contract uses Ownable contract and SafeMath library from OpenZeppelin repository. 
SafeMath library is used for math operations with safety checks that detect errors.

###### RewardsToken describes ERC20 token with next parameters:

- symbol: RWD
- name: Rewards Cash
- decimals: 18
- hardCap: 5 * (10**(18+8))

###### RewardsToken has 2 modifiers:
- canMint: checks whether mintingFinished is not false.
- canTransfer: checks whether msg.sender is owner or frozen is not false.

###### RewardsToken has 14 functions:

- mint is a public function: mints a specified amount of tokens to the specified address. Has onlyOwner and canMint modifiers.
- finishMinting is a public function: sets mintingFinished to true. Has onlyOwner modifier.
- startMinting is a public function: sets mintingFinished to false. Has onlyOwner modifier.
- transfer is a public function: transfers specified amount of tokens to the specified account. Has canTransfer modifier.
- transferFrom is a public function: transfers specified amount of allowed tokens to the specified account. Has canTransfer modifier.
- approve is a public function: approves a specified amount of tokens.
- allowance is a public view function: returns an amount of tokens that an owner allowed to a spender.
- increaseApproval is a public function: increases an amount of approved tokens for the specified account.
- decreaseApproval is a public function: decreases an amount of approved tokens for the specified account.
- balanceOf is a public view function: returns balance of the specified address.
- burn is a public function: burns specified amount of tokens from msg.sender balance.
- revoke is a public function: revokes specified amount of tokens from the specified address. Has onlyOwner modifier.
- freeze is a public function: sets frozen to true. Has onlyOwner modifier.
- unfreeze is a public function: sets frozen to false. Has onlyOwner modifier.

 
#### VestingVault contract overview

##### VestingVault contract is used to implement token vesting scheme. 

###### VestingVault constructor sets:
- token to _token 
- locked to false

###### VestingVault has 1 modifiers:
- isOpen : checks whether locked is false.

###### VestingVault has 9 functions:
- returnVestedAddresses is a public view function: returns an
array of vestedAddresses.
- returnGrantInfo is a public view function: returns information about grant for the specified address.
- grant is a public view function: returns an array of vestedAddresses. Has onlyOwner and isOpen modifier.
- transferableTokens is a public view function: returns a number of tokens available to transfer at specified time.
- calculateTransferableTokens is a private pure function: returns an available amount of tokens to transfer at specified time.
- claim is a public function: transfers vested tokens to msg.sender.
- burnRemainingTokens is a public function: transfers all tokens from contract to the owner and burns them. Has onlyOwner modifier.
- withdraw is a public function: transfers all tokens from contract to the owner. Has onlyOwner modifier.
- lockVault is a public function: locks vault. 

#### RewardsTokenDistribution contract overview 

##### RewardsTokenDistribution contract is used for tokens distribution. 

###### RewardsTokenDistributionconstructor sets:
- token to _token
- vestingVault to _vestingVault 
- finished to false

###### RewardsTokenDistribution has 1 modifier:
- isAllowed: checks whether finished is false.

###### RewardsTokenDistributionhas 6 functions:
- allocNormalUser is a public function: mints specified amount of tokens to the specified address. Has onlyOwner and isAllowed modifiers.
- allocNormalUsers is a public function: mints specified amounts of tokens to the specified addresses. Has onlyOwner and isAllowed modifiers.
10
 
- allocVestedUser is a public function: allocates specified amount of tokens to the specified address. Has onlyOwner and isAllowed modifiers.
- transferBackTokenOwnership is a public function: transfers an ownership of token contract to the owner. Has onlyOwner modifier.
- transferBackVestingVaultOwnership is a public function: transfers an ownership of vestingVault contract to the owner. Has onlyOwner modifier.
- finalize is a public function: calls finishMinting function and finishes token distribution. Has onlyOwner modifier.
