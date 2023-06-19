// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/ISRC20.sol";
import "../interfaces/IUSDT.sol";
import "./IAffinity.sol";

/// @notice Arch design for roles and privileges management
contract Affinity is AccessControl, IAffinity {
    /// #if_updated {:msg "Constructor can change the value"} msg.sig == 0x0 ==> SAVIOR == msg.sender;
    /// #if_updated {:msg "Only transferSavior can change it"} msg.sig == 0x0 ==> SAVIOR == msg.sender;
    /// #if_updated msg.sig != 0x0 ==> 
    ///    (
    ///        msg.sig == bytes4(keccak256("transferSavior(address)")) && 
    ///        msg.sender == old(SAVIOR)
    ///    );
    address public SAVIOR;

    /// @notice Initial bunch of roles
    bytes32 public constant ROOT_GROUP = keccak256("ROOT_GROUP");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant ALLY_ROLE = keccak256("ALLY_ROLE");

    modifier isSavior() {
        require(msg.sender == SAVIOR, "Affinity: Caller is not the Savior");
        _;
    }

    modifier isKeeper() {
        require(hasRole(KEEPER_ROLE, msg.sender), "Affinity: Caller is not keeper");
        _;
    }

    modifier isManager() {
        require(hasRole(MANAGER_ROLE, msg.sender), "Affinity: Caller is not manager");
        _;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Affinity: EOA required");
        _;
    }

    constructor(address _SAVIOR) public {
        SAVIOR = _SAVIOR;

        _setupRole(ROOT_GROUP, _SAVIOR);

        _setRoleAdmin(KEEPER_ROLE, ROOT_GROUP);
        _setRoleAdmin(MANAGER_ROLE, ROOT_GROUP);
        _setRoleAdmin(ALLY_ROLE, ROOT_GROUP);
    }

    /// #if_succeeds SAVIOR == multiSigWallet;
    /// #if_succeeds old(SAVIOR) == msg.sender;
    function transferSavior(address multiSigWallet) external isSavior {
        require(multiSigWallet != address(0), "Affinity: Account is zero address");
        require(Address.isContract(multiSigWallet), "Affinity: EOA is not allowed");
        require(SAVIOR != multiSigWallet, "Affinity: Nonsense");
        SAVIOR = multiSigWallet;
        _setupRole(ROOT_GROUP, multiSigWallet);
        renounceRole(ROOT_GROUP, msg.sender);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds ISRC20(token).allowance(address(this), spender) == amount;
    function allow(
        address token,
        address spender,
        uint256 amount
    ) external override isSavior {
        ISRC20(token).approve(spender, amount);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    function allowTetherToken(
        address token,
        address spender,
        uint256 amount
    ) external override isSavior {
        _allowTetherToken(token, spender, amount);
    }


    /// #if_succeeds 
    ///     IUSDT(token).allowance(address(this), spender) == amount || 
    ///     (old(IUSDT(token).allowance(address(this), spender)) >= amount && IUSDT(token).allowance(address(this), spender) == old(IUSDT(token).allowance(address(this), spender))) || 
    ///     (old(IUSDT(token).allowance(address(this), spender)) < amount && old(IUSDT(token).allowance(address(this), spender)) > 0 && IUSDT(token).allowance(address(this), spender) == 0);
    function _allowTetherToken(
        address token,
        address spender,
        uint256 amount
    ) internal {
        IUSDT USDT = IUSDT(token);
        uint256 _allowance = USDT.allowance(address(this), spender);
        if (_allowance >= amount) {
            return;
        }

        if (_allowance > 0) {
            USDT.approve(spender, 0);
        }
        USDT.approve(spender, amount);
    }
}
