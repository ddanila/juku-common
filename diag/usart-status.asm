; Non-destructive Intel 8251 status diagnostic.
;
; The consumer defines DIAG_USART_CONTROL. Reading status does not acknowledge
; receive data or reset errors. A returns the PE/OE/FE error-bit mask (zero is
; success); Tx/Rx readiness is deliberately not a failure predicate because
; it depends on the current bounded half-duplex turn.

diag_usart_status_test:
        in      DIAG_USART_CONTROL
        ani     038h
        ret
