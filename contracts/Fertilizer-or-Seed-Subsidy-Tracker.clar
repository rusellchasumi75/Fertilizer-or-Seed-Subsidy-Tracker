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
        height: uint
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
                height: stacks-block-height
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
            block-height: (get height record)
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


(define-map regional-stats
    (string-ascii 100)
    {
        total-beneficiaries: uint,
        total-distributed: uint,
        fertilizer-distributed: uint,
        seed-distributed: uint,
        last-distribution: uint,
        avg-distribution: uint
    }
)

(define-map region-alerts 
    (string-ascii 100)
    {
        alert-type: (string-ascii 50),
        triggered-at: uint,
        threshold-value: uint
    }
)

(define-data-var alert-threshold uint u500)

(define-read-only (get-regional-stats (region (string-ascii 100)))
    (default-to 
        {total-beneficiaries: u0, total-distributed: u0, fertilizer-distributed: u0, 
         seed-distributed: u0, last-distribution: u0, avg-distribution: u0}
        (map-get? regional-stats region)
    )
)

(define-read-only (get-region-alert (region (string-ascii 100)))
    (map-get? region-alerts region)
)

(define-read-only (max2 (a uint) (b uint))
    (if (> a b) a b)
)
(define-read-only (min2 (a uint) (b uint))
    (if (< a b) a b)
)

(define-read-only (calculate-distribution-inequality)
    (let (
            (north-stats (get-regional-stats "North"))
            (south-stats (get-regional-stats "South"))
            (east-stats (get-regional-stats "East"))
            (west-stats (get-regional-stats "West"))
            (north-fert (get fertilizer-distributed north-stats))
            (south-fert (get fertilizer-distributed south-stats))
            (east-fert (get fertilizer-distributed east-stats))
            (west-fert (get fertilizer-distributed west-stats))
            (north-seed (get seed-distributed north-stats))
            (south-seed (get seed-distributed south-stats))
            (east-seed (get seed-distributed east-stats))
            (west-seed (get seed-distributed west-stats))
            (fert-max (max2 (max2 north-fert south-fert) (max2 east-fert west-fert)))
            (fert-min (min2 (min2 north-fert south-fert) (min2 east-fert west-fert)))
            (seed-max (max2 (max2 north-seed south-seed) (max2 east-seed west-seed)))
            (seed-min (min2 (min2 north-seed south-seed) (min2 east-seed west-seed)))
        )
        {
            fertilizer-inequality: (- fert-max fert-min),
            seed-inequality: (- seed-max seed-min),
            recommendation: "Focus on underperforming regions"
        }
    )
)

(define-read-only (get-underperforming-regions)
    (let ((threshold (var-get alert-threshold))
          (regions (list "North" "South" "East" "West" "Central" "Coastal" "Mountain" "Valley")))
        (filter check-underperforming regions)
    )
)

(define-private (check-underperforming (region (string-ascii 100)))
    (let ((stats (get-regional-stats region)))
        (< (get avg-distribution stats) (var-get alert-threshold))
    )
)

(define-private (extract-region (location (string-ascii 100)))
    (if (is-eq (slice? location u0 u5) (some "North")) "North"
    (if (is-eq (slice? location u0 u5) (some "South")) "South"  
    (if (is-eq (slice? location u0 u4) (some "East")) "East"
    (if (is-eq (slice? location u0 u4) (some "West")) "West"
    (if (is-eq (slice? location u0 u7) (some "Central")) "Central"
    (if (is-eq (slice? location u0 u7) (some "Coastal")) "Coastal"
    (if (is-eq (slice? location u0 u8) (some "Mountain")) "Mountain"
    "Valley")))))))
)

(define-private (update-regional-stats (region (string-ascii 100)) (amount uint) (subsidy-type (string-ascii 20)))
    (let ((current-stats (get-regional-stats region))
          (new-total (+ (get total-distributed current-stats) amount))
          (new-avg (/ new-total (max2 (get total-beneficiaries current-stats) u1))))
        (map-set regional-stats region {
            total-beneficiaries: (get total-beneficiaries current-stats),
            total-distributed: new-total,
            fertilizer-distributed: (if (is-eq subsidy-type "fertilizer") 
                (+ (get fertilizer-distributed current-stats) amount)
                (get fertilizer-distributed current-stats)),
            seed-distributed: (if (is-eq subsidy-type "seed") 
                (+ (get seed-distributed current-stats) amount)
                (get seed-distributed current-stats)),
            last-distribution: stacks-block-height,
            avg-distribution: new-avg
        })
        (check-and-trigger-alert region new-avg)
    )
)

