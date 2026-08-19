; Resident, selector-driven N4/host transport for JukuNet ABI 1.3.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; The including ROM defines ROMHOSTSTATEBASE, a 27-byte low-RAM block. The
; code owns Janet framing, bounded polling, duplicate-safe publication,
; capability/time buffers and reconnect state. CP/M retains only its calling
; conventions, SCB commit and local-console policy.

RHUSARTDATA     equ     008h
RHUSARTCTL      equ     009h
RHOP_POLL       equ     020h
RHOP_OUT        equ     021h
RHOP_TIME_GET   equ     022h
RHOP_TIME_SET   equ     023h
RHOP_STATUS     equ     024h
RHOP_DIAG       equ     025h
RHOP_CAPS       equ     026h
RHOP_BOOT       equ     027h
RHOP_BULK       equ     028h
RH_BULK_MAX     equ     32
RH_IDLE_POLLS   equ     1

RHEN            equ     ROMHOSTSTATEBASE
RHPRES          equ     ROMHOSTSTATEBASE+1
RHBACK          equ     ROMHOSTSTATEBASE+2
RHHAVE          equ     ROMHOSTSTATEBASE+3
RHKEY           equ     ROMHOSTSTATEBASE+4
RHSEQ           equ     ROMHOSTSTATEBASE+5
RHOP            equ     ROMHOSTSTATEBASE+6
RHARG           equ     ROMHOSTSTATEBASE+7
RHARG1          equ     ROMHOSTSTATEBASE+8
RHARG2          equ     ROMHOSTSTATEBASE+9
RHARG3          equ     ROMHOSTSTATEBASE+10
RHSTATUSBYTE    equ     ROMHOSTSTATEBASE+11
RHTBUF          equ     ROMHOSTSTATEBASE+12
RHCAPBUF        equ     ROMHOSTSTATEBASE+17
RHBLEN          equ     ROMHOSTSTATEBASE+21
RHBPTR          equ     ROMHOSTSTATEBASE+22
RHLASTFAIL      equ     ROMHOSTSTATEBASE+24
RHRECONNECT     equ     ROMHOSTSTATEBASE+25
RHINPUT         equ     ROMHOSTSTATEBASE+26
ROMHOSTSTATEBYTES equ   27

; C selects one of JROMHOST*. Unknown selectors return FFh/CY set.
rom_host_impl:
        sta     RHINPUT                 ; selector decode must preserve A input
        mov     a,c
        ora     a
        jz      rh_enable
        dcr     a
        jz      rh_config
        dcr     a
        jz      rh_status
        dcr     a
        jz      rh_input
        dcr     a
        jz      rh_output
        dcr     a
        jz      rh_time_get
        dcr     a
        jz      rh_time_set
        dcr     a
        jz      rh_publish_status
        dcr     a
        jz      rh_publish_diag
        dcr     a
        jz      rh_publish_boot
        dcr     a
        jz      rh_caps
        dcr     a
        jz      rh_bulk
        dcr     a
        jz      rh_state
rh_bad:
        mvi     a,0ffh
        stc
        ret

rh_enable:
        mvi     a,1
        sta     RHPRES
        sta     RHEN
        sta     RHBACK
        xra     a
        sta     RHHAVE
        sta     RHLASTFAIL
        sta     RHRECONNECT
        ret

; A is the explicit host feature byte. Bit 0 advertises N4 console support.
rh_config:
        lda     RHINPUT
        ani     1
        jnz     rh_enable
        sta     RHPRES
        sta     RHEN
        sta     RHHAVE
        sta     RHBACK
        ret

; Return FFh when a remote key is cached, otherwise zero. Preserve BC/DE/HL.
rh_status:
        push    b
        push    d
        push    h
        lda     RHHAVE
        ora     a
        jnz     rh_status_ret
        lda     RHPRES
        ora     a
        jz      rh_status_zero
        lda     RHEN
        ora     a
        jz      rh_status_disabled
        lda     RHBACK
        dcr     a
        sta     RHBACK
        jnz     rh_status_zero
        mvi     a,RH_IDLE_POLLS
        sta     RHBACK
        jmp     rh_status_poll
