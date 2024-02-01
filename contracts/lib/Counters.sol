// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Counters
 * @dev Provides an incrementing uint256 mapped by address
 */
library Counters {
    struct Counter {
        mapping(address => uint256) currentNonce;
    }

    /**
     * @dev "Consume a nonce": return the current value and increment
     */
    function useNonce(
        Counter storage counter,
        address owner
    ) internal returns (uint256 currentNonce) {
        currentNonce = counter.currentNonce[owner];
        counter.currentNonce[owner]++;
    }

    /**
     * @dev "Consume a nonce": return the current value and increment
     */
    function current(
        Counter storage counter,
        address owner
    ) internal view returns (uint256) {
        return counter.currentNonce[owner];
    }
}
