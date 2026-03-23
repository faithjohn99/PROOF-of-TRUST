;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Trust Endorsement Registry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; -------------------------
;; Ownership & Admins
;; -------------------------

(define-data-var contract-owner principal tx-sender)

(define-map admins
  { admin: principal }
  { enabled: bool }
)

;; -------------------------
;; Global Control
;; -------------------------

(define-data-var paused bool false)

;; -------------------------
;; Trust Registry
;; -------------------------

;; Stores endorsement: endorser -> target
(define-map endorsements
  { from: principal, to: principal }
  {
    trust-score: uint,
    note: (optional (string-ascii 100)),
    created-at: uint,
    active: bool
  }
)

;; Aggregate trust score per user
(define-map trust-score
  { user: principal }
  {
    total: uint,
    received-count: uint
  }
)

;; Track how many endorsements a user has given
(define-map given-count
  { user: principal }
  { count: uint }
)

;; Total endorsements count
(define-data-var endorsement-count uint u0)

;; -------------------------
;; Constants
;; -------------------------

(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PAUSED (err u101))
(define-constant ERR-SELF-ENDORSE (err u102))
(define-constant ERR-ALREADY-ENDORSED (err u103))
(define-constant ERR-NOT-ENDORSED (err u104))
(define-constant ERR-INVALID-SCORE (err u105))

;; -------------------------
;; Internal Helpers
;; -------------------------

(define-private (is-owner (caller principal))
  (is-eq caller (var-get contract-owner))
)

(define-private (is-admin (caller principal))
  (or
    (is-owner caller)
    (default-to false
      (get enabled (map-get? admins { admin: caller }))
    )
  )
)

(define-private (not-paused)
  (not (var-get paused))
)

(define-private (get-score (user principal))
  (default-to { total: u0, received-count: u0 }
    (map-get? trust-score { user: user })
  )
)

(define-private (get-given (user principal))
  (default-to u0
    (get count (map-get? given-count { user: user }))
  )
)

(define-private (get-endorsement (from principal) (to principal))
  (map-get? endorsements { from: from, to: to })
)

;; -------------------------
;; Read-Only Views
;; -------------------------

(define-read-only (get-endorsement-info (from principal) (to principal))
  (get-endorsement from to)
)

(define-read-only (get-trust-score (user principal))
  (get-score user)
)

(define-read-only (has-endorsed (from principal) (to principal))
  (default-to false
    (get active (get-endorsement from to))
  )
)

(define-read-only (get-endorsement-count)
  (var-get endorsement-count)
)

(define-read-only (is-paused)
  (var-get paused)
)

;; -------------------------
;; User Actions
;; -------------------------

;; Create endorsement
(define-public (endorse
  (to principal)
  (score uint)
  (note (optional (string-ascii 100)))
)
  (begin
    (asserts! (not-paused) ERR-PAUSED)
    (asserts! (not (is-eq tx-sender to)) ERR-SELF-ENDORSE)
    (asserts! (> score u0) ERR-INVALID-SCORE)

    (asserts!
      (not (has-endorsed tx-sender to))
      ERR-ALREADY-ENDORSED
    )

    ;; Save endorsement
    (map-set endorsements
      { from: tx-sender, to: to }
      {
        trust-score: score,
        note: note,
        created-at: u0,
        active: true
      }
    )

    ;; Update receiver total score
    (let (
          (current (get-score to))
         )
      (map-set trust-score
        { user: to }
        {
          total: (+ (get total current) score),
          received-count: (+ (get received-count current) u1)
        }
      )
    )

    ;; Update sender stats
    (let ((given (get-given tx-sender)))
      (map-set given-count
        { user: tx-sender }
        { count: (+ given u1) }
      )
    )

    ;; Increment count
    (var-set endorsement-count (+ (var-get endorsement-count) u1))

    (ok true)
  )
)

;; Remove endorsement
(define-public (revoke-endorsement (to principal))
  (let (
        (entry (unwrap! (get-endorsement tx-sender to) ERR-NOT-ENDORSED))
       )

    (asserts! (get active entry) ERR-NOT-ENDORSED)

    ;; Update trust score
    (let (
          (current (get-score to))
          (score (get trust-score entry))
         )
      (map-set trust-score
        { user: to }
        {
          total: (- (get total current) score),
          received-count: (- (get received-count current) u1)
        }
      )
    )

    ;; Update sender stats
    (let ((given (get-given tx-sender)))
      (map-set given-count
        { user: tx-sender }
        { count: (- given u1) }
      )
    )

    ;; Remove endorsement
    (map-delete endorsements { from: tx-sender, to: to })

    (ok true)
  )
)

;; -------------------------
;; Admin Actions
;; -------------------------

;; Force remove endorsement
(define-public (admin-remove (from principal) (to principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)

    (let (
          (entry (unwrap! (get-endorsement from to) ERR-NOT-ENDORSED))
         )

      ;; Adjust score
      (let (
            (current (get-score to))
            (score (get trust-score entry))
           )
        (map-set trust-score
          { user: to }
          {
            total: (- (get total current) score),
            received-count: (- (get received-count current) u1)
          }
        )
      )

      ;; Adjust sender stats
      (let ((given (get-given from)))
        (map-set given-count
          { user: from }
          { count: (- given u1) }
        )
      )

      (map-delete endorsements { from: from, to: to })

      (ok true)
    )
  )
)

;; -------------------------
;; Admin Management
;; -------------------------

(define-public (add-admin (admin principal))
  (begin
    (asserts! (is-owner tx-sender) ERR-UNAUTHORIZED)
    (map-set admins { admin: admin } { enabled: true })
    (ok true)
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-owner tx-sender) ERR-UNAUTHORIZED)
    (map-delete admins { admin: admin })
    (ok true)
  )
)

;; -------------------------
;; Emergency Controls
;; -------------------------

(define-public (pause)
  (begin
    (asserts! (is-owner tx-sender) ERR-UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-owner tx-sender) ERR-UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)