rh_status_disabled:
        lda     RHBACK
        dcr     a
        sta     RHBACK
        jnz     rh_status_zero
rh_status_poll:
        call    rh_clear_args
        mvi     a,RHOP_POLL
        call    rh_call
        lda     RHHAVE
        ora     a
        jnz     rh_status_ret
rh_status_zero:
        xra     a
rh_status_ret:
        pop     h
        pop     d
        pop     b
        ret

rh_input:
        lda     RHKEY
        push    psw
        xra     a
        sta     RHHAVE
        inr     a
        sta     RHBACK
        pop     psw
        ret

; A is one byte to mirror. Host loss is deliberately invisible to CONOUT.
rh_output:
        lda     RHINPUT
        sta     RHARG
        lda     RHEN
        ora     a
        jz      rh_output_done
        xra     a
        sta     RHARG1
        sta     RHARG2
        sta     RHARG3
        mvi     a,RHOP_OUT
        call    rh_call
rh_output_done:
        xra     a
        ret

; Return A=0 and HL -> five received clock bytes, or A=1 and HL=0000h.
rh_time_get:
        call    rh_clear_args
        mvi     a,RHOP_TIME_GET
        call    rh_call
        ora     a
        jnz     rh_pointer_fail
        lxi     h,RHTBUF
        ret

; HL points to four CP/M date/time bytes to publish as a session offset.
rh_time_set:
        lxi     d,RHARG
        mvi     b,4
rh_time_set_copy:
        mov     a,m
        stax    d
        inx     h
        inx     d
        dcr     b
        jnz     rh_time_set_copy
        mvi     a,RHOP_TIME_SET
        jmp     rh_call

rh_publish_status:
        mvi     c,RHOP_STATUS
        jmp     rh_publish
rh_publish_diag:
        mvi     c,RHOP_DIAG
        jmp     rh_publish
rh_publish_boot:
        mvi     c,RHOP_BOOT
; A/B/D/E are the four tuple bytes. Publication is bounded and best effort.
rh_publish:
        lda     RHINPUT
        sta     RHARG
        mov     a,b
        sta     RHARG1
        mov     a,d
        sta     RHARG2
        mov     a,e
        sta     RHARG3
        mov     a,c
        jmp     rh_call

rh_caps:
        call    rh_clear_args
        mvi     a,RHOP_CAPS
        call    rh_call
        ora     a
        jnz     rh_pointer_fail
        lxi     h,RHCAPBUF
        ret
rh_pointer_fail:
        lxi     h,0
        mvi     a,1
        ret

; HL points to 1..32 bytes and B is the length.
rh_bulk:
        mov     a,b
        ora     a
        jz      rh_bulk_bad
        cpi     RH_BULK_MAX+1
        jnc     rh_bulk_bad
        sta     RHBLEN
        shld    RHBPTR
        lda     RHEN
        ora     a
        jz      rh_bulk_ok
        mvi     a,RHOP_BULK
        sta     RHOP
        call    rh_begin
        lda     RHBLEN
        call    rh_send
        lhld    RHBPTR
        lda     RHBLEN
        mov     d,a
rh_bulk_send:
        mov     a,m
        call    rh_send
        inx     h
        dcr     d
        jnz     rh_bulk_send
        call    rh_finish
        ret
rh_bulk_ok:
        xra     a
        ret
rh_bulk_bad:
        mvi     a,1
        ret

; Return HL -> {last failure, reconnect count}.
rh_state:
        lxi     h,RHLASTFAIL
        xra     a
        ret

rh_clear_args:
        xra     a
        sta     RHARG
        sta     RHARG1
        sta     RHARG2
        sta     RHARG3
        ret

; A=operation. Return zero for a valid status 0/2 response.
rh_call:
        sta     RHOP
        call    rh_begin
        lda     RHARG
        call    rh_send
        lda     RHARG1
        call    rh_send
        lda     RHARG2
        call    rh_send
        lda     RHARG3
        call    rh_send
