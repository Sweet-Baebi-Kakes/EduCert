;; EduCert - Digital Certificate Verification System
;; Allows educational institutions to issue and verify digital certificates

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Data structures
(define-map certificates
  { certificate-id: uint }
  {
    student-address: principal,
    institution: principal,
    course-name: (string-ascii 100),
    completion-date: uint,
    grade: (string-ascii 10),
    is-revoked: bool
  }
)

(define-map institutions
  { institution-address: principal }
  {
    name: (string-ascii 100),
    is-verified: bool,
    registration-date: uint
  }
)

(define-data-var next-certificate-id uint u1)

;; Input validation functions
(define-private (is-valid-name (name (string-ascii 100)))
  (> (len name) u0)
)

(define-private (is-valid-grade (grade (string-ascii 10)))
  (> (len grade) u0)
)

;; Additional input validation functions
(define-private (is-valid-principal (addr principal))
  (not (is-eq addr 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-certificate-id (cert-id uint))
  (and (> cert-id u0) (< cert-id (var-get next-certificate-id)))
)

;; Register an educational institution
(define-public (register-institution (name (string-ascii 100)))
  (begin
    ;; Validate input
    (asserts! (is-valid-name name) err-invalid-input)

    (let ((institution-data {
      name: name,
      is-verified: false,
      registration-date: block-height
    }))
      ;; Check if institution is already registered
      (asserts! (is-none (map-get? institutions { institution-address: tx-sender })) err-already-exists)
      (map-set institutions { institution-address: tx-sender } institution-data)
      (ok true)
    )
  )
)

;; Verify an institution (only contract owner)
(define-public (verify-institution (institution principal))
  (begin
    ;; Check if caller is contract owner
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Validate institution principal
    (asserts! (is-valid-principal institution) err-invalid-input)

    (match (map-get? institutions { institution-address: institution })
      institution-data
      (begin
        (map-set institutions 
          { institution-address: institution }
          (merge institution-data { is-verified: true })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Issue a certificate (only verified institutions)
(define-public (issue-certificate 
  (student principal)
  (course-name (string-ascii 100))
  (grade (string-ascii 10))
)
  (begin
    ;; Validate inputs
    (asserts! (is-valid-name course-name) err-invalid-input)
    (asserts! (is-valid-grade grade) err-invalid-input)
    (asserts! (is-valid-principal student) err-invalid-input)

    (let ((certificate-id (var-get next-certificate-id)))
      (match (map-get? institutions { institution-address: tx-sender })
        institution-data
        (if (get is-verified institution-data)
          (begin
            (map-set certificates
              { certificate-id: certificate-id }
              {
                student-address: student,
                institution: tx-sender,
                course-name: course-name,
                completion-date: block-height,
                grade: grade,
                is-revoked: false
              }
            )
            (var-set next-certificate-id (+ certificate-id u1))
            (ok certificate-id)
          )
          err-unauthorized
        )
        err-not-found
      )
    )
  )
)

;; Verify a certificate
(define-read-only (verify-certificate (certificate-id uint))
  (match (map-get? certificates { certificate-id: certificate-id })
    certificate-data
    (if (get is-revoked certificate-data)
      (ok none)
      (ok (some certificate-data))
    )
    err-not-found
  )
)

;; Revoke a certificate (only issuing institution)
(define-public (revoke-certificate (certificate-id uint))
  (begin
    ;; Validate certificate ID
    (asserts! (is-valid-certificate-id certificate-id) err-invalid-input)

    (match (map-get? certificates { certificate-id: certificate-id })
      certificate-data
      (begin
        ;; Check if caller is the issuing institution
        (asserts! (is-eq tx-sender (get institution certificate-data)) err-unauthorized)

        (map-set certificates
          { certificate-id: certificate-id }
          (merge certificate-data { is-revoked: true })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Get institution info
(define-read-only (get-institution (institution principal))
  (map-get? institutions { institution-address: institution })
)

;; Get certificate by ID
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates { certificate-id: certificate-id })
)

;; Get certificates by student
(define-read-only (get-student-certificates (student principal))
  ;; Note: This is a simplified version. In practice, you might want to maintain
  ;; a separate map or use events for efficient querying
  (ok "Use events or maintain separate mapping for efficient student certificate lookup")
)
