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