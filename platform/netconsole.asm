; Optional remote CP/M console multiplexed over the resident Janet USART.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; N4 capability negotiation enables this module. Local screen and keyboard
; remain authoritative. Output is mirrored with one bounded transaction per
; character; status polls are rate-limited while idle. A missing/broken host
; disables mirroring and polling until a later status call reprobes it.

.ifndef NATIVE_SERVICES
NATIVE_SERVICES equ     0
.endif

        cseg
        public  NCENA
        public  NCSTAT
        public  NCIN
        public  NCOUT
if NATIVE_SERVICES
        public  NCTIME
        public  NCPUBLISH
        public  NCDIAG
        public  NCCAPS
endif

USARTDATA      equ     008h
USARTCTL       equ     009h
NC_POLL        equ     020h
NC_OUT         equ     021h
if NATIVE_SERVICES
NC_TIME_GET    equ     022h
NC_TIME_SET    equ     023h
NC_STATUS      equ     024h
NC_DIAG        equ     025h
NC_CAPS        equ     026h
; This native network-ROM profile fixes BIOS at BC00h. GENCPM relocates the
; SCB to BB9Ch, hence its canonical +58h clock field is runtime BBF4h.
SCBDATE        equ     0bbf4h
NCRECONNECT    equ     0c65ch
NCLASTFAIL     equ     0c65dh
endif
.ifdef NETCONSOLE_EAGER_POLL
NCIDLEPOLLS    equ     1
.else
NCIDLEPOLLS    equ     64
.endif

NCENA: mvi     a,1
        sta     NCPRES
        sta     NCEN
        sta     NCBACK         ; poll on the first remote status call
        xra     a
        sta     NCHAVE
if NATIVE_SERVICES
        sta     NCRECONNECT
        sta     NCLASTFAIL
endif
        ret

; Return FFh when a remote byte is cached, otherwise zero. Preserve BC/DE/HL.
NCSTAT:
        push    b
        push    d
        push    h
        lda     NCHAVE
        ora     a
        jnz     NCSTRET
        lda     NCPRES
        ora     a
        jz      NCSTZERO
        lda     NCEN
        ora     a
        jz      NCSTDISABLED
        lda     NCBACK
        dcr     a
        sta     NCBACK
        jnz     NCSTZERO
        mvi     a,NCIDLEPOLLS
        sta     NCBACK
        jmp     NCSTPOLL
NCSTDISABLED:
        lda     NCBACK
        dcr     a
        sta     NCBACK
        jnz     NCSTZERO
NCSTPOLL:
        xra     a
        sta     NCARG
        mvi     a,NC_POLL
        call    NCCALL
        lda     NCHAVE
        ora     a
        jnz     NCSTRET
NCSTZERO:
        xra     a
NCSTRET:
        pop     h
        pop     d
        pop     b
        ret

; Consume the cached remote byte. Caller first checks NCSTAT.
NCIN:  lda     NCKEY
        push    psw
        xra     a
        sta     NCHAVE
        inr     a
        sta     NCBACK         ; drain a remote command burst without idle delay
        pop     psw
        ret

; Mirror A when enabled. Host loss is deliberately invisible to CONOUT.
NCOUT: push    psw
        push    b
        push    d
        push    h
        sta     NCARG
        lda     NCEN
        ora     a
        jz      NCOUTDONE
        mvi     a,NC_OUT
        call    NCCALL
NCOUTDONE:
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

if NATIVE_SERVICES
; CP/M 3 TIME transport. C=00h fetches the host clock; C=FFh publishes the
; SCB date/hour/minute as a session-only host offset. Preserve HL and DE as
; required by the System Guide. A=0 succeeds; A=1 leaves the SCB unchanged.
NCTIME:
        push    h
        push    d
        mov     a,c
        ora     a
        jz      NCTIMEGET
        inr     a
        jnz     NCTIMEFAIL
        lda     SCBDATE
        sta     NCARG
        lda     SCBDATE+1
        sta     NCARG1
        lda     SCBDATE+2
        sta     NCARG2
        lda     SCBDATE+3
        sta     NCARG3
        mvi     a,NC_TIME_SET
        jmp     NCTIMECALL
