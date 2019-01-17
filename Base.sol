pragma solidity ^0.4.24;


// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

// ----------------------------------------------------------------------------
// Ownable contract
// ----------------------------------------------------------------------------
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
}

/**
 * @title Claimable
 * @dev Extension for the Ownable contract, where the ownership needs to be claimed.
 * This allows the new owner to accept the transfer.
 */
contract Claimable is Ownable {
  address public pendingOwner;

  event OwnershipTransferPending(address indexed owner, address indexed pendingOwner);

  /**
   * @dev Modifier throws if called by any account other than the pendingOwner.
   */
  modifier onlyPendingOwner() {
    require(msg.sender == pendingOwner);
    _;
  }

  /**
   * @dev Allows the current owner to set the pendingOwner address.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    emit OwnershipTransferPending(owner, pendingOwner);
    pendingOwner = newOwner;
  }

  /**
   * @dev Allows the pendingOwner address to finalize the transfer.
   */
  function claimOwnership() onlyPendingOwner public {
    emit OwnershipTransferred(owner, pendingOwner);
    owner = pendingOwner;
    pendingOwner = address(0);
  }
}

// ----------------------------------------------------------------------------
// Pausable contract
// ----------------------------------------------------------------------------
/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Claimable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

// ----------------------------------------------------------------------------
// Administratable contract
// ----------------------------------------------------------------------------
/**
 * @title Administratable
 * @dev The Admin contract has the list of admin addresses.
 */
contract Administratable is Claimable {
  struct MintStruct {
    uint256 mintedTotal;
    uint256 lastMintTimestamp;
  }

  struct BurnStruct {
    uint256 burntTotal;
    uint256 lastBurnTimestamp;
  }

  mapping(address => bool) public admins;
  mapping(address => MintStruct) public mintLimiter;
  mapping(address => BurnStruct) public burnLimiter;

  event AdminAddressAdded(address indexed addr);
  event AdminAddressRemoved(address indexed addr);


  /**
   * @dev Throws if called by any account that's not admin or owner.
   */
  modifier onlyAdmin() {
    require(admins[msg.sender] || msg.sender == owner);
    _;
  }

  /**
   * @dev add an address to the admin list
   * @param addr address
   * @return true if the address was added to the admin list, false if the address was already in the admin list
   */
  function addAddressToAdmin(address addr) onlyOwner public returns(bool success) {
    if (!admins[addr]) {
      admins[addr] = true;
      mintLimiter[addr] = MintStruct(0, 0);
      burnLimiter[addr] = BurnStruct(0, 0);
      emit AdminAddressAdded(addr);
      success = true;
    }
  }

  /**
   * @dev remove an address from the admin list
   * @param addr address
   * @return true if the address was removed from the admin list,
   * false if the address wasn't in the admin list in the first place
   */
  function removeAddressFromAdmin(address addr) onlyOwner public returns(bool success) {
    if (admins[addr]) {
      admins[addr] = false;
      delete mintLimiter[addr];
      delete burnLimiter[addr];
      emit AdminAddressRemoved(addr);
      success = true;
    }
  }
}
