pragma solidity ^0.8.0;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/65ef662a2ba263b62de0f45b062c8942362ba8c8/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


/// @title ERC809: a standard interface for rentable rival non-fungible tokens.
abstract contract ERC809 is ERC721Enumerable {
  // address of the ERC721 contract tokenizing reseravation/access of this contract's token
  address public reservationContract;

  /// @notice Find the renter of an NFT token as of `_time`
  /// @dev The renter is who made a reservation on `_tokenId` and the reservation spans over `_time`.
  function renterOf(uint256 _tokenId, uint256 _time) public virtual view returns (address);

  /// @notice Query if token `_tokenId` if available to reserve between `_start` and `_stop` time
  function isAvailable(uint256 _tokenId, uint256 _start, uint256 _stop) public virtual view returns (bool);

  /// @notice Cancel reservation for `_tokenId` between `_start` and `_stop`
  /// @dev All reservations between `_start` and `_stop` are cancelled. `_start` and `_stop` do not guarantee
  //   to be the ends for any one of the reservations
  function cancelAll(uint256 _tokenId, uint256 _start, uint256 _stop) public virtual returns (uint256);

  /// @notice Cancel a single reservation for `_tokenId`
  function cancel(uint256 _tokenId, uint256 _reservationId) public virtual;
}


/// @title ERC809Child: an auxiliary ERC809 token representing access to a ERC809.
abstract contract ERC809Child is ERC721Enumerable {
  // address of the parent ERC721 contract whose tokens are open for access
  address public _owner;

  /// @dev This emits when a successful reservation is made for accessing any NFT.
  event Creation(address indexed _renter, uint256 _calendarId, uint256 _tokenId);

  /// @dev This emits when a successful cancellation is made for a reservation.
  event Cancellation(address indexed _renter, uint256 _calendarId, uint256 _tokenId);
}