NCTIMEGET:
        mvi     a,NC_TIME_GET
NCTIMECALL:
        call    NCCALL
        jmp     NCTIMERET
NCTIMEFAIL:
        mvi     a,1
NCTIMERET:
        pop     d
        pop     h
        ret

; Publish the same bounded configuration tuple shown by the target STATUS
; utility. A=raw S21, B=decoded video mode, D=feature flags, E=last clock
; status. This is best-effort observability: preserve every caller register
; and leave host loss to the existing NCCALL recovery path.
NCPUBLISH:
        push    b
        mvi     c,NC_STATUS
        jmp     NCPUBLISH1
; Publish a machine-readable diagnostic tuple. A=suite, B=pass mask,
; D=failure mask, E=flags. It shares the status publisher's bounded turn.
NCDIAG:
        push    b
        mvi     c,NC_DIAG
NCPUBLISH1:
        push    psw
        push    d
        push    h
        sta     NCARG
        mov     a,b
        sta     NCARG1
        mov     a,d
        sta     NCARG2
        mov     a,e
        sta     NCARG3
        mov     a,c
        call    NCCALL
        pop     h
        pop     d
        pop     psw
        pop     b
        ret

; Query explicit host capabilities. Return A=0 and HL -> four bytes
; (protocol, maximum read-ahead, feature flags, drive count), or A=1/HL=0.
; Unlike the startup N4 marker this is a request/reply contract and can be
; repeated after host replacement.
NCCAPS:
        mvi     a,NC_CAPS
        call    NCCALL
        ora     a
        jnz     NCCAPSFAIL
        lxi     h,NCCAPBUF
        ret
NCCAPSFAIL:
        lxi     h,0
        mvi     a,1
        ret
endif

; A=operation, NCARG=argument. Return zero for a valid status 0/2 response.
NCCALL:sta     NCOP
        lda     NCSEQ
        inr     a
        sta     NCSEQ
        mvi     a,035h
        out     USARTCTL       ; TxEN + RxE + error reset + RTS
        mvi     b,0
        mvi     a,'J'
        call    NCSEND
        mvi     a,'D'
        call    NCSEND
        lda     NCOP
        call    NCSEND
        lda     NCSEQ
        call    NCSEND
        lda     NCARG
        call    NCSEND
if NATIVE_SERVICES
        lda     NCARG1
        call    NCSEND
        lda     NCARG2
        call    NCSEND
        lda     NCARG3
.else
        xra     a
        call    NCSEND
        xra     a
        call    NCSEND
        xra     a
endif
        call    NCSEND
        mov     a,b
        call    NCTX

        ; Match the turnaround proven by NetDisk v3 on physical CS00015.
        ; The old 400-count delay kept Rx disabled past the host's 2 ms reply
        ; guard, so the leading reply byte could be lost at 19,200 baud.
        lxi     d,128
NCDRAIN:
        dcx     d
        mov     a,d
        ora     e
        jnz     NCDRAIN
        mvi     a,034h
        out     USARTCTL       ; release the half-duplex transmitter

NCSYNC:call    NCRX
        jc      NCFAIL
        cpi     'D'
        jnz     NCSYNC
        mvi     b,'D'
        call    NCRX
        jc      NCFAIL
        mov     c,a
        xra     b
        mov     b,a
        mov     a,c
        cpi     'J'
        jnz     NCSYNC
        call    NCRXC
        jc      NCFAIL
        mov     c,a
        lda     NCSEQ
        cmp     c
        jnz     NCFAIL
        call    NCRXC
        jc      NCFAIL
        sta     NCSTATUS
