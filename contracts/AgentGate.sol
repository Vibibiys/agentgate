// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface for the official Agent ID contract (SPACE ID, ERC-721 on BSC).
/// AgentGate only ever READS from it — it never calls any state-changing function on it.
interface IAgentId {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentGate — an Agent-ID-gated registry for agent-only mints and actions
/// @notice AgentGate is an open registry that only holders of an Agent ID can join.
/// An address "holds an Agent ID" if and only if `balanceOf(address) > 0` on the
/// official Agent ID contract (SPACE ID ERC-721) at 0x60b9262456de011f7d15a54cdd8c48baaa8b022f
/// on BSC mainnet (chain id 56).
///
/// Agent ID integration (core access control, not decoration):
/// - `register()` is gated directly on Agent ID ownership at the moment of registration.
/// - `checkIn()` re-checks Agent ID ownership on every call, so an address that no
///   longer holds an Agent ID can no longer check in.
/// - `isVerifiedAgent(address)` is the composable gate other projects call: it returns
///   true only for an address that is registered AND still holds an Agent ID right now.
///   A mint or action contract can require `AgentGate.isVerifiedAgent(msg.sender)`
///   to restrict itself to verified Agent ID holders.
///
/// Safety / trust model:
/// - This contract moves NO assets. It has no payable functions, performs no token
///   transfers, and never asks for or uses token approvals (no approve/transferFrom).
/// - There are NO privileged/admin functions. The `owner` recorded at deployment is
///   informational only (it identifies the deployer); no function in this contract
///   checks it, and there is no way to pause, edit, remove, or upgrade registrations.
/// - Registrations are permanent and one per address.
contract AgentGate {
    /// @notice The official Agent ID contract (SPACE ID ERC-721), BSC mainnet.
    IAgentId public constant AGENT_ID =
        IAgentId(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    /// @notice Deployer address, recorded for transparency only.
    /// No function reads this value and the deployer has no special powers.
    address public immutable owner;

    event Registered(address agent, uint256 index, uint256 timestamp);
    event CheckedIn(address agent, uint256 day, uint256 totalCheckIns);

    mapping(address => bool) private _registered;
    mapping(address => uint256) private _registeredAt; // block.timestamp of registration
    mapping(address => uint256) private _indexOf; // running index assigned at registration
    mapping(address => uint256) private _checkIns; // per-agent check-in count
    mapping(address => uint256) private _lastCheckInDay; // last UTC day (timestamp / 86400) checked in

    uint256 private _totalAgents;
    uint256 private _totalCheckIns; // global check-in count across all agents

    constructor() {
        owner = msg.sender;
    }

    /// @notice Register the caller as a verified agent.
    /// @dev Requires the caller to hold an Agent ID right now. One registration per address.
    function register() external {
        require(!_registered[msg.sender], "AgentGate: already registered");
        require(
            AGENT_ID.balanceOf(msg.sender) > 0,
            "AgentGate: Agent ID required"
        );

        uint256 index = _totalAgents;
        _registered[msg.sender] = true;
        _registeredAt[msg.sender] = block.timestamp;
        _indexOf[msg.sender] = index;
        _totalAgents = index + 1;

        emit Registered(msg.sender, index, block.timestamp);
    }

    /// @notice Check in for the current UTC day.
    /// @dev Requires registration AND that the caller still holds an Agent ID.
    /// One check-in per address per UTC day.
    function checkIn() external {
        require(_registered[msg.sender], "AgentGate: not registered");
        require(
            AGENT_ID.balanceOf(msg.sender) > 0,
            "AgentGate: Agent ID required"
        );

        uint256 day = block.timestamp / 86400;
        require(
            _checkIns[msg.sender] == 0 || _lastCheckInDay[msg.sender] != day,
            "AgentGate: already checked in today"
        );
        _lastCheckInDay[msg.sender] = day;
        uint256 agentTotal = _checkIns[msg.sender] + 1;
        _checkIns[msg.sender] = agentTotal;
        _totalCheckIns += 1;

        emit CheckedIn(msg.sender, day, agentTotal);
    }

    // ------------------------------------------------------------------
    // Views — the gate other projects compose with
    // ------------------------------------------------------------------

    /// @notice True if the address has ever registered (registration is permanent).
    function isRegistered(address agent) external view returns (bool) {
        return _registered[agent];
    }

    /// @notice THE GATE: true only if the address is registered AND currently
    /// holds an Agent ID. Other contracts call this to allowlist agent-only
    /// mints/actions, e.g. `require(agentGate.isVerifiedAgent(msg.sender))`.
    function isVerifiedAgent(address agent) external view returns (bool) {
        return _registered[agent] && AGENT_ID.balanceOf(agent) > 0;
    }

    /// @notice Total number of registered agents.
    function totalAgents() external view returns (uint256) {
        return _totalAgents;
    }

    /// @notice Total check-ins across all agents.
    function totalCheckIns() external view returns (uint256) {
        return _totalCheckIns;
    }

    /// @notice Number of check-ins by one agent.
    function checkInsOf(address agent) external view returns (uint256) {
        return _checkIns[agent];
    }

    /// @notice Registration timestamp (seconds) of an address, or 0 if unregistered.
    function registeredAt(address agent) external view returns (uint256) {
        return _registeredAt[agent];
    }

    /// @notice Running index assigned at registration (meaningful only if registered).
    function indexOf(address agent) external view returns (uint256) {
        return _indexOf[agent];
    }
}
