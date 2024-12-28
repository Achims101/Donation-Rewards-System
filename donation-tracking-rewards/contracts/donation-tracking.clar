;; Tokenized Donation Smart Contract
;; Allows users to make donations and receive donation tokens as proof
;; Implements features like donation tracking, rewards, and administrative controls

;; Define NFT Trait
(define-trait nft-trait
  (
    ;; Transfer a token from one principal to another
    (transfer (uint principal principal) (response bool uint))
    
    ;; Get the owner of a specific token ID
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Get the last token ID (for total supply)
    (get-last-token-id () (response uint uint))
    
    ;; Get the URI for a specific token
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
  )
)

;; Error Constants
(define-constant ERROR_NOT_CONTRACT_OWNER (err u100))
(define-constant ERROR_DONATION_AMOUNT_INVALID (err u101))
(define-constant ERROR_USER_UNAUTHORIZED (err u102))
(define-constant ERROR_REWARDS_ALREADY_CLAIMED (err u103))
(define-constant ERROR_WALLET_ADDRESS_INVALID (err u104))
(define-constant ERROR_DONATION_SYSTEM_PAUSED (err u105))
(define-constant ERROR_TOKEN_TRANSFER_FAILED (err u106))
(define-constant ERROR_INSUFFICIENT_DONATION_BALANCE (err u107))
(define-constant ERROR_DONATION_TOKEN_ID_INVALID (err u108))
(define-constant ERROR_RECORD_NOT_FOUND (err u109))
(define-constant ERROR_ZERO_DONATION_AMOUNT (err u110))

;; System Constants
(define-constant DONATION_CONTRACT_OWNER tx-sender)
(define-constant DONATION_NFT_TOKEN_URI "https://donation-tracking.uri")
(define-constant MINIMUM_DONATION_REWARD_MULTIPLIER u10)
(define-constant DONATION_REWARD_TOKEN_RATE u10)
(define-constant DAILY_BLOCK_COUNT u144) ;; Average blocks per day for time calculations

;; Data Variables
(define-data-var minimum-required-donation-amount uint u1000000) ;; 1 STX
(define-data-var total-lifetime-donations uint u0)
(define-data-var total-unique-donors uint u0)
(define-data-var donation-system-paused bool false)
(define-data-var current-donation-sequence uint u0)

;; Data Maps
(define-map donor-activity-records 
    principal 
    {
        total-donation-amount: uint,
        donation-count: uint,
        most-recent-donation-block: uint,
        reward-tokens-claimed: bool,
        consecutive-donation-days: uint
    }
)

(define-map donation-history-records 
    uint 
    {
        donor-wallet-address: principal,
        donation-amount-stx: uint,
        donation-block-height: uint,
        donation-token-identifier: uint,
        donation-purpose-category: (optional (string-ascii 64))
    }
)

;; SFT Interface
(define-fungible-token donation-reward-token)

;; Private Functions
(define-private (verify-contract-owner)
    (is-eq tx-sender DONATION_CONTRACT_OWNER)
)

(define-private (get-donor-activity-summary (donor-wallet-address principal))
    (default-to 
        {
            total-donation-amount: u0,
            donation-count: u0,
            most-recent-donation-block: u0,
            reward-tokens-claimed: false,
            consecutive-donation-days: u0
        }
        (map-get? donor-activity-records donor-wallet-address)
    )
)

(define-private (update-donor-activity-records 
    (donor-wallet-address principal) 
    (current-donation-amount uint)
)
    (let (
        (existing-donor-data (get-donor-activity-summary donor-wallet-address))
        (updated-donation-count (+ (get donation-count existing-donor-data) u1))
        (new-total-donation-amount (+ (get total-donation-amount existing-donor-data) current-donation-amount))
        (current-donation-streak (get consecutive-donation-days existing-donor-data))
        (last-donation-block-height (get most-recent-donation-block existing-donor-data))
        (updated-donation-streak (if (< (- block-height last-donation-block-height) DAILY_BLOCK_COUNT)
            (+ current-donation-streak u1)
            u1))
    )
    (map-set donor-activity-records 
        donor-wallet-address
        {
            total-donation-amount: new-total-donation-amount,
            donation-count: updated-donation-count,
            most-recent-donation-block: block-height,
            reward-tokens-claimed: (get reward-tokens-claimed existing-donor-data),
            consecutive-donation-days: updated-donation-streak
        }
    ))
)

