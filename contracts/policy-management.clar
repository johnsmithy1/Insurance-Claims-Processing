;; Policy Management Contract
;; Handles insurance policy creation, updates, and retrieval

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_POLICY_EXISTS u2)
(define-constant ERR_POLICY_NOT_FOUND u3)
(define-constant ERR_INVALID_PARAMS u4)

;; Data structures
(define-map policies
  { policy-id: (string-ascii 36) }
  {
    owner: principal,
    coverage-amount: uint,
    premium: uint,
    start-block: uint,
    end-block: uint,
    coverage-type: (string-ascii 20),
    active: bool
  }
)

(define-map policy-owners
  { owner: principal }
  { policy-count: uint }
)

;; Public functions
(define-public (create-policy
    (policy-id (string-ascii 36))
    (coverage-amount uint)
    (premium uint)
    (duration uint)
    (coverage-type (string-ascii 20)))
  (let
    (
      (caller tx-sender)
      (current-block block-height)
      (end-block (+ block-height duration))
    )
    (asserts! (> coverage-amount u0) (err ERR_INVALID_PARAMS))
    (asserts! (> premium u0) (err ERR_INVALID_PARAMS))
    (asserts! (> duration u0) (err ERR_INVALID_PARAMS))

    ;; Check if policy already exists
    (asserts! (is-none (map-get? policies { policy-id: policy-id })) (err ERR_POLICY_EXISTS))

    ;; Create the policy
    (map-set policies
      { policy-id: policy-id }
      {
        owner: caller,
        coverage-amount: coverage-amount,
        premium: premium,
        start-block: current-block,
        end-block: end-block,
        coverage-type: coverage-type,
        active: true
      }
    )

    ;; Update owner's policy count
    (match (map-get? policy-owners { owner: caller })
      existing-data (map-set policy-owners
                      { owner: caller }
                      { policy-count: (+ u1 (get policy-count existing-data)) })
      (map-set policy-owners { owner: caller } { policy-count: u1 })
    )

    (ok policy-id)
  )
)

(define-public (cancel-policy (policy-id (string-ascii 36)))
  (let
    ((caller tx-sender))

    (match (map-get? policies { policy-id: policy-id })
      policy (begin
        ;; Check if caller is the policy owner
        (asserts! (is-eq caller (get owner policy)) (err ERR_UNAUTHORIZED))

        ;; Update policy to inactive
        (map-set policies
          { policy-id: policy-id }
          (merge policy { active: false })
        )

        (ok true)
      )
      (err ERR_POLICY_NOT_FOUND)
    )
  )
)

(define-read-only (get-policy (policy-id (string-ascii 36)))
  (match (map-get? policies { policy-id: policy-id })
    policy (ok policy)
    (err ERR_POLICY_NOT_FOUND)
  )
)

(define-read-only (is-policy-active (policy-id (string-ascii 36)))
  (match (map-get? policies { policy-id: policy-id })
    policy (ok (and
                (get active policy)
                (<= (get start-block policy) block-height)
                (>= (get end-block policy) block-height)))
    (err ERR_POLICY_NOT_FOUND)
  )
)

(define-read-only (get-owner-policy-count (owner principal))
  (match (map-get? policy-owners { owner: owner })
    data (ok (get policy-count data))
    (ok u0)
  )
)
