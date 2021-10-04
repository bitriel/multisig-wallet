// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

/// @title Multisignature wallet - Allows multiple parties to agree on transactions before execution.
contract MultiSigWallet {
  using SafeMath for uint256;
  using SafeCast for uint8;
  using SafeERC20 for IERC20;

  event TransactionApproved(address indexed sender, uint256 indexed transactionId);
  event ApprovalRevoked(address indexed sender, uint256 indexed transactionId);
  event TransactionSubmitted(uint256 indexed transactionId);
  event TransactionExecuted(uint256 indexed transactionId);
  event ExecutionFailed(uint256 indexed transactionId);
  event Deposited(address indexed sender, uint256 value);
  event TokenDeposited(address indexed sender, IERC20 indexed token, uint256 value);
  event NewOwnerAdded(address indexed owner);
  event OwnerRemoval(address indexed owner);
  event RequirementChanged(uint256 required);

  struct Transaction {
    address payable to;
    uint value;
    bytes data;
    address token;
    uint8 approval;
    bool executed;
  }

  uint8 constant public MAX_OWNER = 50;

  mapping (uint256 => Transaction) public transactions;
  mapping (uint256 => mapping (address => bool)) public approvals;
  mapping (address => bool) public owners;
  // address[] public owners;
  uint8 public required;
  uint8 public ownerCount;
  uint256 public transactionCount;

  /// @dev Contract constructor sets initial owners and required number of confirmations.
  /// @param _owners List of initial owners.
  /// @param _required Number of required confirmations.
  constructor(address[] memory _owners, uint8 _required) 
    validate(uint8(_owners.length), _required) 
  {
    required = _required;
    ownerCount = uint8(_owners.length);

    for (uint8 i=0; i<_owners.length; i++) {
      require(!owners[_owners[i]]);
      owners[_owners[i]] = true;
    }
  }

  /// @dev deposit native token into this contract.
  receive() external payable {
    if (msg.value > 0)
      emit Deposited(msg.sender, msg.value);
  }

  function deposit(IERC20 _token, uint256 _value) external {
    require(_value > 0, "Invalid token amount");
    _token.safeTransferFrom(msg.sender, address(this), _value);

    emit TokenDeposited(msg.sender, _token, _value);
  }

  /// @dev Allows to add a new owner. Transaction has to be sent by wallet.
  /// @param _owner Address of new owner.
  function addOwner(address _owner) external
    isValid(_owner)
    isWallet
    notOwner(_owner)
    validate(ownerCount + 1, required)
  {
    owners[_owner] = true;
    ownerCount++;

    emit NewOwnerAdded(_owner);
  }

  /// @dev Allows to remove an owner. Transaction has to be sent by wallet.
  /// @param _owner Address of owner.
  function removeOwner(address _owner) external
    isWallet
    isOwner(_owner)
  {
    delete owners[_owner];
    ownerCount--;
    if (required > ownerCount)
      changeRequired(ownerCount);

    emit OwnerRemoval(_owner);
  }

  /// @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
  /// @param _owner Address of owner to be replaced.
  /// @param _newOwner Address of new owner.
  function replaceOwner(address _owner, address _newOwner) external
    isWallet
    isOwner(_owner)
    notOwner(_newOwner)
  {
    delete owners[_owner];
    owners[_newOwner] = true;

    emit OwnerRemoval(_owner);
    emit NewOwnerAdded(_newOwner);
  }

  /// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
  /// @param _required Number of required confirmations.
  function changeRequired(uint8 _required) public
    isWallet
    validate(ownerCount, _required)
  {
    required = _required;

    emit RequirementChanged(_required);
  }

  /// @dev Allows an owner to submit and approve a transaction.
  /// @param _to transaction destination address
  /// @param _value transaction value in Wei.
  /// @param _data transaction data payload.
  /// @return txnId returns transaction ID.
  function submit(address payable _to, uint256 _value, bytes calldata _data) external
    returns (uint256 txnId)
  {
    txnId = _addTransaction(address(0), _to, _value, _data);
    emit TransactionSubmitted(txnId);
    approve(txnId);
  }

  /// @dev Allows an owner to submit and approve a transaction on BEP-20 tokens.
  /// @param _token a BEP-20 token address
  /// @param _to transaction destination address
  /// @param _value transaction value in Wei.
  /// @param _data transaction data payload.
  /// @return txnId returns transaction ID.
  function submitToken(address _token, address payable _to, uint256 _value, bytes calldata _data) external 
    returns (uint256 txnId) 
  {
    txnId = _addTransaction(_token, _to, _value, _data);
    emit TransactionSubmitted(txnId);
    approve(txnId);
  }

  /// @dev Allows an owner to approve a transaction.
  /// @param _txnId transaction ID.
  function approve(uint256 _txnId) public
    isOwner(msg.sender)
    hasTransaction(_txnId)
    notApproved(_txnId, msg.sender)
  {
    transactions[_txnId].approval++;
    approvals[_txnId][msg.sender] = true;
    emit TransactionApproved(msg.sender, _txnId);
    execute(_txnId);
  }

  /// @dev Allows an owner to revoke a approval for a transaction.
  /// @param _txnId transaction ID.
  function revokeApproval(uint256 _txnId) external
    isOwner(msg.sender)
    approved(_txnId, msg.sender)
    notExecuted(_txnId)
  {
    transactions[_txnId].approval--;
    approvals[_txnId][msg.sender] = false;
    emit ApprovalRevoked(msg.sender, _txnId);
  }

  /// @dev Allows anyone to execute a approved transaction.
  /// @param _txnId transaction ID.
  /// @return success wether it's success
  function execute(uint256 _txnId) public
    isOwner(msg.sender)
    approved(_txnId, msg.sender)
    notExecuted(_txnId)
    returns (bool success)
  {
    if (isConfirmed(_txnId)) {
      Transaction storage txn = transactions[_txnId];
      bool result = false;

      if(txn.token == address(0)) 
        (result, ) = txn.to.call{value: txn.value}("");
      else 
        result = IERC20(txn.token).transfer(txn.to, txn.value);
        
      if (result) {
        emit TransactionExecuted(_txnId);
        txn.executed = true;
      } else {
        emit ExecutionFailed(_txnId);
      }

      return txn.executed;
    }
  }

  /// @dev Returns the confirmation status of a transaction.
  /// @param _txnId transaction ID.
  /// @return status confirmation status.
  function isConfirmed(uint _txnId) public view returns (bool status) {
    if (transactions[_txnId].approval >= required)
      return true;

    // uint count = 0;
    //     for (uint i=0; i<owners.length; i++) {
    //         if (confirmations[transactionId][owners[i]])
    //             count += 1;
    //         if (count == required)
    //             return true;
    //     }
  }

  /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
  /// @param _token `0x` if token is native, otherwise is BEP20 token address
  /// @param _to transaction destination address
  /// @param _value transaction value in Wei.
  /// @param _data transaction data payload.
  /// @return txnId returns transaction ID.
  function _addTransaction(address _token, address payable _to, uint _value, bytes calldata _data) internal
    isValid(_to)
    returns (uint txnId)
  {
    txnId = transactionCount++;
    transactions[txnId] = Transaction({
      to: _to,
      value: _value,
      data: _data,
      token: _token,
      approval: 0,
      executed: false
    });
    // transactionCount++;
    emit TransactionSubmitted(txnId);
  }

  /// @dev Returns number of approvals of a transaction.
  /// @param _txnId transaction ID.
  /// @return count Number of approvals.
  function getApprovalCount(uint _txnId) external view returns (uint8 count) {
    count = transactions[_txnId].approval;
    // for (uint i=0; i<owners.length; i++)
    //   if (confirmations[_txnId][owners[i]])
    //     count += 1;
  }

  /// @dev Returns total number of transactions which filers are applied.
  /// @param _pending Include pending transactions.
  /// @param _executed Include executed transactions.
  /// @return count Total number of transactions after filters are applied.
  function getTransactionCount(bool _pending, bool _executed) external view returns (uint256 count)
  {
    for (uint256 i=0; i<transactionCount; i++)
      if (_pending && !transactions[i].executed || _executed && transactions[i].executed)
        count++;
  }

  // /// @dev Returns list of owners.
  // /// @return List of owner addresses.
  // function getOwners()
  //     public
  //     constant
  //     returns (address[])
  // {
  //     return owners;
  // }

  // /// @dev Returns array with owner addresses, which confirmed transaction.
  // /// @param transactionId Transaction ID.
  // /// @return Returns array of owner addresses.
  // function getConfirmations(uint transactionId)
  //     public
  //     constant
  //     returns (address[] _confirmations)
  // {
  //     address[] memory confirmationsTemp = new address[](owners.length);
  //     uint count = 0;
  //     uint i;
  //     for (i=0; i<owners.length; i++)
  //         if (confirmations[transactionId][owners[i]]) {
  //             confirmationsTemp[count] = owners[i];
  //             count += 1;
  //         }
  //     _confirmations = new address[](count);
  //     for (i=0; i<count; i++)
  //         _confirmations[i] = confirmationsTemp[i];
  // }

  // /// @dev Returns list of transaction IDs in defined range.
  // /// @param _from Index start position of transaction array.
  // /// @param _to Index end position of transaction array.
  // /// @param __pending Include pending transactions.
  // /// @param _executed Include executed transactions.
  // /// @return Returns array of transaction IDs.
  // function getTransactionIds(uint256 _from, uint256 _to, bool _pending, bool _executed) external view
  //   returns (uint256[] memory transactionIds)
  // {
  //   uint256[] memory temp;
  //   for (uint256 i=_from; i<=_to; i++)
  //     if (_pending && !transactions[i].executed || _executed && transactions[i].executed)
  //       temp.push(i);
    
  //   transactionIds = temp;
  // }

  modifier isWallet() {
    require(msg.sender == address(this));
    _;
  }

  modifier notOwner(address _owner) {
    require(!owners[_owner]);
    _;
  }

  modifier isOwner(address _owner) {
    require(owners[_owner]);
    _;
  }

  modifier hasTransaction(uint _txnId) {
    require(transactions[_txnId].to != address(0));
    _;
  }

  modifier approved(uint _txnId, address _owner) {
    require(approvals[_txnId][_owner]);
    _;
  }

  modifier notApproved(uint _txnId, address _owner) {
    require(!approvals[_txnId][_owner]);
    _;
  }

  modifier notExecuted(uint _txnId) {
    require(!transactions[_txnId].executed);
    _;
  }

  modifier isValid(address _address) {
    require(_address != address(0));
    _;
  }

  modifier validate(uint8 _ownerCount, uint8 _required) {
    require(_required != 0 && _ownerCount != 0 
      && _ownerCount <= MAX_OWNER
      && _required <= _ownerCount
    );
    _;
  }
}
