//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/LibPart.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";
import "./@rarible/lazy-mint/contracts/erc-721/IERC721LazyMint.sol";
import "./@rarible/lazy-mint/contracts/erc-721/LibERC721LazyMint.sol";
import "./@rarible/lazy-mint/contracts/erc-1155/IERC1155LazyMint.sol";
import "./@rarible/lazy-mint/contracts/erc-1155/LibERC1155LazyMint.sol";

contract SmartContract is ERC721, Ownable, RoyaltiesV2Impl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC721("Mechlin", "MCK") {
        _setupRole(MINTER_ROLE, minter);
    }

    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        string uri;
        LibPart.Part[] creators;
        LibPart.Part[] royalties;
        bytes signature;
    }

    function redeem(address redeemer, NFTVoucher calldata voucher, bytes memory signature) public payable returns (uint256) {
        address signer = _verify(voucher, signature);
        require(
            hasRole(MINTER_ROLE, signer),
            "Signature invalid or unauthorized"
        );
        require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");
        _mint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);
        _transfer(signer, redeemer, voucher.tokenId);
        pendingWithdrawals[signer] += msg.value;
        return voucher.tokenId;
    }

    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32){
        return _hashTypedDataV4(keccak256(abi.encode(keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"),
                    voucher.tokenId, voucher.minPrice, keccak256(bytes(voucher.uri)))));
    }

    function _verify(NFTVoucher calldata voucher, bytes memory signature) internal view returns (address) {
    bytes32 digest = _hash(voucher);
    return digest.toEthSignedMessageHash().recover(signature);
    }

    function mint(address _to) public onlyOwner {
        super._mint(_to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function setRoyalties(
        uint256 _tokenId,
        address payable _royaltiesReceipientAddress,
        uint96 _percentageBasisPoints
    ) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        LibPart.Part[] memory _royalties = royalties[_tokenId];
        if (_royalties.length > 0) {
            return (
                _royalties[0].account,
                (_salePrice * _royalties[0].value) / 10000
            );
        }
        return (address(0), 0);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        if (interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        if (interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

     function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControl, ERC721) returns (bool) {
    return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://mydomain/metadata/";
    }
}
