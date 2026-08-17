; Fixed mutable state shared by the resident console and its mode-3 helper.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.

RCOP            equ     JROMSTATEBASE+020h
RCADDR          equ     RCOP+1
RCMASK          equ     RCOP+3
RCROWS          equ     RCOP+5
RCPIXELS        equ     RCOP+6          ; sixteen prepared bytes, two per row

RCCOL           equ     RCOP+022
RCROW           equ     RCOP+023
RCESC           equ     RCOP+024
RCOUTCHAR       equ     RCOP+025
RCSHIFT         equ     RCOP+026
RCCURVISIBLE    equ     RCOP+027
RCCURCOUNT      equ     RCOP+028
RCWORK          equ     RCOP+030
.ifdef ROM_ABI_LOCALE
RCFONTROWS      equ     RCOP+032
RCVIDMODE       equ     RCOP+02bh
RCCOLS          equ     RCOP+02ch
RCTEXTROWS      equ     RCOP+02dh
RCCELLWIDTH     equ     RCOP+02eh
RCCELLHEIGHT    equ     RCOP+02fh
RCCELLMASK      equ     RCOP+030h
RCVIDSTEP       equ     RCOP+031h        ; byte stride minus one for helper
RCROWBYTES      equ     RCOP+032h
RCCURSORLINE    equ     RCOP+034h
RCSCROLLBYTES   equ     RCOP+036h
RCSCROLLSOURCE  equ     RCOP+038h
.endif

RCOPCLEAR       equ     0
RCOPSCROLL      equ     1
RCOPDRAW        equ     2
