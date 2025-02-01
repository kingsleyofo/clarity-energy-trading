;; Define the contract
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

;; Error codes 
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-LISTED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INSUFFICIENT-FUNDS (err u403))
(define-constant ERR-EXPIRED (err u405))

;; Storage variables
(define-data-var next-listing-id uint u1)

;; Public functions
(define-public (list-energy (amount uint) (price-per-unit uint) (duration uint))
    (let (
        (seller-balance (default-to u0 (get-energy-balance tx-sender)))
        (listing-id (var-get next-listing-id))
        (expiry (+ block-height duration))
    )
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
    (ok listing-id))
)

(define-public (buy-energy (seller principal) (listing-id uint) (amount uint))
    (let (
        (listing (unwrap! (map-get? energy-listings {seller: seller, listing-id: listing-id}) ERR-NOT-FOUND))
        (price (* amount (get price-per-unit listing)))
        (buyer-balance (stx-get-balance tx-sender))
    )
    (asserts! (<= block-height (get expiry listing)) ERR-EXPIRED)
    (asserts! (<= amount (get amount listing)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= buyer-balance price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX from buyer to seller
    (try! (stx-transfer? price tx-sender seller))
    
    ;; Update energy balances
    (map-set user-energy-balance
        tx-sender
        (+ (default-to u0 (get-energy-balance tx-sender)) amount)
    )
    
    ;; Update trading metrics
    (update-metrics seller tx-sender amount)
    
    ;; Update or delete listing
    (if (< amount (get amount listing))
        (map-set energy-listings
            {seller: seller, listing-id: listing-id}
            (merge listing {amount: (- (get amount listing) amount)})
        )
        (map-delete energy-listings {seller: seller, listing-id: listing-id})
    )
    (ok true))
)

(define-public (cancel-listing (listing-id uint))
    (let (
        (listing (unwrap! (map-get? energy-listings {seller: tx-sender, listing-id: listing-id}) ERR-NOT-FOUND))
    )
    (map-delete energy-listings {seller: tx-sender, listing-id: listing-id})
    (map-set user-energy-balance
        tx-sender
        (+ (default-to u0 (get-energy-balance tx-sender)) (get amount listing))
    )
    (ok true))
)

(define-public (add-energy (amount uint))
    (let (
        (current-balance (default-to u0 (get-energy-balance tx-sender)))
    )
    (map-set user-energy-balance
        tx-sender
        (+ current-balance amount)
    )
    (ok true))
)

;; Private functions
(define-private (update-metrics (seller principal) (buyer principal) (amount uint))
    (let (
        (seller-metrics (default-to {total-sold: u0, total-bought: u0, last-trade: block-height} 
                        (map-get? trading-metrics seller)))
        (buyer-metrics (default-to {total-sold: u0, total-bought: u0, last-trade: block-height}
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
))

;; Read only functions
(define-read-only (get-energy-balance (user principal))
    (map-get? user-energy-balance user)
)

(define-read-only (get-listing (seller principal) (listing-id uint))
    (map-get? energy-listings {seller: seller, listing-id: listing-id})
)

(define-read-only (get-user-metrics (user principal))
    (map-get? trading-metrics user)
)
