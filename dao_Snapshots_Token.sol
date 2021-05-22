// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

	/**
	 * GovernanceToken
	 * 治理代币ERC20 + AccessControl + Snapshots
	 * OpenZeppelin 组合实战
	 * 
	 * 功能：
	 * - 标准 ERC20 代币
	 * - ERC20Snapshot 快照功能（比如用于DAO治理投票）
	 * - AccessControl角色控制铸造
	 */

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/Context.sol";

	/**
	 * GovernanceToken
	 * 治理代币合约
	 * 
	 * 角色：
	 * - MINTER_ROLE: 可以铸造代币
	 * - SNAPSHOT_ROLE: 可以创建快照
	 * 
	 * - ERC20Snapshot 用于时间点快照
	 * - 快照支持治理投票
	 */
contract GovernanceToken is Context, AccessControl, ERC20, ERC20Snapshot {
    
	// 铸造角色
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	// 快照管理员
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    
    // 快照 ID 到代币总供应的映射,e
    mapping(uint256 => uint256) private _totalSupplySnapshot;
    
    /**
     * 构造函数,初始化ERC token。
     */
    constructor() ERC20("Governance Token", "GOV") {
        // 部署者获得管理员权限
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        
        // 部署者获得铸造和快照权限
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(SNAPSHOT_ROLE, _msgSender());
    }
    
    /**
     * 创建快照
     * 快照当前余额状态，用于治理投票
     */
    function snapshot() external onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        uint256 snapshotId = _snapshot();
        
        // 记录快照的总供应量
        _totalSupplySnapshot[snapshotId] = totalSupply();
        
        return snapshotId;
    }
    
    /**
     * 铸造代币
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    
    /**
     * 批量铸造
     */
    function mintBatch(address[] calldata to, uint256[] calldata amounts) 
        external 
        onlyRole(MINTER_ROLE) 
    {
        require(to.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], amounts[i]);
        }
    }
    
    /**
     * 销毁代币
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
    
    /**
     * 获取某个快照的总供应量
     */
    function _totalSupplyAt(uint256 snapshotId) external view  returns (uint256) {
        return _totalSupplySnapshot[snapshotId];
    }
    
    /**
     * 获取某个地址在快照时的余额
     */
    function _balanceOfAt(address account, uint256 snapshotId) 
        external 
        view 
        returns (uint256) 
    {
        return balanceOfAt(account, snapshotId);
    }
    
    // ==========额 ERC165 ==========
    
    function supportsInterface(bytes4 interfaceId)
        public view override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    virtual
    override(ERC20, ERC20Snapshot)
	{
		super._beforeTokenTransfer(from, to, amount);
	}
}