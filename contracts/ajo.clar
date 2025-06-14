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