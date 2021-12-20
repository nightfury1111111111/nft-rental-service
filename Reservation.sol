pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/access/Ownable.sol";
import "./ERC809.sol";


contract Reservation is Ownable, ERC809Child {

  mapping(uint256 => uint256) public rentalCarIds;
  mapping(uint256 => uint256) public startTimestamps;
  mapping(uint256 => uint256) public stopTimestamps;

  mapping(uint256 => uint256) public rentPrice;
  mapping(uint256 => bool) public feeCollected;

  uint256 nextTokenId;

  constructor() ERC721("Reservation", "REZ") {
  }

  /// @notice Reserve access to token `_tokenId` from time `_start` to time `_stop`
  /// @dev A successful reservation must ensure each time slot in the range _start to _stop
  ///  is not previously reserved (by calling the function checkAvailable() described below)
  ///  and then emit a Reserve event.
  function reserve(address _to, uint256 _rentalCarId, uint256 _start, uint256 _stop, uint256 _rentPrice)
  external
  onlyOwner()
  returns(uint256)
  {
    uint256 tokenId = nextTokenId;
    nextTokenId = nextTokenId+ 1;

    super._mint(_to, tokenId);

    rentalCarIds[tokenId] = _rentalCarId;
    startTimestamps[tokenId] = _start;
    stopTimestamps[tokenId] = _stop;
    rentPrice[tokenId] = _rentPrice;

    emit Creation(_to, _rentalCarId, tokenId);

    return tokenId;
  }

  function setFeeCollected(uint256 _tokenId, bool collected)
  public
  {
    feeCollected[_tokenId] = collected;
  }

  function cancel(address _owner, uint256 _tokenId)
  external
  onlyOwner()
  {
    super._burn(_tokenId);

    uint256 rentalCarId = rentalCarIds[_tokenId];
    delete rentalCarIds[_tokenId];
    delete startTimestamps[_tokenId];
    delete stopTimestamps[_tokenId];

    emit Cancellation(_owner, rentalCarId, _tokenId);
  }
}
