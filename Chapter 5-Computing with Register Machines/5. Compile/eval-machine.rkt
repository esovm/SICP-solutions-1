(load "compiler.rkt")
(load "ev-operations.rkt")
(load "machine-model.rkt")

(define eceval
  (make-machine
   '(env proc val argl arg1 arg2 continue exp unev)
   eceval-operations
   '(
       (branch (label external-entry))         ; branches if flag is set
     read-eval-print-loop
       (perform (op initialize-stack))
       (perform
        (op prompt-for-input) (const ";;; EC-Eval input"))
       (assign exp (op read))
       (assign env (op get-global-environment))
       (assign continue (label print-result))
       (goto (label eval-dispatch))
     external-entry
       (perform (op initialize-stack))
       (assign env (op get-global-environment))
       (assign continue (label print-result))
       (goto (reg val))
     print-result
       (perform (op print-stack-statistics))
       (perform
        (op announce-output) (const ";;; EC-Eval value:"))
       (perform (op user-print) (reg val))
       (goto (label read-eval-print-loop))
     eval-dispatch
       (test (op self-evaluating?) (reg exp))
       (branch (label ev-self-eval))
       (test (op variable?) (reg exp))
       (branch (label ev-variable))
       (test (op quoted?) (reg exp))
       (branch (label ev-quoted))
       (test (op assignment?) (reg exp))
       (branch (label ev-assignment))
       (test (op definition?) (reg exp))
       (branch (label ev-definition))
       (test (op if?) (reg exp))
       (branch (label ev-if))
       (test (op cond?) (reg exp))
       (branch (label ev-cond))
       (test (op lambda?) (reg exp))
       (branch (label ev-lambda))
       (test (op let?) (reg exp))
       (branch (label ev-let))
       (test (op begin?) (reg exp))
       (branch (label ev-begin))
       (test (op application?) (reg exp))
       (branch (label ev-application))
       (goto (label unknown-expression-type))
       
     ev-self-eval
       (assign val (reg exp))
       (goto (reg continue))
       
     ev-variable
       (assign val (op lookup-variable-value) (reg exp) (reg env))
       ;(test (op unbound-var?) (reg val))
       ;(branch (label ev-unbound-variable))
       ;(assign val (op extract-value) (reg val))
       (goto (reg continue))
     ev-unbound-variable
       (assign val (const undefined-variable-error))
       (goto (label signal-error))
       
     ev-quoted
       (assign val (op text-of-quotation) (reg exp))
       (goto (reg continue))
       
     ev-lambda
       (assign unev (op lambda-parameters) (reg exp))
       (assign exp (op lambda-body) (reg exp))
       (assign val (op make-procedure)
               (reg unev) (reg exp) (reg env))
       (goto (reg continue))
       
     ev-application
       (save continue)
       (assign unev (op operands) (reg exp))
       (assign exp (op operator) (reg exp))
       (test (op symbol?) (reg exp))
       (branch (label ev-appl-symbol-operator))
       (save env)
       (save unev)
       (assign continue (label ev-appl-did-operator))
       (goto (label eval-dispatch))
     ev-appl-symbol-operator
       (assign continue (label ev-appl-did-symbol-operator))
       (goto (label eval-dispatch))
     ev-appl-did-operator
       (restore unev)               ; the operands
       (restore env)
     ev-appl-did-symbol-operator
       (assign argl (op empty-arglist))
       (assign proc (reg val))      ; the operator
       (test (op no-operands?) (reg unev))
       (branch (label apply-dispatch))
       (save proc)     
     ev-appl-operand-loop
       (save argl)
       (assign exp (op first-operand) (reg unev))
       (test (op last-operand?) (reg unev))
       (branch (label ev-appl-last-arg))
       (save env)
       (save unev)
       (assign continue (label ev-appl-accumulate-arg))
       (goto (label eval-dispatch))
     ev-appl-accumulate-arg
       (restore unev)
       (restore env)
       (restore argl)
       (assign argl (op adjoin-arg) (reg val) (reg argl))
       (assign unev (op rest-operands) (reg unev))
       (goto (label ev-appl-operand-loop))
     ev-appl-last-arg
       (assign continue (label ev-appl-accum-last-arg))
       (goto (label eval-dispatch))
     ev-appl-accum-last-arg
       (restore argl)
       (assign argl (op adjoin-arg) (reg val) (reg argl))
       (restore proc)
       (goto (label apply-dispatch))
     ev-appl-with-quoted-args
       (assign argl (reg unev))
       
     apply-dispatch
       (test (op primitive-procedure?) (reg proc))
       (branch (label primitive-apply))
       (test (op compound-procedure?) (reg proc))
       (branch (label compound-apply))
       (test (op compiled-procedure?) (reg proc))
       (branch (label compiled-apply))
       (goto (label unknown-procedure-type))
     primitive-apply
       (assign val (op apply-primitive-procedure)
                   (reg proc)
                   (reg argl))
       ;(test (op not-pair?) (reg val))
       ;(branch (label apply-arg-not-pair))
       ;(test (op arg-is-not-number?) (reg val))
       ;(branch (label apply-arg-not-number))
       ;(test (op division-by-zero?) (reg val))
       ;(branch (label apply-div-by-zero))
       ;(test (op at-least-one-arg?) (reg val))
       ;(branch (label apply-one-arg))
       ;(test (op at-least-two-args?) (reg val))
       ;(branch (label apply-two-arg))
       ;(test (op too-many-arguments?) (reg val))
       ;(branch (label apply-too-many-arguments))
       ;(test (op too-few-arguments?) (reg val))
       ;(branch (label apply-too-few-arguments))
       ;(test (op number-of-args-not-match?) (reg val))
       ;(branch (label apply-number-of-args-not-match))
       ;(assign val (op extract-value) (reg val))
       (restore continue)
       (goto (reg continue))
     compound-apply
       (assign unev (op procedure-parameters) (reg proc))
       (assign env (op procedure-environment) (reg proc))
       (assign env (op extend-environment)
                   (reg unev) (reg argl) (reg env))
       (assign unev (op procedure-body) (reg proc))
       (goto (label ev-sequence))
     compiled-apply
       (restore continue)
       (assign val (op compiled-procedure-entry) (reg proc))
       (goto (reg val))
       
;     apply-arg-not-pair
;       (assign val (const non-pair-argument-error))
;       (goto (label signal-error))
;     apply-arg-not-number
;       (assign val (const non-number-argument-error))
;       (goto (label signal-error))
;     apply-div-by-zero
;       (assign val (const division-by-zero-error))
;       (goto (label signal-error))
;     apply-one-arg
;       (assign val (const at-least-one-argument-error))
;       (goto (label signal-error))
;     apply-two-arg
;       (assign val (const at-least-two-argument-error))
;       (goto (label signal-error))
;     apply-too-many-arguments
;       (assign val (const too-many-arguments-error))
;       (goto (label signal-error))
;     apply-too-few-arguments
;       (assign val (const too-few-arguments-error))
;       (goto (label signal-error))
;     apply-number-of-args-not-match
;       (assign val (const number-of-args-not-match-error))
;       (goto (label signal-error))
       
     ev-begin
       (assign unev (op begin-actions) (reg exp))
       (save continue)
       (goto (label ev-sequence))
       
     ev-sequence
       (assign exp (op first-exp) (reg unev))
       (test (op last-exp?) (reg unev))
       (branch (label ev-sequence-last-exp))
       (save unev)
       (save env)
       (assign continue (label ev-sequence-continue))
       (goto (label eval-dispatch))
     ev-sequence-continue
       (restore env)
       (restore unev)
       (assign unev (op rest-exps) (reg unev))
       (goto (label ev-sequence))
     ev-sequence-last-exp
       (restore continue)
       (goto (label eval-dispatch))
       
     ev-if
       (save exp)
       (save env)
       (save continue)
       (assign continue (label ev-if-decide))
       (assign exp (op if-predicate) (reg exp))
       (goto (label eval-dispatch))
     ev-if-decide
       (restore continue)
       (restore env)
       (restore exp)
       (test (op true?) (reg val))
       (branch (label ev-if-consequent))
     ev-if-alternative
       (assign exp (op if-alternative) (reg exp))
       (goto (label eval-dispatch))
     ev-if-consequent
       (assign exp (op if-consequent) (reg exp))
       (goto (label eval-dispatch))
       
     ev-assignment
       (assign unev (op assignment-variable) (reg exp))
       (save unev)                    ; save variable for later
       (assign exp (op assignment-value) (reg exp))
       (save env)
       (save continue)
       (assign continue (label ev-assignment-1))
       (goto (label eval-dispatch))   ; evaluate the assignment value
     ev-assignment-1
       (restore continue)
       (restore env)
       (restore unev)
       ;(assign val
        ;(op set-variable-value!) (reg unev) (reg val) (reg env))
       ;(assign exp (reg unev))
       ;(test (op eq?) (reg val) (const unbound))
       ;(branch (label ev-unbound-variable))
       (perform (op set-variable-value!) (reg unev) (reg val) (reg env))
       (assign val (const ok))
       (goto (reg continue))
       
     ev-definition
       (assign unev (op definition-variable) (reg exp))
       (save unev)
       (assign exp (op definition-value) (reg exp))
       (save env)
       (save continue)
       (assign continue (label ev-definition-1))
       (goto (label eval-dispatch))   ; evaluate the definition value
     ev-definition-1
       (restore continue)
       (restore env)
       (restore unev)
       (perform
        (op define-variable!) (reg unev) (reg val) (reg env))
       (assign val (const ok))
       (goto (reg continue))
       
     ev-cond
       (assign unev (op cond-clauses) (reg exp))
       (save continue)                ; save the entry
     ev-clauses
       (test (op null?) (reg unev))
       (branch (label ev-cond-done))
       (assign exp (op first-clause) (reg unev))
       (test (op cond-else-clause?) (reg exp))
       (branch (label ev-cond-clause-actions))
       (save unev)
       (save env)
       (save exp)
       (assign exp (op cond-predicate) (reg exp))
       (assign continue (label ev-cond-decide))
       (goto (label eval-dispatch))
     ev-cond-decide
       (restore exp)
       (restore env)
       (restore unev)
       (test (op true?) (reg val))
       (branch (label ev-cond-clause-actions))
     ev-cond-alternative
       (assign unev (op rest-clauses) (reg unev))
       (goto (label ev-clauses))
     ev-cond-clause-actions
       (assign unev (op cond-actions) (reg exp))
       (goto (label ev-sequence))
     ev-cond-done
       (goto (reg continue))

     ev-let
       (save continue)
       (save env)
       (save exp)
       (assign unev (op let-vars) (reg exp))
       (assign exp (op let-body) (reg exp))
       (assign val (op make-procedure)              ; model the ev-lambda
                   (reg unev) (reg exp) (reg env))  ; the val is the proc
       (restore exp)
       (assign unev (op let-vals) (reg exp))        ; the operands
       (save unev)
       (goto (label ev-appl-did-operator))
       ; the rest is the same with ev-application

     unknown-expression-type
       (assign val (const unknown-expression-type-error))
       (goto (label signal-error))
     unknown-procedure-type
       (restore continue)
       (assign val (const unknown-procedure-type-error))
       (goto (label signal-error))

     signal-error
       (perform (op user-print) (reg val))
       ;(perform (op display) (const " -- "))
       ;(perform (op display) (reg exp))
       (goto (label read-eval-print-loop))
       
     )))

;(set-breakpoint eceval 'compiled-branch7 3)
;(trace-on eceval)
;(start eceval)

(define (start-eceval)
  (set-register-contents! eceval 'flag false)
  (start eceval))

(define (compile-and-go expression)
  (let ((instructions
         (assemble (statements
                    (compile expression 'val 'return '()))
                    eceval)))
    (set-register-contents! eceval 'val instructions)
    (set-register-contents! eceval 'flag true)
    (start eceval)))

;(start-eceval)
(compile-and-go '(define (f n)
                   (g (+ n 1))))