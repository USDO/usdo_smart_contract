pragma solidity ^0.4.24;

import "contracts/Base.sol";
/**
 * @title Callable
 * @dev Extension for the Claimable contract.
 * This allows the contract only be called by certain contract.
 */
contract Callable is Claimable {
  mapping(address => bool) public callers;

  event CallerAddressAdded(address indexed addr);
  event CallerAddressRemoved(address indexed addr);


  /**
   * @dev Modifier throws if called by any account other than the callers or owner.
   */
  modifier onlyCaller() {
    require(callers[msg.sender]);
    _;
  }

  /**
   * @dev add an address to the caller list
   * @param addr address
   * @return true if the address was added to the caller list, false if the address was already in the caller list
   */
  function addAddressToCaller(address addr) onlyOwner public returns(bool success) {
    if (!callers[addr]) {
      callers[addr] = true;
      emit CallerAddressAdded(addr);
      success = true;
    }
  }

  /**
   * @dev remove an address from the caller list
   * @param addr address
   * @return true if the address was removed from the caller list,
   * false if the address wasn't in the caller list in the first place
   */
  function removeAddressFromCaller(address addr) onlyOwner public returns(bool success) {
    if (callers[addr]) {
      callers[addr] = false;
      emit CallerAddressRemoved(addr);
      success = true;
    }
  }
}

// ----------------------------------------------------------------------------
// Blacklist
// ----------------------------------------------------------------------------
/**
 * @title Blacklist
 * @dev The Blacklist contract has a blacklist of addresses, and provides basic authorization control functions.
 */
contract Blacklist is Callable {
  mapping(address => bool) public blacklist;

  function addAddressToBlacklist(address addr) onlyCaller public returns (bool success) {
    if (!blacklist[addr]) {
      blacklist[addr] = true;
      success = true;
    }
  }

  function removeAddressFromBlacklist(address addr) onlyCaller public returns (bool success) {
    if (blacklist[addr]) {
      blacklist[addr] = false;
      success = true;
    }
  }
}

// ----------------------------------------------------------------------------
// Verified
// ----------------------------------------------------------------------------
/**
 * @title Verified
 * @dev The Verified contract has a list of verified addresses.
 */
contract Verified is Callable {
  mapping(address => bool) public verifiedList;
  bool public shouldVerify = true;

  function verifyAddress(address addr) onlyCaller public returns (bool success) {
    if (!verifiedList[addr]) {
      verifiedList[addr] = true;
      success = true;
    }
  }

  function unverifyAddress(address addr) onlyCaller public returns (bool success) {
    if (verifiedList[addr]) {
      verifiedList[addr] = false;
      success = true;
    }
  }

  function setShouldVerify(bool value) onlyCaller public returns (bool success) {
    shouldVerify = value;
    return true;
  }
}

// ----------------------------------------------------------------------------
// Allowance
// ----------------------------------------------------------------------------
/**
 * @title Allowance
 * @dev Storage for the Allowance List.
 */
contract Allowance is Callable {
  using SafeMath for uint256;

  mapping (address => mapping (address => uint256)) public allowanceOf;

  function addAllowance(address _holder, address _spender, uint256 _value) onlyCaller public {
    allowanceOf[_holder][_spender] = allowanceOf[_holder][_spender].add(_value);
  }

  function subAllowance(address _holder, address _spender, uint256 _value) onlyCaller public {
    uint256 oldValue = allowanceOf[_holder][_spender];
    if (_value > oldValue) {
      allowanceOf[_holder][_spender] = 0;
    } else {
      allowanceOf[_holder][_spender] = oldValue.sub(_value);
    }
  }

  function setAllowance(address _holder, address _spender, uint256 _value) onlyCaller public {
    allowanceOf[_holder][_spender] = _value;
  }
}

// ----------------------------------------------------------------------------
// Balance
// ----------------------------------------------------------------------------
/**
 * @title Balance
 * @dev Storage for the Balance List.
 */
contract Balance is Callable {
  using SafeMath for uint256;

  mapping (address => uint256) public balanceOf;

  uint256 public totalSupply;

  function addBalance(address _addr, uint256 _value) onlyCaller public {
    balanceOf[_addr] = balanceOf[_addr].add(_value);
  }

  function subBalance(address _addr, uint256 _value) onlyCaller public {
    balanceOf[_addr] = balanceOf[_addr].sub(_value);
  }

  function setBalance(address _addr, uint256 _value) onlyCaller public {
    balanceOf[_addr] = _value;
  }

  function addTotalSupply(uint256 _value) onlyCaller public {
    totalSupply = totalSupply.add(_value);
  }

  function subTotalSupply(uint256 _value) onlyCaller public {
    totalSupply = totalSupply.sub(_value);
  }
}

// ----------------------------------------------------------------------------
// UserContract
// ----------------------------------------------------------------------------
/**
 * @title UserContract
 * @dev A contract for the blacklist and verified list modifiers.
 */
contract UserContract {
  Blacklist internal _blacklist;
  Verified internal _verifiedList;

  constructor(
    Blacklist _blacklistContract, Verified _verifiedListContract
  ) public {
    _blacklist = _blacklistContract;
    _verifiedList = _verifiedListContract;
  }


  /**
   * @dev Throws if the given address is blacklisted.
   */
  modifier onlyNotBlacklistedAddr(address addr) {
    require(!_blacklist.blacklist(addr));
    _;
  }

  /**
   * @dev Throws if one of the given addresses is blacklisted.
   */
  modifier onlyNotBlacklistedAddrs(address[] addrs) {
    for (uint256 i = 0; i < addrs.length; i++) {
      require(!_blacklist.blacklist(addrs[i]));
    }
    _;
  }

  /**
   * @dev Throws if the given address is not verified.
   */
  modifier onlyVerifiedAddr(address addr) {
    if (_verifiedList.shouldVerify()) {
      require(_verifiedList.verifiedList(addr));
    }
    _;
  }

  /**
   * @dev Throws if one of the given addresses is not verified.
   */
  modifier onlyVerifiedAddrs(address[] addrs) {
    if (_verifiedList.shouldVerify()) {
      for (uint256 i = 0; i < addrs.length; i++) {
        require(_verifiedList.verifiedList(addrs[i]));
      }
    }
    _;
  }

  function blacklist(address addr) public view returns (bool) {
    return _blacklist.blacklist(addr);
  }

  function verifiedlist(address addr) public view returns (bool) {
    return _verifiedList.verifiedList(addr);
  }
}
