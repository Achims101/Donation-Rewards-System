# Tokenized Donation Smart Contract

A Clarity smart contract that enables secure, transparent, and incentivized charitable donations on the Stacks blockchain. The contract implements a reward system using fungible tokens to incentivize donations and maintain donor engagement.

## Features

### Core Functionality
- **Donation Processing**: Accept STX tokens as donations with customizable minimum amounts
- **Donation Categories**: Support for categorized donations with optional purpose labels
- **Reward Tokens**: Automatic minting of reward tokens proportional to donation amounts
- **Donation Tracking**: Comprehensive tracking of individual and cumulative donations
- **Donor Statistics**: Detailed donor activity monitoring including donation streaks
- **Administrative Controls**: Secure contract management functions for authorized administrators

### Reward Mechanism
- Donors receive reward tokens 1:1 with their donation amount
- Additional bonus rewards for reaching donation thresholds
- Reward multiplier system for consistent donors
- Daily streak tracking for continuous engagement

## Contract Constants

- `MINIMUM_DONATION_REWARD_MULTIPLIER`: 10x minimum donation required for bonus rewards
- `DONATION_REWARD_TOKEN_RATE`: 10% bonus token distribution rate
- `DAILY_BLOCK_COUNT`: 144 blocks (approximately one day for streak calculations)
- Default minimum donation: 1 STX (1,000,000 microSTX)

## Functions

### Public Functions

#### For Donors
1. `submit-donation`
   ```clarity
   (submit-donation (donation-amount-stx uint) (donation-purpose (optional (string-ascii 64))))
   ```
   - Submit a donation with optional purpose category
   - Automatically mints reward tokens
   - Updates donor statistics and global metrics

2. `claim-donor-reward-tokens`
   ```clarity
   (claim-donor-reward-tokens)
   ```
   - Claim bonus reward tokens after meeting threshold requirements
   - One-time claim per donation threshold
   - Requires minimum cumulative donations

#### For Administrators
1. `update-minimum-donation-requirement`
   ```clarity
   (update-minimum-donation-requirement (new-minimum-amount-stx uint))
   ```
   - Update the minimum required donation amount

2. `toggle-donation-system-pause`
   ```clarity
   (toggle-donation-system-pause)
   ```
   - Pause/unpause donation functionality
   - Emergency control mechanism

3. `withdraw-donation-funds`
   ```clarity
   (withdraw-donation-funds (withdrawal-amount-stx uint))
   ```
   - Withdraw collected donations to contract owner

### Read-Only Functions

1. `get-donor-details`
   ```clarity
   (get-donor-details (donor-wallet-address principal))
   ```
   - Retrieve detailed donor statistics

2. `get-donation-details`
   ```clarity
   (get-donation-details (donation-sequence-id uint))
   ```
   - Get specific donation transaction details

3. `get-donation-system-statistics`
   ```clarity
   (get-donation-system-statistics)
   ```
   - View global contract statistics

## Data Structures

### Donor Activity Records
```clarity
{
    total-donation-amount: uint,
    donation-count: uint,
    most-recent-donation-block: uint,
    reward-tokens-claimed: bool,
    consecutive-donation-days: uint
}
```

### Donation History Records
```clarity
{
    donor-wallet-address: principal,
    donation-amount-stx: uint,
    donation-block-height: uint,
    donation-token-identifier: uint,
    donation-purpose-category: (optional (string-ascii 64))
}
```

## Error Codes

- `ERROR_NOT_CONTRACT_OWNER` (u100): Operation restricted to contract owner
- `ERROR_DONATION_AMOUNT_INVALID` (u101): Donation amount below minimum
- `ERROR_USER_UNAUTHORIZED` (u102): Unauthorized operation attempt
- `ERROR_REWARDS_ALREADY_CLAIMED` (u103): Bonus rewards already claimed
- `ERROR_WALLET_ADDRESS_INVALID` (u104): Invalid wallet address provided
- `ERROR_DONATION_SYSTEM_PAUSED` (u105): Contract operations are paused
- `ERROR_TOKEN_TRANSFER_FAILED` (u106): Token transfer operation failed
- `ERROR_INSUFFICIENT_DONATION_BALANCE` (u107): Insufficient balance for operation
- `ERROR_DONATION_TOKEN_ID_INVALID` (u108): Invalid donation token ID
- `ERROR_RECORD_NOT_FOUND` (u109): Requested record not found
- `ERROR_ZERO_DONATION_AMOUNT` (u110): Zero amount not allowed

## Security Considerations

1. **Access Control**
   - Contract owner verification for administrative functions
   - Strict validation of donation amounts and addresses

2. **Funds Safety**
   - Protected withdrawal mechanism
   - Emergency pause functionality
   - Validated token transfers

3. **Data Integrity**
   - Comprehensive error handling
   - Transaction record maintenance
   - Atomic operations for critical functions