(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-MEMBER (err u101))
(define-constant ERR-NOT-MEMBER (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-CYCLE-IN-PROGRESS (err u104))
(define-constant ERR-CYCLE-NOT-STARTED (err u105))
(define-constant ERR-ALREADY-CONTRIBUTED (err u106))
(define-constant ERR-NOT-PAYOUT-TIME (err u107))
(define-constant ERR-ALREADY-RECEIVED-PAYOUT (err u108))
(define-constant ERR-INSUFFICIENT-FUNDS (err u109))
(define-constant ERR-CYCLE-COMPLETE (err u110))
(define-constant ERR-INVALID-CYCLE-LENGTH (err u111))
(define-constant ERR-INVALID-CONTRIBUTION-AMOUNT (err u112))

(define-data-var admin principal tx-sender)
(define-data-var contribution-amount uint u0)
(define-data-var cycle-length uint u0)
(define-data-var current-cycle uint u0)
(define-data-var cycle-started bool false)
(define-data-var total-members uint u0)
(define-data-var current-recipient uint u0)
(define-data-var total-balance uint u0)

(define-map members principal uint)
(define-map member-contributions {member: principal, cycle: uint} uint)
(define-map received-payout {member: principal, cycle: uint} bool)
(define-map cycle-contributions uint uint)

(define-constant ERR-CONTRIBUTION-DEADLINE-PASSED (err u114))
(define-constant ERR-NO-PENALTIES-TO-DISTRIBUTE (err u115))

(define-data-var penalty-rate uint u10)
(define-data-var contribution-deadline uint u0)
(define-data-var penalty-pool uint u0)
(define-data-var per-member-bonus uint u0)


(define-map cycle-deadlines uint uint)
(define-map member-penalties {member: principal, cycle: uint} uint)
(define-map on-time-contributors {cycle: uint, member: principal} bool)

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (get-contribution-amount)
  (var-get contribution-amount))

(define-read-only (get-cycle-length)
  (var-get cycle-length))

(define-read-only (get-current-cycle)
  (var-get current-cycle))

(define-read-only (is-cycle-started)
  (var-get cycle-started))

(define-read-only (get-total-members)
  (var-get total-members))

(define-read-only (get-current-recipient)
  (var-get current-recipient))

(define-read-only (get-total-balance)
  (var-get total-balance))

(define-read-only (is-member (user principal))
  (is-some (map-get? members user)))

(define-read-only (get-member-id (user principal))
  (default-to u0 (map-get? members user)))

(define-read-only (has-contributed (user principal) (cycle uint))
  (is-some (map-get? member-contributions {member: user, cycle: cycle})))

(define-read-only (has-received-payout (user principal) (cycle uint))
  (default-to false (map-get? received-payout {member: user, cycle: cycle})))

(define-read-only (get-cycle-contribution (cycle uint))
  (default-to u0 (map-get? cycle-contributions cycle)))

(define-public (initialize (contribution uint) (members-count uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> contribution u0) ERR-INVALID-CONTRIBUTION-AMOUNT)
    (asserts! (> members-count u0) ERR-INVALID-CYCLE-LENGTH)
    (var-set contribution-amount contribution)
    (var-set cycle-length members-count)
    (var-set current-cycle u1)
    (var-set total-members u0)
    (var-set current-recipient u0)
    (ok true)))

(define-public (join-group)
  (begin
  (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)

    (asserts! (not (is-member tx-sender)) ERR-ALREADY-MEMBER)
    (asserts! (< (var-get total-members) (var-get cycle-length)) ERR-CYCLE-IN-PROGRESS)
    (map-set members tx-sender (+ (var-get total-members) u1))
    (var-set total-members (+ (var-get total-members) u1))
    (ok true)))

