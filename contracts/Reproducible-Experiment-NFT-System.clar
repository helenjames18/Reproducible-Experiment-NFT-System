(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-REPLICATION (err u103))
(define-constant ERR-INSUFFICIENT-REPLICATIONS (err u104))
(define-constant ERR-ALREADY-REPLICATED (err u105))
(define-constant ERR-INVALID-RATING (err u106))

(define-constant ERR-NOT-INVITED (err u108))
(define-constant ERR-INVITE-EXPIRED (err u109))
(define-constant ERR-ALREADY-INVITED (err u110))

(define-constant ERR-INSUFFICIENT-REPUTATION (err u111))
(define-constant ERR-ALREADY-REVIEWED (err u112))
(define-constant ERR-CANNOT-REVIEW-OWN (err u113))
(define-constant MIN-REVIEWER-REPUTATION u50)

(define-data-var required-positive-reviews uint u2)

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

(define-map experiment-bounties
  uint
  {
    total-pool: uint,
    contributors-count: uint,
    rewards-distributed: uint
  }
)

(define-map bounty-contributors
  {experiment-id: uint, contributor: principal}
  uint
)

(define-public (contribute-bounty (experiment-id uint) (amount uint))
  (let (
    (experiment (unwrap! (map-get? experiments experiment-id) ERR-NOT-FOUND))
    (current-bounty (default-to {total-pool: u0, contributors-count: u0, rewards-distributed: u0} 
                               (map-get? experiment-bounties experiment-id)))
    (current-contribution (default-to u0 (map-get? bounty-contributors {experiment-id: experiment-id, contributor: tx-sender})))
  )
    (asserts! (> amount u0) (err u107))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set experiment-bounties
      experiment-id
      {
        total-pool: (+ (get total-pool current-bounty) amount),
        contributors-count: (if (is-eq current-contribution u0) 
                              (+ (get contributors-count current-bounty) u1) 
                              (get contributors-count current-bounty)),
        rewards-distributed: (get rewards-distributed current-bounty)
      }
    )
    (map-set bounty-contributors
      {experiment-id: experiment-id, contributor: tx-sender}
      (+ current-contribution amount)
    )
    (ok true)
  )
)

(define-private (distribute-bounty-reward (experiment-id uint) (replicator principal))
  (let (
    (bounty (map-get? experiment-bounties experiment-id))
    (experiment (unwrap! (map-get? experiments experiment-id) ERR-NOT-FOUND))
  )
    (match bounty
      some-bounty
      (let (
        (total-pool (get total-pool some-bounty))
        (successful-reps (get successful-replications experiment))
        (reward-amount (if (> successful-reps u0) (/ total-pool successful-reps) u0))
      )
        (if (and (> reward-amount u0) (> total-pool (get rewards-distributed some-bounty)))
          (begin
            (try! (as-contract (stx-transfer? reward-amount tx-sender replicator)))
            (map-set experiment-bounties
              experiment-id
              (merge some-bounty {rewards-distributed: (+ (get rewards-distributed some-bounty) reward-amount)})
            )
            (ok reward-amount)
          )
          (ok u0)
        )
      )
      (ok u0)
    )
  )
)

(define-read-only (get-experiment-bounty (experiment-id uint))
  (map-get? experiment-bounties experiment-id)
)

(define-read-only (get-user-bounty-contribution (experiment-id uint) (contributor principal))
  (map-get? bounty-contributors {experiment-id: experiment-id, contributor: contributor})
)

(define-map experiment-invitations
  {experiment-id: uint, invitee: principal}
  {
    inviter: principal,
    invited-at: uint,
    expires-at: uint,
    accepted: bool
  }
)

(define-map user-pending-invites
  principal
  (list 10 uint)
)

(define-public (invite-collaborator (experiment-id uint) (invitee principal) (duration-blocks uint))
  (let (
    (experiment (unwrap! (map-get? experiments experiment-id) ERR-NOT-FOUND))
    (invite-key {experiment-id: experiment-id, invitee: invitee})
    (current-height stacks-block-height)
    (expires-at (+ current-height duration-blocks))
  )
    (asserts! (is-eq tx-sender (get creator experiment)) ERR-OWNER-ONLY)
    (asserts! (is-none (map-get? experiment-invitations invite-key)) ERR-ALREADY-INVITED)
    (asserts! (> duration-blocks u0) ERR-INVALID-REPLICATION)
    (map-set experiment-invitations
      invite-key
      {
        inviter: tx-sender,
        invited-at: current-height,
        expires-at: expires-at,
        accepted: false
      }
    )
    (let ((current-invites (default-to (list) (map-get? user-pending-invites invitee))))
      (map-set user-pending-invites invitee (unwrap-panic (as-max-len? (append current-invites experiment-id) u10)))
    )
    (ok true)
  )
)

