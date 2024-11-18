// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockSmartM {
    mapping(address account => uint256 balance) public balanceOf;

    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {}

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {
        balanceOf[msg.sender] -= amount_;
        balanceOf[recipient_] += amount_;

        return true;
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_) external returns (bool success_) {
        balanceOf[sender_] -= amount_;
        balanceOf[recipient_] += amount_;

        return true;
    }

    function setBalanceOf(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }
}