(define-public (start-cycle)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get cycle-started)) ERR-CYCLE-IN-PROGRESS)
    (asserts! (is-eq (var-get total-members) (var-get cycle-length)) ERR-INVALID-CYCLE-LENGTH)
    (var-set cycle-started true)
    (var-set current-recipient u1)
    (ok true)))

(define-public (contribute)
  (begin
  (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
  (update-stats-after-contribution)

    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (var-get cycle-started) ERR-CYCLE-NOT-STARTED)
    (asserts! (not (has-contributed tx-sender (var-get current-cycle))) ERR-ALREADY-CONTRIBUTED)
    (asserts! (not (is-eq (var-get current-cycle) u0)) ERR-CYCLE-COMPLETE)
    
    (try! (stx-transfer? (var-get contribution-amount) tx-sender (as-contract tx-sender)))
    
    (map-set member-contributions {member: tx-sender, cycle: (var-get current-cycle)} (var-get contribution-amount))
    (map-set cycle-contributions (var-get current-cycle) (+ (get-cycle-contribution (var-get current-cycle)) (var-get contribution-amount)))
    (var-set total-balance (+ (var-get total-balance) (var-get contribution-amount)))
    
    (ok true)))

(define-public (claim-payout)
  (let ((member-id (get-member-id tx-sender)))
  (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)

    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (var-get cycle-started) ERR-CYCLE-NOT-STARTED)
    (asserts! (is-eq member-id (var-get current-recipient)) ERR-NOT-PAYOUT-TIME)
    (asserts! (not (has-received-payout tx-sender (var-get current-cycle))) ERR-ALREADY-RECEIVED-PAYOUT)
    (asserts! (>= (var-get total-balance) (* (var-get contribution-amount) (var-get total-members))) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? (* (var-get contribution-amount) (var-get total-members)) tx-sender tx-sender)))
    
    (map-set received-payout {member: tx-sender, cycle: (var-get current-cycle)} true)
    (var-set total-balance (- (var-get total-balance) (* (var-get contribution-amount) (var-get total-members))))
    
    (if (is-eq (var-get current-recipient) (var-get total-members))
        (begin
          (var-set current-cycle (+ (var-get current-cycle) u1))
          (var-set current-recipient u1)
          (if (> (var-get current-cycle) (var-get cycle-length))
              (var-set cycle-started false)
              true))
        (var-set current-recipient (+ (var-get current-recipient) u1)))
    (update-stats-after-payout)

    (ok true)))

(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get total-balance)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (var-set total-balance (- (var-get total-balance) amount))
    (ok true)))

(define-public (change-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)))





(define-constant ERR-CONTRACT-PAUSED (err u113))

(define-data-var contract-paused bool false)

(define-read-only (is-paused)
  (var-get contract-paused))

(define-public (set-pause-state (new-state bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set contract-paused new-state)
    (ok true)))


(define-data-var total-cycles-completed uint u0)
(define-data-var total-contributions uint u0)
(define-data-var total-payouts uint u0)

(define-read-only (get-group-stats)
  (ok {
    cycles-completed: (var-get total-cycles-completed),
    total-contributions: (var-get total-contributions),
    total-payouts: (var-get total-payouts)
  }))

(define-private (update-stats-after-contribution)
  (var-set total-contributions (+ (var-get total-contributions) u1)))

(define-private (update-stats-after-payout)
  (begin
    (var-set total-payouts (+ (var-get total-payouts) u1))
    (if (is-eq (var-get current-recipient) (var-get total-members))
      (var-set total-cycles-completed (+ (var-get total-cycles-completed) u1))
      true)))




(define-read-only (get-penalty-rate)
  (var-get penalty-rate))

(define-read-only (get-contribution-deadline)
  (var-get contribution-deadline))

(define-read-only (get-penalty-pool)
  (var-get penalty-pool))

(define-read-only (get-cycle-deadline (cycle uint))
  (default-to u0 (map-get? cycle-deadlines cycle)))

(define-read-only (get-member-penalty (user principal) (cycle uint))
  (default-to u0 (map-get? member-penalties {member: user, cycle: cycle})))

