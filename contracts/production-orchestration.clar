;; Production Orchestration Contract
;; Coordinates manufacturing processes and production orders

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-order-not-found (err u201))
(define-constant err-order-already-exists (err u202))
(define-constant err-invalid-status (err u203))
(define-constant err-unauthorized (err u204))

;; Production order status constants
(define-constant status-created u0)
(define-constant status-in-progress u1)
(define-constant status-completed u2)
(define-constant status-cancelled u3)

;; Production orders
(define-map production-orders
  { order-id: (string-ascii 64) }
  {
    product-type: (string-ascii 128),
    quantity: uint,
    priority: uint,
    created-by: principal,
    assigned-equipment: (string-ascii 64),
    status: uint,
    start-time: uint,
    estimated-completion: uint,
    actual-completion: uint
  }
)

;; Production steps
(define-map production-steps
  { order-id: (string-ascii 64), step-number: uint }
  {
    description: (string-ascii 256),
    equipment-required: (string-ascii 64),
    estimated-duration: uint,
    actual-duration: uint,
    status: uint,
    completed-by: principal
  }
)

;; Create production order
(define-public (create-production-order
  (order-id (string-ascii 64))
  (product-type (string-ascii 128))
  (quantity uint)
  (priority uint)
  (assigned-equipment (string-ascii 64))
  (estimated-completion uint))
  (begin
    (asserts! (is-none (map-get? production-orders { order-id: order-id })) err-order-already-exists)
    (map-set production-orders
      { order-id: order-id }
      {
        product-type: product-type,
        quantity: quantity,
        priority: priority,
        created-by: tx-sender,
        assigned-equipment: assigned-equipment,
        status: status-created,
        start-time: u0,
        estimated-completion: estimated-completion,
        actual-completion: u0
      }
    )
    (ok order-id)
  )
)

;; Start production order
(define-public (start-production-order (order-id (string-ascii 64)))
  (match (map-get? production-orders { order-id: order-id })
    order-data
    (begin
      (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get created-by order-data))) err-unauthorized)
      (map-set production-orders
        { order-id: order-id }
        (merge order-data {
          status: status-in-progress,
          start-time: block-height
        })
      )
      (ok true)
    )
    err-order-not-found
  )
)

;; Complete production order
(define-public (complete-production-order (order-id (string-ascii 64)))
  (match (map-get? production-orders { order-id: order-id })
    order-data
    (begin
      (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get created-by order-data))) err-unauthorized)
      (map-set production-orders
        { order-id: order-id }
        (merge order-data {
          status: status-completed,
          actual-completion: block-height
        })
      )
      (ok true)
    )
    err-order-not-found
  )
)

;; Add production step
(define-public (add-production-step
  (order-id (string-ascii 64))
  (step-number uint)
  (description (string-ascii 256))
  (equipment-required (string-ascii 64))
  (estimated-duration uint))
  (begin
    (asserts! (is-some (map-get? production-orders { order-id: order-id })) err-order-not-found)
    (map-set production-steps
      { order-id: order-id, step-number: step-number }
      {
        description: description,
        equipment-required: equipment-required,
        estimated-duration: estimated-duration,
        actual-duration: u0,
        status: status-created,
        completed-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Get production order
(define-read-only (get-production-order (order-id (string-ascii 64)))
  (map-get? production-orders { order-id: order-id })
)

;; Get production step
(define-read-only (get-production-step (order-id (string-ascii 64)) (step-number uint))
  (map-get? production-steps { order-id: order-id, step-number: step-number })
)
