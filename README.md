
# PROOF-of-TRUST

A Clarity smart contract for a decentralized Trust Endorsement Registry on the Stacks blockchain.

## Overview

This contract enables users to endorse each other, track trust scores, and manage trust relationships in a transparent and decentralized manner. It includes robust admin controls, error handling, and emergency pause functionality.

## Features

- **Endorsements:** Users can endorse others with a trust score and optional note.
- **Trust Scores:** Aggregate trust scores and endorsement counts are tracked for each user.
- **Revocation:** Endorsements can be revoked by the sender or forcibly removed by an admin.
- **Admin Controls:** Owner can add or remove admins, pause/unpause the contract, and manage endorsements.
- **Read-Only Views:** Query endorsement info, trust scores, endorsement counts, and contract state.

## Contract Structure

- `endorse`: Endorse another user with a score and note.
- `revoke-endorsement`: Remove your endorsement from a user.
- `admin-remove`: Admins can forcibly remove an endorsement.
- `add-admin` / `remove-admin`: Owner can manage admin accounts.
- `pause` / `unpause`: Owner can pause or resume contract operations.
- Read-only functions for querying endorsements, trust scores, and contract state.

## Error Codes

- `u100`: Unauthorized
- `u101`: Contract is paused
- `u102`: Self-endorsement not allowed
- `u103`: Already endorsed
- `u104`: Not endorsed
- `u105`: Invalid score

## Usage

1. **Deploy the contract** to the Stacks blockchain.
2. **Endorse a user:**  
   Call `endorse` with the target principal, score, and optional note.
3. **Revoke an endorsement:**  
   Call `revoke-endorsement` with the target principal.
4. **Admin actions:**  
   Use `admin-remove`, `add-admin`, `remove-admin`, `pause`, and `unpause` as needed.

## Development

- Contract: PROOF-of-TRUST.clar
- Tests: PROOF-of-TRUST.test.ts
- Configuration:  
  - Clarinet.toml  
  - settings
