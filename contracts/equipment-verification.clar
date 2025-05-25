;; Equipment Verification Contract
;; Validates and manages industrial machinery registration and verification

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-equipment-not-found (err u101))
(define-constant err-equipment-already-exists (err u102))
(define-constant err-invalid-status (err u103))

;; Equipment status constants
(define-constant status-pending u0)
(define-constant status-verified u1)
(define-constant status-rejected u2)
(define-constant status-maintenance u3)

;; Equipment data structure
(define-map equipment
  { equipment-id: (string-ascii 64) }
  {
    manufacturer: (string-ascii 128),
    model: (string-ascii 128),
    serial-number: (string-ascii 64),
    installation-date: uint,
    verification-status: uint,
    last-inspection: uint,
    operator: principal
  }
)

;; Equipment verification history
(define-map verification-history
  { equipment-id: (string-ascii 64), timestamp: uint }
  {
    verifier: principal,
    status: uint,
    notes: (string-ascii 256)
  }
)

;; Register new equipment
(define-public (register-equipment
  (equipment-id (string-ascii 64))
  (manufacturer (string-ascii 128))
  (model (string-ascii 128))
  (serial-number (string-ascii 64))
  (operator principal))
  (begin
    (asserts! (is-none (map-get? equipment { equipment-id: equipment-id })) err-equipment-already-exists)
    (map-set equipment
      { equipment-id: equipment-id }
      {
        manufacturer: manufacturer,
        model: model,
        serial-number: serial-number,
        installation-date: block-height,
        verification-status: status-pending,
        last-inspection: block-height,
        operator: operator
      }
    )
    (ok equipment-id)
  )
)

;; Verify equipment (owner only)
(define-public (verify-equipment
  (equipment-id (string-ascii 64))
  (status uint)
  (notes (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= status u3) err-invalid-status)
    (match (map-get? equipment { equipment-id: equipment-id })
      equipment-data
      (begin
        (map-set equipment
          { equipment-id: equipment-id }
          (merge equipment-data { verification-status: status, last-inspection: block-height })
        )
        (map-set verification-history
          { equipment-id: equipment-id, timestamp: block-height }
          {
            verifier: tx-sender,
            status: status,
            notes: notes
          }
        )
        (ok true)
      )
      err-equipment-not-found
    )
  )
)

;; Get equipment details
(define-read-only (get-equipment (equipment-id (string-ascii 64)))
  (map-get? equipment { equipment-id: equipment-id })
)

;; Check if equipment is verified
(define-read-only (is-equipment-verified (equipment-id (string-ascii 64)))
  (match (map-get? equipment { equipment-id: equipment-id })
    equipment-data
    (is-eq (get verification-status equipment-data) status-verified)
    false
  )
)

;; Get verification history
(define-read-only (get-verification-history (equipment-id (string-ascii 64)) (timestamp uint))
  (map-get? verification-history { equipment-id: equipment-id, timestamp: timestamp })
)
