pragma solidity ^0.8.0;

import "./Reservation.sol";
import "./ERC809.sol";
import "./TreeMap.sol";
import "./ContextMixin.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/utils/Strings.sol";

contract RentalCar is ERC809, ContextMixin {
  using TreeMap for TreeMap.Map;

  constructor() ERC721("RentalCar", "RCT") {
    reservationContract = address(new Reservation());
  }

  // Metadata associated with each RCT token
  struct RentalCarMetaData {
    uint256 hourlyRentPrice;
    // TODO: collateral to be added
    // uint256 collateral;
  }

  // mapping of token(RentalCar) id to RentalCarMetaData
  mapping(uint256 => RentalCarMetaData) rentalCarMeta;

  // limit reservation duration to 48 hours because we do not have spam protection yet
  uint256 constant public RESERVATION_DURATION_LIMIT = 48 hours;

  // mapping of token(RCT) id to mapping from start/end timestamp of a reservation to its id
  mapping(uint256 => TreeMap.Map) public startTimestampsMap;

  /// @notice Create a new RCT token
  function mint(uint256 _hourlyRentPrice)
  public
  {
    uint256 _tokenId = totalSupply();
    super._mint(msg.sender, _tokenId);
    rentalCarMeta[_tokenId].hourlyRentPrice = _hourlyRentPrice;
  }

  /// @notice Destroy a RCT token
  function burn(uint256 _tokenId)
  public
  onlyOwner(_tokenId)
  {
    super._burn(_tokenId);
    delete rentalCarMeta[_tokenId];
  }

  /// @notice Only RCT token owner modifier
  modifier onlyOwner(uint256 _tokenId) {
    require(msg.sender == ownerOf(_tokenId), "Not authorized");
    _;
  }

  /// @notice Only RCT token owner or Reservation owner modifier
  modifier onlyOwnerOrRenter(uint256 _tokenId, uint256 _reservationId) {
    bool isOwner = msg.sender == ownerOf(_tokenId);
    Reservation reservation = Reservation(reservationContract);
    address renter = reservation.ownerOf(_reservationId);
    bool isRenter = msg.sender == renter;
    require(isOwner || isRenter, "Not authorized");
    _;
  }

  /// @notice Updates hourly rent price of RCT token
  function updateHourlyRentPrice(uint256 _tokenId, uint256 _hourlyRentPrice)
  public
  onlyOwner(_tokenId)
  {
    rentalCarMeta[_tokenId].hourlyRentPrice = _hourlyRentPrice;
  }

  /// @notice Query if token `_tokenId` if available to reserve between `_start` and `_stop` time
  /// @dev For the requested token, we examine its current resertions, check
  ///   1. whether the last reservation that has `startTime` before `_start` already ended before `_start`
  ///                Okay                            Bad
  ///           *startTime*   stopTime        *startTime*   stopTime
  ///             |---------|                  |---------|
  ///                          |-------               |-------
  ///                          _start                 _start
  ///   2. whether the soonest reservation that has `endTime` after `_end` will start after `_end`.
  ///                Okay                            Bad
  ///          startTime   *stopTime*         startTime   *stopTime*
  ///             |---------|                  |---------|
  ///    -------|                           -------|
  ///           _stop                              _stop
  ///
  //   NB: reservation interval are [start time, stop time] i.e. closed on both ends.
  function isAvailable(uint256 _tokenId, uint256 _start, uint256 _stop)
  public
  view
  override
  returns(bool)
  {
    require(_stop > _start, "Stop must ends after start");
    require(_stop - _start <= RESERVATION_DURATION_LIMIT, "Reservation duration must not exceed limit");

    bool found;
    uint256 reservationId;
    uint256 startTime;

    // find closest event that started after _start
    (found, startTime, reservationId) = startTimestampsMap[_tokenId].ceilingEntry(_start);
    if (found && _stop > startTime) {
      return false;
    }

    // find closest event that started before _start
    (found, startTime, reservationId) = startTimestampsMap[_tokenId].floorEntry(_start);
    if (found) {
      Reservation reservation = Reservation(reservationContract);
      if (reservation.stopTimestamps(reservationId) > _start) {
        return false;
      }
    }

    return true;
  }

  /// @notice Reserve access to token `_tokenId` from time `_start` to time `_stop`
  /// @dev A successful reservation must ensure each time slot in the range _start to _stop
  ///  is not previously reserved.
  function reserve(uint256 _tokenId, uint256 _start, uint256 _stop)
  public
  payable
  returns(uint256)
  {
    require(_exists(_tokenId), "RentalCar does not exist");
    require(_start >= block.timestamp, "Cannot reserve for past date");

    if (!isAvailable(_tokenId, _start, _stop)) {
      revert("RentalCar is unavailable during this time period");
    }

    uint256 noOfHours = (_stop - _start) / 3600;
    uint256 remainder = (_stop - _start) - 3600 * noOfHours;

    if(remainder > 0) {
        noOfHours += 1;
    }

    uint256 rentPrice = rentalCarMeta[_tokenId].hourlyRentPrice * noOfHours;
    require(msg.value >= rentPrice, "Provided ether is less then the rent price");

    Reservation reservation = Reservation(reservationContract);
    uint256 reservationId = reservation.reserve(msg.sender, _tokenId, _start, _stop, rentPrice);
    startTimestampsMap[_tokenId].put(_start, reservationId);

    return reservationId; 
  }

  /// @notice Cancel all reservations for `_tokenId` between `_start` and `_stop`
  /// @return number of reservation that has been cancelled
  function cancelAll(uint256 _tokenId, uint256 _start, uint256 _stop)
  public
  override
  returns (uint256)
  {
    require(_exists(_tokenId), "RentalCar does not exist");

    TreeMap.Map storage startTimestamps = startTimestampsMap[_tokenId];
    Reservation reservation = Reservation(reservationContract);

    bool found = true;
    uint256 startTime = _start;
    uint256 stopTime;
    uint256 reservationId;
    uint256 cancelled = 0;

    uint256 rentPrice;
    address payable renter;

    // If the msg.sender is owner of RCT token, he should be able to cancel all the reservations made
    // A renter can cancel all bookings made by him in the given time period
    (found, startTime, reservationId) = startTimestamps.ceilingEntry(startTime);
    while (found) {
      stopTime = reservation.stopTimestamps(reservationId);
      if (stopTime <= _stop && ((reservation.ownerOf(reservationId) == msg.sender) || (ownerOf(_tokenId) == msg.sender))) {

        rentPrice = reservation.rentPrice(reservationId);
        renter = payable(reservation.ownerOf(reservationId));
        renter.transfer(rentPrice);

        reservation.cancel(msg.sender, reservationId);
        startTimestamps.remove(startTime);

        cancelled++;
      }

      (found, startTime, reservationId) = startTimestamps.higherEntry(startTime);
    }

    return cancelled;
  }

  /// @notice Cancel reservation `_reservationId` for RCT `_tokenId`
  function cancel(uint256 _tokenId, uint256 _reservationId)
  public
  onlyOwnerOrRenter(_tokenId, _reservationId)
  override
  {
    require(_exists(_tokenId), "RentalCar does not exist");

    Reservation reservation = Reservation(reservationContract);

    uint256 startTime = reservation.startTimestamps(_reservationId);
    uint256 rentalCarId = reservation.rentalCarIds(_reservationId);
    if (rentalCarId != _tokenId) {
      revert("RentalCar id is invalid");
    }

    uint256 rentPrice = reservation.rentPrice(_reservationId);
    address payable renter = payable(reservation.ownerOf(_reservationId));
    renter.transfer(rentPrice);

    reservation.cancel(msg.sender, _reservationId);

    TreeMap.Map storage startTimestamps = startTimestampsMap[_tokenId];
    startTimestamps.remove(startTime);
  }

  /// @notice Find the owner of the reservation that overlaps `_timestamp` for the RCT `_tokenId`
  function renterOf(uint256 _tokenId, uint256 _timestamp)
  public
  override
  view
  returns (address reservationOwner)
  {
    TreeMap.Map storage startTimestamps = startTimestampsMap[_tokenId];

    // find the last reservation that started before _timestamp
    bool found;
    uint256 startTime;
    uint256 reservationId;
    (found, startTime, reservationId) = startTimestamps.floorEntry(_timestamp);

    if (found) {
      Reservation reservation = Reservation(reservationContract);
      // verify the reservation ends after _timestamp
      if (reservation.stopTimestamps(reservationId) >= _timestamp) {
        return reservation.ownerOf(reservationId);
      }
    }
  }

  /// @notice Count all reservations for a RentalCar
  function reservationBalanceOf(uint256 _tokenId)
  public
  view
  returns (uint256)
  {
    return startTimestampsMap[_tokenId].size();
  }

  /// @notice RCT token owner can collect fee once reservation is completed or has been started
  function takeFee(uint256 _tokenId)
  public
  {
    TreeMap.Map storage startTimestamps = startTimestampsMap[_tokenId];

    bool found;
    uint256 startTime;
    uint256 reservationId;
    bool feeCollected;
    uint256 rentPrice;

    (found, startTime, reservationId) = startTimestamps.floorEntry(block.timestamp);

    address payable tokenOwner = payable(ownerOf(_tokenId));
    Reservation reservation = Reservation(reservationContract);

    while (found) {

      feeCollected = reservation.feeCollected(reservationId);
      
      if(feeCollected) {
        break;
      }

      rentPrice = reservation.rentPrice(reservationId);
      tokenOwner.transfer(rentPrice);
      reservation.setFeeCollected(reservationId, true);

      (found, startTime, reservationId) = startTimestamps.floorEntry(startTime-1);
    }
  }
  
  // Provides URI to get token basic details required to be listed on open marketplaces
  function tokenURI(uint256 _tokenId) override public pure returns (string memory) {
    return string(abi.encodePacked(baseTokenURI(), Strings.toString(_tokenId)));
  }
  
  function baseTokenURI() public pure returns (string memory) {
    return "https://creatures-api.opensea.io/api/creature/";
  }

  /**
  * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
  */
  function _msgSender()
  internal
  override
  view
  returns (address sender)
  {
    return ContextMixin.msgSender();
  }
  

  // Allow OpenSea's ERC721 Proxy Address to transact on these assets 
  function isApprovedForAll(
    address _owner,
    address _operator
  )
  public
  override
  view
  returns (bool isOperator)
  {
    // if OpenSea's ERC721 Proxy Address is detected, auto-return true
    if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
      return true;
    }
        
    // otherwise, use the default ERC721.isApprovedForAll()
    return ERC721.isApprovedForAll(_owner, _operator);
  }
}
