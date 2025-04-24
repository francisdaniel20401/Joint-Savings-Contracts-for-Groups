# 🏦 Ajo Smart Contract 🏦

## 📝 Description

The Ajo smart contract implements a digital version of the traditional African thrift savings system (also known as Ajo, Esusu, or Susu). This system allows a group of people to contribute a fixed amount of money at regular intervals, with one member receiving the total pool each cycle until everyone has received a payout.

## 🌟 Features

- ✅ Group membership management
- 💰 Fixed contribution amounts
- 🔄 Automated rotation of payouts
- 🔒 Secure fund management
- 📊 Transparent contribution tracking

## 🚀 Getting Started

### Prerequisites

- Clarinet installed
- Stacks wallet for testing

### 📋 Contract Functions

#### Admin Functions

- `initialize(contribution-amount, members-count)`: Set up the Ajo group parameters
- `start-cycle()`: Begin the contribution and payout cycle
- `withdraw-funds(amount)`: Emergency function to withdraw funds (admin only)
- `change-admin(new-admin)`: Transfer admin rights to another principal

#### Member Functions

- `join-group()`: Join the Ajo savings group
- `contribute()`: Make your contribution for the current cycle
- `claim-payout()`: Claim your payout when it's your turn

#### Read-Only Functions

- `get-admin()`: Returns the current admin
- `get-contribution-amount()`: Returns the fixed contribution amount
- `get-cycle-length()`: Returns the number of members/cycle length
- `get-current-cycle()`: Returns the current cycle number
- `is-cycle-started()`: Checks if a cycle is in progress
- `get-total-members()`: Returns the total number of members
- `get-current-recipient()`: Returns the current recipient's ID
- `get-total-balance()`: Returns the total balance in the contract
- `is-member(user)`: Checks if a principal is a member
- `get-member-id(user)`: Returns a member's ID
- `has-contributed(user, cycle)`: Checks if a member has contributed in a specific cycle
- `has-received-payout(user, cycle)`: Checks if a member has received a payout in a specific cycle
- `get-cycle-contribution(cycle)`: Returns total contributions for a specific cycle

## 🔄 Typical Workflow

1. Admin initializes the group with contribution amount and member count
2. Members join the group until the required number is reached
3. Admin starts the cycle
4. Members make their contributions
5. Current recipient claims the pool when all contributions are in
6. Process repeats until all members have received a payout
7. A new cycle can begin if desired

## ⚠️ Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Caller is not authorized for this action
- `ERR-ALREADY-MEMBER (u101)`: Principal is already a member
- `ERR-NOT-MEMBER (u102)`: Principal is not a member
- `ERR-INVALID-AMOUNT (u103)`: Invalid amount specified
- `ERR-CYCLE-IN-PROGRESS (u104)`: A cycle is already in progress
- `ERR-CYCLE-NOT-STARTED (u105)`: No cycle has been started
- `ERR-ALREADY-CONTRIBUTED (u106)`: Member has already contributed this cycle
- `ERR-NOT-PAYOUT-TIME (u107)`: Not this member's turn for payout
- `ERR-ALREADY-RECEIVED-PAYOUT (u108)`: Member has already received payout
- `ERR-INSUFFICIENT-FUNDS (u109)`: Insufficient funds for operation
- `ERR-CYCLE-COMPLETE (u110)`: The cycle is complete
- `ERR-INVALID-CYCLE-LENGTH (u111)`: Invalid cycle length
- `ERR-INVALID-CONTRIBUTION-AMOUNT (u112)`: Invalid contribution amount

## 🔗 Testing

Use Clarinet console to test the contract functions:

```
clarinet console
```

Example test sequence:
1. Initialize the group
2. Have members join
3. Start the cycle
4. Make contributions
5. Claim payouts