;; Public Functions
(define-public (submit-donation (donation-amount-stx uint) (donation-purpose (optional (string-ascii 64))))
    (begin
        (asserts! (not (var-get donation-system-paused)) ERROR_DONATION_SYSTEM_PAUSED)
        (asserts! (> donation-amount-stx u0) ERROR_ZERO_DONATION_AMOUNT)
        (asserts! (>= donation-amount-stx (var-get minimum-required-donation-amount)) ERROR_DONATION_AMOUNT_INVALID)
        
        ;; Check if donation-purpose is provided and valid
        (asserts! (match donation-purpose
                    category (is-eq (len category) (len category))
                    true)
                  ERROR_DONATION_AMOUNT_INVALID)
        
        ;; Process STX transfer
        (try! (stx-transfer? donation-amount-stx tx-sender (as-contract tx-sender)))
        
        ;; Update global statistics
        (var-set total-lifetime-donations (+ (var-get total-lifetime-donations) donation-amount-stx))
        (update-donor-activity-records tx-sender donation-amount-stx)
        
        ;; Issue donation reward tokens
        (try! (ft-mint? donation-reward-token donation-amount-stx tx-sender))
        
        ;; Record donation transaction
        (map-set donation-history-records 
            (var-get current-donation-sequence)
            {
                donor-wallet-address: tx-sender,
                donation-amount-stx: donation-amount-stx,
                donation-block-height: block-height,
                donation-token-identifier: (var-get current-donation-sequence),
                donation-purpose-category: donation-purpose
            }
        )
        
        ;; Increment donation sequence
        (var-set current-donation-sequence (+ (var-get current-donation-sequence) u1))
        
        ;; Update unique donor count if first time donor
        (if (is-eq (get donation-count (get-donor-activity-summary tx-sender)) u1)
            (var-set total-unique-donors (+ (var-get total-unique-donors) u1))
            true
        )
        
        (ok true)
    )
)

(define-public (claim-donor-reward-tokens)
    (let (
        (donor-activity-summary (get-donor-activity-summary tx-sender))
    )
    (begin
        (asserts! (not (var-get donation-system-paused)) ERROR_DONATION_SYSTEM_PAUSED)
        (asserts! (>= (get total-donation-amount donor-activity-summary) 
            (* (var-get minimum-required-donation-amount) MINIMUM_DONATION_REWARD_MULTIPLIER)) 
            ERROR_INSUFFICIENT_DONATION_BALANCE)
        (asserts! (not (get reward-tokens-claimed donor-activity-summary)) ERROR_REWARDS_ALREADY_CLAIMED)
        
        ;; Update reward claim status
        (map-set donor-activity-records 
            tx-sender
            (merge donor-activity-summary { reward-tokens-claimed: true })
        )
        
        ;; Mint bonus reward tokens
        (try! (ft-mint? donation-reward-token 
            (/ (get total-donation-amount donor-activity-summary) DONATION_REWARD_TOKEN_RATE) 
            tx-sender))
        
        (ok true)
    ))
)

;; Administrative Functions
(define-public (update-minimum-donation-requirement (new-minimum-amount-stx uint))
    (begin
        (asserts! (verify-contract-owner) ERROR_NOT_CONTRACT_OWNER)
        (asserts! (> new-minimum-amount-stx u0) ERROR_ZERO_DONATION_AMOUNT)
        (var-set minimum-required-donation-amount new-minimum-amount-stx)
        (ok true)
    )
)

(define-public (toggle-donation-system-pause)
    (begin
        (asserts! (verify-contract-owner) ERROR_NOT_CONTRACT_OWNER)
        (var-set donation-system-paused (not (var-get donation-system-paused)))
        (ok true)
    )
)

(define-public (withdraw-donation-funds (withdrawal-amount-stx uint))
    (begin
        (asserts! (verify-contract-owner) ERROR_NOT_CONTRACT_OWNER)
        (asserts! (> withdrawal-amount-stx u0) ERROR_ZERO_DONATION_AMOUNT)
        (try! (as-contract (stx-transfer? withdrawal-amount-stx tx-sender DONATION_CONTRACT_OWNER)))
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-donor-details (donor-wallet-address principal))
    (match (map-get? donor-activity-records donor-wallet-address)
        donor-data (ok donor-data)
        ERROR_RECORD_NOT_FOUND
    )
)

(define-read-only (get-donation-details (donation-sequence-id uint))
    (match (map-get? donation-history-records donation-sequence-id)
        transaction-data (ok transaction-data)
        ERROR_RECORD_NOT_FOUND
    )
)

(define-read-only (get-donation-system-statistics)
    (ok {
        total-donation-amount: (var-get total-lifetime-donations),
        total-unique-donors: (var-get total-unique-donors),
        current-minimum-donation: (var-get minimum-required-donation-amount),
        system-paused-status: (var-get donation-system-paused),
        current-donation-sequence: (var-get current-donation-sequence)
    })
)

;; Error Handling
(define-private (handle-operation-result (operation-result (response bool uint)) (error-code uint))
    (match operation-result
        success (ok true)
        error (err error-code)
    )
)