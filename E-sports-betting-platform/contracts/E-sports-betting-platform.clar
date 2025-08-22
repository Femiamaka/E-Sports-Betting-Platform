;; E-Sports Betting Platform Contract - Wager on Gaming Tournament Outcomes
;; Built with Clarinet for Stacks Blockchain

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u400))
(define-constant ERR-INSUFFICIENT-FUNDS (err u401))
(define-constant ERR-TOURNAMENT-NOT-FOUND (err u402))
(define-constant ERR-BETTING-CLOSED (err u403))
(define-constant ERR-INVALID-TEAM (err u404))
(define-constant ERR-TOURNAMENT-NOT-FINISHED (err u405))
(define-constant ERR-ALREADY-CLAIMED (err u406))
(define-constant ERR-NO-WINNING-BETS (err u407))
(define-constant ERR-TOURNAMENT-ALREADY-RESOLVED (err u408))
(define-constant ERR-INVALID-RESULT (err u409))
(define-constant ERR-CONTRACT-PAUSED (err u410))
(define-constant ERR-MINIMUM-BET-NOT-MET (err u411))
(define-constant ERR-MAXIMUM-BET-EXCEEDED (err u412))
(define-constant ERR-INVALID-GAME-TYPE (err u413))

;; Contract configuration
(define-constant MINIMUM-BET u100000) ;; 0.1 STX minimum
(define-constant MAXIMUM-BET u1000000000) ;; 1000 STX maximum
(define-constant PLATFORM-FEE-PERCENTAGE u250) ;; 2.5% platform fee (out of 10000)
(define-constant ORACLE-DELAY-BLOCKS u144) ;; ~24 hours delay for oracle updates

;; Game types
(define-constant GAME-TYPE-LOL u1) ;; League of Legends
(define-constant GAME-TYPE-CSGO u2) ;; Counter-Strike: Global Offensive
(define-constant GAME-TYPE-DOTA2 u3) ;; Dota 2
(define-constant GAME-TYPE-VALORANT u4) ;; Valorant
(define-constant GAME-TYPE-OVERWATCH u5) ;; Overwatch
(define-constant GAME-TYPE-FORTNITE u6) ;; Fortnite

;; Tournament status
(define-constant STATUS-UPCOMING u1)
(define-constant STATUS-LIVE u2)
(define-constant STATUS-BETTING-CLOSED u3)
(define-constant STATUS-FINISHED u4)
(define-constant STATUS-RESOLVED u5)

;; Contract state variables
(define-data-var contract-paused bool false)
(define-data-var tournament-counter uint u0)
(define-data-var bet-counter uint u0)
(define-data-var total-platform-fees uint u0)
(define-data-var oracle-address principal tx-sender)

;; Tournament data structure
(define-map tournaments uint {
    name: (string-ascii 100),
    game-type: uint,
    team-a: (string-ascii 50),
    team-b: (string-ascii 50),
    start-time: uint, ;; Block height when tournament starts
    betting-close-time: uint, ;; Block height when betting closes
    status: uint,
    winner: (optional uint), ;; 1 for team-a, 2 for team-b, none if not resolved
    total-pool-team-a: uint,
    total-pool-team-b: uint,
    total-bets-count: uint,
    creator: principal,
    oracle-locked-block: (optional uint) ;; Block when oracle result was submitted
})

;; Individual bet data
(define-map bets uint {
    tournament-id: uint,
    bettor: principal,
    team-choice: uint, ;; 1 for team-a, 2 for team-b
    amount: uint,
    potential-payout: uint,
    claimed: bool,
    bet-block: uint,
    odds-at-bet: uint ;; Odds when bet was placed (multiplied by 10000)
})

;; User statistics
(define-map user-stats principal {
    total-bets-placed: uint,
    total-wagered: uint,
    total-winnings: uint,
    active-bets: uint,
    biggest-win: uint,
    win-rate: uint ;; Percentage out of 10000
})

