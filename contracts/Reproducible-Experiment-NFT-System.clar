(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-REPLICATION (err u103))
(define-constant ERR-INSUFFICIENT-REPLICATIONS (err u104))
(define-constant ERR-ALREADY-REPLICATED (err u105))
(define-constant ERR-INVALID-RATING (err u106))

(define-data-var next-experiment-id uint u1)
(define-data-var next-replication-id uint u1)
(define-data-var next-token-id uint u1)
(define-data-var min-successful-replications uint u3)

(define-map experiments 
  uint 
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    methodology: (string-ascii 1000),
    expected-results: (string-ascii 500),
    created-at: uint,
    total-replications: uint,
    successful-replications: uint,
    nft-minted: bool
  }
)

(define-map replications
  uint
  {
    experiment-id: uint,
    replicator: principal,
    results: (string-ascii 500),
    success: bool,
    rating: uint,
    created-at: uint,
    verified: bool
  }
)

(define-map user-replications
  {user: principal, experiment-id: uint}
  uint
)

(define-map user-reputation
  principal
  {
    total-replications: uint,
    successful-replications: uint,
    reputation-score: uint
  }
)

(define-non-fungible-token reproducibility-nft uint)

(define-map nft-metadata
  uint
  {
    experiment-id: uint,
    title: (string-ascii 100),
    creator: principal,
    successful-replications: uint,
    minted-at: uint
  }
)

(define-public (create-experiment (title (string-ascii 100)) (description (string-ascii 500)) (methodology (string-ascii 1000)) (expected-results (string-ascii 500)))
  (let ((experiment-id (var-get next-experiment-id)))
    (map-set experiments 
      experiment-id 
      {
        creator: tx-sender,
        title: title,
        description: description,
        methodology: methodology,
        expected-results: expected-results,
        created-at: stacks-block-height,
        total-replications: u0,
        successful-replications: u0,
        nft-minted: false
      }
    )
    (var-set next-experiment-id (+ experiment-id u1))
    (ok experiment-id)
  )
)

(define-public (submit-replication (experiment-id uint) (results (string-ascii 500)) (success bool) (rating uint))
  (let (
    (experiment (unwrap! (map-get? experiments experiment-id) ERR-NOT-FOUND))
    (replication-id (var-get next-replication-id))
    (user-rep (default-to {total-replications: u0, successful-replications: u0, reputation-score: u0} (map-get? user-reputation tx-sender)))
  )
    (asserts! (is-none (map-get? user-replications {user: tx-sender, experiment-id: experiment-id})) ERR-ALREADY-REPLICATED)
    (asserts! (and (>= rating u1) (<= rating u10)) ERR-INVALID-RATING)
    (map-set replications
      replication-id
      {
        experiment-id: experiment-id,
        replicator: tx-sender,
        results: results,
        success: success,
        rating: rating,
        created-at: stacks-block-height,
        verified: false
      }
    )
    (map-set user-replications {user: tx-sender, experiment-id: experiment-id} replication-id)
    (map-set experiments
      experiment-id
      (merge experiment {
        total-replications: (+ (get total-replications experiment) u1),
        successful-replications: (if success (+ (get successful-replications experiment) u1) (get successful-replications experiment))
      })
    )
    (map-set user-reputation
      tx-sender
      {
        total-replications: (+ (get total-replications user-rep) u1),
        successful-replications: (if success (+ (get successful-replications user-rep) u1) (get successful-replications user-rep)),
        reputation-score: (+ (get reputation-score user-rep) rating)
      }
    )
    (var-set next-replication-id (+ replication-id u1))
    (ok replication-id)
  )
)

(define-public (mint-reproducibility-nft (experiment-id uint))
  (let (
    (experiment (unwrap! (map-get? experiments experiment-id) ERR-NOT-FOUND))
    (token-id (var-get next-token-id))
  )
    (asserts! (is-eq tx-sender (get creator experiment)) ERR-OWNER-ONLY)
    (asserts! (>= (get successful-replications experiment) (var-get min-successful-replications)) ERR-INSUFFICIENT-REPLICATIONS)
    (asserts! (not (get nft-minted experiment)) ERR-ALREADY-EXISTS)
    (try! (nft-mint? reproducibility-nft token-id tx-sender))
    (map-set nft-metadata
      token-id
      {
        experiment-id: experiment-id,
        title: (get title experiment),
        creator: tx-sender,
        successful-replications: (get successful-replications experiment),
        minted-at: stacks-block-height
      }
    )
    (map-set experiments
      experiment-id
      (merge experiment {nft-minted: true})
    )
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

(define-public (verify-replication (replication-id uint))
  (let ((replication (unwrap! (map-get? replications replication-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set replications
      replication-id
      (merge replication {verified: true})
    )
    (ok true)
  )
)

(define-public (set-min-replications (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set min-successful-replications new-min)
    (ok true)
  )
)

(define-read-only (get-experiment (experiment-id uint))
  (map-get? experiments experiment-id)
)

(define-read-only (get-replication (replication-id uint))
  (map-get? replications replication-id)
)

(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation user)
)

(define-read-only (get-nft-metadata (token-id uint))
  (map-get? nft-metadata token-id)
)

(define-read-only (get-user-replication (user principal) (experiment-id uint))
  (map-get? user-replications {user: user, experiment-id: experiment-id})
)

(define-read-only (get-next-experiment-id)
  (var-get next-experiment-id)
)

(define-read-only (get-next-replication-id)
  (var-get next-replication-id)
)

(define-read-only (get-min-replications)
  (var-get min-successful-replications)
) 
