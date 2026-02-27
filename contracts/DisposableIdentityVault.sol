// SPDX-License-Identifier: MIT AND Proprietary
// © 2026 Andrew Thomas. All Rights Reserved. 
// This software is proprietary. Unauthorized copying is prohibited.


pragma solidity ^0.8.20;

/**
 * @title DisposableIdentityVault
 * @dev Secure storage for encrypted PII (SSN/IDs) using disposable pseudo-codes.
 * This version includes a pay-to-access model and "Burn-on-Read" functionality.
 */
contract DisposableIdentityVault {
    address payable public owner;
    uint256 public accessFee = 0.01 ether; // Fee for business to check ID

    // We store 'bytes' instead of 'string' for better encryption compatibility
    mapping(uint256 => bytes) private encryptedVault;
    mapping(uint256 => bool) public isCodeActive;

    // Events for frontend tracking
    event TokenGenerated(uint256 indexed code);
    event AccessLogged(uint256 indexed code, address indexed business, uint256 feePaid);
    event FeeWithdrawn(address indexed owner, uint256 amount);

    constructor() {
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Admin only");
        _;
    }

    /**
     * @dev Step 1: User/Admin stores the encrypted data.
     * Takes an encrypted 'blob' and a desired number of disposable codes.
     */
    function generateAndStore(bytes memory _encryptedSecret, uint256 _count) public onlyOwner {
        // Simple seed for pseudo-randomization (In production, use Chainlink VRF)
        bytes32 seed = keccak256(abi.encodePacked(_encryptedSecret, block.timestamp, msg.sender));
        
        for (uint i = 0; i < _count; i++) {
            seed = keccak256(abi.encodePacked(seed, i));
            // Generate a 15-27 digit pseudo-code
            uint256 code = (uint256(seed) % (10**27 - 10**15)) + 10**15;
            
            encryptedVault[code] = _encryptedSecret;
            isCodeActive[code] = true;

            emit TokenGenerated(code);
        }
    }

    /**
     * @dev Step 2: Public verification. 
     * Businesses can check if a QR code/token is still valid before paying.
     */
    function checkTokenStatus(uint256 _code) public view returns (bool) {
        return isCodeActive[_code];
    }

    /**
     * @dev Step 3: Business pays to access data.
     * Logic: Release data -> Burn Token -> Collect Fee.
     */
    function businessRecall(uint256 _code) public payable returns (bytes memory) {
        require(msg.value >= accessFee, "Payment too low for access");
        require(isCodeActive[_code], "Token invalid or already used");

        bytes memory secretData = encryptedVault[_code];

        // "BURN-ON-READ" MECHANISM
        delete encryptedVault[_code];
        isCodeActive[_code] = false;

        emit AccessLogged(_code, msg.sender, msg.value);
        
        return secretData; 
    }

    /**
     * @dev Step 4: Monetization.
     * Owner can change the access fee based on market value.
     */
    function setAccessFee(uint256 _newFeeInWei) public onlyOwner {
        accessFee = _newFeeInWei;
    }

    /**
     * @dev Step 5: Profit realization.
     * Collects all the ETH sent by businesses.
     */
  /*  function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");
        
        owner.transfer(balance);
        emit FeeWithdrawn(owner, balance);
    } */

    // Safety fallback to receive funds
    receive() external payable {}
}