;;; qrencode-tests.el --- Tests for qrencode.el

;; Copyright (C) 2021 Rüdiger Sonderfeld

;; Author: Rüdiger Sonderfeld <ruediger@c-plusplus.de>

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Tests for qrencode.el

;;; Code:

(require 'ert)
(require 'qrencode)

;;; Error correction code tests
;; Based on https://research.swtch.com/field

(ert-deftest qrencode-field-test ()
  (pcase-let* ((field (qrencode--init-field #x11d 2))
               (`(,log ,exp) field))
    (dotimes (i 255)
      (should (= (aref log (aref exp i)) i))
      (should (= (aref log (aref exp (+ i 255))) i))
      (should (= (aref exp (aref log (1+ i))) (1+ i))))
    (should (= (qrencode--field-exp field 0) 1))
    (should (= (qrencode--field-exp field 1) 2))))

(ert-deftest qrencode-ecc-test ()
  (let ((data [#x10 #x20 #x0c #x56 #x61 #x80 #xec #x11 #xec #x11 #xec #x11 #xec #x11 #xec #x11])
        (check [#xa5 #x24 #xd4 #xc1 #xed #x36 #xc7 #x87 #x2c #x55]))
    (should (equal (qrencode--ecc data (length check)) check))))

(ert-deftest qrencode-ecc-linear-test ()
  (let ((field (qrencode--init-field #x11d 2)))
    
    (should (equal (qrencode--ecc [#x00 #x00] 2 field) [#x00 #x00]))

    (let* ((c1 (qrencode--ecc [#x00 #x01] 2 field))
           (c2 (qrencode--ecc [#x00 #x02] 2 field))
           (cx (cl-loop for i across c1 for j across c2 vconcat (vector (logxor i j))))
           (c4 (qrencode--ecc [#x00 #x03] 2 field)))
      (should (equal c4 cx)))))

;;; Util

(ert-deftest qrencode-size-test ()
  (should (= (qrencode--size 1) 21))
  (should (= (qrencode--size 2) 25))
  (should (= (qrencode--size 6) 41))
  (should (= (qrencode--size 7) 45))
  (should (= (qrencode--size 14) 73))
  (should (= (qrencode--size 21) 101))
  (should (= (qrencode--size 40) 177)))

;;; Data encoding
(ert-deftest qrencode-mode-test ()
  (should (= (qrencode--mode 'byte) 4)))

(ert-deftest qrencode-encode-byte-test ()
  (should (equal (qrencode--encode-byte "hello") [#x40 #x56 #x86 #x56 #xc6 #xc6])))

(ert-deftest qrencode-encode-aa-test ()
  (let ((s (qrencode--square 5)))
    (dotimes (r 5)
      (dotimes (c 5)
        (should (= (qrencode--aaref s c r) 0))))
    (qrencode--aaset s 2 1 1)
    (should (= (qrencode--aaref s 2 1) 1))
    ;; Check that nothing else was changed
    (dotimes (r 5)
      (dotimes (c 5)
        (unless (and (equal (cons c r) '(2 . 1)))
          (should (= (qrencode--aaref s c r) 0)))))

    (qrencode--copy-square s [[2]] 1 2)
    (should (= (qrencode--aaref s 2 1) 2))
    (qrencode--copy-square s [[3 3] [3 3]] 1 1)
    (should (= (qrencode--aaref s 1 1) 3))
    (should (= (qrencode--aaref s 2 1) 3))
    (should (= (qrencode--aaref s 1 2) 3))
    (should (= (qrencode--aaref s 2 2) 3))

    (qrencode--set-rect s 2 2 2 2 4)
    (should (= (qrencode--aaref s 2 2) 4))
    (should (= (qrencode--aaref s 3 2) 4))
    (should (= (qrencode--aaref s 2 3) 4))
    (should (= (qrencode--aaref s 3 3) 4))))

(ert-deftest qrencode-template-test ()
  (pcase-let ((`(,qr . ,fp) (qrencode--template  1)))  ; TODO: Maybe test a version with alignment pattern
    (should (equal qr [[1 1 1 1 1 1 1 0 0 0 0 0 0 0 1 1 1 1 1 1 1]
                       [1 0 0 0 0 0 1 0 0 0 0 0 0 0 1 0 0 0 0 0 1]
                       [1 0 1 1 1 0 1 0 0 0 0 0 0 0 1 0 1 1 1 0 1]
                       [1 0 1 1 1 0 1 0 0 0 0 0 0 0 1 0 1 1 1 0 1]
                       [1 0 1 1 1 0 1 0 0 0 0 0 0 0 1 0 1 1 1 0 1]
                       [1 0 0 0 0 0 1 0 0 0 0 0 0 0 1 0 0 0 0 0 1]
                       [1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1]
                       [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 0 1 1 1 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 0 1 1 1 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 0 1 1 1 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]]))
    (should (equal fp [[1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 1 1 1 1 1 1 1 1]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
                       [1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]]))))


;; TODO: Test qrencode--draw-data

;;; Data masking
(ert-deftest qrencode-penalty-test ()
  ;; Exactly five same colour should not incur penalty
  (should (< (qrencode--penalty [[1 1 1 1 1 0]
                                 [0 1 0 1 0 1]
                                 [1 0 1 0 1 0]
                                 [0 1 0 1 0 1]
                                 [1 0 1 0 1 0]
                                 [0 1 0 1 0 1]])
             3))
  ;; Six of same colour should incurs penalty
  (should (>= (qrencode--penalty [[1 1 1 1 1 1]
                                  [0 1 0 1 0 1]
                                  [1 0 1 0 1 0]
                                  [0 1 0 1 0 1]
                                  [1 0 1 0 1 0]
                                  [0 1 0 1 0 1]])
              3)))


(ert-deftest qrencode-masks-test ()
  (should (equal (qrencode--apply-mask (qrencode--square 10) (qrencode--square 10) 0)
                 [[1 0 1 0 1 0 1 0 1 0]
                  [0 1 0 1 0 1 0 1 0 1]
                  [1 0 1 0 1 0 1 0 1 0]
                  [0 1 0 1 0 1 0 1 0 1]
                  [1 0 1 0 1 0 1 0 1 0]
                  [0 1 0 1 0 1 0 1 0 1]
                  [1 0 1 0 1 0 1 0 1 0]
                  [0 1 0 1 0 1 0 1 0 1]
                  [1 0 1 0 1 0 1 0 1 0]
                  [0 1 0 1 0 1 0 1 0 1]]))
  (should (equal (qrencode--apply-mask (qrencode--square 10) (qrencode--square 10) 1)
                 [[1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]]))
  (should (equal (qrencode--apply-mask (qrencode--square 10) (qrencode--square 10) 1)
                 [[1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]
                  [1 1 1 1 1 1 1 1 1 1]
                  [0 0 0 0 0 0 0 0 0 0]]))
  ;; TODO: remaining masks
  )

;; TODO: test find-best-mask

;;; Version/Info encoding

(ert-deftest qrencode-bch-encode-test ()
  ;; Section 7.9.1. Err corr: M, Mask 5 (101) -> 0b100000011001110
  (should (= (qrencode--bch-encode #x5) #x40CE)))

;; TODO test: encode-info encode-version

;; Analyse data

;; QREncode: TODo

(provide 'qrencode-tests)
;;; qrencode-tests.el ends here