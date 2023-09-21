pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../mocks/ERC1155MintsToDeployer.sol";
import '../ocean/Interactions.sol';
import "../ocean/Ocean.sol";
import "../fractionalizer/Fractionalizer1155.sol";
import "../fractionalizer/FractionalizerFactory.sol";

contract Fractionalizer1155Test is Test {

    Ocean _ocean;
    uint256 exchangeRate = 100;
    ERC1155MintsToDeployer _mockCollection;
    Fractionalizer1155 _fractionalizer;
    FractionalizerFactory _factory;

    function setUp() public {
        uint256[] memory ids = new uint256[](2);
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 100;

        _mockCollection = new ERC1155MintsToDeployer(ids, amounts);

        _ocean = new Ocean("");
        _factory = new FractionalizerFactory();
        address _deployedAddress = _factory.deploy(address(_ocean), address(_mockCollection), exchangeRate, false);
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
        return _calculateOceanId(address(_mockCollection), _tokenId);
    }

    function _getInteraction_and_ids_for_compute_output_amount(bool _order, uint256 _amount, uint256 _tokenId) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      ids = new uint256[](2);
      bytes32 interactionIdToComputeOutputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeOutputAmount));
      interactions = new Interaction[](2);
              
      uint256 _userAssetOceanId = _fetchOceanId(_tokenId);
      
      uint256 _fungibleTokenId;
      if (_fractionalizer.fungibleTokenIds(_userAssetOceanId) == 0) _fungibleTokenId = _fetchFungibleId(_fractionalizer.registeredTokenNonce());
      else _fungibleTokenId = _fractionalizer.fungibleTokenIds(_userAssetOceanId);

      if (_order) {

        bytes32 interactionIdToWrapErc1155 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.WrapErc1155));
        
        // minting fungible tokens
        ids[0] = _userAssetOceanId;
        ids[1] = _fungibleTokenId;

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount,
            metadata: bytes32(_tokenId)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(_tokenId)
        });

      } else {

        ids[0] = _fungibleTokenId;
        ids[1] = _userAssetOceanId;

        bytes32 interactionIdToUnWrapErc1155 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.UnwrapErc1155));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeOutputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(_tokenId)
        });

        // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount / exchangeRate,
            metadata: bytes32(_tokenId)
        });
      }
    }


    function _getInteraction_and_ids_for_compute_input_amount(bool _order, uint256 _amount, uint256 _tokenId) internal view returns(Interaction[] memory interactions, uint256[] memory ids) {
      bytes32 interactionIdToComputeInputAmount =  _fetchInteractionId(address(_fractionalizer), uint256(InteractionType.ComputeInputAmount));
      ids = new uint256[](2);
      interactions = new Interaction[](2);

      uint256 _userAssetOceanId = _fetchOceanId(_tokenId);

      uint256 _fungibleTokenId;
      if (_fractionalizer.fungibleTokenIds(_userAssetOceanId) == 0) _fungibleTokenId = _fetchFungibleId(_fractionalizer.registeredTokenNonce());
      else _fungibleTokenId = _fractionalizer.fungibleTokenIds(_userAssetOceanId);

      if (_order) {
        bytes32 interactionIdToWrapErc1155 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.WrapErc1155));
        
        ids[0] = _userAssetOceanId;
        ids[1] = _fungibleTokenId;

        // wrap erc721
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount / exchangeRate,
            metadata: bytes32(_tokenId)
        });

        // mint fungible tokens
        interactions[1] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(_tokenId)
        });

      } else {
        ids[0] = _fungibleTokenId;
        ids[1] = _userAssetOceanId;

        bytes32 interactionIdToUnWrapErc1155 =  _fetchInteractionId(address(_mockCollection), uint256(InteractionType.UnwrapErc1155));

        // burn fungible tokens
        interactions[0] = Interaction({
            interactionTypeAndAddress: interactionIdToComputeInputAmount,
            inputToken: ids[0],
            outputToken: ids[1],
            specifiedAmount: _amount,
            metadata: bytes32(_tokenId)
        });

         // unwrap erc721
        interactions[1] = Interaction({
           interactionTypeAndAddress: interactionIdToUnWrapErc1155,
            inputToken: 0,
            outputToken: 0,
            specifiedAmount: _amount,
            metadata: bytes32(_tokenId)
        });
      }
    }

    function testComputeOutputAmount_reverts_when_invalid_token_ids_are_passed() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 0);
        interactions[1].outputToken = ids[0];

        vm.expectRevert();
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeInputAmount_reverts_when_invalid_token_ids_are_passed() public {
       // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5, 0);
        interactions[1].inputToken = 3;

        vm.expectRevert();
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeInputAmount_reverts_when_invalid_amount_passed_and_minting_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 0);
        interactions[1].specifiedAmount = 3;

        vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeOutputAmount_reverts_when_invalid_amount_passed_and_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 0);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, 5 * exchangeRate, 0);

        _ocean.doMultipleInteractions(interactions, ids);
        interactions[0].specifiedAmount = 3;

        vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
        _ocean.doMultipleInteractions(interactions, ids);
    }

    function testComputeOutputAmount_when_minting_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 0);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 5 * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], 5 * exchangeRate);
    }

    function testComputeInputAmount_when_minting_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 0);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 5 * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], 5 * exchangeRate);
    }

    function testComputeOutputAmount_when_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 0);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, 5 * exchangeRate, 0);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], 5 * exchangeRate);
    }

    function testComputeInputAmount_when_burning_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 0);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false, 5, 0);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], 5 * exchangeRate);
    }

       function testComputeOutputAmount_when_minting_multiple_types_of_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 0);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 5 * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], 5 * exchangeRate);

        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 1);

        (, , mintIds, mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), 5 * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], 5 * exchangeRate);
    }

    function testComputeInputAmount_when_minting_multiple_types_of_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 0);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 5 * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], 5 * exchangeRate);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 1);

        (, , mintIds, mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), 5 * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], 5 * exchangeRate);
    }

    function testComputeOutputAmount_when_burning_multiple_types_of_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 0);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, 5 * exchangeRate, 0);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], 5 * exchangeRate);


        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(true, 5, 1);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, 5 * exchangeRate, 1);

        (burnIds, burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], 5 * exchangeRate);
    }

    function testComputeInputAmount_when_burning_multiple_types_of_fungible_tokens() public {
        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 0);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false, 5, 0);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], 5 * exchangeRate);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(true, 5 * exchangeRate, 1);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false, 5, 1);

        (burnIds, burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], 5 * exchangeRate);
    }

    function testFuzzComputeOutputAmount_when_minting_fungible_tokens(uint256 _amount) public {
        _amount = bound(_amount, 1, 99);

        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, _amount, 0);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), _amount * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], _amount * exchangeRate);

        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(true, _amount, 1);

        (, , mintIds, mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), _amount * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], _amount * exchangeRate);
    }

    function testFuzzComputeInputAmount_when_minting_fungible_tokens(uint256 _amount) public {
        _amount = bound(_amount, 1, 99);

        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, _amount * exchangeRate, 0);

        (, , uint256[] memory mintIds, uint256[] memory mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), _amount * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], _amount * exchangeRate);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(true, _amount * exchangeRate, 1);

        (, , mintIds, mintAmounts) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), _amount * exchangeRate);
        assertEq(mintAmounts.length, 1);
        assertEq(mintAmounts.length, mintIds.length);
        assertEq(mintAmounts[0], _amount * exchangeRate);
    }

    function testFuzzComputeOutputAmount_when_burning_fungible_tokens(uint256 _amount) public {
        _amount = bound(_amount, 1, 99);

        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_output_amount(true, _amount, 0);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, _amount * exchangeRate, 0);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], _amount * exchangeRate);


        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(true, _amount, 1);

        _ocean.doMultipleInteractions(interactions, ids);
        
        (interactions, ids) = _getInteraction_and_ids_for_compute_output_amount(false, _amount * exchangeRate, 1);

        (burnIds, burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], _amount * exchangeRate);
    }

    function testFuzzComputeInputAmount_when_burning_fungible_tokens(uint256 _amount) public {
        _amount = bound(_amount, 1, 99);

        // approving ocean to spend token
        _mockCollection.setApprovalForAll(address(_ocean), true);

        (Interaction[] memory interactions, uint256[] memory ids) = _getInteraction_and_ids_for_compute_input_amount(true, _amount * exchangeRate, 0);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false, _amount, 0);

        (uint256[] memory burnIds, uint256[] memory burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(0)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], _amount * exchangeRate);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(true, _amount * exchangeRate, 1);

        _ocean.doMultipleInteractions(interactions, ids);

        (interactions, ids) = _getInteraction_and_ids_for_compute_input_amount(false, _amount, 1);

        (burnIds, burnAmounts, , ) = _ocean.doMultipleInteractions(interactions, ids);
        assertEq(_fractionalizer.getTokenSupply(_fetchOceanId(1)), 0);
        assertEq(burnIds.length, 1);
        assertEq(burnAmounts.length, burnIds.length);
        assertEq(burnAmounts[0], _amount * exchangeRate);
    }
}