if NATIVE_SERVICES
        lda     NCOP
        cpi     NC_TIME_GET
        jnz     NCNOTTIME
        lda     NCSTATUS
        ora     a
        jnz     NCNOKEY
        lxi     h,NCTBUF
        mvi     d,5
NCTIMERX:
        call    NCRXC
        jc      NCFAIL
        mov     m,a
        inx     h
        dcr     d
        jnz     NCTIMERX
        jmp     NCNOKEY
NCNOTTIME:
        cpi     NC_CAPS
        jnz     NCNOTCAPS
        lda     NCSTATUS
        ora     a
        jnz     NCNOKEY
        lxi     h,NCCAPBUF
        mvi     d,4
NCCAPRX:
        call    NCRXC
        jc      NCFAIL
        mov     m,a
        inx     h
        dcr     d
        jnz     NCCAPRX
        jmp     NCNOKEY
NCNOTCAPS:
        lda     NCSTATUS
endif
        cpi     2
        jnz     NCNOKEY
        call    NCRXC
        jc      NCFAIL
        sta     NCKEY
        mvi     a,0ffh
        sta     NCHAVE
NCNOKEY:
        call    NCRX
        jc      NCFAIL
        cmp     b
        jnz     NCFAIL
        lda     NCSTATUS
        ora     a
        jz      NCSUCCESS
        cpi     2
        jnz     NCFAIL
NCSUCCESS:
if NATIVE_SERVICES
        lda     NCOP
        cpi     NC_TIME_GET
        jnz     NCSUCCESS1
        lxi     h,NCTBUF
        lxi     d,SCBDATE
        mvi     c,5
NCTIMECOMMIT:
        mov     a,m
        stax    d
        inx     h
        inx     d
        dcr     c
        jnz     NCTIMECOMMIT
NCSUCCESS1:
endif
if NATIVE_SERVICES
        lda     NCEN
        ora     a
        jnz     NCSUCCESS2
        lda     NCLASTFAIL
        ora     a
        jz      NCSUCCESS2
        lda     NCRECONNECT
        inr     a
        jnz     NCRECONNECTSTORE
        dcr     a                       ; saturate at FFh
NCRECONNECTSTORE:
        sta     NCRECONNECT
NCSUCCESS2:
endif
        mvi     a,1
        sta     NCEN
        xra     a
        ret

NCFAIL:xra     a
        sta     NCEN
        sta     NCHAVE
        sta     NCBACK         ; underflow gives 256 local CONST calls
if NATIVE_SERVICES
        inr     a
        sta     NCLASTFAIL     ; 01h: bounded N4 timeout/framing failure
endif
        mvi     a,1
        ret

NCSEND:mov     c,a
        xra     b
        mov     b,a
        mov     a,c
NCTX:  mov     c,a
NCTX1: in      USARTCTL
        ani     1
        jz      NCTX1
        mov     a,c
        out     USARTDATA
        ret

; Short console wait: roughly one eighth of the disk byte timeout.
NCRX:  push    b
        lxi     b,8192
NCRX1: in      USARTCTL
        ani     2
        jnz     NCRX2
        dcx     b
        mov     a,b
        ora     c
        jnz     NCRX1
        pop     b
        stc
        ret
NCRX2: in      USARTDATA
        pop     b
        ora     a
        ret
NCRXC:call    NCRX
        rc
        mov     c,a
        xra     b
        mov     b,a
        mov     a,c
        ora     a
        ret

NCEN:  db      0
NCPRES:db      0
NCBACK:db      0
NCHAVE:db      0
NCKEY: db      0
NCSEQ: db      0
NCOP:  db      0
NCARG: db      0
NCSTATUS:db    0
if NATIVE_SERVICES
NCARG1:db      0
NCARG2:db      0
NCARG3:db      0
NCTBUF:ds      5
NCCAPBUF:ds    4
endif
