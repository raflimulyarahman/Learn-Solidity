// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract StudentData {
    // TODO 1: Deklarasikan 6 state variables
    // Hint: string public studentName;
    // Hint: uint256 public studentId;
    // ... tulis 4 lainnya!
    string public studentName;
    uint256 public studentId;
    bool public isActive;
    address public wallet;
    uint256 public registeredTime;
    uint256 public credits;

    // TODO 2: Buat constructor
    constructor() {
        // Set nilai awal untuk semua variables
        // Hint: studentName = "Budi Santoso";
        // Hint: wallet = msg.sender;
        studentName = "Budi Santoso";
        studentId = 2101001;
        isActive = true;
        wallet = msg.sender;
        registeredTime = block.timestamp;

    }

    // TODO 3: Buat fungsi updateCredits()
    // Hint: function updateCredits() public { ... }

    function updateCredits() public {
        credits += 3;
    }

    // TODO 4: Buat fungsi getAge()
    // Hint: function getAge() public view returns (uint256) { ... }
    // Hint: return block.timestamp - registeredTime;

    function getAge() public view returns (uint256) {
        return block.timestamp - registeredTime;
    }

}