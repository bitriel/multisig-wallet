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

  event TransactionConfirmed(address indexed sender, uint256 indexed transactionId);
  event ConfirmationRevoked(address indexed sender, uint256 indexed transactionId);
  event TransactionSubmitted(uint256 indexed transactionId);
  event TransactionExecuted(uint256 indexed transactionId);
  event ExecutionFailed(uint256 indexed transactionId);
  event Deposited(address indexed sender, uint256 value);
  event TokenDeposited(address indexed sender, IERC20 indexed token, uint256 value);
  event NewOwnerAdded(address indexed owner);
  event OwnerRemoval(address indexed owner);
  event RequirementChanged(uint256 required);

  struct Transaction {
    address to;
    uint value;
    bytes data;
    bool executed;
  }

  uint8 constant public MAX_OWNER = 50;

  mapping (uint256 => Transaction) public transactions;
  mapping (uint256 => mapping (address => bool)) public confirmations;
  mapping (address => bool) public isOwner;
  uint8 public required;
  uint256 public ownerCount;
  uint256 public transactionCount;

  /// @dev Contract constructor sets initial owners and required number of confirmations.
  /// @param _owners List of initial owners.
  /// @param _required Number of required confirmations.
  constructor(address[] memory _owners, uint _required) public validate(_owners.length, _required) {
    required = _required;
    ownerCount = _owners.length;

    for (uint i=0; i<_owners.length; i++) {
      require(!isOwner[_owners[i]]);
      isOwner[_owners[i]] = true;
    }
  }

  /// @dev deposit native token into this contract.
  receive() external payable {
    if (msg.value > 0)
      emit Deposited(msg.sender, msg.value);
  }

  function deposit(IERC20 token, uint256 value) external {
    require(value > 0, "Invalid token amount");
    token.safeTransferFrom(msg.sender, address(this), value);

    emit TokenDeposited(msg.sender, token, value);
  }

  /// @dev Allows to add a new owner. Transaction has to be sent by wallet.
  /// @param _owner Address of new owner.
  function addOwner(address _owner) external
    isValid(_owner)
    isWallet
    notOwner(_owner)
    validate(ownerCount + 1, required)
  {
    isOwner[_owner] = true;
    ownerCount++;

    emit NewOwnerAdded(_owner);
  }

  /// @dev Allows to remove an owner. Transaction has to be sent by wallet.
  /// @param _owner Address of owner.
  function removeOwner(address _owner) external
    isWallet
    isOwner(_owner)
  {
    delete isOwner[_owner];
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
    delete isOwner[_owner];
    isOwner[_newOwner] = true;

    emit OwnerRemoval(_owner);
    emit NewOwnerAdded(_newOwner);
  }

  /// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
  /// @param _required Number of required confirmations.
  function changeRequired(uint _required)
    public
    isWallet
    validate(ownerCount, _required)
  {
    required = _required;

    emit RequirementChanged(_required);
  }

  /// @dev Allows an owner to submit and confirm a transaction.
  /// @param _to Transaction target address.
  /// @param _value Transaction ether value.
  /// @param _data Transaction data payload.
  /// @return Returns transaction ID.
  function submitTransaction(address _to, uint _value, bytes calldata _data) external
    returns (uint transactionId)
  {
    transactionId = _addTransaction(_to, _value, _data);
    confirmTransaction(transactionId);
  }

  /// @dev Allows an owner to confirm a transaction.
  /// @param _transactionId Transaction ID.
  function confirmTransaction(uint _transactionId) public
    ownerExists(msg.sender)
    transactionExists(transactionId)
    notConfirmed(transactionId, msg.sender)
  {
      confirmations[transactionId][msg.sender] = true;
      Confirmation(msg.sender, transactionId);
      executeTransaction(transactionId);
  }

  /// @dev Allows an owner to revoke a confirmation for a transaction.
  /// @param transactionId Transaction ID.
  function revokeConfirmation(uint transactionId)
      public
      ownerExists(msg.sender)
      confirmed(transactionId, msg.sender)
      notExecuted(transactionId)
  {
      confirmations[transactionId][msg.sender] = false;
      Revocation(msg.sender, transactionId);
  }

  /// @dev Allows anyone to execute a confirmed transaction.
  /// @param transactionId Transaction ID.
  function executeTransaction(uint transactionId)
      public
      ownerExists(msg.sender)
      confirmed(transactionId, msg.sender)
      notExecuted(transactionId)
  {
      if (isConfirmed(transactionId)) {
          Transaction storage txn = transactions[transactionId];
          txn.executed = true;
          if (external_call(txn.destination, txn.value, txn.data.length, txn.data))
              Execution(transactionId);
          else {
              ExecutionFailure(transactionId);
              txn.executed = false;
          }
      }
  }

  // call has been separated into its own function in order to take advantage
  // of the Solidity's code generator to produce a loop that copies tx.data into memory.
  function external_call(address destination, uint value, uint dataLength, bytes data) internal returns (bool) {
      bool result;
      assembly {
          let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
          let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
          result := call(
              sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
                                  // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                  // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
              destination,
              value,
              d,
              dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
              x,
              0                  // Output is ignored, therefore the output size is zero
          )
      }
      return result;
  }

  /// @dev Returns the confirmation status of a transaction.
  /// @param transactionId Transaction ID.
  /// @return Confirmation status.
  function isConfirmed(uint transactionId)
      public
      constant
      returns (bool)
  {
      uint count = 0;
      for (uint i=0; i<owners.length; i++) {
          if (confirmations[transactionId][owners[i]])
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
  /// @param data Transaction data payload.
  /// @return Returns transaction ID.
  function addTransaction(address destination, uint value, bytes data)
      internal
      notNull(destination)
      returns (uint transactionId)
  {
      transactionId = transactionCount;
      transactions[transactionId] = Transaction({
          destination: destination,
          value: value,
          data: data,
          executed: false
      });
      transactionCount += 1;
      Submission(transactionId);
  }

  /*
    * Web3 call functions
    */
  /// @dev Returns number of confirmations of a transaction.
  /// @param transactionId Transaction ID.
  /// @return Number of confirmations.
  function getConfirmationCount(uint transactionId)
      public
      constant
      returns (uint count)
  {
      for (uint i=0; i<owners.length; i++)
          if (confirmations[transactionId][owners[i]])
              count += 1;
  }

  /// @dev Returns total number of transactions after filers are applied.
  /// @param pending Include pending transactions.
  /// @param executed Include executed transactions.
  /// @return Total number of transactions after filters are applied.
  function getTransactionCount(bool pending, bool executed)
      public
      constant
      returns (uint count)
  {
      for (uint i=0; i<transactionCount; i++)
          if (   pending && !transactions[i].executed
              || executed && transactions[i].executed)
              count += 1;
  }

  /// @dev Returns list of owners.
  /// @return List of owner addresses.
  function getOwners()
      public
      constant
      returns (address[])
  {
      return owners;
  }

  /// @dev Returns array with owner addresses, which confirmed transaction.
  /// @param transactionId Transaction ID.
  /// @return Returns array of owner addresses.
  function getConfirmations(uint transactionId)
      public
      constant
      returns (address[] _confirmations)
  {
      address[] memory confirmationsTemp = new address[](owners.length);
      uint count = 0;
      uint i;
      for (i=0; i<owners.length; i++)
          if (confirmations[transactionId][owners[i]]) {
              confirmationsTemp[count] = owners[i];
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
  function getTransactionIds(uint from, uint to, bool pending, bool executed)
      public
      constant
      returns (uint[] _transactionIds)
  {
      uint[] memory transactionIdsTemp = new uint[](transactionCount);
      uint count = 0;
      uint i;
      for (i=0; i<transactionCount; i++)
          if (   pending && !transactions[i].executed
              || executed && transactions[i].executed)
          {
              transactionIdsTemp[count] = i;
              count += 1;
          }
      _transactionIds = new uint[](to - from);
      for (i=from; i<to; i++)
          _transactionIds[i - from] = transactionIdsTemp[i];
  }

  modifier isWallet() {
    require(msg.sender == address(this));
    _;
  }

  modifier notOwner(address _owner) {
    require(!isOwner[_owner]);
    _;
  }

  modifier isOwner(address _owner) {
    require(isOwner[_owner]);
    _;
  }

  modifier hasTransaction(uint _transactionId) {
    require(transactions[_transactionId].to != 0);
    _;
  }

  modifier confirmed(uint _transactionId, address _owner) {
    require(confirmations[_transactionId][_owner]);
    _;
  }

  modifier notConfirmed(uint _transactionId, address _owner) {
    require(!confirmations[_transactionId][_owner]);
    _;
  }

  modifier notExecuted(uint _transactionId) {
    require(!transactions[_transactionId].executed);
    _;
  }

  modifier isValid(address _address) {
    require(_address != 0);
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