(define-read-only (contributed-on-time (user principal) (cycle uint))
  (default-to false (map-get? on-time-contributors {cycle: cycle, member: user})))

(define-public (set-penalty-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u50) ERR-INVALID-AMOUNT)
    (var-set penalty-rate new-rate)
    (ok true)))

(define-public (set-cycle-deadline (cycle uint) (deadline uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set cycle-deadlines cycle deadline)
    (ok true)))

(define-public (contribute-with-penalty)
  (let (
    (current-cycle-val (var-get current-cycle))
    (deadline (get-cycle-deadline current-cycle-val))
    (base-amount (var-get contribution-amount))
    (is-late (> stacks-block-height deadline))
    (penalty-amount (if is-late (/ (* base-amount (var-get penalty-rate)) u100) u0))
    (total-amount (+ base-amount penalty-amount))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (var-get cycle-started) ERR-CYCLE-NOT-STARTED)
    (asserts! (not (has-contributed tx-sender current-cycle-val)) ERR-ALREADY-CONTRIBUTED)
    (asserts! (not (is-eq current-cycle-val u0)) ERR-CYCLE-COMPLETE)
    
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    (map-set member-contributions {member: tx-sender, cycle: current-cycle-val} base-amount)
    (map-set cycle-contributions current-cycle-val (+ (get-cycle-contribution current-cycle-val) base-amount))
    
    (if is-late
      (begin
        (map-set member-penalties {member: tx-sender, cycle: current-cycle-val} penalty-amount)
        (var-set penalty-pool (+ (var-get penalty-pool) penalty-amount)))
      (map-set on-time-contributors {cycle: current-cycle-val, member: tx-sender} true))
    
    (var-set total-balance (+ (var-get total-balance) base-amount))
    (update-stats-after-contribution)
    
    (ok true)))

(define-public (distribute-penalties (cycle uint))
  (let (
    (penalty-amount (var-get penalty-pool))
    (on-time-count (count-on-time-contributors cycle))
    ;; (per-member-bonus (if (> on-time-count u0) (/ penalty-amount on-time-count) u0))
  )
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> penalty-amount u0) ERR-NO-PENALTIES-TO-DISTRIBUTE)
    ;; (asserts! (> on-time-count u0) ERR-NO-PENALTIES-TO-DISTRIBUTE)
    
    (var-set penalty-pool u0)
    (var-set total-balance (+ (var-get total-balance) penalty-amount))
    
    (ok {
      total-distributed: penalty-amount,
      on-time-count: on-time-count
    })))

(define-public (claim-penalty-bonus (cycle uint))
  (let (
    (penalty-amount (var-get penalty-pool))
    (on-time-count (count-on-time-contributors cycle))
    ;; (per-member-bonus (if (> on-time-count u0) (/ penalty-amount on-time-count) u0))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (contributed-on-time tx-sender cycle) ERR-NOT-AUTHORIZED)
    ;; (asserts! (> per-member-bonus u0) ERR-NO-PENALTIES-TO-DISTRIBUTE)
    
    ;; (try! (as-contract (stx-transfer? per-member-bonus tx-sender tx-sender)))
    
    (ok {
      total-distributed: penalty-amount,
      on-time-count: on-time-count
    })))

(define-private (count-on-time-contributors (cycle uint))
  (fold count-on-time-member (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) {cycle: cycle, count: u0}))

(define-private (count-on-time-member (member-id uint) (data {cycle: uint, count: uint}))
  (let (
    (member-principal (get-member-by-id member-id))
    (cycle (get cycle data))
    (current-count (get count data))
  )
    (if (and 
          (is-some member-principal)
          (contributed-on-time (unwrap-panic member-principal) cycle))
      {cycle: cycle, count: (+ current-count u1)}
      data)))

