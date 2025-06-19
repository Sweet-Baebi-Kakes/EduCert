;; EduCert - Digital Certificate Verification System
;; Allows educational institutions to issue and verify digital certificates

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))

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

;; Register an educational institution
(define-public (register-institution (name (string-ascii 100)))
  (let ((institution-data {
    name: name,
    is-verified: false,
    registration-date: block-height
  }))
    (map-set institutions { institution-address: tx-sender } institution-data)
    (ok true)
  )
)

;; Verify an institution (only contract owner)
(define-public (verify-institution (institution principal))
  (if (is-eq tx-sender contract-owner)
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
    err-owner-only
  )
)

;; Issue a certificate (only verified institutions)
(define-public (issue-certificate 
  (student principal)
  (course-name (string-ascii 100))
  (grade (string-ascii 10))
)
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
  (match (map-get? certificates { certificate-id: certificate-id })
    certificate-data
    (if (is-eq tx-sender (get institution certificate-data))
      (begin
        (map-set certificates
          { certificate-id: certificate-id }
          (merge certificate-data { is-revoked: true })
        )
        (ok true)
      )
      err-unauthorized
    )
    err-not-found
  )
)

;; Get institution info
(define-read-only (get-institution (institution principal))
  (map-get? institutions { institution-address: institution })
)