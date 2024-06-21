pragma solidity 0.8.10;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../mocks/ERC721MintsToDeployer.sol";
import '../ocean/Interactions.sol';
import "../ocean/Ocean.sol";
import "../fractionalizer/Fractionalizer721.sol";
import "../fractionalizer/FractionalizerFactory.sol";

contract Fractionalizer721Test is DSTest {

    Vm public constant vm = Vm(HEVM_ADDRESS);
    Ocean _ocean;
    uint256 exchangeRate = 100;
    ERC721MintsToDeployer _mockCollection;
    Fractionalizer721 _fractionalizer;
    FractionalizerFactory _factory;

    function setUp() public {
        uint256[] memory ids = new uint256[](1);
        _mockCollection = new ERC721MintsToDeployer(ids);
        _ocean = new Ocean("");
        _factory = new FractionalizerFactory();
        address _deployedAddress = _factory.deploy(address(_ocean), address(_mockCollection), exchangeRate, true);
        _fractionalizer = Fractionalizer721(_deployedAddress);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
       return this.onERC721Received.selector;
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

    function _getInteraction_and_ids_for_compute_output_amount(bool _order) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      ids = new uint256[](2);
      bytes32 interactionIdToComputeOutputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeOutputAmount));
      interactions = new Interaction[](2);
      if (_order) {

        bytes32 interactionIdToWrapErc721 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.WrapErc721));
        
        // minting fungible tokens
        ids[0] = _calculateOceanId(address(_mockCollection), 0);
        ids[1] = _fractionalizer.fungibleTokenId();

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(0)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: 1,
            metadata: bytes32(0)
        });

      } else {

        ids[0] = _fractionalizer.fungibleTokenId();
        ids[1] = _calculateOceanId(address(_mockCollection), 0);

        bytes32 interactionIdToUnWrapErc721 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.UnwrapErc721));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: exchangeRate,
            metadata: bytes32(0)
        });

        // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(0)
        });
      }
    }


    function _getInteraction_and_ids_for_compute_input_amount(bool _order) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      bytes32 interactionIdToComputeInputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeInputAmount));
      ids = new uint256[](2);
      interactions = new Interaction[](2);

      if (_order) {
        bytes32 interactionIdToWrapErc721 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.WrapErc721));
        
        ids[0] = _calculateOceanId(address(_mockCollection), 0);
        ids[1] = _fractionalizer.fungibleTokenId();

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(0)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: exchangeRate,
            metadata: bytes32(0)
        });

      } else {
        ids[0] = _fractionalizer.fungibleTokenId();
        ids[1] = _calculateOceanId(address(_mockCollection), 0);

        bytes32 interactionIdToUnWrapErc721 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.UnwrapErc721));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: 1,
            metadata: bytes32(0)
        });

         // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc721,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: 1,
            metadata: bytes32(0)
        });
      }
    }


    function testComputeOutputAmount_reverts_when_invalid_token_ids_are_passed() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);
        interactions[1].outputToken = ids[0];

        vm.expectRevert();
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeInputAmount_reverts_when_invalid_token_ids_are_passed() public {
       // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);
        interactions[1].inputToken = _fractionalizer.fungibleTokenId();

        vm.expectRevert();
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeOutputAmount_reverts_when_invalid_amount_passed_and_minting_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);
        interactions[1].specifiedAmount = 14;

        vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeInputAmount_reverts_when_invalid_amount_passed_and_minting_fungible_tokens() public {
       // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);
        interactions[1].specifiedAmount = 1;

        vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeOutputAmount_reverts_when_invalid_amount_passed_and_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false);
        interactions[0].specifiedAmount = 1;

        vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeInputAmount_reverts_when_invalid_amount_and_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false);
        interactions[0].specifiedAmount = exchangeRate;

        vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
        _ocean.doMultipleInteractions(interactions, ids);
    }


    function testComputeOutputAmount_when_minting_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(mintIds[0]), exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], exchangeRate);
    }

    function testComputeInputAmount_when_minting_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(mintIds[0]), exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], exchangeRate);
    }

    function testComputeOutputAmount_when_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(burnIds[0]), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], exchangeRate);
        assert(_mockCollection.ownerOf(0) == address(this));
    }

    function testComputeInputAmount_when_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.approve(address(_ocean), 0);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(burnIds[0]), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], exchangeRate);
        assert(_mockCollection.ownerOf(0) == address(this));
    }
}