;; Tournament creator reputation
(define-map creator-reputation principal {
    tournaments-created: uint,
    tournaments-resolved: uint,
    reputation-score: uint, ;; Out of 10000
    last-activity: uint
})

;; Game type information
(define-map game-types uint {
    name: (string-ascii 30),
    active: bool,
    total-tournaments: uint,
    total-volume: uint
})

;; Oracle submissions for tournament results
(define-map oracle-submissions uint {
    tournament-id: uint,
    submitted-by: principal,
    winner: uint, ;; 1 for team-a, 2 for team-b
    submission-block: uint,
    verified: bool
})

;; Initialize game types
(define-private (setup-game-types)
    (begin
        (map-set game-types GAME-TYPE-LOL {
            name: "League of Legends",
            active: true,
            total-tournaments: u0,
            total-volume: u0
        })
        (map-set game-types GAME-TYPE-CSGO {
            name: "Counter-Strike GO",
            active: true,
            total-tournaments: u0,
            total-volume: u0
        })
        (map-set game-types GAME-TYPE-DOTA2 {
            name: "Dota 2",
            active: true,
            total-tournaments: u0,
            total-volume: u0
        })
        (map-set game-types GAME-TYPE-VALORANT {
            name: "Valorant",
            active: true,
            total-tournaments: u0,
            total-volume: u0
        })
        (map-set game-types GAME-TYPE-OVERWATCH {
            name: "Overwatch",
            active: true,
            total-tournaments: u0,
            total-volume: u0
        })
        (map-set game-types GAME-TYPE-FORTNITE {
            name: "Fortnite",
            active: true,
            total-tournaments: u0,
            total-volume: u0
        })
    )
)

;; Calculate odds for a team based on current betting pools
(define-private (calculate-odds (total-pool-team-a uint) (total-pool-team-b uint) (team uint))
    (let ((total-pool (+ total-pool-team-a total-pool-team-b)))
        (if (is-eq total-pool u0)
            u20000 ;; Default 2:1 odds if no bets placed
            (if (is-eq team u1)
                ;; Odds for team A = (total pool / team A pool) * 10000
                (if (is-eq total-pool-team-a u0)
                    u50000 ;; Very high odds if no bets on team A
                    (/ (* total-pool u10000) total-pool-team-a)
                )
                ;; Odds for team B = (total pool / team B pool) * 10000
                (if (is-eq total-pool-team-b u0)
                    u50000 ;; Very high odds if no bets on team B
                    (/ (* total-pool u10000) total-pool-team-b)
                )
            )
        )
    )
)

;; Calculate potential payout for a bet
(define-private (calculate-payout (bet-amount uint) (odds uint))
    ;; Payout = (bet-amount * odds) / 10000
    (/ (* bet-amount odds) u10000)
)

;; Create a new tournament
(define-public (create-tournament 
    (name (string-ascii 100))
    (game-type uint)
    (team-a (string-ascii 50))
    (team-b (string-ascii 50))
    (start-time uint)
    (betting-close-time uint))
    
    (let ((tournament-id (+ (var-get tournament-counter) u1)))
        
        ;; Validate inputs
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        (asserts! (is-some (map-get? game-types game-type)) ERR-INVALID-GAME-TYPE)
        (asserts! (> start-time stacks-block-height) ERR-INVALID-RESULT)
        (asserts! (> betting-close-time stacks-block-height) ERR-INVALID-RESULT)
        (asserts! (< betting-close-time start-time) ERR-INVALID-RESULT)
        
        ;; Create tournament
        (map-set tournaments tournament-id {
            name: name,
            game-type: game-type,
            team-a: team-a,
            team-b: team-b,
            start-time: start-time,
            betting-close-time: betting-close-time,
            status: STATUS-UPCOMING,
            winner: none,
            total-pool-team-a: u0,
            total-pool-team-b: u0,
            total-bets-count: u0,
            creator: tx-sender,
            oracle-locked-block: none
        })
        
        ;; Update counters
        (var-set tournament-counter tournament-id)
        
        ;; Update game type stats
        (let ((game-data (unwrap! (map-get? game-types game-type) ERR-INVALID-GAME-TYPE)))
            (map-set game-types game-type (merge game-data {
                total-tournaments: (+ (get total-tournaments game-data) u1)
            }))
        )
        
        ;; Update creator reputation
        (update-creator-reputation tx-sender u1 u0)
        
        (ok tournament-id)
    )
)