(define-private (check-and-trigger-alert (region (string-ascii 100)) (avg-amount uint))
    (if (< avg-amount (var-get alert-threshold))
        (map-set region-alerts region {
            alert-type: "underperforming",
            triggered-at: stacks-block-height,
            threshold-value: avg-amount
        })
        (map-delete region-alerts region)
    )
)

(define-map audit-trail
    uint
    {
        transaction-hash: (buff 32),
        beneficiary: principal,
        amount: uint,
        timestamp: uint,
        previous-hash: (buff 32),
        verification-status: (string-ascii 10)
    }
)

(define-map suspicious-activities
    uint
    {
        activity-type: (string-ascii 30),
        flagged-at: uint,
        risk-score: uint,
        auto-generated: bool
    }
)

(define-data-var audit-counter uint u0)
(define-data-var last-audit-hash (buff 32) 0x00000000000000000000000000000000)

(define-read-only (generate-transaction-hash (beneficiary principal) (amount uint) (height uint))
    (keccak256 (concat 
        (concat (unwrap-panic (to-consensus-buff? beneficiary)) (unwrap-panic (to-consensus-buff? amount)))
        (unwrap-panic (to-consensus-buff? height))
    ))
)

(define-private (create-audit-record (beneficiary principal) (amount uint))
    (let ((counter (+ (var-get audit-counter) u1))
          (tx-hash (generate-transaction-hash beneficiary amount stacks-block-height))
          (prev-hash (var-get last-audit-hash)))
        (map-set audit-trail counter {
            transaction-hash: tx-hash,
            beneficiary: beneficiary,
            amount: amount,
            timestamp: stacks-block-height,
            previous-hash: prev-hash,
            verification-status: "verified"
        })
        (var-set audit-counter counter)
        (var-set last-audit-hash tx-hash)
        (detect-suspicious-patterns beneficiary amount)
    )
)

(define-private (detect-suspicious-patterns (beneficiary principal) (amount uint))
    (let ((history (get-beneficiary-history beneficiary))
          (total-received (get total-received history))
          (risk-score (if (> amount u1000) u8 (if (> total-received u5000) u6 u2))))
        (if (>= risk-score u6)
            (map-set suspicious-activities (+ (var-get audit-counter) u1) {
                activity-type: "high-value-distribution",
                flagged-at: stacks-block-height,
                risk-score: risk-score,
                auto-generated: true
            })
            true
        )
    )
)

(define-read-only (verify-audit-chain (start-id uint) (end-id uint))
    (fold verify-single-audit (list start-id (+ start-id u1) (+ start-id u2)) true)
)

(define-private (verify-single-audit (audit-id uint) (is-valid bool))
    (if (not is-valid)
        false
        (match (map-get? audit-trail audit-id)
            record (let ((expected-hash (generate-transaction-hash 
                           (get beneficiary record)
                           (get amount record)
                           (get timestamp record))))
                       (is-eq (get transaction-hash record) expected-hash))
            false
        )
    )
)

(define-read-only (get-audit-record (audit-id uint))
    (map-get? audit-trail audit-id)
)

(define-read-only (get-suspicious-activities (limit uint))
    (map get-activity-by-id (list u1 u2 u3 u4 u5))
)

(define-private (get-activity-by-id (id uint))
    (map-get? suspicious-activities id)
)

(define-read-only (validate-distribution-integrity (beneficiary principal) (claimed-total uint))
    (let ((actual-history (get-beneficiary-history beneficiary))
          (actual-total (get total-received actual-history)))
        {
            is-valid: (is-eq claimed-total actual-total),
            variance: (if (> claimed-total actual-total) 
                        (- claimed-total actual-total)
                        (- actual-total claimed-total)),
            confidence-level: (if (is-eq claimed-total actual-total) u100 u0)
        }
    )
)