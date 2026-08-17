; Versioned ABI for the network-first Juku ROM.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; The resident ROM is visible only in memory mode 1 at D800h..FFFFh. CP/M
; calls the low-RAM gate instead of incidental implementation addresses.

JROMABIBASE     equ     0ff00h
JROMABIMAJOR    equ     1
.ifdef ROM_ABI_LOCALE
JROMABIMINOR    equ     1
.else
JROMABIMINOR    equ     0
.endif
JROMABISIZE     equ     0100h

; Manifest at FF00h. The first eight bytes are "JUKUABI",00h.
JROMMAJOR       equ     JROMABIBASE+8
JROMMINOR       equ     JROMABIBASE+9
JROMTABLELO     equ     JROMABIBASE+10
JROMTABLEHI     equ     JROMABIBASE+11
JROMFEATURELO   equ     JROMABIBASE+12
JROMFEATUREHI   equ     JROMABIBASE+13
JROMBUILD       equ     JROMABIBASE+14     ; pointer to NUL build identity
JROMWORKBYTES   equ     JROMABIBASE+16     ; required mutable workspace
JROMHELPBYTES   equ     JROMABIBASE+18     ; copied mode-3 helper bytes
JROMMANIFESTEND equ     JROMABIBASE+32

; Feature bits returned in DE by GETINFO and stored little-endian above.
JROMFCONSOLE    equ     0001h
JROMFKEYBOARD   equ     0002h
JROMFSERIAL     equ     0004h
JROMFNETDISK    equ     0008h
JROMFSOUND      equ     0010h
JROMFDIAG       equ     0020h
JROMFNETCON     equ     0040h
JROMFLOCALE     equ     0080h
JROMFKEYREMAP   equ     0100h

; Fixed three-byte JMP vectors. ABI minor versions may append behavior but
; must never move or change an existing vector's calling convention.
JROMINIT        equ     JROMABIBASE+020h
JROMCONINIT     equ     JROMABIBASE+023h
JROMCONSTAT     equ     JROMABIBASE+026h
JROMCONIN       equ     JROMABIBASE+029h
JROMCONOUT      equ     JROMABIBASE+02ch
JROMSERINIT     equ     JROMABIBASE+02fh
JROMSERRX       equ     JROMABIBASE+032h
JROMSERTX       equ     JROMABIBASE+035h
JROMNETDISK     equ     JROMABIBASE+038h
JROMKEYINIT     equ     JROMABIBASE+03bh
JROMKEYSCAN     equ     JROMABIBASE+03eh
JROMSOUND       equ     JROMABIBASE+041h
JROMDIAG        equ     JROMABIBASE+044h
JROMGETINFO     equ     JROMABIBASE+047h
.ifdef ROM_ABI_LOCALE
JROMCONFIG      equ     JROMABIBASE+04ah
JROMKEYREMAP    equ     JROMABIBASE+04dh
.endif

; JCGNETDISK request v1 (10 bytes at caller-owned low RAM).
JROMNETREQBYTES equ     10
JROMNETREQVER   equ     0
JROMNETREQOP    equ     1
JROMNETREQDRIVE equ     2
JROMNETREQTRACK equ     3
JROMNETREQSECTOR equ    5
JROMNETREQDMA   equ     6
JROMNETREQCACHE equ     8
JROMNETOPREAD   equ     0
JROMNETOPINVALIDATE equ 1
JROMNETOPMODE   equ     2
JROMNETOPWRITE  equ     3

; Fixed low-RAM ownership. The first implementation reserves 512 bytes.
JROMRAMBASE     equ     0d600h
JROMRAMEND      equ     0d800h
JROMGATEBASE    equ     0d620h
JROMHELPBASE    equ     0d700h
JROMSTATEBASE   equ     0d780h

; Fixed low-RAM gate vectors mirror the ROM order. Consumers can include the
; gate source or call these addresses from a separately linked BIOS.
JCGINITADDR     equ     JROMGATEBASE+000h
JCGCONINITADDR  equ     JROMGATEBASE+003h
JCGCONSTATADDR  equ     JROMGATEBASE+006h
JCGCONINADDR    equ     JROMGATEBASE+009h
JCGCONOUTADDR   equ     JROMGATEBASE+00ch
JCGSERINITADDR  equ     JROMGATEBASE+00fh
JCGSERRXADDR    equ     JROMGATEBASE+012h
JCGSERTXADDR    equ     JROMGATEBASE+015h
JCGNETDISKADDR  equ     JROMGATEBASE+018h
JCGKEYINITADDR  equ     JROMGATEBASE+01bh
JCGKEYSCANADDR  equ     JROMGATEBASE+01eh
JCGSOUNDADDR    equ     JROMGATEBASE+021h
JCGDIAGADDR     equ     JROMGATEBASE+024h
JCGGETINFOADDR  equ     JROMGATEBASE+027h
.ifdef ROM_ABI_LOCALE
JCGCONFIGADDR   equ     JROMGATEBASE+02ah
JCGKEYREMAPADDR equ     JROMGATEBASE+02dh
.endif
