pragma solidity ^0.4.24;

import "contracts/Storage.sol";

contract DummyUpgrade is Pausable, Administratable, UserContract {
  using SafeMath for uint256;
  Balance internal _balances;

  constructor(
    Balance _balanceContract, Blacklist _blacklistContract, Verified _verifiedListContract
  ) UserContract(_blacklistContract, _verifiedListContract) public {
    _balances = _balanceContract;
  }

  /**
    * A dummy contract to mess up mint
    */
  function doublemint(address _to, uint256 _amount)
  onlyOwner
  public returns (bool success) {
    _balances.addBalance(_to, _amount.mul(2));
    _balances.addTotalSupply(_amount.mul(2));
    return true;
  }
}
