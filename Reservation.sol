pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/access/Ownable.sol";
import "./ERC809.sol";


contract Reservation is Ownable, ERC809Child {

  enum ReservationStatus {
    Reserved, // When NFT is freshly reserved
    PickedUp, // When Car is picked up by renter
    Returned, // When Car is returned by renter
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

  uint256 nextTokenId;

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
  public
  {
    pickUpTimes[_tokenId] = _pickUpTime;
    reservationStatuses[_tokenId] = ReservationStatus.PickedUp;
  }

  function carReturned(uint256 _tokenId, uint256 _retrunTime)
  public
  {
    returnTimes[_tokenId] = _retrunTime;
    reservationStatuses[_tokenId] = ReservationStatus.Returned;
  }

  function setReservationComplete(uint256 _tokenId, bool _reservationComplete)
  public
  {
    reservationData[_tokenId].reservationComplete = _reservationComplete;
  }

  function setReceivedCollateral(uint256 _tokenId, uint256 _receivedCollateral)
  public
  {
    reservationData[_tokenId].receivedCollateral = _receivedCollateral;
  }

  function cancel(address _owner, uint256 _tokenId)
  external
  onlyOwner()
  {
    super._burn(_tokenId);

    uint256 rentalCarId = reservationData[_tokenId].rentalCarId;
    reservationData[_tokenId].cancelled = true;

    reservationStatuses[_tokenId] = ReservationStatus.Cancelled;
    emit Cancellation(_owner, rentalCarId, _tokenId);
  }
}
