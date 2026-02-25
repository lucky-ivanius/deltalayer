// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.3.0/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin-contracts-5.3.0/access/Ownable.sol";
import {IERC165} from "@openzeppelin-contracts-5.3.0/utils/introspection/IERC165.sol";
import {IReceiver} from "./interfaces/IReceiver.sol";

/// @title DeltaLayer Escrow
/// @notice Holds USDC payments and settles via CRE Keystone Forwarder reports
/// @dev Implements IReceiver to accept reports from the Chainlink KeystoneForwarder
contract Escrow is IReceiver, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    // Types
    // ──────────────────────────────────────────────

    struct Settlement {
        bytes32 generation;
        bytes32 payment;
        uint256 paid;
        uint256 actual;
    }

    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    IERC20 public immutable USDC;
    address public immutable PROTOCOL;
    address public forwarder;

    /// @notice settlement hash => settled flag (replay protection)
    mapping(bytes32 => bool) public settled;

    // ──────────────────────────────────────────────
    // Errors
    // ──────────────────────────────────────────────

    error InvalidForwarder();
    error InvalidSender(address sender, address expected);
    error AlreadySettled(bytes32 hash);
    error ActualExceedsPaid(uint256 actual, uint256 paid);
    error ZeroAddress();

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event Settled(
        bytes32 indexed hash,
        bytes32 indexed generation,
        bytes32 indexed payment,
        uint256 paid,
        uint256 actual,
        uint256 refund
    );

    event ForwarderUpdated(address indexed previous, address indexed current);

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    /// @param _usdc The USDC token address
    /// @param _protocol The protocol address that receives actual cost
    /// @param _forwarder The CRE Keystone Forwarder address
    constructor(
        address _usdc,
        address _protocol,
        address _forwarder
    ) Ownable(msg.sender) {
        if (_usdc == address(0) || _protocol == address(0)) revert ZeroAddress();
        if (_forwarder == address(0)) revert InvalidForwarder();

        USDC = IERC20(_usdc);
        PROTOCOL = _protocol;
        forwarder = _forwarder;
    }

    // ──────────────────────────────────────────────
    // IReceiver
    // ──────────────────────────────────────────────

    /// @inheritdoc IReceiver
    /// @dev Only callable by the Keystone Forwarder. The report is ABI-encoded
    ///      as (bytes32 generation, bytes32 payment, uint256 paid, uint256 actual, address payer).
    function onReport(
        bytes calldata,
        bytes calldata report
    ) external override nonReentrant {
        if (msg.sender != forwarder) revert InvalidSender(msg.sender, forwarder);

        (
            bytes32 generation,
            bytes32 payment,
            uint256 paid,
            uint256 actual,
            address payer
        ) = abi.decode(report, (bytes32, bytes32, uint256, uint256, address));

        if (actual > paid) revert ActualExceedsPaid(actual, paid);

        bytes32 hash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr,        generation)
            mstore(add(ptr, 32), payment)
            mstore(add(ptr, 64), paid)
            mstore(add(ptr, 96), actual)
            hash := keccak256(ptr, 128)
        }
        if (settled[hash]) revert AlreadySettled(hash);
        settled[hash] = true;

        uint256 refund = paid - actual;

        if (actual > 0) USDC.safeTransfer(PROTOCOL, actual);
        if (refund > 0) USDC.safeTransfer(payer, refund);

        emit Settled(hash, generation, payment, paid, actual, refund);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IReceiver).interfaceId || id == type(IERC165).interfaceId;
    }

    // ──────────────────────────────────────────────
    // Admin
    // ──────────────────────────────────────────────

    /// @notice Update the Keystone Forwarder address
    function setForwarder(address _forwarder) external onlyOwner {
        if (_forwarder == address(0)) revert InvalidForwarder();
        emit ForwarderUpdated(forwarder, _forwarder);
        forwarder = _forwarder;
    }
}
