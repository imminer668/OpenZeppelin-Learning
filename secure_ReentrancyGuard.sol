// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 版本控制：
 import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/security/ReentrancyGuard.sol";
 import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/Address.sol";
 import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/access/Ownable.sol";

*/
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * 
 * 
 * 带 ReentrancyGuard 的安全银行SecureBank
 * 重要安全措施：
 * - nonReentrant modifier 防止重入
 * - Checks-Effects-Interactions 模式
 * - 事件先行，便于监控
 */
contract SecureBank is Ownable, ReentrancyGuard {
    
    using Address for address payable;
    
    // 余额映射
    mapping(address => uint256) public balances;
    
    // 总存款（用于统计）
    uint256 public totalDeposits;
    
    // 事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    
    /**
     * 存款
     * 使用 Checks-Effects-Interactions 模式
     */
    function deposit() external payable nonReentrant {
        // Checks: 验证输入
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        // Effects: 更新状态（在调用外部函数之前）
        uint256 newBalance = balances[msg.sender] + msg.value;
        balances[msg.sender] = newBalance;
        totalDeposits += msg.value;
        
        // Interactions: 事件（无外部调用，这里没问题）
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * 提现
     * 
     * 安全措施：
     * 1. nonReentrant 防止重入
     * 2. 先检查余额
     * 3. 清零余额后再转账（CEI 模式）
     * 4. 使用 call 而非 transfer（节省 Gas）
     */
    function withdraw(uint256 amount) external nonReentrant {
        // Checks
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // Effects: 先更新状态
        balances[msg.sender] -= amount;
        
        // Interactions: 最后才转账
        payable(msg.sender).sendValue(amount);
        
        emit Withdraw(msg.sender, amount);
    }
    
    /**
     * 转账给其他用户
     */
    function transfer(address payable to, uint256 amount) 
        external 
        nonReentrant 
    {
        // Checks
        require(amount > 0, "Transfer amount must be greater than 0");
        require(to != address(0), "Cannot transfer to zero address");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // Effects: 先更新状态
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
    }
    
    /**
     * 获取余额
     */
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
    
    /**
     * 仅管理员：提取合约余额
     */
    function withdrawContractBalance() external onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No balance to withdraw");
        
        // 转账给 owner
        payable(owner()).sendValue(contractBalance);
    }
}


