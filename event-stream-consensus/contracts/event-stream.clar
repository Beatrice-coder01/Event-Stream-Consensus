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