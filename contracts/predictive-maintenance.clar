;; Predictive Maintenance Contract
;; Forecasts equipment service needs and schedules maintenance

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-equipment-not-found (err u401))
(define-constant err-maintenance-not-found (err u402))
(define-constant err-unauthorized (err u403))

;; Maintenance types
(define-constant maintenance-preventive u0)
(define-constant maintenance-corrective u1)
(define-constant maintenance-emergency u2)

;; Maintenance status
(define-constant status-scheduled u0)
(define-constant status-in-progress u1)
(define-constant status-completed u2)
(define-constant status-cancelled u3)

;; Equipment health tracking
(define-map equipment-health
  { equipment-id: (string-ascii 64) }
  {
    health-score: uint,
    operating-hours: uint,
    last-maintenance: uint,
    next-maintenance: uint,
    failure-probability: uint,
    maintenance-history-count: uint
  }
)

;; Maintenance schedules
(define-map maintenance-schedules
  { maintenance-id: (string-ascii 64) }
  {
    equipment-id: (string-ascii 64),
    maintenance-type: uint,
    scheduled-date: uint,
    estimated-duration: uint,
    assigned-technician: principal,
    status: uint,
    priority: uint,
    description: (string-ascii 256)
  }
)

;; Maintenance records
(define-map maintenance-records
  { equipment-id: (string-ascii 64), timestamp: uint }
  {
    maintenance-id: (string-ascii 64),
    technician: principal,
    duration: uint,
    parts-replaced: (string-ascii 256),
    notes: (string-ascii 512),
    cost: uint
  }
)

;; Initialize equipment health
(define-public (initialize-equipment-health
  (equipment-id (string-ascii 64))
  (initial-health-score uint))
  (begin
    (map-set equipment-health
      { equipment-id: equipment-id }
      {
        health-score: initial-health-score,
        operating-hours: u0,
        last-maintenance: block-height,
        next-maintenance: (+ block-height u1000), ;; Default 1000 blocks
        failure-probability: u0,
        maintenance-history-count: u0
      }
    )
    (ok equipment-id)
  )
)

;; Update equipment health
(define-public (update-equipment-health
  (equipment-id (string-ascii 64))
  (operating-hours uint)
  (health-score uint))
  (match (map-get? equipment-health { equipment-id: equipment-id })
    health-data
    (begin
      (let
        (
          (failure-prob (calculate-failure-probability operating-hours health-score))
          (next-maintenance (calculate-next-maintenance operating-hours health-score))
        )
        (map-set equipment-health
          { equipment-id: equipment-id }
          (merge health-data {
            health-score: health-score,
            operating-hours: operating-hours,
            failure-probability: failure-prob,
            next-maintenance: next-maintenance
          })
        )
        (ok true)
      )
    )
    err-equipment-not-found
  )
)

;; Schedule maintenance
(define-public (schedule-maintenance
  (maintenance-id (string-ascii 64))
  (equipment-id (string-ascii 64))
  (maintenance-type uint)
  (scheduled-date uint)
  (estimated-duration uint)
  (assigned-technician principal)
  (priority uint)
  (description (string-ascii 256)))
  (begin
    (map-set maintenance-schedules
      { maintenance-id: maintenance-id }
      {
        equipment-id: equipment-id,
        maintenance-type: maintenance-type,
        scheduled-date: scheduled-date,
        estimated-duration: estimated-duration,
        assigned-technician: assigned-technician,
        status: status-scheduled,
        priority: priority,
        description: description
      }
    )
    (ok maintenance-id)
  )
)

;; Complete maintenance
(define-public (complete-maintenance
  (maintenance-id (string-ascii 64))
  (duration uint)
  (parts-replaced (string-ascii 256))
  (notes (string-ascii 512))
  (cost uint))
  (match (map-get? maintenance-schedules { maintenance-id: maintenance-id })
    schedule-data
    (let
      (
        (equipment-id (get equipment-id schedule-data))
      )
      ;; Update maintenance schedule status
      (map-set maintenance-schedules
        { maintenance-id: maintenance-id }
        (merge schedule-data { status: status-completed })
      )
      ;; Record maintenance
      (map-set maintenance-records
        { equipment-id: equipment-id, timestamp: block-height }
        {
          maintenance-id: maintenance-id,
          technician: tx-sender,
          duration: duration,
          parts-replaced: parts-replaced,
          notes: notes,
          cost: cost
        }
      )
      ;; Update equipment health
      (match (map-get? equipment-health { equipment-id: equipment-id })
        health-data
        (map-set equipment-health
          { equipment-id: equipment-id }
          (merge health-data {
            last-maintenance: block-height,
            maintenance-history-count: (+ (get maintenance-history-count health-data) u1)
          })
        )
        false
      )
      (ok true)
    )
    err-maintenance-not-found
  )
)

;; Calculate failure probability (simplified)
(define-private (calculate-failure-probability (operating-hours uint) (health-score uint))
  (if (> operating-hours u10000)
    (- u100 health-score)
    (/ (- u100 health-score) u2)
  )
)

;; Calculate next maintenance (simplified)
(define-private (calculate-next-maintenance (operating-hours uint) (health-score uint))
  (+ block-height (* (/ health-score u10) u100))
)

;; Get equipment health
(define-read-only (get-equipment-health (equipment-id (string-ascii 64)))
  (map-get? equipment-health { equipment-id: equipment-id })
)

;; Get maintenance schedule
(define-read-only (get-maintenance-schedule (maintenance-id (string-ascii 64)))
  (map-get? maintenance-schedules { maintenance-id: maintenance-id })
)

;; Get maintenance record
(define-read-only (get-maintenance-record (equipment-id (string-ascii 64)) (timestamp uint))
  (map-get? maintenance-records { equipment-id: equipment-id, timestamp: timestamp })
)
