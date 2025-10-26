;; EventStream Consensus - Decentralized event verification and attendance
;; Cryptographic check-ins with proof-of-attendance tokens

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-checked-in (err u102))
(define-constant err-event-ended (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-params (err u105))
(define-constant err-already-verified (err u106))
(define-constant err-insufficient-badges (err u107))
(define-constant err-event-not-started (err u108))
(define-constant err-already-rated (err u109))

;; Data vars
(define-data-var event-nonce uint u0)

;; Data maps
(define-map events
    { event-id: uint }
    {
        organizer: principal,
        event-name: (string-ascii 100),
        event-type: (string-ascii 50),
        start-block: uint,
        end-block: uint,
        attendee-count: uint,
        active: bool
    }
)

(define-map attendances
    { event-id: uint, attendee: principal }
    { checked-in: bool, check-in-block: uint, badge-issued: bool }
)

(define-map badges
    { attendee: principal }
    { total-badges: uint }
)

(define-map organizer-reputation
    { organizer: principal }
    { 
        events-created: uint,
        total-attendees: uint,
        average-rating: uint,
        verified: bool
    }
)

(define-map event-ratings
    { event-id: uint, rater: principal }
    { rating: uint, feedback: (string-ascii 200) }
)

(define-map event-categories
    { category: (string-ascii 50) }
    { event-count: uint, active: bool }
)

(define-map verified-attendees
    { event-id: uint, attendee: principal }
    { verified-by: principal, verification-block: uint }
)

(define-map attendee-stats
    { attendee: principal, event-type: (string-ascii 50) }
    { attendance-count: uint }
)

;; Read-only functions
(define-read-only (get-event (event-id uint))
    (map-get? events { event-id: event-id })
)

(define-read-only (get-attendance (event-id uint) (attendee principal))
    (map-get? attendances { event-id: event-id, attendee: attendee })
)

(define-read-only (get-badge-count (attendee principal))
    (default-to { total-badges: u0 } (map-get? badges { attendee: attendee }))
)

(define-read-only (get-event-nonce)
    (ok (var-get event-nonce))
)

(define-read-only (get-organizer-reputation (organizer principal))
    (map-get? organizer-reputation { organizer: organizer })
)

(define-read-only (get-event-rating (event-id uint) (rater principal))
    (map-get? event-ratings { event-id: event-id, rater: rater })
)

(define-read-only (get-category-info (category (string-ascii 50)))
    (map-get? event-categories { category: category })
)

(define-read-only (is-attendance-verified (event-id uint) (attendee principal))
    (is-some (map-get? verified-attendees { event-id: event-id, attendee: attendee }))
)

(define-read-only (get-attendee-stats (attendee principal) (event-type (string-ascii 50)))
    (default-to { attendance-count: u0 } 
        (map-get? attendee-stats { attendee: attendee, event-type: event-type }))
)

(define-read-only (has-checked-in (event-id uint) (attendee principal))
    (match (map-get? attendances { event-id: event-id, attendee: attendee })
        attendance (get checked-in attendance)
        false
    )
)

(define-read-only (is-event-active (event-id uint))
    (match (map-get? events { event-id: event-id })
        event (get active event)
        false
    )
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-event (event-name (string-ascii 100)) (event-type (string-ascii 50)) (duration uint))
    (let
        (
            (new-event-id (+ (var-get event-nonce) u1))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration))
            (current-rep (default-to 
                { events-created: u0, total-attendees: u0, average-rating: u0, verified: false }
                (map-get? organizer-reputation { organizer: tx-sender })))
        )
        (asserts! (> duration u0) err-invalid-params)
        (map-set events
            { event-id: new-event-id }
            {
                organizer: tx-sender,
                event-name: event-name,
                event-type: event-type,
                start-block: start-block,
                end-block: end-block,
                attendee-count: u0,
                active: true
            }
        )
        (map-set organizer-reputation
            { organizer: tx-sender }
            (merge current-rep { events-created: (+ (get events-created current-rep) u1) })
        )
        (var-set event-nonce new-event-id)
        (ok new-event-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (check-in (event-id uint))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
            (current-badges (get total-badges (get-badge-count tx-sender)))
            (event-type (get event-type event))
            (current-stats (get attendance-count (get-attendee-stats tx-sender event-type)))
        )
        (asserts! (get active event) err-event-ended)
        (asserts! (>= stacks-block-height (get start-block event)) err-event-not-started)
        (asserts! (<= stacks-block-height (get end-block event)) err-event-ended)
        (asserts! (is-none (map-get? attendances { event-id: event-id, attendee: tx-sender })) err-already-checked-in)
        (map-set attendances
            { event-id: event-id, attendee: tx-sender }
            { checked-in: true, check-in-block: stacks-block-height, badge-issued: true }
        )
        (map-set events
            { event-id: event-id }
            (merge event { attendee-count: (+ (get attendee-count event) u1) })
        )
        (map-set badges
            { attendee: tx-sender }
            { total-badges: (+ current-badges u1) }
        )
        (map-set attendee-stats
            { attendee: tx-sender, event-type: event-type }
            { attendance-count: (+ current-stats u1) }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (end-event (event-id uint))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
        )
        (asserts! (is-eq (get organizer event) tx-sender) err-unauthorized)
        (map-set events
            { event-id: event-id }
            (merge event { active: false })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (verify-attendance (event-id uint) (attendee principal))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
            (attendance (unwrap! (map-get? attendances { event-id: event-id, attendee: attendee }) err-not-found))
        )
        (asserts! (is-eq (get organizer event) tx-sender) err-unauthorized)
        (asserts! (get checked-in attendance) err-not-found)
        (asserts! (is-none (map-get? verified-attendees { event-id: event-id, attendee: attendee })) err-already-verified)
        (map-set verified-attendees
            { event-id: event-id, attendee: attendee }
            { verified-by: tx-sender, verification-block: stacks-block-height }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (rate-event (event-id uint) (rating uint) (feedback (string-ascii 200)))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
            (attendance (unwrap! (map-get? attendances { event-id: event-id, attendee: tx-sender }) err-not-found))
        )
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-params)
        (asserts! (get checked-in attendance) err-unauthorized)
        (asserts! (is-none (map-get? event-ratings { event-id: event-id, rater: tx-sender })) err-already-rated)
        (map-set event-ratings
            { event-id: event-id, rater: tx-sender }
            { rating: rating, feedback: feedback }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (register-category (category (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set event-categories
            { category: category }
            { event-count: u0, active: true }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (deactivate-category (category (string-ascii 50)))
    (let
        (
            (cat-info (unwrap! (map-get? event-categories { category: category }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set event-categories
            { category: category }
            (merge cat-info { active: false })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (verify-organizer (organizer principal))
    (let
        (
            (rep (unwrap! (map-get? organizer-reputation { organizer: organizer }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set organizer-reputation
            { organizer: organizer }
            (merge rep { verified: true })
        )
        (ok true)
    )
)

(define-public (bulk-check-in (event-id uint) (attendees (list 10 principal)))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
        )
        (asserts! (is-eq (get organizer event) tx-sender) err-unauthorized)
        (asserts! (get active event) err-event-ended)
        (ok (map process-bulk-checkin attendees))
    )
)

(define-private (process-bulk-checkin (attendee principal))
    (begin
        (map-set attendances
            { event-id: (var-get event-nonce), attendee: attendee }
            { checked-in: true, check-in-block: stacks-block-height, badge-issued: true }
        )
        true
    )
)

;; #[allow(unchecked_data)]
(define-public (claim-badge (event-id uint))
    (let
        (
            (attendance (unwrap! (map-get? attendances { event-id: event-id, attendee: tx-sender }) err-not-found))
            (current-badges (get total-badges (get-badge-count tx-sender)))
        )
        (asserts! (get checked-in attendance) err-unauthorized)
        (asserts! (not (get badge-issued attendance)) err-already-verified)
        (map-set attendances
            { event-id: event-id, attendee: tx-sender }
            (merge attendance { badge-issued: true })
        )
        (map-set badges
            { attendee: tx-sender }
            { total-badges: (+ current-badges u1) }
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (update-event-details (event-id uint) (new-name (string-ascii 100)) (new-end-block uint))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
        )
        (asserts! (is-eq (get organizer event) tx-sender) err-unauthorized)
        (asserts! (get active event) err-event-ended)
        (asserts! (> new-end-block stacks-block-height) err-invalid-params)
        (map-set events
            { event-id: event-id }
            (merge event { event-name: new-name, end-block: new-end-block })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (transfer-event-ownership (event-id uint) (new-organizer principal))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
        )
        (asserts! (is-eq (get organizer event) tx-sender) err-unauthorized)
        (map-set events
            { event-id: event-id }
            (merge event { organizer: new-organizer })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (revoke-attendance (event-id uint) (attendee principal))
    (let
        (
            (event (unwrap! (map-get? events { event-id: event-id }) err-not-found))
            (attendance (unwrap! (map-get? attendances { event-id: event-id, attendee: attendee }) err-not-found))
        )
        (asserts! (is-eq (get organizer event) tx-sender) err-unauthorized)
        (map-delete attendances { event-id: event-id, attendee: attendee })
        (map-set events
            { event-id: event-id }
            (merge event { attendee-count: (- (get attendee-count event) u1) })
        )
        (ok true)
    )
)