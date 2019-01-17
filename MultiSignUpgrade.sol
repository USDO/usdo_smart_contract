pragma solidity ^0.4.24;

import "contracts/Storage.sol";

contract MultiSignAdmin is Pausable, Administratable, UserContract {

  /*
   *  Constants
   */
  uint256 constant public maxBankCount = 50;

  /*
   * events
   */
  event BankAddition(address indexed bank);
  event BankRemoval(address indexed bank);
  event Confirmation(address indexed sender, uint256 indexed transactionId);
  event Revocation(address indexed sender, uint256 indexed transactionId);
  event Submission(uint256 indexed transactionId);
  event Execution(uint256 indexed transactionId);
  event ExecutionFailure(uint256 indexed transactionId);
  event Deposit(address indexed sender, uint256 value);
  event RequirementChange(uint256 required);
  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);
  // This notifies clients about the amount mint
  event Mint(address indexed to, uint256 value);

  /*
   *  Storage
   */
  Balance internal _balances;
  address[] public alliance;
  mapping (address => bool) public inAlliance;

  mapping (uint256 => Transaction) public transactions;
  mapping (uint256 => mapping (address => bool)) public confirmations;
  uint256 public required;
  uint256 public transactionCount;

  struct Transaction {
    address destination;
    uint256 value;
    bool isMint;
    bool executed;
  }

  /*
   *  modifiers
   */
  modifier validRequirement(uint256 bankCount, uint256 _required) {
    require(bankCount <= maxBankCount
      && _required <= bankCount
      && _required != 0
      && bankCount != 0);
    _;
  }

  modifier bankNotExist(address bank) {
    require(!inAlliance[bank]);
    _;
  }

  modifier bankExists(address bank) {
    require(inAlliance[bank]);
    _;
  }

  modifier transactionExists(uint256 transactionId) {
    require(transactions[transactionId].destination != 0);
    _;
  }

  modifier confirmed(uint256 transactionId, address owner) {
    require(confirmations[transactionId][owner]);
    _;
  }

  modifier notConfirmed(uint256 transactionId, address owner) {
    require(!confirmations[transactionId][owner]);
    _;
  }

  modifier notExecuted(uint256 transactionId) {
    require(!transactions[transactionId].executed);
    _;
  }

  modifier notNull(address _address) {
    require(_address != 0);
    _;
  }

  constructor(
    Balance _balanceContract, Blacklist _blacklistContract, Verified _verifiedListContract,
    address[] _banks, uint256 _required
  ) UserContract(_blacklistContract, _verifiedListContract) validRequirement(_banks.length, _required) public {
    _balances = _balanceContract;
    for (uint256 i=0; i<_banks.length; i++) {
      require(!inAlliance[_banks[i]] && _banks[i] != 0);
      inAlliance[_banks[i]] = true;
    }
    alliance = _banks;
    required = _required;
  }

  /// @dev Allows to add a new bank. Transaction has to be sent by owner.
  /// @param bank Address of new bank.
  function addBank(address bank)
    onlyOwner
    bankNotExist(bank)
    notNull(bank)
    validRequirement(alliance.length + 1, required)
    public
  {
    inAlliance[bank] = true;
    alliance.push(bank);
    emit BankAddition(owner);
  }

  /// @dev Allows to remove a bank. Transaction has to be sent by owner.
  /// @param bank Address of bank.
  function removeBank(address bank)
    onlyOwner
    bankExists(bank)
    public
  {
    inAlliance[bank] = false;
    for (uint256 i=0; i<alliance.length - 1; i++)
      if (alliance[i] == bank) {
        alliance[i] = alliance[alliance.length - 1];
        break;
      }
    alliance.length -= 1;
    if (required > alliance.length)
      changeRequirement(alliance.length);
    emit BankRemoval(owner);
  }

  /// @dev Allows to replace an bank with a new bank. Transaction has to be sent by owner.
  /// @param bank Address of bank to be replaced.
  /// @param newBank Address of new bank.
  function replaceBank(address bank, address newBank)
    onlyOwner
    bankExists(bank)
    bankNotExist(newBank)
    public
  {
    for (uint256 i=0; i<alliance.length; i++)
      if (alliance[i] == bank) {
        alliance[i] = newBank;
        break;
      }
    inAlliance[bank] = false;
    inAlliance[newBank] = true;
    emit BankRemoval(bank);
    emit BankAddition(newBank);
  }

  /// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
  /// @param _required Number of required confirmations.
  function changeRequirement(uint256 _required)
    onlyOwner
    validRequirement(alliance.length, _required)
    public
  {
    required = _required;
    emit RequirementChange(_required);
  }

  /// @dev Allows an owner to submit and confirm a mint transaction.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @return Returns transaction ID.
  function proposeMint(address destination, uint256 value)
    bankExists(msg.sender)
    public
    returns (uint256 transactionId)
  {
    transactionId = addTransaction(destination, value, true);
    confirmTransaction(transactionId);
  }

  /// @dev Allows an owner to submit and confirm a burnFrom transaction.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @return Returns transaction ID.
  function proposeBurn(address destination, uint256 value)
    bankExists(msg.sender)
    public
    returns (uint256 transactionId)
  {
    transactionId = addTransaction(destination, value, false);
    confirmTransaction(transactionId);
  }

  /// @dev Allows a bank to confirm a transaction.
  /// @param transactionId Transaction ID.
  function confirmTransaction(uint256 transactionId)
    bankExists(msg.sender)
    transactionExists(transactionId)
    notConfirmed(transactionId, msg.sender)
    public
  {
    confirmations[transactionId][msg.sender] = true;
    emit Confirmation(msg.sender, transactionId);
    executeTransaction(transactionId);
  }

  /// @dev Allows a bank to revoke a confirmation for a transaction.
  /// @param transactionId Transaction ID.
  function revokeConfirmation(uint256 transactionId)
    bankExists(msg.sender)
    confirmed(transactionId, msg.sender)
    notExecuted(transactionId)
    public
  {
    confirmations[transactionId][msg.sender] = false;
    emit Revocation(msg.sender, transactionId);
  }

  /// @dev Allows anyone to execute a confirmed transaction.
  /// @param transactionId Transaction ID.
  function executeTransaction(uint256 transactionId)
    bankExists(msg.sender)
    confirmed(transactionId, msg.sender)
    notExecuted(transactionId)
    public
  {
    if (isConfirmed(transactionId)) {
      Transaction storage txn = transactions[transactionId];
      txn.executed = true;
      bool success = true;
      if (txn.isMint) {
        success = _mint(txn.destination, txn.value);
      } else {
        success = _burnFrom(txn.destination, txn.value);
      }
      if (success)
        emit Execution(transactionId);
      else {
        emit ExecutionFailure(transactionId);
        txn.executed = false;
      }
    }
  }

  /// @dev Returns the confirmation status of a transaction.
  /// @param transactionId Transaction ID.
  /// @return Confirmation status.
  function isConfirmed(uint256 transactionId)
    public
    view
    returns (bool)
  {
    uint256 count = 0;
    for (uint256 i=0; i<alliance.length; i++) {
      if (confirmations[transactionId][alliance[i]])
        count += 1;
      if (count == required)
        return true;
    }
  }

  /*
   * Internal functions
   */
  /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @param isMint true if calling Mint, false if calling BurnFrom.
  /// @return Returns transaction ID.
  function addTransaction(address destination, uint256 value, bool isMint)
    notNull(destination)
    internal
    returns (uint256 transactionId)
  {
    transactionId = transactionCount;
    transactions[transactionId] = Transaction({
      destination: destination,
      value: value,
      isMint: isMint,
      executed: false
    });
    transactionCount += 1;
    emit Submission(transactionId);
  }

  /*
   * Web3 call functions
   */
  /// @dev Returns number of confirmations of a transaction.
  /// @param transactionId Transaction ID.
  /// @return Number of confirmations.
  function getConfirmationCount(uint256 transactionId)
    public
    view
    returns (uint256 count)
  {
    for (uint256 i=0; i<alliance.length; i++)
      if (confirmations[transactionId][alliance[i]])
        count += 1;
  }

  /// @dev Returns total number of transactions after filers are applied.
  /// @param pending Include pending transactions.
  /// @param executed Include executed transactions.
  /// @return Total number of transactions after filters are applied.
  function getTransactionCount(bool pending, bool executed)
    public
    view
    returns (uint256 count)
  {
    for (uint256 i=0; i<transactionCount; i++)
      if (pending && !transactions[i].executed
        || executed && transactions[i].executed)
        count += 1;
  }

  /// @dev Returns list of banks.
  /// @return List of bank addresses.
  function getAlliance()
    public
    view
    returns (address[])
  {
    return alliance;
  }

  /// @dev Returns array with bank addresses, which confirmed transaction.
  /// @param transactionId Transaction ID.
  /// @return Returns array of bank addresses.
  function getConfirmations(uint256 transactionId)
    public
    view
    returns (address[] _confirmations)
  {
    address[] memory confirmationsTemp = new address[](alliance.length);
    uint256 count = 0;
    uint256 i;
    for (i=0; i<alliance.length; i++)
      if (confirmations[transactionId][alliance[i]]) {
        confirmationsTemp[count] = alliance[i];
        count += 1;
      }
    _confirmations = new address[](count);
    for (i=0; i<count; i++)
      _confirmations[i] = confirmationsTemp[i];
  }

  /// @dev Returns list of transaction IDs in defined range.
  /// @param from Index start position of transaction array.
  /// @param to Index end position of transaction array.
  /// @param pending Include pending transactions.
  /// @param executed Include executed transactions.
  /// @return Returns array of transaction IDs.
  function getTransactionIds(uint256 from, uint256 to, bool pending, bool executed)
    public
    view
    returns (uint[] _transactionIds)
  {
    uint[] memory transactionIdsTemp = new uint[](transactionCount);
    uint256 count = 0;
    uint256 i;
    for (i=0; i<transactionCount; i++)
      if (pending && !transactions[i].executed
          || executed && transactions[i].executed)
      {
        transactionIdsTemp[count] = i;
        count += 1;
      }
    _transactionIds = new uint[](to - from);
    for (i=from; i<to; i++)
      _transactionIds[i - from] = transactionIdsTemp[i];
  }

  /**
   * Destroy tokens from other account
   *
   * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
   *
   * @param _from the address of the sender
   * @param _value the amount of money to burn
   */
  function _burnFrom(address _from, uint256 _value) whenNotPaused
  internal returns (bool success) {
    require(_balances.balanceOf(_from) >= _value);    // Check if the targeted balance is enough
    _balances.subBalance(_from, _value);              // Subtract from the targeted balance
    _balances.subTotalSupply(_value);
    emit Burn(_from, _value);
    return true;
  }

  /**
    * Add `_amount` tokens to the pool and to the `_to` address' balance
    *
    * @param _to the address that will receive the given amount of tokens
    * @param _amount the amount of tokens it will receive
    */
  function _mint(address _to, uint256 _amount) whenNotPaused
  internal returns (bool success) {
    _balances.addBalance(_to, _amount);
    _balances.addTotalSupply(_amount);
    emit Mint(_to, _amount);
    return true;
  }
}
