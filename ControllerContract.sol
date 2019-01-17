pragma solidity ^0.4.24;

import "contracts/Storage.sol";

/**
 * @title ControllerContract
 * @dev A contract for managing the blacklist and verified list and burning and minting of the tokens.
 */
contract ControllerContract is Pausable, Administratable, UserContract {
  using SafeMath for uint256;
  Balance internal _balances;

  uint256 constant decimals = 18;
  uint256 constant maxBLBatch = 100;
  uint256 public dailyMintLimit = 10000 * 10 ** decimals;
  uint256 public dailyBurnLimit = 10000 * 10 ** decimals;
  uint256 constant dayInSeconds = 86400;

  constructor(
    Balance _balanceContract, Blacklist _blacklistContract, Verified _verifiedListContract
  ) UserContract(_blacklistContract, _verifiedListContract) public {
    _balances = _balanceContract;
  }

  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);
  // This notifies clients about the amount mint
  event Mint(address indexed to, uint256 value);
  // This notifies clients about the amount of limit mint by some admin
  event LimitMint(address indexed admin, address indexed to, uint256 value);
  // This notifies clients about the amount of limit burn by some admin
  event LimitBurn(address indexed admin, address indexed from, uint256 value);

  event VerifiedAddressAdded(address indexed addr);
  event VerifiedAddressRemoved(address indexed addr);

  event BlacklistedAddressAdded(address indexed addr);
  event BlacklistedAddressRemoved(address indexed addr);

  // blacklist operations
  function _addToBlacklist(address addr) internal returns (bool success) {
    success = _blacklist.addAddressToBlacklist(addr);
    if (success) {
      emit BlacklistedAddressAdded(addr);
    }
  }

  function _removeFromBlacklist(address addr) internal returns (bool success) {
    success = _blacklist.removeAddressFromBlacklist(addr);
    if (success) {
      emit BlacklistedAddressRemoved(addr);
    }
  }

  /**
   * @dev add an address to the blacklist
   * @param addr address
   * @return true if the address was added to the blacklist, false if the address was already in the blacklist
   */
  function addAddressToBlacklist(address addr) onlyAdmin whenNotPaused public returns (bool) {
    return _addToBlacklist(addr);
  }

  /**
   * @dev add addresses to the blacklist
   * @param addrs addresses
   * @return true if at least one address was added to the blacklist,
   * false if all addresses were already in the blacklist
   */
  function addAddressesToBlacklist(address[] addrs) onlyAdmin whenNotPaused public returns (bool success) {
    uint256 cnt = uint256(addrs.length);
    require(cnt <= maxBLBatch);
    success = true;
    for (uint256 i = 0; i < addrs.length; i++) {
      if (!_addToBlacklist(addrs[i])) {
        success = false;
      }
    }
  }

  /**
   * @dev remove an address from the blacklist
   * @param addr address
   * @return true if the address was removed from the blacklist,
   * false if the address wasn't in the blacklist in the first place
   */
  function removeAddressFromBlacklist(address addr) onlyAdmin whenNotPaused public returns (bool) {
    return _removeFromBlacklist(addr);
  }

  /**
   * @dev remove addresses from the blacklist
   * @param addrs addresses
   * @return true if at least one address was removed from the blacklist,
   * false if all addresses weren't in the blacklist in the first place
   */
  function removeAddressesFromBlacklist(address[] addrs) onlyAdmin whenNotPaused public returns (bool success) {
    success = true;
    for (uint256 i = 0; i < addrs.length; i++) {
      if (!_removeFromBlacklist(addrs[i])) {
        success = false;
      }
    }
  }

  // verified list operations
  function _verifyAddress(address addr) internal returns (bool success) {
    success = _verifiedList.verifyAddress(addr);
    if (success) {
      emit VerifiedAddressAdded(addr);
    }
  }

  function _unverifyAddress(address addr) internal returns (bool success) {
    success = _verifiedList.unverifyAddress(addr);
    if (success) {
      emit VerifiedAddressRemoved(addr);
    }
  }

  /**
   * @dev add an address to the verifiedlist
   * @param addr address
   * @return true if the address was added to the verifiedlist, false if the address was already in the verifiedlist or if the address is in the blacklist
   */
  function verifyAddress(address addr) onlyAdmin onlyNotBlacklistedAddr(addr) whenNotPaused public returns (bool) {
    return _verifyAddress(addr);
  }

  /**
   * @dev add addresses to the verifiedlist
   * @param addrs addresses
   * @return true if at least one address was added to the verifiedlist,
   * false if all addresses were already in the verifiedlist
   */
  function verifyAddresses(address[] addrs) onlyAdmin onlyNotBlacklistedAddrs(addrs) whenNotPaused public returns (bool success) {
    success = true;
    for (uint256 i = 0; i < addrs.length; i++) {
      if (!_verifyAddress(addrs[i])) {
        success = false;
      }
    }
  }


  /**
   * @dev remove an address from the verifiedlist
   * @param addr address
   * @return true if the address was removed from the verifiedlist,
   * false if the address wasn't in the verifiedlist in the first place
   */
  function unverifyAddress(address addr) onlyAdmin whenNotPaused public returns (bool) {
    return _unverifyAddress(addr);
  }


  /**
   * @dev remove addresses from the verifiedlist
   * @param addrs addresses
   * @return true if at least one address was removed from the verifiedlist,
   * false if all addresses weren't in the verifiedlist in the first place
   */
  function unverifyAddresses(address[] addrs) onlyAdmin whenNotPaused public returns (bool success) {
    success = true;
    for (uint256 i = 0; i < addrs.length; i++) {
      if (!_unverifyAddress(addrs[i])) {
        success = false;
      }
    }
  }

  /**
   * @dev set if to use the verified list
   * @param value true if should verify address, false if should skip address verification
   */
   function shouldVerify(bool value) onlyOwner public returns (bool success) {
     _verifiedList.setShouldVerify(value);
     return true;
   }

  /**
   * Destroy tokens from other account
   *
   * Remove `_amount` tokens from the system irreversibly on behalf of `_from`.
   *
   * @param _from the address of the sender
   * @param _amount the amount of money to burn
   */
  function burnFrom(address _from, uint256 _amount) onlyOwner whenNotPaused
  public returns (bool success) {
    require(_balances.balanceOf(_from) >= _amount);    // Check if the targeted balance is enough
    _balances.subBalance(_from, _amount);              // Subtract from the targeted balance
    _balances.subTotalSupply(_amount);
    emit Burn(_from, _amount);
    return true;
  }

  /**
   * Destroy tokens from other account
   * If the burn total amount exceeds the daily threshold, this operation will fail
   *
   * Remove `_amount` tokens from the system irreversibly on behalf of `_from`.
   *
   * @param _from the address of the sender
   * @param _amount the amount of money to burn
   */
  function limitBurnFrom(address _from, uint256 _amount) onlyAdmin whenNotPaused
  public returns (bool success) {
    require(_balances.balanceOf(_from) >= _amount && _amount <= dailyBurnLimit);
    if (burnLimiter[msg.sender].lastBurnTimestamp.div(dayInSeconds) != now.div(dayInSeconds)) {
      burnLimiter[msg.sender].burntTotal = 0;
    }
    require(burnLimiter[msg.sender].burntTotal.add(_amount) <= dailyBurnLimit);
    _balances.subBalance(_from, _amount);              // Subtract from the targeted balance
    _balances.subTotalSupply(_amount);
    burnLimiter[msg.sender].lastBurnTimestamp = now;
    burnLimiter[msg.sender].burntTotal = burnLimiter[msg.sender].burntTotal.add(_amount);
    emit LimitBurn(msg.sender, _from, _amount);
    emit Burn(_from, _amount);
    return true;
  }

  /**
    * Add `_amount` tokens to the pool and to the `_to` address' balance.
    * If the mint total amount exceeds the daily threshold, this operation will fail
    *
    * @param _to the address that will receive the given amount of tokens
    * @param _amount the amount of tokens it will receive
    */
  function limitMint(address _to, uint256 _amount)
  onlyAdmin whenNotPaused onlyNotBlacklistedAddr(_to) onlyVerifiedAddr(_to)
  public returns (bool success) {
    require(_to != msg.sender);
    require(_amount <= dailyMintLimit);
    if (mintLimiter[msg.sender].lastMintTimestamp.div(dayInSeconds) != now.div(dayInSeconds)) {
      mintLimiter[msg.sender].mintedTotal = 0;
    }
    require(mintLimiter[msg.sender].mintedTotal.add(_amount) <= dailyMintLimit);
    _balances.addBalance(_to, _amount);
    _balances.addTotalSupply(_amount);
    mintLimiter[msg.sender].lastMintTimestamp = now;
    mintLimiter[msg.sender].mintedTotal = mintLimiter[msg.sender].mintedTotal.add(_amount);
    emit LimitMint(msg.sender, _to, _amount);
    emit Mint(_to, _amount);
    return true;
  }

  function setDailyMintLimit(uint256 _limit) onlyOwner public returns (bool) {
    dailyMintLimit = _limit;
    return true;
  }

  function setDailyBurnLimit(uint256 _limit) onlyOwner public returns (bool) {
    dailyBurnLimit = _limit;
    return true;
  }

  /**
    * Add `_amount` tokens to the pool and to the `_to` address' balance
    *
    * @param _to the address that will receive the given amount of tokens
    * @param _amount the amount of tokens it will receive
    */
  function mint(address _to, uint256 _amount)
  onlyOwner whenNotPaused onlyNotBlacklistedAddr(_to) onlyVerifiedAddr(_to)
  public returns (bool success) {
    _balances.addBalance(_to, _amount);
    _balances.addTotalSupply(_amount);
    emit Mint(_to, _amount);
    return true;
  }
}
