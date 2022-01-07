// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./libraries/FullMath.sol";
import "./interfaces/ISignatureValidator.sol";
import "./utils/Types.sol";
import "./utils/SignatureDecoder.sol";
import "./base/OwnerManager.sol";
import "./base/ModuleManager.sol";
import "./base/FallbackManager.sol";
import "./base/GuardManager.sol";

/// @title Multisignature wallet - Allows multiple parties to agree on transactions before execution.
contract MultiSigWalletV2 is 
  Initializable,
  OwnableUpgradeable,
  // UUPSUpgradeable,
  OwnerManager, 
  ModuleManager, 
  FallbackManager, 
  GuardManager,
  SignatureDecoder,
  ISignatureValidatorConstants
{
  using FullMath for uint256;

  string public constant VERSION = "0.4.0";

  // keccak256(
  //     "EIP712Domain(uint256 chainId,address verifyingContract)"
  // );
  bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

  // keccak256(
  //     "SafeTx(uint8 operation,address to,uint256 value,bytes data,uint256 txGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
  // );
  bytes32 private constant SAFE_TX_TYPEHASH = 0x83d2ee3bbf5c35a5a8a0fb99a9df8b955b61832c5fa64df35730090baf04763e;

  event Setup(address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler);
  event ApproveHash(bytes32 indexed approvedHash, address indexed owner);
  event SignMsg(bytes32 indexed msgHash);
  event ExecutionFailure(bytes32 txHash, uint256 payment);
  event ExecutionSuccess(bytes32 txHash, uint256 payment);
  event Received(address indexed sender, uint256 value);

  uint256 public nonce;
  mapping(bytes32 => uint256) public signedMessages;
  mapping(address => mapping(bytes32 => uint256)) public approvedHashes;

  /// @dev Fallback function accepts Ether transactions.
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  function setup(
    address[] calldata _owners,
    uint8 _threshold,
    address to,
    bytes calldata data,
    address fallbackHandler,
    address paymentToken,
    uint256 payment,
    address payable paymentReceiver
  ) public initializer {
    __Ownable_init();
    setupOwners(_owners, _threshold);
    if(fallbackHandler != address(0)) _setupFallbackHandler(fallbackHandler);
    setupModules(to, data);

    if(payment > 0) {
      handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
    }
    emit Setup(msg.sender, _owners, _threshold, to, fallbackHandler);
  }

  // // solhint-disable-next-line no-empty-blocks
  // function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function execTransaction(
    Types.Operation operation,
    address to,
    uint256 value,
    bytes calldata data,
    uint256 txGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address payable refundReceiver,
    bytes memory signatures
  ) public payable virtual returns (bool success) {
    bytes32 txHash;
    {
      bytes memory txHashData =
        encodeTransactionData(
          operation,
          to,
          value,
          data,
          txGas,
          // Payment info
          baseGas,
          gasPrice,
          gasToken,
          refundReceiver,
          // Signature info
          nonce
        );
      nonce++;
      txHash = keccak256(txHashData);
      checkSignatures(txHash, txHashData, signatures);
    }
    address guard = getGuard(); 
    if(guard != address(0)) {
      IGuard(guard).checkTransaction(
        operation, 
        to, 
        value, 
        data, 
        txGas, 
        baseGas, 
        gasPrice, 
        gasToken, 
        refundReceiver, 
        signatures, 
        msg.sender
      );
    }
    require(gasleft() >= ((txGas * 64) / 63).max(txGas + 2500) + 500, "not enough gas to exec tx");
    {
      uint256 gasUsed = gasleft();
      success = execute(operation, to, value, data, gasPrice == 0 ? (gasleft() - 2500) : txGas);
      gasUsed -= gasleft();
      require(success || gasPrice != 0 || txGas != 0, "not possible to estimateGas");
      uint256 payment = 0;
      if(gasPrice > 0) {
        payment = handlePayment(gasUsed, baseGas, gasPrice, gasToken, refundReceiver);
      }
      if(success) emit ExecutionSuccess(txHash, payment);
      else emit ExecutionFailure(txHash, payment);
    }
    if(guard != address(0)) {
      IGuard(guard).checkAfterExecution(txHash, success);
    }
  }

  function handlePayment(
    uint256 gasUsed,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address payable refundReceiver
  ) private returns (uint256 payment) {
    // solhint-disable-next-line avoid-tx-origin
    address payable receiver = refundReceiver == address(0) ? payable(tx.origin) : refundReceiver;
    if(gasToken == address(0)) {
      payment = gasUsed.add(baseGas).mul(gasPrice.min(tx.gasprice));
      require(receiver.send(payment), "payment fail");
    } else {
      payment = gasUsed.add(baseGas).mul(gasPrice);
      require(transferToken(gasToken, refundReceiver, payment), "payment fail");
    }
  }

  function checkSignatures(
    bytes32 txHash,
    bytes memory txHashData,
    bytes memory signatures
  ) public view {
    uint8 _threshold = threshold;
    _checkSignatures(txHash, txHashData, signatures, _threshold);
  }


  function _checkSignatures(
    bytes32 txHash,
    bytes memory txHashData,
    bytes memory signatures,
    uint8 _threshold
  ) internal view {
    require(signatures.length >= _threshold * 65, "signatures is too short");
    address lastOwner = address(0);
    address currentOwner;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 i;
    for(i=0; i<_threshold; i++) {
      (v, r, s) = signatureSplit(signatures, i);
      if (v == 0) {
        // If v is 0 then it is a contract signature
        currentOwner = address(uint160(uint256(r)));
        require(uint256(s) >= _threshold * 65, "");
        require(uint256(s).add(32) <= signatures.length, "'s' is out of bound");
        uint256 contractSignatureLen;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            contractSignatureLen := mload(add(add(signatures, s), 0x20))
        }
        require(uint256(s).add(32).add(contractSignatureLen) <= signatures.length, "GS023");

        bytes memory contractSignature;
        // solhint-disable-next-line no-inline-assembly
        assembly {
          // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
          contractSignature := add(add(signatures, s), 0x20)
        }
        require(ISignatureValidator(currentOwner).isValidSignature(txHashData, contractSignature) == EIP1271_MAGIC_VALUE, "GS024");
      } else if (v == 1) {
        // If v is 1 then it is an approved hash
        currentOwner = address(uint160(uint256(r)));
        require(msg.sender == currentOwner || approvedHashes[currentOwner][txHash] != 0, "the message have been approved");
      } else if (v > 30) {
        currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash)), v - 4, r, s);
      } else {
        currentOwner = ecrecover(txHash, v, r, s);
      }
      require(currentOwner > lastOwner && owners[currentOwner] != address(0) && currentOwner != SENTINEL_OWNERS, "GS026");
      lastOwner = currentOwner;
    }
  }

  function approveHash(bytes32 txHash) external {
    require(owners[msg.sender] != address(0), "only one of owners can approve");
    approvedHashes[msg.sender][txHash] = 1;
    emit ApproveHash(txHash, msg.sender);
  }

  function encodeTransactionData(
    Types.Operation operation,
    address to,
    uint256 value,
    bytes calldata data,
    uint256 txGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address refundReceiver,
    uint256 _nonce
  ) public view returns (bytes memory) {
    bytes32 txHash = keccak256(abi.encode(
      SAFE_TX_TYPEHASH,
      operation,
      to,
      value,
      data,
      txGas,
      baseGas,
      gasPrice,
      gasToken,
      refundReceiver,
      _nonce
    ));
    return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), txHash);
  }

  function getTransactionHash(
    Types.Operation operation,
    address to,
    uint256 value,
    bytes calldata data,
    uint256 txGas,
    uint256 baseGas,
    uint256 gasPrice,
    address gasToken,
    address refundReceiver,
    uint256 _nonce
  ) public view returns (bytes32) {
    return keccak256(encodeTransactionData(operation, to, value, data, txGas, baseGas, gasPrice, gasToken, refundReceiver, _nonce));
  }

  function getChainId() public view returns (uint256 id) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      id := chainid()
    }
  }

  function domainSeparator() public view returns (bytes32) {
    return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this));
  }

  function transferToken(
    address token,
    address receiver,
    uint256 amount
  ) internal returns (bool transferred) {
    // 0xa9059cbb - keccack("transfer(address,uint256)")
    bytes memory data = abi.encodeWithSelector(0xa9059cbb, receiver, amount);
    // solhint-disable-next-line no-inline-assembly
    assembly {
      // We write the return value to scratch space.
      // See https://docs.soliditylang.org/en/v0.7.6/internals/layout_in_memory.html#layout-in-memory
      let success := call(sub(gas(), 10000), token, 0, add(data, 0x20), mload(data), 0, 0x20)
      switch returndatasize()
        case 0 {
          transferred := success
        }
        case 0x20 {
          transferred := iszero(or(iszero(success), iszero(mload(0))))
        }
        default {
          transferred := 0
        }
    }
  }
}
