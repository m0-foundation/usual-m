// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockM {
    uint256 internal constant _EXP_SCALED_ONE = 1e12;

    uint128 public currentIndex;

    mapping(address account => bool isEarning) public isEarning;

    mapping(address account => uint256 balance) _balances;
    mapping(address account => uint256 principal) _principals;

    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {}

    function balanceOf(address account_) external view returns (uint256 balance_) {
        if (isEarning[account_]) return (_principals[account_] * currentIndex) / _EXP_SCALED_ONE;

        return _balances[account_];
    }

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {
        _transfer(msg.sender, recipient_, amount_);
        return true;
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_) external returns (bool success_) {
        _transfer(sender_, recipient_, amount_);

        return true;
    }

    function setBalanceOf(address account_, uint256 balance_) external {
        if (isEarning[account_]) {
            _principals[account_] = (balance_ * _EXP_SCALED_ONE) / currentIndex;
        } else {
            _balances[account_] = balance_;
        }
    }

    function setCurrentIndex(uint128 currentIndex_) external {
        currentIndex = currentIndex_;
    }

    function startEarning() external {
        isEarning[msg.sender] = true;

        _principals[msg.sender] = (_balances[msg.sender] * _EXP_SCALED_ONE) / currentIndex;
        delete _balances[msg.sender];
    }

    function stopEarning() external {
        isEarning[msg.sender] = false;

        _balances[msg.sender] = (_principals[msg.sender] * currentIndex) / _EXP_SCALED_ONE;
        delete _principals[msg.sender];
    }

    function approve(address, uint256) external returns (bool) {
        return true;
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal {
        if (isEarning[sender_]) {
            _principals[sender_] -= (amount_ * _EXP_SCALED_ONE) / currentIndex;
        } else {
            _balances[sender_] -= amount_;
        }

        if (isEarning[recipient_]) {
            _principals[recipient_] += (amount_ * _EXP_SCALED_ONE) / currentIndex;
        } else {
            _balances[recipient_] += amount_;
        }
    }
}
