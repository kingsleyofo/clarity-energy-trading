;; Energy Market Smart Contract
;; Enables P2P trading of energy units with enhanced safety and events

;; Constants
(define-constant MAX-PRICE-PER-UNIT u1000000000)
(define-constant MAX-LISTING-DURATION u1440) ;; ~10 days in blocks
(define-constant MIN-TRADE-AMOUNT u1)

;; Error codes 
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-LISTED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INSUFFICIENT-FUNDS (err u403))
(define-constant ERR-EXPIRED (err u405))
(define-constant ERR-INVALID-AMOUNT (err u406))
(define-constant ERR-INVALID-PRICE (err u407))
(define-constant ERR-INVALID-DURATION (err u408))
(define-constant ERR-UNAUTHORIZED (err u409))

;; Data Maps
(define-map energy-listings
    { seller: principal, listing-id: uint }
    { amount: uint, price-per-unit: uint, expiry: uint }
)

(define-map user-energy-balance
    principal
    uint
)

(define-map trading-metrics
    principal
    { total-sold: uint, total-bought: uint, last-trade: uint }
)

;; Storage variables
(define-data-var next-listing-id uint u1)
(define-data-var last-event-id uint u0)

;; Helper functions
(define-private (get-energy-balance (user principal))
    (default-to u0 (map-get? user-energy-balance user))
)

(define-private (update-metrics (seller principal) (buyer principal) (amount uint))
    (let (
        (seller-metrics (default-to { total-sold: u0, total-bought: u0, last-trade: u0 } 
            (map-get? trading-metrics seller)))
        (buyer-metrics (default-to { total-sold: u0, total-bought: u0, last-trade: u0 } 
            (map-get? trading-metrics buyer)))
    )
    (map-set trading-metrics seller 
        (merge seller-metrics { 
            total-sold: (+ (get total-sold seller-metrics) amount),
            last-trade: block-height
        })
    )
    (map-set trading-metrics buyer
        (merge buyer-metrics { 
            total-bought: (+ (get total-bought buyer-metrics) amount),
            last-trade: block-height
        })
    )
    (ok true))
)

;; Public functions
(define-public (deposit-energy (amount uint))
    (begin
        (map-set user-energy-balance
            tx-sender
            (+ (get-energy-balance tx-sender) amount)
        )
        (print {event: "energy-deposit", user: tx-sender, amount: amount})
        (ok true))
)

[Previous functions remain unchanged...]

(define-public (cancel-listing (listing-id uint))
    (let (
        (listing (unwrap! (map-get? energy-listings {seller: tx-sender, listing-id: listing-id}) ERR-NOT-FOUND))
    )
    ;; Return energy to seller's balance
    (map-set user-energy-balance
        tx-sender
        (+ (get-energy-balance tx-sender) (get amount listing))
    )
    (map-delete energy-listings {seller: tx-sender, listing-id: listing-id})
    (print {event: "listing-cancelled", seller: tx-sender, listing-id: listing-id})
    (ok true))
)
