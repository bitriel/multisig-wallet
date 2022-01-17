// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./utils/Types.sol";
import "./base/OwnerManager.sol";
import "./base/Executor.sol";
import "./handler/TokensHandler.sol";

/// @title Multisignature wallet - Allows multiple parties to agree on transactions before execution.
contract MultiSigWallet is OwnerManager, Executor, TokensHandler, Initializable {
  event Received(address indexed sender, uint256 value);
  event TransactionApproved(address indexed sender, uint256 indexed transactionId);
  event ApprovalRevoked(address indexed sender, uint256 indexed transactionId);
  event TransactionSubmitted(uint256 indexed transactionId);
  event TransactionExecuted(uint256 indexed transactionId);
  event ExecutionFailed(uint256 indexed transactionId);

  struct Transaction {
    Types.Operation operation;
    address target;
    uint256 value;
    bytes data;
    uint8 approval;
    bool executed;
  }

  uint8 constant public MAX_OWNER = 50;

  mapping (uint256 => Transaction) public transactions;
  mapping (uint256 => mapping (address => bool)) public approvals;
  uint256 public transactionCount;

  /// @dev sets initial owners and required number of confirmations.
  /// @param _owners List of initial owners.
  /// @param _required Number of required confirmations.
  function initialize(address[] memory _owners, uint8 _required) public initializer {
    setupOwners(_owners, _required);
  }

  /// @dev deposit native token into this contract.
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /// @dev Allows an owner to submit and approve a transaction.
  /// @param operation external call operation
  /// @param target transaction destination address
  /// @param value transaction value in Wei.
  /// @param data transaction data payload.
  /// @return txnId returns transaction ID.
  function submitTransaction(
    Types.Operation operation, 
    address target, 
    uint256 value, 
    bytes memory data
  ) public returns (uint256 txnId) 
  {
    txnId = _addTransaction(operation, target, value, data);
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
    executeTransaction(_txnId);
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
  function executeTransaction(uint256 _txnId) public
    isOwner(msg.sender)
    approved(_txnId, msg.sender)
    notExecuted(_txnId)
    returns (bool success)
  {
    if (isConfirmed(_txnId)) {
      Transaction storage txn = transactions[_txnId];
      success = execute(txn.operation, txn.target, txn.value, txn.data, (gasleft() - 2500));
      if (success) {
        txn.executed = true;
        emit TransactionExecuted(_txnId);
      } else {
        txn.executed = false;
        emit ExecutionFailed(_txnId);
      }
    }
  }

  /// @dev Returns the confirmation status of a transaction.
  /// @param _txnId transaction ID.
  /// @return status confirmation status.
  function isConfirmed(uint _txnId) public view returns (bool status) {
    status = transactions[_txnId].approval >= getThreshold();
  }

  /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
  /// @param operation external call operation
  /// @param target transaction destination address
  /// @param value transaction value in Wei.
  /// @param data transaction data payload.
  /// @return txnId returns transaction ID.
  function _addTransaction(
    Types.Operation operation, 
    address target, 
    uint256 value, 
    bytes memory data
  ) internal
    isValid(target)
    returns (uint txnId)
  {
    txnId = transactionCount++;
    transactions[txnId] = Transaction({
      operation: operation,
      target: target,
      value: value,
      data: data,
      approval: 0,
      executed: false
    });
    
    emit TransactionSubmitted(txnId);
  }

  /// @dev Returns number of approvals of a transaction.
  /// @param _txnId transaction ID.
  /// @return count Number of approvals.
  function getApprovalCount(uint _txnId) external view returns (uint8 count) {
    count = transactions[_txnId].approval;
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

  modifier hasTransaction(uint256 _txnId) {
    require(_txnId < transactionCount, "transaction is not exist");
    _;
  }

  modifier approved(uint256 _txnId, address _owner) {
    require(approvals[_txnId][_owner], "not been approved by this owner");
    _;
  }

  modifier notApproved(uint256 _txnId, address _owner) {
    require(!approvals[_txnId][_owner], "has been approved by this owner");
    _;
  }

  modifier notExecuted(uint256 _txnId) {
    require(!transactions[_txnId].executed, "transaction is executed");
    _;
  }

  modifier isValid(address _address) {
    require(_address != address(0), "this address is zero address");
    _;
  }
}