(define-public (accept-invitation (experiment-id uint))
  (let (
    (invite-key {experiment-id: experiment-id, invitee: tx-sender})
    (invitation (unwrap! (map-get? experiment-invitations invite-key) ERR-NOT-INVITED))
    (current-height stacks-block-height)
  )
    (asserts! (<= current-height (get expires-at invitation)) ERR-INVITE-EXPIRED)
    (asserts! (not (get accepted invitation)) ERR-ALREADY-EXISTS)
    (map-set experiment-invitations
      invite-key
      (merge invitation {accepted: true})
    )
    (ok true)
  )
)

(define-private (is-invited-collaborator (experiment-id uint) (user principal))
  (match (map-get? experiment-invitations {experiment-id: experiment-id, invitee: user})
    invitation (and (get accepted invitation) (<= stacks-block-height (get expires-at invitation)))
    false
  )
)

(define-read-only (get-invitation-status (experiment-id uint) (invitee principal))
  (map-get? experiment-invitations {experiment-id: experiment-id, invitee: invitee})
)

(define-read-only (get-user-invitations (user principal))
  (map-get? user-pending-invites user)
)

(define-map experiment-reviews
  {experiment-id: uint, reviewer: principal}
  {
    approved: bool,
    review-score: uint,
    feedback: (string-ascii 300),
    reviewed-at: uint
  }
)

(define-map experiment-review-summary
  uint
  {
    total-reviews: uint,
    positive-reviews: uint,
    average-score: uint,
    review-complete: bool
  }
)

(define-public (submit-peer-review 
  (experiment-id uint) 
  (approved bool) 
  (review-score uint) 
  (feedback (string-ascii 300)))
  (let (
    (experiment (unwrap! (map-get? experiments experiment-id) ERR-NOT-FOUND))
    (reviewer-rep (unwrap! (map-get? user-reputation tx-sender) ERR-INSUFFICIENT-REPUTATION))
    (review-key {experiment-id: experiment-id, reviewer: tx-sender})
    (current-summary (default-to 
      {total-reviews: u0, positive-reviews: u0, average-score: u0, review-complete: false}
      (map-get? experiment-review-summary experiment-id)))
  )
    (asserts! (not (is-eq tx-sender (get creator experiment))) ERR-CANNOT-REVIEW-OWN)
    (asserts! (>= (get reputation-score reviewer-rep) MIN-REVIEWER-REPUTATION) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (is-none (map-get? experiment-reviews review-key)) ERR-ALREADY-REVIEWED)
    (asserts! (and (>= review-score u1) (<= review-score u10)) ERR-INVALID-RATING)
    (map-set experiment-reviews
      review-key
      {
        approved: approved,
        review-score: review-score,
        feedback: feedback,
        reviewed-at: stacks-block-height
      }
    )
    (let (
      (new-total (+ (get total-reviews current-summary) u1))
      (new-positive (if approved (+ (get positive-reviews current-summary) u1) (get positive-reviews current-summary)))
      (new-avg (/ (+ (* (get average-score current-summary) (get total-reviews current-summary)) review-score) new-total))
      (is-complete (>= new-positive (var-get required-positive-reviews)))
    )
      (map-set experiment-review-summary
        experiment-id
        {
          total-reviews: new-total,
          positive-reviews: new-positive,
          average-score: new-avg,
          review-complete: is-complete
        }
      )
      (ok is-complete)
    )
  )
)

(define-read-only (get-experiment-review-summary (experiment-id uint))
  (map-get? experiment-review-summary experiment-id)
)

(define-read-only (get-peer-review (experiment-id uint) (reviewer principal))
  (map-get? experiment-reviews {experiment-id: experiment-id, reviewer: reviewer})
)

(define-read-only (is-experiment-peer-approved (experiment-id uint))
  (match (map-get? experiment-review-summary experiment-id)
    summary (get review-complete summary)
    false
  )
)