;; Place a bet on a tournament
(define-public (place-bet (tournament-id uint) (team-choice uint) (bet-amount uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (bet-id (+ (var-get bet-counter) u1)))
        
        ;; Validate bet
        (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
        (asserts! (>= bet-amount MINIMUM-BET) ERR-MINIMUM-BET-NOT-MET)
        (asserts! (<= bet-amount MAXIMUM-BET) ERR-MAXIMUM-BET-EXCEEDED)
        (asserts! (or (is-eq team-choice u1) (is-eq team-choice u2)) ERR-INVALID-TEAM)
        (asserts! (< stacks-block-height (get betting-close-time tournament-data)) ERR-BETTING-CLOSED)
        (asserts! (>= (stx-get-balance tx-sender) bet-amount) ERR-INSUFFICIENT-FUNDS)
        
        ;; Calculate current odds and potential payout
        (let ((current-odds (calculate-odds 
                (get total-pool-team-a tournament-data)
                (get total-pool-team-b tournament-data)
                team-choice))
              (potential-payout (calculate-payout bet-amount current-odds)))
            
            ;; Transfer bet amount to contract
            (try! (stx-transfer? bet-amount tx-sender (as-contract tx-sender)))
            
            ;; Create bet record
            (map-set bets bet-id {
                tournament-id: tournament-id,
                bettor: tx-sender,
                team-choice: team-choice,
                amount: bet-amount,
                potential-payout: potential-payout,
                claimed: false,
                bet-block: stacks-block-height,
                odds-at-bet: current-odds
            })
            
            ;; Update tournament pools
            (let ((updated-tournament (merge tournament-data {
                    total-pool-team-a: (if (is-eq team-choice u1) 
                        (+ (get total-pool-team-a tournament-data) bet-amount)
                        (get total-pool-team-a tournament-data)),
                    total-pool-team-b: (if (is-eq team-choice u2)
                        (+ (get total-pool-team-b tournament-data) bet-amount)
                        (get total-pool-team-b tournament-data)),
                    total-bets-count: (+ (get total-bets-count tournament-data) u1)
                })))
                
                (map-set tournaments tournament-id updated-tournament)
            )
            
            ;; Update counters
            (var-set bet-counter bet-id)
            
            ;; Update user stats
            (update-user-stats tx-sender bet-amount u0 false)
            
            (ok {
                bet-id: bet-id,
                odds: current-odds,
                potential-payout: potential-payout
            })
        )
    )
)

;; Submit tournament result (Oracle function)
(define-public (submit-result (tournament-id uint) (winner uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND)))
        
        ;; Validate submission
        (asserts! (is-eq tx-sender (var-get oracle-address)) ERR-OWNER-ONLY)
        (asserts! (or (is-eq winner u1) (is-eq winner u2)) ERR-INVALID-RESULT)
        (asserts! (is-eq (get status tournament-data) STATUS-FINISHED) ERR-TOURNAMENT-NOT-FINISHED)
        (asserts! (is-none (get winner tournament-data)) ERR-TOURNAMENT-ALREADY-RESOLVED)
        
        ;; Update tournament with result
        (map-set tournaments tournament-id (merge tournament-data {
            winner: (some winner),
            status: STATUS-RESOLVED,
            oracle-locked-block: (some stacks-block-height)
        }))
        
        ;; Update creator reputation
        (update-creator-reputation (get creator tournament-data) u0 u1)
        
        (ok true)
    )
)

