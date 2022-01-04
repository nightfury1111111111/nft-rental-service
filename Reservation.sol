pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/access/Ownable.sol";
import "./ERC809.sol";


contract Reservation is Ownable, ERC809Child {

  enum ReservationStatus {
    Reserved, // When NFT is freshly reserved
    PickedUp, // When Car is picked up by renter
    Returned, // When Car is returned by renter
    ReturnAcknowledged, // When car owner acknowledges the car return
    ReservationComplete, // When car owner acknowledges the car return
    Cancelled // When reservation is cancelled
  }

  mapping(uint256 => uint256) public rentalCarIds;
  mapping(uint256 => uint256) public startTimestamps;
  mapping(uint256 => uint256) public stopTimestamps;

  mapping(uint256 => uint256) public rentPrices;
  mapping(uint256 => uint256) public receivedCollaterals;
 
  mapping(uint256 => uint256) public pickUpTimes;
  mapping(uint256 => uint256) public returnTimes;
  mapping(uint256 => ReservationStatus) public reservationStatuses;

  mapping(uint256 => bool) public feeCollected;
  mapping(uint256 => bool) public collateralClaimed;

  uint256 nextTokenId;

  event CarPickedUp(address indexed _renter, uint256 _rentalCarId, uint256 _tokenId);
  event CarReturned(address indexed _renter, uint256 _rentalCarId, uint256 _tokenId);
  event CarReturnAcknowledged(address indexed _rentalCarOwner, uint256 _rentalCarId, uint256 _tokenId);
  event ReservationComplete(address indexed _rentalCarOwner, uint256 _rentalCarId, uint256 _tokenId);
  event ReservationFeeCollected(address indexed _rentalCarOwner, uint256 _rentalCarId, uint256 _tokenId);
  event CollateralClaimed(address indexed _renter, uint256 _rentalCarId, uint256 _tokenId);

  constructor() ERC721("Reservation", "REZ") {
  }

  /// @notice Reserve access to token `_tokenId` from time `_start` to time `_stop`
  /// @dev A successful reservation must ensure each time slot in the range _start to _stop
  ///  is not previously reserved (by calling the function checkAvailable() described below)
  ///  and then emit a Reserve event.327
  function reserve(
    address _to,
    uint256 _rentalCarId,
    uint256 _start,
    uint256 _stop,
    uint256 _rentPrice,
    uint256 _collateral
  )
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
    rentPrices[tokenId] = _rentPrice;
    receivedCollaterals[tokenId] = _collateral;

    reservationStatuses[tokenId] = ReservationStatus.Reserved;
    emit Creation(_to, _rentalCarId, tokenId);

    return tokenId;
  }

  function carPickedUp(uint256 _tokenId, uint256 _pickUpTime)
  external
  onlyOwner()
  {
    pickUpTimes[_tokenId] = _pickUpTime;
    reservationStatuses[_tokenId] = ReservationStatus.PickedUp;
    emit CarPickedUp(msg.sender, rentalCarIds[_tokenId], _tokenId);
  }

  function carReturned(uint256 _tokenId, uint256 _retrunTime)
  external
  onlyOwner()
  {
    returnTimes[_tokenId] = _retrunTime;
    reservationStatuses[_tokenId] = ReservationStatus.Returned;
    emit CarReturned(msg.sender, rentalCarIds[_tokenId], _tokenId);
  }

  function markReservationComplete(uint256 _tokenId)
  external
  onlyOwner()
  {
    reservationStatuses[_tokenId] = ReservationStatus.ReservationComplete;
    emit ReservationComplete(msg.sender, rentalCarIds[_tokenId], _tokenId);
  }

  function markFeeCollected(uint256 _tokenId)
  external
  onlyOwner()
  {
    feeCollected[_tokenId] = true;
    emit ReservationFeeCollected(msg.sender, rentalCarIds[_tokenId], _tokenId);
  }

  function markCollateralClaimed(uint256 _tokenId)
  external
  onlyOwner()
  {
    collateralClaimed[_tokenId] = true;
    emit ReservationFeeCollected(ownerOf(_tokenId), rentalCarIds[_tokenId], _tokenId);
  }

  function markReturnAcknoledge(uint256 _tokenId)
  external
  onlyOwner()
  {
    reservationStatuses[_tokenId] = ReservationStatus.ReturnAcknowledged;
    emit CarReturnAcknowledged(msg.sender, rentalCarIds[_tokenId], _tokenId);
  }

  function setReceivedCollateral(uint256 _tokenId, uint256 _receivedCollateral)
  external
  onlyOwner()
  {
    receivedCollaterals[_tokenId] = _receivedCollateral;
  }

  function updateRentPrice(uint256 _tokenId, uint256 _newRentPrice)
  external
  onlyOwner()
  {
    rentPrices[_tokenId] = _newRentPrice;
  }

  function updateStopTime(uint256 _tokenId, uint256 stopTime)
  external
  onlyOwner()
  {
    stopTimestamps[_tokenId] = stopTime;
  }

  function cancel(address _owner, uint256 _tokenId)
  external
  onlyOwner()
  {
    super._burn(_tokenId);

    uint256 rentalCarId = rentalCarIds[_tokenId];
    reservationStatuses[_tokenId] = ReservationStatus.Cancelled;
    
    emit Cancellation(_owner, rentalCarId, _tokenId);
  }
}
