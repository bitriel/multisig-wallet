// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;
import "../utils/SelfAuthorized.sol";

abstract contract OwnerManager is SelfAuthorized {
  event AddedOwner(address owner);
  event RemovedOwner(address owner);
  event ChangedThreshold(uint8 threshold);

  address internal constant SENTINEL_OWNERS = address(0x1);
  mapping(address => address) internal owners;
  uint256 internal ownerCount;
  uint8 internal threshold;

  function setupOwners(address[] memory _owners, uint8 _threshold) internal {
    require(threshold == 0, "can only be called once");
    require(_threshold <= _owners.length, "threshold is more than owners");
    require(_threshold >= 1, "at least one owner");
    address currentOwner = SENTINEL_OWNERS;
    for(uint i=0; i<_owners.length; i++) {
      address owner = _owners[i];
      require(owner != address(0) && owner != address(this) && owner != currentOwner && owner != SENTINEL_OWNERS, "not allowed owner address");
      require(owners[owner] == address(0), "duplicate owner address");
      owners[currentOwner] = owner;
      currentOwner = owner;
    }
    owners[currentOwner] = SENTINEL_OWNERS;
    ownerCount = _owners.length;
    threshold = _threshold;
  } 

  function addOwnerWithThreshold(address owner, uint8 _threshold) public authorized {
    require(owner != address(0) && owner != address(this) && owner != SENTINEL_OWNERS, "not allowed owner address");
    require(owners[owner] == address(0), "duplicate owner address");
    owners[owner] = owners[SENTINEL_OWNERS];
    owners[SENTINEL_OWNERS] = owner;
    ownerCount++;
    emit AddedOwner(owner);

    if(threshold != _threshold) changeThreshold(_threshold);
  }

  function removeOwnerWithThreshold(address prevOwner, address owner, uint8 _threshold) internal authorized {
    require(ownerCount - 1 >= _threshold, "threshold can not be reached");
    require(owner != address(0) && owner != SENTINEL_OWNERS, "invalid owner address");
    require(owners[prevOwner] == owner, "not correspond to the owner");
    owners[prevOwner] = owners[owner];
    owners[owner] = address(0);
    ownerCount--;
    emit RemovedOwner(owner);

    if(threshold != _threshold) changeThreshold(_threshold);
  }

  function swapOwner(address prevOwner, address oldOwner, address newOwner) public authorized {
    require(newOwner != address(0) && newOwner != address(this) && newOwner != SENTINEL_OWNERS, "invalid new owner address");
    require(owners[newOwner] == address(0), "duplicate owner address");
    require(oldOwner != address(0) && oldOwner != SENTINEL_OWNERS, "invalid old owner address");
    require(owners[prevOwner] == oldOwner, "not correspond to the oldOwner");
    owners[newOwner] = owners[oldOwner];
    owners[prevOwner] = newOwner;
    owners[oldOwner] = address(0);
    emit RemovedOwner(oldOwner);
    emit AddedOwner(newOwner);
  }

  function changeThreshold(uint8 _threshold) public authorized {
    require(_threshold <= ownerCount, "threshold is more than owners");
    require(_threshold >= 1, "at least one owner");
    threshold = _threshold;
    emit ChangedThreshold(_threshold);
  }

  function getThreshold() public view returns (uint8) {
    return threshold;
  }

  function checkOwner(address owner) public view returns (bool) {
    return owner != SENTINEL_OWNERS && owners[owner] != address(0);
  }

  function getOwners() public view returns (address[] memory) {
    address[] memory _owners = new address[](ownerCount);

    address currentOwner = owners[SENTINEL_OWNERS];
    for(uint i=0; i<ownerCount; i++) {
      _owners[i] = currentOwner;
      currentOwner = owners[currentOwner];
    }
    return _owners;
  }

  modifier notOwner(address _owner) {
    require(!checkOwner(_owner), "is one of the owners");
    _;
  }

  modifier isOwner(address _owner) {
    require(checkOwner(_owner), "is not one of the owners");
    _;
  }
}