;; Claim winnings from a bet
(define-public (claim-winnings (bet-id uint))
    (let ((bet-data (unwrap! (map-get? bets bet-id) ERR-NO-WINNING-BETS))
          (tournament-data (unwrap! (map-get? tournaments (get tournament-id bet-data)) ERR-TOURNAMENT-NOT-FOUND))
          (winner (unwrap! (get winner tournament-data) ERR-TOURNAMENT-NOT-FINISHED)))
        
        ;; Validate claim
        (asserts! (is-eq (get bettor bet-data) tx-sender) ERR-OWNER-ONLY)
        (asserts! (not (get claimed bet-data)) ERR-ALREADY-CLAIMED)
        (asserts! (is-eq (get team-choice bet-data) winner) ERR-NO-WINNING-BETS)
        
        ;; Calculate winnings after platform fee
        (let ((gross-winnings (get potential-payout bet-data))
              (platform-fee (/ (* gross-winnings PLATFORM-FEE-PERCENTAGE) u10000))
              (net-winnings (- gross-winnings platform-fee)))
            
            ;; Mark bet as claimed
            (map-set bets bet-id (merge bet-data {claimed: true}))
            
            ;; Transfer winnings
            (try! (as-contract (stx-transfer? net-winnings tx-sender (get bettor bet-data))))
            
            ;; Update platform fees
            (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
            
            ;; Update user stats
            (update-user-stats tx-sender u0 net-winnings true)
            
            (ok net-winnings)
        )
    )
)

;; Update tournament status (can be called by anyone to progress status) - FIXED VERSION
(define-public (update-tournament-status (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (current-status (get status tournament-data)))
        
        ;; Upcoming -> Live
        (if (and (is-eq current-status STATUS-UPCOMING) 
                 (>= stacks-block-height (get start-time tournament-data)))
            (begin
                (map-set tournaments tournament-id (merge tournament-data {status: STATUS-LIVE}))
                (ok STATUS-LIVE))
            
            ;; Live -> Betting Closed
            (if (and (is-eq current-status STATUS-LIVE)
                     (>= stacks-block-height (get betting-close-time tournament-data)))
                (begin
                    (map-set tournaments tournament-id (merge tournament-data {status: STATUS-BETTING-CLOSED}))
                    (ok STATUS-BETTING-CLOSED))
                
                ;; Manual finish (for oracle to mark as finished before resolving)
                (if (and (is-eq current-status STATUS-BETTING-CLOSED)
                         (is-eq tx-sender (var-get oracle-address)))
                    (begin
                        (map-set tournaments tournament-id (merge tournament-data {status: STATUS-FINISHED}))
                        (ok STATUS-FINISHED))
                    
                    ;; Default case - return current status
                    (ok current-status)
                )
            )
        )
    )
)

;; Update user statistics
(define-private (update-user-stats (user principal) (wagered uint) (winnings uint) (won bool))
    (let ((current-stats (default-to 
            {total-bets-placed: u0, total-wagered: u0, total-winnings: u0, 
             active-bets: u0, biggest-win: u0, win-rate: u0}
            (map-get? user-stats user))))
        
        (let ((new-total-bets (if (> wagered u0) (+ (get total-bets-placed current-stats) u1) (get total-bets-placed current-stats)))
              (new-win-rate (if (and (> new-total-bets u0) won)
                  (/ (* (+ (if won u1 u0) 
                           (/ (* (get win-rate current-stats) (get total-bets-placed current-stats)) u10000))
                        u10000) new-total-bets)
                  (get win-rate current-stats))))
            
            (map-set user-stats user {
                total-bets-placed: new-total-bets,
                total-wagered: (+ (get total-wagered current-stats) wagered),
                total-winnings: (+ (get total-winnings current-stats) winnings),
                active-bets: (get active-bets current-stats),
                biggest-win: (if (> winnings (get biggest-win current-stats)) 
                    winnings (get biggest-win current-stats)),
                win-rate: new-win-rate
            })
        )
    )
)

;; Update creator reputation
(define-private (update-creator-reputation (creator principal) (created uint) (resolved uint))
    (let ((current-rep (default-to
            {tournaments-created: u0, tournaments-resolved: u0, 
             reputation-score: u5000, last-activity: u0}
            (map-get? creator-reputation creator))))
        
        (let ((new-created (+ (get tournaments-created current-rep) created))
              (new-resolved (+ (get tournaments-resolved current-rep) resolved)))
            
            (map-set creator-reputation creator {
                tournaments-created: new-created,
                tournaments-resolved: new-resolved,
                reputation-score: (if (> new-created u0)
                    (/ (* new-resolved u10000) new-created)
                    u5000),
                last-activity: stacks-block-height
            })
        )
    )
)

;; Read-only functions

;; Get tournament details
(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id)
)

