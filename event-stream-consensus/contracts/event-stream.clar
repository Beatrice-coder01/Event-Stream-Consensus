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