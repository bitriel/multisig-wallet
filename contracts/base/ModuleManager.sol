// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;
import "../utils/SelfAuthorized.sol";
import "../utils/Types.sol";
import "./Executor.sol";

contract ModuleManager is SelfAuthorized, Executor {
  event EnabledModule(address module);
  event DisabledModule(address module);
  event ExecutionFromModuleSuccess(address indexed module);
  event ExecutionFromModuleFailure(address indexed module);

  address internal constant SENTINEL_MODULES = address(0x1);
  mapping(address => address) internal modules;

  function setupModules(address to, bytes memory data) internal {
    require(modules[SENTINEL_MODULES] == address(0), "can only be called once");
    modules[SENTINEL_MODULES] = SENTINEL_MODULES;
    
    if(to != address(0)) {
      require(execute(Types.Operation.DelegateCall, to, 0, data, gasleft()), "transaction fails");
    }
  }

  function enableModule(address module) public authorized {
    require(module != address(0) && module != address(this) && module != SENTINEL_MODULES, "invalid module address");
    require(modules[module] != address(0), "dup module address");
    modules[module] = SENTINEL_MODULES;
    modules[SENTINEL_MODULES] = module;
    emit EnabledModule(module);
  }

  function disableModule(address prevModule, address module) public authorized {
    require(module != address(0) && module != address(this) && module != SENTINEL_MODULES, "invalid module address");
    require(modules[prevModule] == module, "not correspond to the module");
    modules[prevModule] = modules[module];
    modules[module] = address(0);
    emit DisabledModule(module);
  }

  function execTransactionFromModule(
    Types.Operation operation, 
    address to, 
    uint256 value, 
    bytes memory data
  ) public virtual returns(bool success) {
    require(msg.sender != SENTINEL_MODULES && modules[msg.sender] != address(0), "not allowed module");
    success = execute(operation, to, value, data, gasleft());
    if(success) emit ExecutionFromModuleSuccess(msg.sender);
    else emit ExecutionFromModuleFailure(msg.sender);
  }

  function execTransactionFromModuleReturnData(
    Types.Operation operation, 
    address to, 
    uint256 value, 
    bytes memory data
  ) public virtual returns(bool success, bytes memory returnData) {
    require(msg.sender != SENTINEL_MODULES && modules[msg.sender] != address(0), "not allowed module");
    success = execTransactionFromModule(operation, to, value, data);
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let ptr := mload(0x40)
      mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
      mstore(ptr, returndatasize())
      returndatacopy(add(ptr, 0x20), 0, returndatasize())
      returnData := ptr
    }
  }

  function isModuleEnabled(address module) public view returns(bool) {
    return module != SENTINEL_MODULES && modules[module] != address(0);
  }

  function getModulePagenated(address start, uint256 pageSize) external view returns(address[] memory array, address next) {
    array = new address[](pageSize);

    uint256 moduleCount = 0;
    address currentModule = modules[start];
    while(currentModule != address(0) && currentModule != SENTINEL_MODULES && moduleCount < pageSize) {
      array[moduleCount] = currentModule;
      currentModule = modules[currentModule];
      moduleCount++;
    }
    next = currentModule;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      mstore(array, moduleCount)
    }
  }
} 