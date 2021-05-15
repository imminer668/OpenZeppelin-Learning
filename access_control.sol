// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *RoleBasedContract
 *基于角色的权限控制合约
 * 
 * 角色设计：
 * - ADMIN_ROLE: 超级管理员，可管理所有角色
 * - OPERATOR_ROLE: 运营人员，可执行日常操作
 * - FINANCE_ROLE: 财务人员，可处理财务相关操作，比如审批提现
 * - MINTER_ROLE: 铸造人员，可铸造代币
 * 
 * _setRoleAdmin为每个 role 的 admin 是更高级别的角色，形成权限层级
 * 版本更新太快了，防止后续版本碟调导致运行不了，可以导入 这个Github的连接
 * import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/AccessControl.sol";
 * import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/Context.sol";
*/

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 *角色定义常量
 */
contract Roles {
    // 角色常量
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant FINANCE_ROLE = keccak256("FINANCE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // 角色层级关系
    // ADMIN_ROLE 是所有角色的 admin
    // OPERATOR_ROLE 的 admin 是 ADMIN_ROLE
    // 其他角色同理
}

/**
 *RoleBasedContract
 *使用 AccessControl 实现多角色权限控制
 *Context 提供有关当前执行上下文的信息，包括交易的发送者及其数据
 */
contract RoleBasedContract is Context, AccessControl, Roles {
    
    // 代币状态
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _owners; // tokenId => owner
    uint256 private _totalSupply;
    uint256 private _nextTokenId;
    
    // 暂停状态
    bool public paused = false;
    
    // 提现状态
    mapping(address => uint256) private _pendingWithdrawals;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event PausedChanged(bool isPaused);
    
    /**
     *构造函数
     * 
     * 权限层级设计：
     * - 部署者获得 ADMIN_ROLE
     * - ADMIN_ROLE 是所有其他角色的 admin
     * - 可以授予和撤销其他角色
     */
    constructor() {
        // 部署者获得 ADMIN_ROLE
        _setupRole(ADMIN_ROLE, _msgSender());
        
        // 设置 ADMIN_ROLE 为所有角色的 admin
        // 这样 ADMIN 可以管理所有角色
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(FINANCE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        
        // 也可以让 OPERATOR_ROLE 成为更低级角色的 admin,如下
        // _setRoleAdmin(MINTER_ROLE, OPERATOR_ROLE);
    }
    
    // ========== 存款/提现功能 ===========
    
    /**
     *存款（任何人都可以调用）
     */
    function deposit() external payable {
        require(msg.value > 0, "Oh,No,Must send ETH");
        _pendingWithdrawals[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     *申请提现（需要 FINANCE_ROLE 财务审批）
     * 这里简化处理，实际应该是两步流程
     */
    function withdraw(uint256 amount) external {
        require(_pendingWithdrawals[msg.sender] >= amount, "Insufficient balance");
        require(!paused, "Contract is paused");
        
        _pendingWithdrawals[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     *获取待提取余额
     */
    function getPendingWithdrawals(address user) external view returns (uint256) {
        return _pendingWithdrawals[user];
    }
    
    /**
     *财务人员确认提现（仅 FINANCE_ROLE）
     */
    function confirmWithdrawal(address payable user, uint256 amount) 
        external 
        onlyRole(FINANCE_ROLE) 
    {
        require(_pendingWithdrawals[user] >= amount, "Insufficient balance");
        require(!paused, "Contract is paused");
        
        _pendingWithdrawals[user] -= amount;
        user.transfer(amount);
        emit Withdrawal(user, amount);
    }
    
    /**
     *批量处理提现（仅 FINANCE_ROLE）
     */
    function batchConfirmWithdrawals(address[] calldata users, uint256[] calldata amounts)
        external
        onlyRole(FINANCE_ROLE)
    {
        require(users.length == amounts.length, "Length mismatch");
        require(!paused, "Contract is paused");
        
        for (uint256 i = 0; i < users.length; i++) {
            require(_pendingWithdrawals[users[i]] >= amounts[i], "Insufficient balance");
            _pendingWithdrawals[users[i]] -= amounts[i];
            payable(users[i]).transfer(amounts[i]);
            emit Withdrawal(users[i], amounts[i]);
        }
    }
    
    // ========== 代币铸造功能 ==========
    
    /**
     *铸造 NFT（仅 MINTER_ROLE）
     */
    function mintNFT(address to) 
        external 
        onlyRole(MINTER_ROLE) 
        returns (uint256) 
    {
        require(!paused, "Contract is paused");
        
        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _totalSupply++;
        
        emit TokenMinted(to, tokenId);
        return tokenId;
    }
    
    /**
     *铸造批量 NFT（仅 MINTER_ROLE）
     */
    function mintBatchNFT(address to, uint256 count)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256[] memory)
    {
        require(!paused, "Contract is paused");
        
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _nextTokenId++;
            _owners[tokenIds[i]] = to;
            _totalSupply++;
            emit TokenMinted(to, tokenIds[i]);
        }
        return tokenIds;
    }
    
    // ========== 暂停功能 ==========
    
    /**
     *暂停合约（仅 PAUSER_ROLE）
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
        emit PausedChanged(true);
    }
    
    /**
     *解除暂停（仅 PAUSER_ROLE）
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        paused = false;
        emit PausedChanged(false);
    }
    
    // ========== 角色管理功能 ==========
    
    /**
     *添加操作员（仅 ADMIN_ROLE）
     */
    function addOperator(address operator) external onlyRole(ADMIN_ROLE) {
        grantRole(OPERATOR_ROLE, operator);
    }
    
    /**
     *移除操作员（仅 ADMIN_ROLE）
     */
    function removeOperator(address operator) external onlyRole(ADMIN_ROLE) {
        revokeRole(OPERATOR_ROLE, operator);
    }
    
    /**
     *添加财务人员（仅 ADMIN_ROLE）
     */
    function addFinance(address finance) external onlyRole(ADMIN_ROLE) {
        grantRole(FINANCE_ROLE, finance);
    }
    
    /**
     *移除财务人员（仅 ADMIN_ROLE）
     */
    function removeFinance(address finance) external onlyRole(ADMIN_ROLE) {
        revokeRole(FINANCE_ROLE, finance);
    }
    
    /**
     *添加铸造人员（可由 ADMIN 或 OPERATOR 执行）
     */
    function addMinter(address minter) external {
        // 只有 ADMIN 或现有 OPERATOR 可以添加 MINTER
        require(
            hasRole(ADMIN_ROLE, _msgSender()) || hasRole(OPERATOR_ROLE, _msgSender()),
            "Only admin or operator can add minters"
        );
        grantRole(MINTER_ROLE, minter);
    }
    
    // ========== 查询功能 ==========
    
    /**
     *获取 NFT 所有者
     */
    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }
    
    /**
     *获取总供应量
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }
    
    /**
     *查询是否为管理员
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }
    
    /**
     *查询是否为操作员
     */
    function isOperator(address account) external view returns (bool) {
        return hasRole(OPERATOR_ROLE, account);
    }
    
    /**
     *查询是否为财务人员
     */
    function isFinance(address account) external view returns (bool) {
        return hasRole(FINANCE_ROLE, account);
    }
    
    /**
     *查询是否为铸造人员
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }
    
    /**
     *获取某角色的 admin 角色
     */
    function _getRoleAdmin(bytes32 role) external view  returns (bytes32) {
        return getRoleAdmin(role);
    }
    
    // ========== ERC165 ==========
    
    function supportsInterface(bytes4 interfaceId)
        public view override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 *OwnableContract
 *简单单一所有者合约
 * 
 * 适用场景：
 * - 简单的管理员合约
 * - 不需要复杂角色系统
 * - 只有一个决策者
 */
contract OwnableContract is Context {
    
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
     *构造函数
     * msg.sender 成为 owner
     */
    constructor() {
        _transferOwnership(_msgSender());
    }
    
    /**
     *返回 owner 地址
     */
    function owner() public view returns (address) {
        return _owner;
    }
    
    /**
     *modifier：仅 owner 可执行
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    /**
     *转移所有权
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        _transferOwnership(newOwner);
    }
    
    /**
     *放弃所有权（谨慎使用）
     */
    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }
    
    /**
     *内部转移所有权
     */
    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 *SimpleTokenWithOwnable
 *Ownable + ERC20（不完全） 简单组合示例
 */
contract SimpleTokenWithOwnable is Context, OwnableContract {
    
    string public constant name = "SimpleToken";
    string public constant symbol = "STK";
    uint256 public constant decimals = 18;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    /**
     *仅 owner 可铸造
     */
    function mint(address to, uint256 amount) external onlyOwner {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }
    
    /**
     *任何人可销毁自己的代币
     */
    function burn(uint256 amount) external {
        require(balanceOf[_msgSender()] >= amount, "Insufficient balance");
        balanceOf[_msgSender()] -= amount;
        totalSupply -= amount;
        emit Burn(_msgSender(), amount);
        emit Transfer(_msgSender(), address(0), amount);
    }
    
    /**
     *转账
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[_msgSender()] >= amount, "Insufficient balance");
        balanceOf[_msgSender()] -= amount;
        balanceOf[to] += amount;
        emit Transfer(_msgSender(), to, amount);
        return true;
    }
}