(define-private (get-member-by-id (member-id uint))
  (if (<= member-id (var-get total-members))
    (some tx-sender)
    none))

(define-constant ERR-INSUFFICIENT-INTEREST-POOL (err u116))
(define-constant ERR-INVALID-INTEREST-RATE (err u117))
(define-constant ERR-REWARD-ALREADY-CLAIMED (err u118))
(define-constant ERR-NO-CONTRIBUTIONS (err u119))
(define-constant ERR-INVALID-MULTIPLIER (err u120))

(define-data-var interest-pool uint u0)
(define-data-var base-interest-rate uint u5)
(define-data-var early-contribution-multiplier uint u2)
(define-data-var loyalty-bonus-rate uint u3)
(define-data-var max-interest-rate uint u15)
(define-data-var contribution-window uint u100)

(define-map member-interest-earned {member: principal, cycle: uint} uint)
(define-map member-reward-claimed {member: principal, cycle: uint} bool)
(define-map member-contribution-timestamp {member: principal, cycle: uint} uint)
(define-map member-loyalty-score principal uint)
(define-map cycle-contribution-order {cycle: uint, member: principal} uint)
(define-map cycle-contribution-count uint uint)
(define-map member-total-interest-earned principal uint)
(define-map cycle-early-contributors uint uint)
(define-map member-consecutive-cycles principal uint)

(define-read-only (get-interest-pool)
  (var-get interest-pool))

(define-read-only (get-base-interest-rate)
  (var-get base-interest-rate))

(define-read-only (get-early-contribution-multiplier)
  (var-get early-contribution-multiplier))

(define-read-only (get-loyalty-bonus-rate)
  (var-get loyalty-bonus-rate))

(define-read-only (get-max-interest-rate)
  (var-get max-interest-rate))

(define-read-only (get-contribution-window)
  (var-get contribution-window))

(define-read-only (get-member-interest-earned (member principal) (cycle uint))
  (default-to u0 (map-get? member-interest-earned {member: member, cycle: cycle})))

(define-read-only (get-member-reward-claimed (member principal) (cycle uint))
  (default-to false (map-get? member-reward-claimed {member: member, cycle: cycle})))

(define-read-only (get-member-contribution-timestamp (member principal) (cycle uint))
  (default-to u0 (map-get? member-contribution-timestamp {member: member, cycle: cycle})))

(define-read-only (get-member-loyalty-score (member principal))
  (default-to u0 (map-get? member-loyalty-score member)))

(define-read-only (get-cycle-contribution-order (cycle uint) (member principal))
  (default-to u0 (map-get? cycle-contribution-order {cycle: cycle, member: member})))

(define-read-only (get-cycle-contribution-count (cycle uint))
  (default-to u0 (map-get? cycle-contribution-count cycle)))

(define-read-only (get-member-total-interest-earned (member principal))
  (default-to u0 (map-get? member-total-interest-earned member)))

(define-read-only (get-cycle-early-contributors (cycle uint))
  (default-to u0 (map-get? cycle-early-contributors cycle)))

(define-read-only (get-member-consecutive-cycles (member principal))
  (default-to u0 (map-get? member-consecutive-cycles member)))

(define-public (set-interest-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u50) ERR-INVALID-INTEREST-RATE)
    (var-set base-interest-rate new-rate)
    (ok true)))

(define-public (set-early-contribution-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-multiplier u1) (<= new-multiplier u5)) ERR-INVALID-MULTIPLIER)
    (var-set early-contribution-multiplier new-multiplier)
    (ok true)))

(define-public (set-loyalty-bonus-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u20) ERR-INVALID-INTEREST-RATE)
    (var-set loyalty-bonus-rate new-rate)
    (ok true)))

(define-public (set-contribution-window (new-window uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> new-window u10) ERR-INVALID-AMOUNT)
    (var-set contribution-window new-window)
    (ok true)))

(define-public (fund-interest-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set interest-pool (+ (var-get interest-pool) amount))
    (ok true)))

