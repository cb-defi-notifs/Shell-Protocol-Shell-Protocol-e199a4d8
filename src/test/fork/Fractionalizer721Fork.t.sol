pragma solidity 0.8.10;

import 'forge-std/Test.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import '../../ocean/Interactions.sol';
import "../../ocean/Ocean.sol";
import "../../fractionalizer/Fractionalizer721.sol";
import "../../fractionalizer/FractionalizerFactory.sol";

contract Fractionalizer721Fork is Test {

    Ocean _ocean = Ocean(0xC32eB36f886F638fffD836DF44C124074cFe3584);
    uint256 exchangeRate = 100;
    IERC721 _collection = IERC721(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address nftOwner = 0x03365fA521Cc5ECE8b1f7eD1Fb00BD4637B01781;
    uint256 tokenId = 175476;
    Fractionalizer721 _fractionalizer;
    FractionalizerFactory _factory;

    function setUp() public {
        vm.createSelectFork("https://arb1.arbitrum.io/rpc"); // Will start on latest block by default
        _factory = new FractionalizerFactory();
        address _deployedAddress = _factory.deploy(address(_ocean), address(_collection), exchangeRate, true);
        _fractionalizer = Fractionalizer721(_deployedAddress);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function _fetchInteractionId(address token, uint256 interactionType) internal pure returns (bytes32) {
        uint256 packedValue = uint256(uint160(token));
        packedValue |= interactionType << 248;
        return bytes32(abi.encode(packedValue));
    }

    function _calculateOceanId(address tokenContract, uint256 _tokenId)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(tokenContract, _tokenId)));
    }

    function _getInteraction_and_ids_for_compute_output_amount(bool _order) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      ids = new uint256[](2);
      bytes32 interactionIdToComputeOutputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeOutputAmount));
      interactions = new Interaction[](2);
      if (_order) {

        bytes32 interactionIdToWrapErc721 =  _fetchInteractionId(address(_collection), uint256(InteractionType.WrapErc721));
        
        // minting fungible tokens
        ids[0] = _calculateOceanId(address(_collection), tokenId);
        ids[1] = _fractionalizer.fungibleTokenId();

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(tokenId)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: 1,
            metadata: bytes32(tokenId)
        });

      } else {

        ids[0] = _fractionalizer.fungibleTokenId();
        ids[1] = _calculateOceanId(address(_collection), tokenId);

        bytes32 interactionIdToUnWrapErc721 =  _fetchInteractionId(address(_collection), uint256(InteractionType.UnwrapErc721));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: exchangeRate,
            metadata: bytes32(tokenId)
        });

        // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(tokenId)
        });
      }
    }


    function _getInteraction_and_ids_for_compute_input_amount(bool _order) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      bytes32 interactionIdToComputeInputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeInputAmount));
      ids = new uint256[](2);
      interactions = new Interaction[](2);

      if (_order) {
        bytes32 interactionIdToWrapErc721 =  _fetchInteractionId(address(_collection), uint256(InteractionType.WrapErc721));
        
        ids[0] = _calculateOceanId(address(_collection), tokenId);
        ids[1] = _fractionalizer.fungibleTokenId();

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(tokenId)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: exchangeRate,
            metadata: bytes32(tokenId)
        });

      } else {
        ids[0] = _fractionalizer.fungibleTokenId();
        ids[1] = _calculateOceanId(address(_collection), tokenId);

        bytes32 interactionIdToUnWrapErc721 =  _fetchInteractionId(address(_collection), uint256(InteractionType.UnwrapErc721));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: 1,
            metadata: bytes32(tokenId)
        });

         // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(tokenId)
        });
      }
    }

    function testComputeOutputAmount_when_minting_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.approve(address(_ocean), tokenId);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(mintIds[0]), exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], exchangeRate);
        vm.stopPrank();
    }

    function testComputeInputAmount_when_minting_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.approve(address(_ocean), tokenId);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(mintIds[0]), exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], exchangeRate);
        vm.stopPrank();
    }

    function testComputeOutputAmount_when_burning_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.approve(address(_ocean), tokenId);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(burnIds[0]), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], exchangeRate);
        assert(_collection.ownerOf(tokenId) == nftOwner);
        vm.stopPrank();
    }

    function testComputeInputAmount_when_burning_fungible_tokens() public {
        vm.startPrank(nftOwner);
        // approving ocean to spend token
        _collection.approve(address(_ocean), tokenId);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(burnIds[0]), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], exchangeRate);
        assert(_collection.ownerOf(tokenId) == nftOwner);
        vm.stopPrank();
    }
}