pragma solidity 0.8.10;

import 'forge-std/Test.sol';
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import '../../ocean/Interactions.sol';
import "../../ocean/Ocean.sol";
import "../../fractionalizer/Fractionalizer1155.sol";
import "../../fractionalizer/FractionalizerFactory.sol";

contract Fractionalizer1155Fork is Test {

    Ocean _ocean = Ocean(0xC32eB36f886F638fffD836DF44C124074cFe3584);
    uint256 exchangeRate = 100;
    IERC1155 _collection = IERC1155(0xDfFD299821aD4A835616F5479c23d6D01AC6e547);
    address nftOwner = 0x6B529a85bB9E9B5050308471746CCC66BB27be64;
    uint256 ownerTokenId = 2;
    uint256 _tokenBalance;
    Fractionalizer1155 _fractionalizer;
    FractionalizerFactory _factory;

    function setUp() public {
        vm.createSelectFork("https://arb1.arbitrum.io/rpc"); // Will start on latest block by default
        _tokenBalance = _collection.balanceOf(nftOwner, ownerTokenId);
        _factory = new FractionalizerFactory();
        address _deployedAddress = _factory.deploy(address(_ocean), address(_collection), exchangeRate, false);
        _fractionalizer = Fractionalizer1155(_deployedAddress);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function _fetchInteractionId(address token, uint256 interactionType) internal pure returns (bytes32) {
        uint256 packedValue = uint256(uint160(token));
        packedValue |= interactionType << 248;
        return bytes32(abi.encode(packedValue));
    }

    function _calculateOceanId(address tokenContract, uint256 tokenId)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(tokenContract, tokenId)));
    }

    function _fetchFungibleId(uint256 _nonce)
        internal
        view
        returns (uint256)
    {
        return _calculateOceanId(address(_fractionalizer), _nonce);
    }

    function _fetchOceanId(uint256 _tokenId)
        internal
        view
        returns (uint256)
    {
        return _calculateOceanId(address(_collection), _tokenId);
    }

    function _getInteraction_and_ids_for_compute_output_amount(bool _order, uint256 _amount) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      ids = new uint256[](2);
      bytes32 interactionIdToComputeOutputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeOutputAmount));
      interactions = new Interaction[](2);

      uint256 _userAssetOceanId = _fetchOceanId(ownerTokenId);

      uint256 _fungibleTokenId;
      if (_fractionalizer.fungibleTokenIds(_userAssetOceanId) == 0) _fungibleTokenId = _fetchFungibleId(_fractionalizer.registeredTokenNonce());
      else _fungibleTokenId = _fractionalizer.fungibleTokenIds(_userAssetOceanId);

      if (_order) {

        bytes32 interactionIdToWrapErc1155 =  _fetchInteractionId(address(_collection), uint256(InteractionType.WrapErc1155));
        
        // minting fungible tokens
        ids[0] = _userAssetOceanId;
        ids[1] = _fungibleTokenId;

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount,
            metadata: bytes32(ownerTokenId)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(ownerTokenId)
        });

      } else {

        ids[0] = _fungibleTokenId;
        ids[1] = _userAssetOceanId;

        bytes32 interactionIdToUnWrapErc1155 =  _fetchInteractionId(address(_collection), uint256(InteractionType.UnwrapErc1155));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(ownerTokenId)
        });

        // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount / exchangeRate,
            metadata: bytes32(ownerTokenId)
        });
      }
    }


    function _getInteraction_and_ids_for_compute_input_amount(bool _order, uint256 _amount) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      bytes32 interactionIdToComputeInputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeInputAmount));
      ids = new uint256[](2);
      interactions = new Interaction[](2);

      uint256 _userAssetOceanId = _fetchOceanId(ownerTokenId);

      uint256 _fungibleTokenId;
      if (_fractionalizer.fungibleTokenIds(_userAssetOceanId) == 0) _fungibleTokenId = _fetchFungibleId(_fractionalizer.registeredTokenNonce());
      else _fungibleTokenId = _fractionalizer.fungibleTokenIds(_userAssetOceanId);

      if (_order) {
        bytes32 interactionIdToWrapErc1155 =  _fetchInteractionId(address(_collection), uint256(InteractionType.WrapErc1155));
        
        ids[0] = _userAssetOceanId;
        ids[1] = _fungibleTokenId;

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount / exchangeRate,
            metadata: bytes32(ownerTokenId)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(ownerTokenId)
        });

      } else {
        ids[0] = _fungibleTokenId;
        ids[1] = _userAssetOceanId;

        bytes32 interactionIdToUnWrapErc1155 =  _fetchInteractionId(address(_collection), uint256(InteractionType.UnwrapErc1155));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(ownerTokenId)
        });

         // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount,
            metadata: bytes32(ownerTokenId)
        });
      }
    }


    function testComputeOutputAmount_reverts_when_invalid_token_ids_are_passed() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, _tokenBalance);
        interactions[1].outputToken = ids[0];

        vm.expectRevert();
        _ocean.doMultipleInteractions(interactions, ids);
        vm.stopPrank();
    }

    function testComputeInputAmount_reverts_when_invalid_token_ids_are_passed() public {
        vm.startPrank(nftOwner);
       // approving ocean to spend token
        _collection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, _tokenBalance);
        interactions[1].inputToken = 123;

        vm.expectRevert();
        _ocean.doMultipleInteractions(interactions, ids);
        vm.stopPrank();
    }

    function testComputeOutputAmount_when_minting_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, _tokenBalance);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(ownerTokenId)), _tokenBalance * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], _tokenBalance * exchangeRate);
        vm.stopPrank();
    }

    function testComputeInputAmount_when_minting_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, _tokenBalance * exchangeRate);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(ownerTokenId)), _tokenBalance * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], _tokenBalance * exchangeRate);
        vm.stopPrank();
    }

    function testComputeOutputAmount_when_burning_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, _tokenBalance);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, _tokenBalance * exchangeRate);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(ownerTokenId)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], _tokenBalance * exchangeRate);
        vm.stopPrank();
    }

    function testComputeInputAmount_when_burning_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, _tokenBalance * exchangeRate);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false, _tokenBalance);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(ownerTokenId)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], _tokenBalance * exchangeRate);
        vm.stopPrank();
    }
}