;; Get bet details
(define-read-only (get-bet (bet-id uint))
    (map-get? bets bet-id)
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
    (map-get? user-stats user)
)

;; Get game type information
(define-read-only (get-game-type (game-type-id uint))
    (map-get? game-types game-type-id)
)

;; Get current odds for a tournament
(define-read-only (get-current-odds (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) none)))
        (some {
            team-a-odds: (calculate-odds 
                (get total-pool-team-a tournament-data)
                (get total-pool-team-b tournament-data) u1),
            team-b-odds: (calculate-odds 
                (get total-pool-team-a tournament-data)
                (get total-pool-team-b tournament-data) u2),
            total-pool: (+ (get total-pool-team-a tournament-data) 
                          (get total-pool-team-b tournament-data))
        })
    )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-tournaments: (var-get tournament-counter),
        total-bets: (var-get bet-counter),
        total-fees-collected: (var-get total-platform-fees),
        contract-paused: (var-get contract-paused),
        oracle-address: (var-get oracle-address)
    }
)

;; Get creator reputation
(define-read-only (get-creator-reputation (creator principal))
    (map-get? creator-reputation creator)
)

;; Check if bet can be claimed
(define-read-only (can-claim-bet (bet-id uint))
    (let ((bet-data (unwrap! (map-get? bets bet-id) none))
          (tournament-data (unwrap! (map-get? tournaments (get tournament-id bet-data)) none))
          (winner-option (get winner tournament-data)))
        
        (some {
            can-claim: (match winner-option
                winner-value (and 
                    (is-eq (get team-choice bet-data) winner-value)
                    (not (get claimed bet-data)))
                false),
            tournament-resolved: (is-some winner-option),
            winning-team: winner-option,
            bet-team: (get team-choice bet-data)
        })
    )
)

;; Admin functions

;; Pause/unpause contract
(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set contract-paused true)
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set contract-paused false)
        (ok true)
    )
)

;; Update oracle address
(define-public (set-oracle-address (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set oracle-address new-oracle)
        (ok true)
    )
)

;; Withdraw platform fees
(define-public (withdraw-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (<= amount (var-get total-platform-fees)) ERR-INSUFFICIENT-FUNDS)
        
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (var-set total-platform-fees (- (var-get total-platform-fees) amount))
        
        (ok amount)
    )
)

;; Emergency withdraw (only if contract is paused)
(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (var-get contract-paused) ERR-CONTRACT-PAUSED)
        
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        
        (ok amount)
    )
)

;; Update game type status
(define-public (update-game-type (game-type-id uint) (active bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        
        (let ((game-data (unwrap! (map-get? game-types game-type-id) ERR-INVALID-GAME-TYPE)))
            (map-set game-types game-type-id (merge game-data {active: active}))
        )
        
        (ok true)
    )
)

;; Initialize contract
(define-private (init)
    (begin
        (setup-game-types)
        (var-set contract-paused false)
        (var-set tournament-counter u0)
        (var-set bet-counter u0)
        (var-set total-platform-fees u0)
        (var-set oracle-address tx-sender)
    )
)

;; Call initialization
(init)