(define-public (contribute-with-interest)
  (let (
    (current-cycle-val (var-get current-cycle))
    (contribution-order (+ (get-cycle-contribution-count current-cycle-val) u1))
    (is-early (< contribution-order (/ (var-get total-members) u2)))
    (consecutive-cycles (get-member-consecutive-cycles tx-sender))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (var-get cycle-started) ERR-CYCLE-NOT-STARTED)
    (asserts! (not (has-contributed tx-sender current-cycle-val)) ERR-ALREADY-CONTRIBUTED)
    (asserts! (not (is-eq current-cycle-val u0)) ERR-CYCLE-COMPLETE)
    
    (try! (stx-transfer? (var-get contribution-amount) tx-sender (as-contract tx-sender)))
    
    (map-set member-contributions {member: tx-sender, cycle: current-cycle-val} (var-get contribution-amount))
    (map-set cycle-contributions current-cycle-val (+ (get-cycle-contribution current-cycle-val) (var-get contribution-amount)))
    (map-set member-contribution-timestamp {member: tx-sender, cycle: current-cycle-val} stacks-block-height)
    (map-set cycle-contribution-order {cycle: current-cycle-val, member: tx-sender} contribution-order)
    (map-set cycle-contribution-count current-cycle-val contribution-order)
    
    (if is-early
      (map-set cycle-early-contributors current-cycle-val (+ (get-cycle-early-contributors current-cycle-val) u1))
      true)
    
    (map-set member-consecutive-cycles tx-sender (+ consecutive-cycles u1))
    (begin
      (unwrap-panic (update-loyalty-score tx-sender))
      (unwrap-panic (calculate-and-store-interest tx-sender current-cycle-val))
    
      (var-set total-balance (+ (var-get total-balance) (var-get contribution-amount)))
      (update-stats-after-contribution)
    
      (ok true))))

(define-public (claim-interest-reward (cycle uint))
  (let (
    (earned-interest (get-member-interest-earned tx-sender cycle))
    (already-claimed (get-member-reward-claimed tx-sender cycle))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (> earned-interest u0) ERR-NO-CONTRIBUTIONS)
    (asserts! (not already-claimed) ERR-REWARD-ALREADY-CLAIMED)
    (asserts! (>= (var-get interest-pool) earned-interest) ERR-INSUFFICIENT-INTEREST-POOL)
    
    (try! (as-contract (stx-transfer? earned-interest tx-sender tx-sender)))
    
    (map-set member-reward-claimed {member: tx-sender, cycle: cycle} true)
    (var-set interest-pool (- (var-get interest-pool) earned-interest))
    (map-set member-total-interest-earned tx-sender (+ (get-member-total-interest-earned tx-sender) earned-interest))
    
    (ok earned-interest)))

(define-public (calculate-cycle-interest (cycle uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> cycle u0) ERR-INVALID-AMOUNT)
    (unwrap-panic (calculate-all-member-interest cycle))
    (ok true)))

(define-private (calculate-and-store-interest (member principal) (cycle uint))
  (let (
    (base-contribution (var-get contribution-amount))
    (contribution-order (get-cycle-contribution-order cycle member))
    (is-early (< contribution-order (/ (var-get total-members) u2)))
    (loyalty-score (get-member-loyalty-score member))
    (consecutive-cycles (get-member-consecutive-cycles member))
    (base-interest-amount (/ (* base-contribution (var-get base-interest-rate)) u100))
    (early-bonus (if is-early (/ (* base-interest-amount (var-get early-contribution-multiplier)) u1) u0))
    (loyalty-bonus (/ (* base-interest-amount (if (<= loyalty-score u10) loyalty-score u10)) u10))
    (consecutive-bonus (/ (* base-interest-amount (if (<= consecutive-cycles u5) consecutive-cycles u5)) u10))
    (total-interest (if (<= (+ base-interest-amount early-bonus loyalty-bonus consecutive-bonus) 
                           (/ (* base-contribution (var-get max-interest-rate)) u100))
                       (+ base-interest-amount early-bonus loyalty-bonus consecutive-bonus)
                       (/ (* base-contribution (var-get max-interest-rate)) u100)))
  )
    (map-set member-interest-earned {member: member, cycle: cycle} total-interest)
    (ok total-interest)))

