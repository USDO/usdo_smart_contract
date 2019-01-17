pragma solidity ^0.4.24;

import "contracts/Storage.sol";

// ----------------------------------------------------------------------------
// ContractInterface
// ----------------------------------------------------------------------------
contract ContractInterface {
  function totalSupply() public view returns (uint256);
  function balanceOf(address tokenOwner) public view returns (uint256);
  function allowance(address tokenOwner, address spender) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function batchTransfer(address[] to, uint256 value) public returns (bool);
  function increaseApproval(address spender, uint256 value) public returns (bool);
  function decreaseApproval(address spender, uint256 value) public returns (bool);
  function burn(uint256 value) public returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed tokenOwner, address indexed spender, uint256 value);
  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);
}

// ----------------------------------------------------------------------------
// USDO contract
// ----------------------------------------------------------------------------
contract USDO is ContractInterface, Pausable, UserContract {
  using SafeMath for uint256;

  // variables of the token
  uint8 public constant decimals = 18;
  uint256 constant maxBatch = 100;

  string public name;
  string public symbol;

  Balance internal _balances;
  Allowance internal _allowance;

  constructor(string _tokenName, string _tokenSymbol,
    Balance _balanceContract, Allowance _allowanceContract,
    Blacklist _blacklistContract, Verified _verifiedListContract
  ) UserContract(_blacklistContract, _verifiedListContract) public {
    name = _tokenName;                                        // Set the name for display purposes
    symbol = _tokenSymbol;                                    // Set the symbol for display purposes
    _balances = _balanceContract;
    _allowance = _allowanceContract;
  }

  function totalSupply() public view returns (uint256) {
    return _balances.totalSupply();
  }

  function balanceOf(address _addr) public view returns (uint256) {
    return _balances.balanceOf(_addr);
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return _allowance.allowanceOf(_owner, _spender);
  }

  /**
   *  @dev Internal transfer, only can be called by this contract
   */
  function _transfer(address _from, address _to, uint256 _value) internal {
    require(_value > 0);                                               // transfering value must be greater than 0
    require(_to != 0x0);                                               // Prevent transfer to 0x0 address. Use burn() instead
    require(_balances.balanceOf(_from) >= _value);                     // Check if the sender has enough
    uint256 previousBalances = _balances.balanceOf(_from).add(_balances.balanceOf(_to)); // Save this for an assertion in the future
    _balances.subBalance(_from, _value);                 // Subtract from the sender
    _balances.addBalance(_to, _value);                     // Add the same to the recipient
    emit Transfer(_from, _to, _value);
    // Asserts are used to use static analysis to find bugs in your code. They should never fail
    assert(_balances.balanceOf(_from) + _balances.balanceOf(_to) == previousBalances);
  }

  /**
   * @dev Transfer tokens
   * Send `_value` tokens to `_to` from your account
   *
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transfer(address _to, uint256 _value)
  whenNotPaused onlyNotBlacklistedAddr(msg.sender) onlyNotBlacklistedAddr(_to) onlyVerifiedAddr(msg.sender) onlyVerifiedAddr(_to)
  public returns (bool) {
    _transfer(msg.sender, _to, _value);
    return true;
  }


  /**
   * @dev Transfer tokens to multiple accounts
   * Send `_value` tokens to all addresses in `_to` from your account
   *
   * @param _to The addresses of the recipients
   * @param _value the amount to send
   */
  function batchTransfer(address[] _to, uint256 _value)
  whenNotPaused onlyNotBlacklistedAddr(msg.sender) onlyNotBlacklistedAddrs(_to) onlyVerifiedAddr(msg.sender) onlyVerifiedAddrs(_to)
  public returns (bool) {
    uint256 cnt = uint256(_to.length);
    require(cnt > 0 && cnt <= maxBatch && _value > 0);
    uint256 amount = _value.mul(cnt);
    require(_balances.balanceOf(msg.sender) >= amount);

    for (uint256 i = 0; i < cnt; i++) {
      _transfer(msg.sender, _to[i], _value);
    }
    return true;
  }

  /**
   * @dev Transfer tokens from other address
   * Send `_value` tokens to `_to` in behalf of `_from`
   *
   * @param _from The address of the sender
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transferFrom(address _from, address _to, uint256 _value)
  whenNotPaused onlyNotBlacklistedAddr(_from) onlyNotBlacklistedAddr(_to) onlyVerifiedAddr(_from) onlyVerifiedAddr(_to)
  public returns (bool) {
    require(_allowance.allowanceOf(_from, msg.sender) >= _value);     // Check allowance
    _allowance.subAllowance(_from, msg.sender, _value);
    _transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   *
   * Allows `_spender` to spend no more than `_value` tokens in your behalf
   *
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   */
  function approve(address _spender, uint256 _value)
  whenNotPaused onlyNotBlacklistedAddr(msg.sender) onlyNotBlacklistedAddr(_spender) onlyVerifiedAddr(msg.sender) onlyVerifiedAddr(_spender)
  public returns (bool) {
    _allowance.setAllowance(msg.sender, _spender, _value);
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint256 _addedValue)
  whenNotPaused onlyNotBlacklistedAddr(msg.sender) onlyNotBlacklistedAddr(_spender) onlyVerifiedAddr(msg.sender) onlyVerifiedAddr(_spender)
  public returns (bool) {
    _allowance.addAllowance(msg.sender, _spender, _addedValue);
    emit Approval(msg.sender, _spender, _allowance.allowanceOf(msg.sender, _spender));
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint256 _subtractedValue)
  whenNotPaused onlyNotBlacklistedAddr(msg.sender) onlyNotBlacklistedAddr(_spender) onlyVerifiedAddr(msg.sender) onlyVerifiedAddr(_spender)
  public returns (bool) {
    _allowance.subAllowance(msg.sender, _spender, _subtractedValue);
    emit Approval(msg.sender, _spender, _allowance.allowanceOf(msg.sender, _spender));
    return true;
  }

  /**
   * @dev Destroy tokens
   * Remove `_value` tokens from the system irreversibly
   *
   * @param _value the amount of money to burn
   */
  function burn(uint256 _value) whenNotPaused onlyNotBlacklistedAddr(msg.sender) onlyVerifiedAddr(msg.sender)
  public returns (bool success) {
    require(_balances.balanceOf(msg.sender) >= _value);         // Check if the sender has enough
    _balances.subBalance(msg.sender, _value);                   // Subtract from the sender
    _balances.subTotalSupply(_value);                           // Updates totalSupply
    emit Burn(msg.sender, _value);
    return true;
  }

  /**
   * @dev Change name and symbol of the tokens
   *
   * @param _name the new name of the token
   * @param _symbol the new symbol of the token
   */
  function changeName(string _name, string _symbol) onlyOwner whenNotPaused public {
    name = _name;
    symbol = _symbol;
  }
}
