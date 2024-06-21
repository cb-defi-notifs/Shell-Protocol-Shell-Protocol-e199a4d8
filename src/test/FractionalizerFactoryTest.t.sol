// SPDX-License-Identifier: MIT
// Cowri Labs Inc.

pragma solidity 0.8.10;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "../ocean/Ocean.sol";
import "../mocks/ERC721MintsToDeployer.sol";
import "../fractionalizer/FractionalizerFactory.sol";
import "../fractionalizer/Fractionalizer721.sol";
import "../fractionalizer/Fractionalizer1155.sol";

contract FractionalizerFactoryTest is DSTest {

    Vm public constant vm = Vm(HEVM_ADDRESS);
    uint256 exchangeRate = 100;
    ERC721MintsToDeployer mockCollection;
    FractionalizerFactory factory;
    Ocean _ocean;

    function setUp() public {
      factory = new FractionalizerFactory();
      _ocean = new Ocean("");

      uint256[] memory ids = new uint256[](1);
      mockCollection = new ERC721MintsToDeployer(ids);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
       return this.onERC721Received.selector;
    }

    function testtFractionalizer721_Deployment() public {
        address _fractionalizer = factory.deploy(address(_ocean), address(mockCollection), exchangeRate, true);
        assertEq(Fractionalizer721(_fractionalizer).exchangeRate(), exchangeRate);
        assert(Fractionalizer721(_fractionalizer).nftCollection() == address(mockCollection));
        assert(Fractionalizer721(_fractionalizer).ocean() == address(_ocean));
    }

    function testtFractionalizer1155_Deployment() public {
        address _fractionalizer = factory.deploy(address(_ocean), address(mockCollection), exchangeRate, false);
        assertEq(Fractionalizer1155(_fractionalizer).exchangeRate(), exchangeRate);
        assert(Fractionalizer1155(_fractionalizer).nftCollection() == address(mockCollection));
        assert(Fractionalizer1155(_fractionalizer).ocean() == address(_ocean));
    }

    function testFractionalizer_Deployment_reverts_with_non_ocean_instance() public {
        vm.expectRevert();
        factory.deploy(address(mockCollection), address(mockCollection), exchangeRate, true);
    }

    function testFractionalizer_Deployment_reverts_if_Fractionalizer_already_exists() public {
        factory.deploy(address(_ocean), address(mockCollection), exchangeRate, true);
        vm.expectRevert(abi.encodeWithSignature('FRACTIONALIZER_EXISTS()'));
        factory.deploy(address(_ocean), address(mockCollection), exchangeRate, true);
    }

    function testFractionalizer_Deployment_reverts_if_eoa_is_passed_as_collection() public {
        vm.expectRevert();
        factory.deploy(address(_ocean), address(0), exchangeRate, true);
    }
}