rh_finish:
        mov     a,b
        call    rh_tx
        lxi     d,128
rh_drain:
        dcx     d
        mov     a,d
        ora     e
        jnz     rh_drain
        mvi     a,034h
        out     RHUSARTCTL
        jmp     rh_sync

rh_begin:
        lda     RHSEQ
        inr     a
        sta     RHSEQ
        mvi     a,035h
        out     RHUSARTCTL
        mvi     b,0
        mvi     a,'J'
        call    rh_send
        mvi     a,'D'
        call    rh_send
        lda     RHOP
        call    rh_send
        lda     RHSEQ
        call    rh_send
        ret

rh_sync:
        call    rh_rx
        jc      rh_fail
        cpi     'D'
        jnz     rh_sync
        mvi     b,'D'
        call    rh_rx
        jc      rh_fail
        mov     c,a
        xra     b
        mov     b,a
        mov     a,c
        cpi     'J'
        jnz     rh_sync
        call    rh_rxc
        jc      rh_fail
        mov     c,a
        lda     RHSEQ
        cmp     c
        jnz     rh_fail
        call    rh_rxc
        jc      rh_fail
        sta     RHSTATUSBYTE
        lda     RHOP
        cpi     RHOP_TIME_GET
        jnz     rh_not_time
        lda     RHSTATUSBYTE
        ora     a
        jnz     rh_no_key
        lxi     h,RHTBUF
        mvi     d,5
rh_time_rx:
        call    rh_rxc
        jc      rh_fail
        mov     m,a
        inx     h
        dcr     d
        jnz     rh_time_rx
        jmp     rh_no_key
rh_not_time:
        cpi     RHOP_CAPS
        jnz     rh_not_caps
        lda     RHSTATUSBYTE
        ora     a
        jnz     rh_no_key
        lxi     h,RHCAPBUF
        mvi     d,4
rh_caps_rx:
        call    rh_rxc
        jc      rh_fail
        mov     m,a
        inx     h
        dcr     d
        jnz     rh_caps_rx
        jmp     rh_no_key
rh_not_caps:
        lda     RHSTATUSBYTE
        cpi     2
        jnz     rh_no_key
        call    rh_rxc
        jc      rh_fail
        sta     RHKEY
        mvi     a,0ffh
        sta     RHHAVE
rh_no_key:
        call    rh_rx
        jc      rh_fail
        cmp     b
        jnz     rh_fail
        lda     RHSTATUSBYTE
        ora     a
        jz      rh_success
        cpi     2
        jnz     rh_fail
rh_success:
        lda     RHEN
        ora     a
        jnz     rh_success_enable
        lda     RHLASTFAIL
        ora     a
        jz      rh_success_enable
        lda     RHRECONNECT
        inr     a
        jnz     rh_reconnect_store
        dcr     a
rh_reconnect_store:
        sta     RHRECONNECT
rh_success_enable:
        mvi     a,1
        sta     RHEN
        xra     a
        ret

rh_fail:
        xra     a
        sta     RHEN
        sta     RHHAVE
        sta     RHBACK
        inr     a
        sta     RHLASTFAIL
        mvi     a,1
        ret

rh_send:
        mov     c,a
        xra     b
        mov     b,a
        mov     a,c
rh_tx:
        mov     c,a
rh_tx_wait:
        in      RHUSARTCTL
        ani     1
        jz      rh_tx_wait
        mov     a,c
        out     RHUSARTDATA
        ret

rh_rx:
        push    b
        lxi     b,8192
rh_rx_wait:
        in      RHUSARTCTL
        ani     2
        jnz     rh_rx_ready
        dcx     b
        mov     a,b
        ora     c
        jnz     rh_rx_wait
        pop     b
        stc
        ret
rh_rx_ready:
        in      RHUSARTDATA
        pop     b
        ora     a
        ret
rh_rxc:
        call    rh_rx
        rc
        mov     c,a
        xra     b
        mov     b,a
        mov     a,c
        ora     a
        ret
