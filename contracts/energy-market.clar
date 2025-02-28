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

;; Events
(define-data-var last-event-id uint u0)

(define-public (list-energy (amount uint) (price-per-unit uint) (duration uint))
    (let (
        (seller-balance (default-to u0 (get-energy-balance tx-sender)))
        (listing-id (var-get next-listing-id))
        (expiry (+ block-height duration))
    )
    ;; Input validation
    (asserts! (>= amount MIN-TRADE-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (<= price-per-unit MAX-PRICE-PER-UNIT) ERR-INVALID-PRICE)
    (asserts! (<= duration MAX-LISTING-DURATION) ERR-INVALID-DURATION)
    (asserts! (>= seller-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    (map-set energy-listings
        {seller: tx-sender, listing-id: listing-id}
        {amount: amount, price-per-unit: price-per-unit, expiry: expiry}
    )
    (map-set user-energy-balance
        tx-sender
        (- seller-balance amount)
    )
    (var-set next-listing-id (+ listing-id u1))
    
    ;; Emit listing event
    (print {event: "new-listing", seller: tx-sender, amount: amount, price: price-per-unit})
    
    (ok listing-id))
)

(define-public (buy-energy (seller principal) (listing-id uint) (amount uint))
    (let (
        (listing (unwrap! (map-get? energy-listings {seller: seller, listing-id: listing-id}) ERR-NOT-FOUND))
        (price (* amount (get price-per-unit listing)))
        (buyer-balance (stx-get-balance tx-sender))
    )
    ;; Input validation
    (asserts! (>= amount MIN-TRADE-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (<= block-height (get expiry listing)) ERR-EXPIRED)
    (asserts! (<= amount (get amount listing)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= buyer-balance price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX
    (try! (stx-transfer? price tx-sender seller))
    
    ;; Update balances
    (map-set user-energy-balance
        tx-sender
        (+ (default-to u0 (get-energy-balance tx-sender)) amount)
    )
    
    ;; Update metrics
    (update-metrics seller tx-sender amount)
    
    ;; Update listing
    (if (< amount (get amount listing))
        (map-set energy-listings
            {seller: seller, listing-id: listing-id}
            (merge listing {amount: (- (get amount listing) amount)})
        )
        (map-delete energy-listings {seller: seller, listing-id: listing-id})
    )
    
    ;; Emit trade event
    (print {event: "trade-executed", seller: seller, buyer: tx-sender, amount: amount, price: price})
    
    (ok true))
)

[Previous functions remain unchanged...]
