# E-Sports Betting Platform

A decentralized betting platform for e-sports tournaments built on the Stacks blockchain using Clarity smart contracts.

## Overview

This smart contract enables users to create tournaments, place bets on e-sports matches, and claim winnings in a trustless manner. The platform supports multiple popular games and includes comprehensive tournament management, odds calculation, and user statistics tracking.

## Features

### Core Functionality
- **Tournament Creation**: Create tournaments for various e-sports games
- **Decentralized Betting**: Place bets on tournament outcomes using STX tokens
- **Dynamic Odds**: Real-time odds calculation based on betting pools
- **Automated Payouts**: Claim winnings after tournament resolution
- **Oracle Integration**: Trusted result submission system

### Supported Games
- League of Legends (LoL)
- Counter-Strike: Global Offensive (CS:GO)
- Dota 2
- Valorant
- Overwatch
- Fortnite

### User Features
- Comprehensive betting statistics
- Win rate tracking
- Tournament creator reputation system
- Betting history and analytics

### Admin Features
- Contract pause/unpause functionality
- Platform fee management
- Oracle address management
- Emergency withdrawal capabilities

## Contract Architecture

### Constants
- **Minimum Bet**: 0.1 STX (100,000 microSTX)
- **Maximum Bet**: 1,000 STX (1,000,000,000 microSTX)
- **Platform Fee**: 2.5% of winnings
- **Oracle Delay**: 144 blocks (~24 hours)

### Tournament Lifecycle
1. **Upcoming**: Tournament created, betting open
2. **Live**: Tournament started, betting still open
3. **Betting Closed**: No more bets accepted
4. **Finished**: Tournament completed, awaiting result
5. **Resolved**: Result submitted, winnings claimable

## Public Functions

### Tournament Management

#### `create-tournament`
Creates a new tournament for betting.

**Parameters:**
- `name`: Tournament name (string-ascii 100)
- `game-type`: Game type ID (uint)
- `team-a`: First team name (string-ascii 50)
- `team-b`: Second team name (string-ascii 50)
- `start-time`: Tournament start block height (uint)
- `betting-close-time`: Betting close block height (uint)

**Returns:** Tournament ID (uint)

#### `update-tournament-status`
Updates tournament status based on block height.

**Parameters:**
- `tournament-id`: Tournament identifier (uint)

**Returns:** New status (uint)

### Betting Functions

#### `place-bet`
Places a bet on a tournament outcome.

**Parameters:**
- `tournament-id`: Tournament identifier (uint)
- `team-choice`: Team selection (1 for team-a, 2 for team-b)
- `bet-amount`: Bet amount in microSTX (uint)

**Returns:** Bet details including ID, odds, and potential payout

#### `claim-winnings`
Claims winnings from a successful bet.

**Parameters:**
- `bet-id`: Bet identifier (uint)

**Returns:** Net winnings amount after platform fee

### Oracle Functions

#### `submit-result`
Submits tournament result (Oracle only).

**Parameters:**
- `tournament-id`: Tournament identifier (uint)
- `winner`: Winning team (1 for team-a, 2 for team-b)

**Returns:** Success boolean

### Admin Functions

#### `pause-contract` / `unpause-contract`
Emergency contract controls (Owner only).

#### `set-oracle-address`
Updates the oracle address (Owner only).

#### `withdraw-fees`
Withdraws accumulated platform fees (Owner only).

#### `emergency-withdraw`
Emergency fund withdrawal when contract is paused (Owner only).

## Read-Only Functions

### Data Retrieval

#### `get-tournament`
Returns tournament details by ID.

#### `get-bet`
Returns bet details by ID.

#### `get-user-stats`
Returns user betting statistics.

#### `get-current-odds`
Returns current odds for both teams in a tournament.

#### `get-platform-stats`
Returns overall platform statistics.

#### `can-claim-bet`
Checks if a bet is eligible for claiming.

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 400 | ERR-OWNER-ONLY | Function restricted to contract owner |
| 401 | ERR-INSUFFICIENT-FUNDS | Insufficient STX balance |
| 402 | ERR-TOURNAMENT-NOT-FOUND | Tournament does not exist |
| 403 | ERR-BETTING-CLOSED | Betting period has ended |
| 404 | ERR-INVALID-TEAM | Invalid team selection |
| 405 | ERR-TOURNAMENT-NOT-FINISHED | Tournament not yet finished |
| 406 | ERR-ALREADY-CLAIMED | Winnings already claimed |
| 407 | ERR-NO-WINNING-BETS | No winnings available |
| 408 | ERR-TOURNAMENT-ALREADY-RESOLVED | Tournament already has result |
| 409 | ERR-INVALID-RESULT | Invalid tournament result |
| 410 | ERR-CONTRACT-PAUSED | Contract is paused |
| 411 | ERR-MINIMUM-BET-NOT-MET | Bet below minimum amount |
| 412 | ERR-MAXIMUM-BET-EXCEEDED | Bet exceeds maximum amount |
| 413 | ERR-INVALID-GAME-TYPE | Unsupported game type |

## Usage Examples

### Creating a Tournament

```clarity
(contract-call? .esports-betting-platform create-tournament
  "World Championship Finals"
  u1  ;; League of Legends
  "Team Liquid"
  "Cloud9"
  u1500  ;; Start at block 1500
  u1200  ;; Betting closes at block 1200
)
```

### Placing a Bet

```clarity
(contract-call? .esports-betting-platform place-bet
  u1         ;; Tournament ID
  u1         ;; Bet on Team A
  u5000000   ;; 5 STX bet
)
```

### Claiming Winnings

```clarity
(contract-call? .esports-betting-platform claim-winnings
  u1  ;; Bet ID
)
```

## Deployment

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX for deployment
- Basic understanding of Clarity smart contracts

### Steps
1. Clone the repository
2. Compile the contract: `clarinet check`
3. Run tests: `clarinet test`
4. Deploy to testnet: `clarinet deploy --testnet`
5. Deploy to mainnet: `clarinet deploy --mainnet`

## Testing

The contract includes comprehensive unit tests covering:
- Tournament creation and validation
- Betting functionality and edge cases
- Oracle result submission
- Winnings calculation and claiming
- Admin functions and access control
- Error handling and edge cases

Run tests with:
```bash
clarinet test
```

## Security Considerations

### Access Control
- Owner-only functions protected by sender verification
- Oracle address configurable by owner only
- Emergency controls for contract management

### Financial Safety
- Minimum and maximum bet limits
- Platform fee calculations with overflow protection
- Funds held in contract until claiming

### Oracle Trust
- Single oracle model (consider multi-oracle for production)
- Oracle result delays for dispute resolution
- Result immutability after submission

## Gas Optimization

The contract is optimized for gas efficiency through:
- Efficient data structures and mappings
- Minimal redundant computations
- Batched operations where possible
- Early validation to prevent unnecessary processing

## Future Improvements

### Potential Enhancements
- Multi-oracle consensus system
- Tournament brackets and elimination rounds
- Live betting during matches
- NFT integration for tournament participation
- Governance token for platform decisions
- Advanced analytics and reporting

### Scaling Considerations
- Layer 2 integration for lower fees
- Batch processing for high-volume periods
- Off-chain data storage for detailed statistics

## License

MIT License - See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit a pull request with detailed description

## Support

For technical support or questions:
- Open an issue on GitHub
- Review the test suite for usage examples
- Check error codes for debugging guidance

## Disclaimer

This smart contract is provided as-is for educational and development purposes. Betting involves financial risk. Users should understand the code and associated risks before deploying or using this contract with real funds. The developers assume no responsibility for financial losses or security vulnerabilities.