(define-private (update-loyalty-score (member principal))
  (let (
    (current-score (get-member-loyalty-score member))
    (new-score (if (<= (+ current-score u1) u10) (+ current-score u1) u10))
  )
    (map-set member-loyalty-score member new-score)
    (ok new-score)))

(define-private (calculate-all-member-interest (cycle uint))
  (let (
    (member-list (list tx-sender))
  )
    (map calculate-member-interest-wrapper member-list)
    (ok true)))

(define-private (calculate-member-interest-wrapper (member principal))
  (if (has-contributed member (var-get current-cycle))
    (calculate-and-store-interest member (var-get current-cycle))
    (ok u0)))

(define-read-only (get-member-interest-projection (member principal) (cycle uint))
  (let (
    (base-contribution (var-get contribution-amount))
    (contribution-order (get-cycle-contribution-order cycle member))
    (is-early (< contribution-order (/ (var-get total-members) u2)))
    (loyalty-score (get-member-loyalty-score member))
    (consecutive-cycles (get-member-consecutive-cycles member))
    (base-interest-amount (/ (* base-contribution (var-get base-interest-rate)) u100))
    (early-bonus (if is-early (/ (* base-interest-amount (var-get early-contribution-multiplier)) u1) u0))
    (loyalty-bonus (/ (* base-interest-amount (if (<= loyalty-score u10) loyalty-score u10)) u10))
    (consecutive-bonus (/ (* base-interest-amount (if (<= consecutive-cycles u5) consecutive-cycles u5)) u10))
    (total-interest (if (<= (+ base-interest-amount early-bonus loyalty-bonus consecutive-bonus) 
                           (/ (* base-contribution (var-get max-interest-rate)) u100))
                       (+ base-interest-amount early-bonus loyalty-bonus consecutive-bonus)
                       (/ (* base-contribution (var-get max-interest-rate)) u100)))
  )
    {
      base-interest: base-interest-amount,
      early-bonus: early-bonus,
      loyalty-bonus: loyalty-bonus,
      consecutive-bonus: consecutive-bonus,
      total-interest: total-interest,
      is-early: is-early
    }))

(define-read-only (get-member-interest-summary (member principal))
  (let (
    (current-cycle-val (var-get current-cycle))
    (total-earned (get-member-total-interest-earned member))
    (loyalty-score (get-member-loyalty-score member))
    (consecutive-cycles (get-member-consecutive-cycles member))
    (current-cycle-earned (get-member-interest-earned member current-cycle-val))
    (can-claim (and (> current-cycle-earned u0) 
                   (not (get-member-reward-claimed member current-cycle-val))))
  )
    {
      total-interest-earned: total-earned,
      loyalty-score: loyalty-score,
      consecutive-cycles: consecutive-cycles,
      current-cycle-earned: current-cycle-earned,
      can-claim: can-claim
    }))

(define-read-only (get-interest-pool-status)
  (let (
    (pool-balance (var-get interest-pool))
    (estimated-rewards (calculate-estimated-cycle-rewards))
  )
    {
      pool-balance: pool-balance,
      estimated-rewards: estimated-rewards,
      sustainability-ratio: (if (> estimated-rewards u0) (/ pool-balance estimated-rewards) u0)
    }))

(define-private (calculate-estimated-cycle-rewards)
  (let (
    (total-members-count (var-get total-members))
    (avg-contribution (var-get contribution-amount))
    (avg-interest-rate (var-get base-interest-rate))
    (estimated-total (/ (* avg-contribution avg-interest-rate total-members-count) u100))
  )
    estimated-total))

