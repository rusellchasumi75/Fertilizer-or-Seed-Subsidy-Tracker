(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_DISTRIBUTED (err u101))
(define-constant ERR_BENEFICIARY_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_DISTRIBUTOR_NOT_AUTHORIZED (err u104))

(define-data-var contract-owner principal CONTRACT_OWNER)

(define-map authorized-distributors principal bool)
(define-map beneficiaries principal {
    name: (string-ascii 100),
    location: (string-ascii 100),
    registered-at: uint
})

(define-map subsidy-records 
    {beneficiary: principal, subsidy-type: (string-ascii 20), season: uint}
    {
        amount: uint,
        distributor: principal,
        distributed-at: uint,
        block-height: uint
    }
)

(define-map beneficiary-totals
    {beneficiary: principal, subsidy-type: (string-ascii 20)}
    uint
)

(define-data-var total-distributed uint u0)
(define-data-var total-beneficiaries uint u0)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (is-authorized-distributor (distributor principal))
    (default-to false (map-get? authorized-distributors distributor))
)

(define-read-only (get-beneficiary (beneficiary principal))
    (map-get? beneficiaries beneficiary)
)

(define-read-only (get-subsidy-record (beneficiary principal) (subsidy-type (string-ascii 20)) (season uint))
    (map-get? subsidy-records {beneficiary: beneficiary, subsidy-type: subsidy-type, season: season})
)

(define-read-only (get-beneficiary-total (beneficiary principal) (subsidy-type (string-ascii 20)))
    (default-to u0 (map-get? beneficiary-totals {beneficiary: beneficiary, subsidy-type: subsidy-type}))
)

(define-read-only (get-total-distributed)
    (var-get total-distributed)
)

(define-read-only (get-total-beneficiaries)
    (var-get total-beneficiaries)
)

(define-read-only (has-received-subsidy (beneficiary principal) (subsidy-type (string-ascii 20)) (season uint))
    (is-some (get-subsidy-record beneficiary subsidy-type season))
)

(define-public (authorize-distributor (distributor principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set authorized-distributors distributor true))
    )
)

(define-public (revoke-distributor (distributor principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-distributors distributor))
    )
)

(define-public (register-beneficiary (beneficiary principal) (name (string-ascii 100)) (location (string-ascii 100)))
    (begin
        (asserts! (is-authorized-distributor tx-sender) ERR_DISTRIBUTOR_NOT_AUTHORIZED)
        (let ((existing-beneficiary (get-beneficiary beneficiary)))
            (if (is-none existing-beneficiary)
                (var-set total-beneficiaries (+ (var-get total-beneficiaries) u1))
                true
            )
        )
        (ok (map-set beneficiaries beneficiary {
            name: name,
            location: location,
            registered-at: stacks-block-height
        }))
    )
)

(define-public (distribute-subsidy 
    (beneficiary principal) 
    (subsidy-type (string-ascii 20)) 
    (amount uint) 
    (season uint)
)
    (begin
        (asserts! (is-authorized-distributor tx-sender) ERR_DISTRIBUTOR_NOT_AUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-some (get-beneficiary beneficiary)) ERR_BENEFICIARY_NOT_FOUND)
        (asserts! (not (has-received-subsidy beneficiary subsidy-type season)) ERR_ALREADY_DISTRIBUTED)
        
        (map-set subsidy-records 
            {beneficiary: beneficiary, subsidy-type: subsidy-type, season: season}
            {
                amount: amount,
                distributor: tx-sender,
                distributed-at: stacks-block-height,
                block-height: stacks-block-height
            }
        )
        
        (let ((current-total (get-beneficiary-total beneficiary subsidy-type)))
            (map-set beneficiary-totals 
                {beneficiary: beneficiary, subsidy-type: subsidy-type}
                (+ current-total amount)
            )
        )
        
        (var-set total-distributed (+ (var-get total-distributed) amount))
        (ok true)
    )
)

(define-public (batch-distribute 
    (distributions (list 50 {beneficiary: principal, subsidy-type: (string-ascii 20), amount: uint, season: uint}))
)
    (begin
        (asserts! (is-authorized-distributor tx-sender) ERR_DISTRIBUTOR_NOT_AUTHORIZED)
        (ok (map distribute-single-subsidy distributions))
    )
)

(define-private (distribute-single-subsidy (distribution {beneficiary: principal, subsidy-type: (string-ascii 20), amount: uint, season: uint}))
    (distribute-subsidy 
        (get beneficiary distribution)
        (get subsidy-type distribution)
        (get amount distribution)
        (get season distribution)
    )
)

(define-read-only (get-beneficiary-history (beneficiary principal))
    (let ((fertilizer-total (get-beneficiary-total beneficiary "fertilizer"))
          (seed-total (get-beneficiary-total beneficiary "seed")))
        {
            fertilizer-total: fertilizer-total,
            seed-total: seed-total,
            total-received: (+ fertilizer-total seed-total)
        }
    )
)

(define-read-only (verify-distribution 
    (beneficiary principal) 
    (subsidy-type (string-ascii 20)) 
    (season uint)
)
    (match (get-subsidy-record beneficiary subsidy-type season)
        record (some {
            verified: true,
            amount: (get amount record),
            distributor: (get distributor record),
            block-height: (get block-height record)
        })
        none
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(authorize-distributor CONTRACT_OWNER)
