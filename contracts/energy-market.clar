;; Define the contract
(define-map energy-listings
    { seller: principal }
    { amount: uint, price-per-unit: uint }
)

(define-map user-energy-balance
    principal
    uint
)

;; Error codes
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-LISTED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INSUFFICIENT-FUNDS (err u403))

;; Public functions
(define-public (list-energy (amount uint) (price-per-unit uint))
    (let (
        (seller-balance (default-to u0 (get-energy-balance tx-sender)))
    )
    (asserts! (>= seller-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (is-none (map-get? energy-listings {seller: tx-sender})) ERR-ALREADY-LISTED)
    
    (map-set energy-listings
        {seller: tx-sender}
        {amount: amount, price-per-unit: price-per-unit}
    )
    (map-set user-energy-balance
        tx-sender
        (- seller-balance amount)
    )
    (ok true))
)

(define-public (buy-energy (seller principal) (amount uint))
    (let (
        (listing (unwrap! (map-get? energy-listings {seller: seller}) ERR-NOT-FOUND))
        (price (* amount (get price-per-unit listing)))
        (buyer-balance (stx-get-balance tx-sender))
    )
    (asserts! (<= amount (get amount listing)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (>= buyer-balance price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX from buyer to seller
    (try! (stx-transfer? price tx-sender seller))
    
    ;; Update energy balances
    (map-set user-energy-balance
        tx-sender
        (+ (default-to u0 (get-energy-balance tx-sender)) amount)
    )
    
    ;; Update or delete listing
    (if (< amount (get amount listing))
        (map-set energy-listings
            {seller: seller}
            {amount: (- (get amount listing) amount), price-per-unit: (get price-per-unit listing)}
        )
        (map-delete energy-listings {seller: seller})
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

;; Read only functions
(define-read-only (get-energy-balance (user principal))
    (map-get? user-energy-balance user)
)

(define-read-only (get-listing (seller principal))
    (map-get? energy-listings {seller: seller})
)