;; Group Governance System - Democratic decision making for AJO groups
(define-constant ERR-INVALID-PROPOSAL-TYPE (err u121))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u122))
(define-constant ERR-PROPOSAL-EXPIRED (err u123))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u124))
(define-constant ERR-ALREADY-VOTED (err u125))
(define-constant ERR-INSUFFICIENT-QUORUM (err u126))
(define-constant ERR-PROPOSAL-REJECTED (err u127))
(define-constant ERR-INVALID-VOTING-PERIOD (err u128))

;; Proposal types: 1=change-contribution-amount, 2=change-penalty-rate, 3=change-admin, 4=emergency-withdrawal
(define-data-var next-proposal-id uint u1)
(define-data-var voting-period uint u1008) ;; Default 1 week in blocks
(define-data-var quorum-percentage uint u60) ;; 60% of members needed for quorum

;; Proposal structure mapping
(define-map proposals uint {
  proposer: principal,
  proposal-type: uint,
  target-value: uint,
  target-principal: (optional principal),
  description: (string-ascii 256),
  created-at: uint,
  voting-deadline: uint,
  yes-votes: uint,
  no-votes: uint,
  executed: bool,
  active: bool
})

;; Track member votes on proposals
(define-map member-votes {proposal-id: uint, member: principal} bool)

;; Track voting participation
(define-map member-voting-history principal uint)

;; Read-only functions for governance
(define-read-only (get-voting-period)
  (var-get voting-period))

(define-read-only (get-quorum-percentage)
  (var-get quorum-percentage))

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-member-vote (proposal-id uint) (member principal))
  (map-get? member-votes {proposal-id: proposal-id, member: member}))

(define-read-only (get-member-voting-history (member principal))
  (default-to u0 (map-get? member-voting-history member)))

(define-read-only (calculate-quorum-needed)
  (/ (* (var-get total-members) (var-get quorum-percentage)) u100))

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
      (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
      (quorum-needed (calculate-quorum-needed))
      (is-expired (> stacks-block-height (get voting-deadline proposal)))
      (has-quorum (>= total-votes quorum-needed))
      (is-passing (> (get yes-votes proposal) (get no-votes proposal)))
    )
    (some {
      proposal: proposal,
      total-votes: total-votes,
      quorum-needed: quorum-needed,
      has-quorum: has-quorum,
      is-expired: is-expired,
      is-passing: is-passing,
      can-execute: (and has-quorum is-passing (not (get executed proposal)))
    }))
    none))

;; Admin governance configuration
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-period u144) (<= new-period u4032)) ERR-INVALID-VOTING-PERIOD) ;; 1 day to 4 weeks
    (var-set voting-period new-period)
    (ok true)))

(define-public (set-quorum-percentage (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-percentage u25) (<= new-percentage u100)) ERR-INVALID-AMOUNT)
    (var-set quorum-percentage new-percentage)
    (ok true)))

;; Create new proposal - any member can propose
(define-public (create-proposal (proposal-type uint) (target-value uint) (target-principal (optional principal)) (description (string-ascii 256)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (voting-deadline (+ stacks-block-height (var-get voting-period)))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (and (>= proposal-type u1) (<= proposal-type u4)) ERR-INVALID-PROPOSAL-TYPE)
    
    (map-set proposals proposal-id {
      proposer: tx-sender,
      proposal-type: proposal-type,
      target-value: target-value,
      target-principal: target-principal,
      description: description,
      created-at: stacks-block-height,
      voting-deadline: voting-deadline,
      yes-votes: u0,
      no-votes: u0,
      executed: false,
      active: true
    })
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)))

