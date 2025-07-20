;; Fund-Me Research Grant Contract
;; Time-locked contract for releasing research/project grants

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_GRANT_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_FUNDS (err u400))
(define-constant ERR_GRANT_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_TIME_NOT_REACHED (err u403))
(define-constant ERR_ALREADY_RELEASED (err u405))
(define-constant ERR_INVALID_DURATION (err u406))

;; Data Variables
(define-data-var next-grant-id uint u1)

;; Data Maps
(define-map grants
  { grant-id: uint }
  {
    funder: principal,
    researcher: principal,
    amount: uint,
    release-time: uint,
    description: (string-ascii 256),
    released: bool,
    created-at: uint
  }
)

(define-map researcher-grants
  { researcher: principal }
  { grant-ids: (list 100 uint) }
)

(define-map funder-grants
  { funder: principal }
  { grant-ids: (list 100 uint) }
)

;; Private Functions
(define-private (add-grant-to-researcher (researcher principal) (grant-id uint))
  (let ((current-grants (default-to { grant-ids: (list) } 
                                   (map-get? researcher-grants { researcher: researcher }))))
    (map-set researcher-grants 
             { researcher: researcher }
             { grant-ids: (unwrap-panic (as-max-len? 
                                       (append (get grant-ids current-grants) grant-id) 
                                       u100)) })))

(define-private (add-grant-to-funder (funder principal) (grant-id uint))
  (let ((current-grants (default-to { grant-ids: (list) } 
                                   (map-get? funder-grants { funder: funder }))))
    (map-set funder-grants 
             { funder: funder }
             { grant-ids: (unwrap-panic (as-max-len? 
                                       (append (get grant-ids current-grants) grant-id) 
                                       u100)) })))

;; Public Functions

;; Create a new grant with time-lock
(define-public (create-grant (researcher principal) 
                            (amount uint) 
                            (delay-blocks uint) 
                            (description (string-ascii 256)))
  (let ((grant-id (var-get next-grant-id))
        (release-time (+ block-height delay-blocks)))
    
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> delay-blocks u0) ERR_INVALID_DURATION)
    (asserts! (<= delay-blocks u525600) ERR_INVALID_DURATION) ;; Max 1 year (assuming ~1min blocks)
    
    ;; Transfer STX from funder to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Create grant record
    (map-set grants
             { grant-id: grant-id }
             {
               funder: tx-sender,
               researcher: researcher,
               amount: amount,
               release-time: release-time,
               description: description,
               released: false,
               created-at: block-height
             })
    
    ;; Update tracking maps
    (add-grant-to-researcher researcher grant-id)
    (add-grant-to-funder tx-sender grant-id)
    
    ;; Increment grant ID counter
    (var-set next-grant-id (+ grant-id u1))
    
    ;; Emit event and return grant ID
    (print { event: "grant-created", grant-id: grant-id, researcher: researcher, amount: amount })
    (ok grant-id)))

;; Release funds to researcher (can be called by anyone once time-lock expires)
(define-public (release-grant (grant-id uint))
  (let ((grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND)))
    
    ;; Check if grant exists and hasn't been released
    (asserts! (not (get released grant)) ERR_ALREADY_RELEASED)
    
    ;; Check if release time has been reached
    (asserts! (>= block-height (get release-time grant)) ERR_TIME_NOT_REACHED)
    
    ;; Transfer funds to researcher
    (try! (as-contract (stx-transfer? (get amount grant) tx-sender (get researcher grant))))
    
    ;; Mark grant as released
    (map-set grants
             { grant-id: grant-id }
             (merge grant { released: true }))
    
    ;; Emit event
    (print { event: "grant-released", grant-id: grant-id, researcher: (get researcher grant), amount: (get amount grant) })
    (ok true)))

;; Emergency withdrawal by funder (only before release time)
(define-public (emergency-withdraw (grant-id uint))
  (let ((grant (unwrap! (map-get? grants { grant-id: grant-id }) ERR_GRANT_NOT_FOUND)))
    
    ;; Only funder can withdraw
    (asserts! (is-eq tx-sender (get funder grant)) ERR_UNAUTHORIZED)
    
    ;; Can only withdraw if not released and before release time
    (asserts! (not (get released grant)) ERR_ALREADY_RELEASED)
    (asserts! (< block-height (get release-time grant)) ERR_TIME_NOT_REACHED)
    
    ;; Transfer funds back to funder
    (try! (as-contract (stx-transfer? (get amount grant) tx-sender (get funder grant))))
    
    ;; Mark grant as released to prevent double spending
    (map-set grants
             { grant-id: grant-id }
             (merge grant { released: true }))
    
    ;; Emit event
    (print { event: "grant-withdrawn", grant-id: grant-id, funder: (get funder grant), amount: (get amount grant) })
    (ok true)))

;; Read-only Functions

;; Get grant details
(define-read-only (get-grant (grant-id uint))
  (map-get? grants { grant-id: grant-id }))

;; Check if grant is ready for release
(define-read-only (is-grant-ready (grant-id uint))
  (match (map-get? grants { grant-id: grant-id })
    grant (and (not (get released grant)) (>= block-height (get release-time grant)))
    false))

;; Get grants by researcher
(define-read-only (get-researcher-grants (researcher principal))
  (map-get? researcher-grants { researcher: researcher }))

;; Get grants by funder
(define-read-only (get-funder-grants (funder principal))
  (map-get? funder-grants { funder: funder }))

;; Get current block height (for UI convenience)
(define-read-only (get-current-block)
  block-height)

;; Get total grants created
(define-read-only (get-total-grants)
  (- (var-get next-grant-id) u1))

;; Calculate blocks until release (returns 0 if already releasable)
(define-read-only (blocks-until-release (grant-id uint))
  (match (map-get? grants { grant-id: grant-id })
    grant (if (>= block-height (get release-time grant))
             u0
             (- (get release-time grant) block-height))
    u0))

;; Get contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))