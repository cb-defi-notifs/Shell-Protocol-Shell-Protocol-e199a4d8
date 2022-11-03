# Ocean + Proteus Repo
The first section of this README applies to the Ocean, which is built and tested using hardhat.

The second section of this README applies to Proteus, which is built and tested using foundry.
# The Ocean

If you aren't familiar with solidity, the [white paper](Ocean_-_Shell_v2_Part_2.pdf) outlines the high level behavior and the key implementation details of the code in this repository.

## What is the Ocean?
The Ocean is a new paradigm for DeFi that is designed to seamlessly and efficiently compose any type of primitive: AMMs, lending pools, algorithmic stablecoins, NFT markets, or even primitives yet to be invented. Composing primitives on the Ocean can save up to four times the marginal gas cost and requires no additional smart contracts beyond the core protocol. Not only are primitives built on the Ocean simpler, they also become part of a larger, composable ecosystem.

### Invariants
 - A user's balances should only move with their permission
    - their own address is `msg.sender`
    - they've set approval for `the msg.sender`
    - they are a contract that was the target of a ComputeInput/Output, and they did not revert the transaction
 - A user should not be able to wrap a token they do not own
    - Assume this token is a well-known, well-behaved token such as DAI
 - A user should not be able to unwrap a token that they did not either wrap themselves or receive from another user
 - A user should not be able to transfer a token that they did not either wrap themselves or receive from another user
 - Receive from another user could be through ERC-1155 transfer functions, or through ComputeInput/ComputeOutput
 - The owner should not be able to change the fee to anything higher than 5 basis points
 - Fees should be credited to the owner's ERC-1155 balance
 - The owner should only be able to transfer tokens that are owned by the owner address
 - The Ocean should conform to all standards that its code claims to (ERC-1155, ERC-165)
    - EXCEPTION: The ocean omits the safeTransfer callback during the mint that occurs after a ComputeInput/ComputeOutput.  The contract receiving the transfer was called just before the mint, and should revert the transaction if it does not want to receive the token.
 - The Ocean should not lose track of wrapped tokens, making them impossible to unwrap
 - The Ocean should do its best to refuse airdrops, but airdrops that do not use callbacks will essentially be burned
 - The Ocean does not support rebasing tokens, fee on transfer tokens
 - The Ocean does not provide any guarantees against the underlying token blacklisting the Ocean or any sort of other non-standard behavior

## Code in this repo

The code is heavily commented.

The top level contract is `contracts/Ocean.sol`, which manages interactions and fees.  It inherits from `contracts/OceanERC1155.sol`, which implements the shared multitoken ledger.  The Ocean is deployed as a single contract.

### Ocean Implementation
The interfaces are declared in:
 - [`contracts/Interactions.sol`](contracts/Interactions.sol)
 - [`contracts/IOceanToken.sol`](contracts/IOceanToken.sol)
 - [`contracts/IOceanFeeChange.sol`](contracts/IOceanFeeChange.sol)
 - [`contracts/IOceanPrimitive.sol`](contracts/IOceanPrimitive.sol)

The key data structures are declared in:
 - [`contracts/Interactions.sol`](contracts/Interactions.sol)
 - [`contracts/BalanceDelta.sol`](contracts/BalanceDelta.sol)

There is a library for managing BalanceDelta arrays:
 - [`contracts/BalanceDelta.sol`](contracts/BalanceDelta.sol)

### Testing
The unit tests, which are used to generate the coverage report, are in:
 - [`test/*`](test/)

You need [npm](https://nodejs.org) to run the tests.

To compile the contracts and run the tests yourself, you can clone this repository and run
```shell
npm install
```
to install the development environment, and then you can run
```shell
npm run coverage
```
The coverage report will be located at `coverage/index.html`, and can be viewed with your web browser.

# Proteus
## Installation
This project was built using Foundry, which you can install here: https://onbjerg.github.io/foundry-book/getting-started/installation.html

The Proteus smart contract can be tested by running `forge test` from the root directory of the repository.

## Getting started
A high level overview of the Proteus algorithm is covered in the update Notion whitepaper. The updated document references sections of the original white paper, which is also included in this repo.
### Explainer
https://shell-protocol.notion.site/Proteus-White-Paper-3-7f33b7e1561347b696874a8ba02b9782
### Visualization
https://www.desmos.com/calculator/0rq42rdkec
## Invariants
We are worried about two things:
 - The pool being left in a state (xBalance, yBalance, totalSupply) where there is no action (swapGivenInputAmount, depositGivenInputAmount, withdrawGivenInputAmount, swapGivenOutputAmount, depositGivenOutputAmount, withdrawGivenOutputAmount) with any arguments (using x or y, amount input or output) that can succeed.  This would mean a Denial of Service.
 - Utility Per Shell (UPS) not monotonically increasing (barring insignificant noise).  This is easy to evaluate when Proteus mimics constant product, as the utility in one slice is directly comparable to the utility in another.  When Proteus is in any other configuration, utility in different slices is not comparable.  One way we have for testing UPS in other configurations is by reversing actions.  A swap, followed by a swap in the opposite direction to nearly the same point, should never cause utility to decrease.  Similarly for deposits and withdraws.

## The property tests and how they relate to the invariants
The property tests can fail because an argument is out of bounds in an unanticipated way.  This causes the test to fail due to an unexpected revert.  Short of rebuilding the proteus model within the property tests, there is not a great way of solving this, though we did our best.  A property test that fails is only concerning if it fails due to UPS monotonicity being violated, or if it fails due to a previous action leaving the pool in a DoS state.