;; Vote on proposal - true for yes, false for no
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    (member-previous-vote (map-get? member-votes {proposal-id: proposal-id, member: tx-sender}))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-member tx-sender) ERR-NOT-MEMBER)
    (asserts! (get active proposal) ERR-PROPOSAL-NOT-ACTIVE)
    (asserts! (<= stacks-block-height (get voting-deadline proposal)) ERR-PROPOSAL-EXPIRED)
    (asserts! (is-none member-previous-vote) ERR-ALREADY-VOTED)
    
    ;; Record the vote
    (map-set member-votes {proposal-id: proposal-id, member: tx-sender} vote)
    
    ;; Update vote counts
    (if vote
      (map-set proposals proposal-id (merge proposal {yes-votes: (+ (get yes-votes proposal) u1)}))
      (map-set proposals proposal-id (merge proposal {no-votes: (+ (get no-votes proposal) u1)})))
    
    ;; Update member voting history
    (map-set member-voting-history tx-sender (+ (get-member-voting-history tx-sender) u1))
    
    (ok true)))

;; Execute approved proposal
(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
    (quorum-needed (calculate-quorum-needed))
    (has-quorum (>= total-votes quorum-needed))
    (is-passing (> (get yes-votes proposal) (get no-votes proposal)))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get active proposal) ERR-PROPOSAL-NOT-ACTIVE)
    (asserts! (not (get executed proposal)) ERR-PROPOSAL-REJECTED)
    (asserts! has-quorum ERR-INSUFFICIENT-QUORUM)
    (asserts! is-passing ERR-PROPOSAL-REJECTED)
    
    ;; Execute based on proposal type
    (if (is-eq (get proposal-type proposal) u1)
      ;; Change contribution amount
      (var-set contribution-amount (get target-value proposal))
      (if (is-eq (get proposal-type proposal) u2)
        ;; Change penalty rate
        (var-set penalty-rate (get target-value proposal))
        (if (is-eq (get proposal-type proposal) u3)
          ;; Change admin
          (match (get target-principal proposal)
            new-admin (var-set admin new-admin)
            false)
          (if (is-eq (get proposal-type proposal) u4)
            ;; Emergency withdrawal
            (try! (as-contract (stx-transfer? (get target-value proposal) tx-sender (var-get admin))))
            false))))
    
    ;; Mark proposal as executed
    (map-set proposals proposal-id (merge proposal {executed: true, active: false}))
    
    (ok true)))

;; Cancel proposal (only proposer or admin)
(define-public (cancel-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
  )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (or (is-eq tx-sender (get proposer proposal)) (is-eq tx-sender (var-get admin))) ERR-NOT-AUTHORIZED)
    (asserts! (get active proposal) ERR-PROPOSAL-NOT-ACTIVE)
    (asserts! (not (get executed proposal)) ERR-PROPOSAL-REJECTED)
    
    (map-set proposals proposal-id (merge proposal {active: false}))
    (ok true)))

;; Get active proposals
(define-read-only (get-active-proposals-count)
  (fold count-active-proposals (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) u0))

(define-private (count-active-proposals (proposal-id uint) (count uint))
  (match (map-get? proposals proposal-id)
    proposal (if (and (get active proposal) (<= stacks-block-height (get voting-deadline proposal)))
               (+ count u1)
               count)
    count))

;; Get governance statistics
(define-read-only (get-governance-stats)
  (let (
    (total-proposals (- (var-get next-proposal-id) u1))
    (active-proposals (get-active-proposals-count))
  )
  {
    total-proposals: total-proposals,
    active-proposals: active-proposals,
    quorum-needed: (calculate-quorum-needed),
    voting-period-blocks: (var-get voting-period)
  }))

;; Helper function to get proposal history for a member
(define-read-only (get-member-governance-summary (member principal))
  (let (
    (proposals-participated (get-member-voting-history member))
    (is-active-member (is-member member))
  )
  {
    proposals-participated: proposals-participated,
    is-active-member: is-active-member,
    voting-power: (if is-active-member u1 u0)
  }))



  