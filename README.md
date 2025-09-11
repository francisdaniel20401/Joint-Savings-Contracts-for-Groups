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

## 🚨 Emergency Fund System

The Ajo contract now includes a comprehensive emergency fund system that provides a safety net for group members facing unexpected financial hardships.

### Features

- **Voluntary Contributions**: Members can contribute to the emergency fund to build a collective safety net
- **Democratic Loan Approval**: Group members vote on emergency loan requests to ensure responsible lending
- **Flexible Repayment**: Borrowers can repay loans at their own pace with no interest charges
- **Eligibility Requirements**: Members must have participated in at least 3 cycles to be eligible
- **Fund Protection**: Maximum loan amounts are capped at 30% of the emergency fund balance

### Emergency Fund Functions

#### Member Functions
- `contribute-to-emergency-fund(amount)`: Add funds to the emergency pool
- `request-emergency-loan(amount, reason)`: Request an emergency loan with justification
- `vote-on-loan(loan-id, approve)`: Vote to approve or reject loan requests
- `repay-loan(loan-id, amount)`: Make repayments on approved loans

#### Admin Functions
- `set-emergency-fund-params(max-loan-pct, min-tenure, approval-threshold)`: Configure fund parameters
- `finalize-loan-approval(loan-id)`: Process loan approval after voting
- `disburse-loan(loan-id)`: Transfer approved loan to borrower

#### Read-Only Functions
- `get-emergency-fund-balance()`: Check current fund balance
- `get-emergency-loan(loan-id)`: View loan details
- `is-member-eligible-for-loan(member)`: Check if member can request loans
- `get-loan-status(loan-id)`: Get comprehensive loan voting and approval status
- `calculate-max-loan-amount()`: See maximum loan amount available

### Loan Process Workflow

1. **Request**: Eligible member requests emergency loan with reason
2. **Voting**: Other group members vote to approve/reject the request
3. **Approval**: Admin finalizes approval if 60% of members support the loan
4. **Disbursement**: Approved loan funds are transferred to borrower
5. **Repayment**: Borrower repays loan gradually, replenishing the fund for others

### Example Usage

#### Contributing to Emergency Fund
```clarity
(contract-call? .ajo contribute-to-emergency-fund u500000) ;; 0.5 STX
```

#### Requesting Emergency Loan
```clarity
(contract-call? .ajo request-emergency-loan u1000000 "Medical emergency")
```

#### Voting on Loan Request
```clarity
(contract-call? .ajo vote-on-loan u1 true) ;; Approve loan #1
```

#### Making Loan Repayment
```clarity
(contract-call? .ajo repay-loan u1 u200000) ;; Repay 0.2 STX
```

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
6. Contribute to emergency fund
7. Request and approve emergency loans

