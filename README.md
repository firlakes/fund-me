# Fund-Me Research Grant Contract

A time-locked smart contract for research and project grant funding on the Stacks blockchain. This contract enables funders to create grants that automatically release funds to researchers after specified time delays.

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Contract Functions](#contract-functions)
- [Usage Examples](#usage-examples)
- [Deployment](#deployment)
- [Security Considerations](#security-considerations)
- [Error Codes](#error-codes)
- [Events](#events)

## Overview

The Fund-Me Grant Contract provides a trustless way to manage research funding with built-in time-locks. Funders deposit STX tokens that are held in escrow and automatically released to researchers after predetermined delays, ensuring milestone-based funding without requiring intermediaries.

## Features

- ⏰ **Time-locked releases** - Funds are held until specified block heights
- 🔒 **Trustless execution** - No intermediaries required for fund releases
- 🚨 **Emergency withdrawals** - Funders can reclaim funds before release time
- 📊 **Grant tracking** - Comprehensive history for researchers and funders
- 🛡️ **Security controls** - Multiple validation layers and access controls
- 📋 **Grant metadata** - Descriptions and timestamps for all grants

## Contract Functions

### Public Functions

#### `create-grant`
Creates a new time-locked grant.

```clarity
(create-grant 
  (researcher principal)     ;; Recipient address
  (amount uint)             ;; Grant amount in microSTX
  (delay-blocks uint)       ;; Time delay in blocks
  (description string-ascii 256)) ;; Project description
```

**Requirements:**
- Amount must be greater than 0
- Delay must be between 1 and 525,600 blocks (~1 year)
- Caller must have sufficient STX balance

#### `release-grant`
Releases funds to the researcher (callable by anyone once time-lock expires).

```clarity
(release-grant (grant-id uint))
```

**Requirements:**
- Grant must exist and not be already released
- Current block height must be >= release time

#### `emergency-withdraw`
Allows funders to withdraw funds before release time.

```clarity
(emergency-withdraw (grant-id uint))
```

**Requirements:**
- Caller must be the original funder
- Grant must not be released
- Current time must be before release time

### Read-Only Functions

#### `get-grant`
Returns complete grant information.

```clarity
(get-grant (grant-id uint))
```

#### `is-grant-ready`
Checks if a grant is ready for release.

```clarity
(is-grant-ready (grant-id uint))
```

#### `get-researcher-grants`
Returns all grant IDs for a researcher.

```clarity
(get-researcher-grants (researcher principal))
```

#### `get-funder-grants`
Returns all grant IDs for a funder.

```clarity
(get-funder-grants (funder principal))
```

#### `blocks-until-release`
Calculates remaining blocks until grant release.

```clarity
(blocks-until-release (grant-id uint))
```

#### `get-contract-balance`
Returns the total STX balance held by the contract.

```clarity
(get-contract-balance)
```

## Usage Examples

### Creating a Grant

```clarity
;; Create a 30-day grant for 1000 STX to fund AI research
(contract-call? .fund-me-grant create-grant
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; Researcher address
  u1000000000                                     ;; 1000 STX (in microSTX)
  u43200                                         ;; 30 days (assuming 1 min blocks)
  "AI Research Project - Phase 1")
```

### Releasing a Grant

```clarity
;; Anyone can trigger release once time-lock expires
(contract-call? .fund-me-grant release-grant u1)
```

### Emergency Withdrawal

```clarity
;; Funder withdraws before release time
(contract-call? .fund-me-grant emergency-withdraw u1)
```

### Checking Grant Status

```clarity
;; Check if grant is ready for release
(contract-call? .fund-me-grant is-grant-ready u1)

;; Get complete grant details
(contract-call? .fund-me-grant get-grant u1)

;; Check blocks remaining until release
(contract-call? .fund-me-grant blocks-until-release u1)
```

## Deployment

### Prerequisites
- Stacks CLI installed
- STX testnet/mainnet wallet configured
- Clarinet for testing (recommended)

### Deploy to Testnet
```bash
stx deploy_contract fund-me-grant fund-me-grant.clar --testnet
```

### Deploy to Mainnet
```bash
stx deploy_contract fund-me-grant fund-me-grant.clar --mainnet
```

### Testing with Clarinet
```toml
# Clarinet.toml
[contracts.fund-me-grant]
path = "contracts/fund-me-grant.clar"
```

## Security Considerations

### Time-Lock Security
- Grants cannot be released before the specified time
- Maximum grant duration is limited to 1 year
- Emergency withdrawals only available before release time

### Access Control
- Only funders can perform emergency withdrawals
- Grant releases can be triggered by anyone (permissionless)
- No admin privileges or backdoors

### Reentrancy Protection
- State changes occur before external calls
- Grant release status prevents double-spending

### Input Validation
- All amounts and durations are validated
- Principal addresses are verified
- String lengths are bounded

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u401 | `ERR_UNAUTHORIZED` | Caller not authorized for action |
| u402 | `ERR_INVALID_AMOUNT` | Grant amount must be greater than 0 |
| u403 | `ERR_TIME_NOT_REACHED` | Time-lock has not expired yet |
| u404 | `ERR_GRANT_NOT_FOUND` | Grant ID does not exist |
| u405 | `ERR_ALREADY_RELEASED` | Grant has already been released |
| u406 | `ERR_INVALID_DURATION` | Duration outside valid range |
| u409 | `ERR_GRANT_ALREADY_EXISTS` | Grant ID already exists |

## Events

The contract emits events for important actions:

### Grant Created
```clarity
{ event: "grant-created", grant-id: uint, researcher: principal, amount: uint }
```

### Grant Released
```clarity
{ event: "grant-released", grant-id: uint, researcher: principal, amount: uint }
```

### Grant Withdrawn
```clarity
{ event: "grant-withdrawn", grant-id: uint, funder: principal, amount: uint }
```
