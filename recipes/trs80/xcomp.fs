0xf000 CONSTANT RS_ADDR
RS_ADDR 0x80 - CONSTANT RAMSTART
212 LOAD  ( z80 assembler )
262 LOAD  ( xcomp )
: CODE XCODE ;
: IMMEDIATE XIMM ;
: (entry) (xentry) ;
: : [ ' X: , ] ;

CURRENT @ XCURRENT !

H@ 256 /MOD 2 PC! 2 PC!
0x3000 BIN( !
282 LOAD  ( boot.z80 )
492 LOAD  ( trs80.z80 )
393 LOAD  ( icore )
(entry) _
( Update LATEST )
PC ORG @ 8 + !
," CURRENT @ HERE ! "
422 463 XPACKR ( core cmp print parse readln fmt )
," : _ RDLN$ (ok) ; _ "
H@ 256 /MOD 2 PC! 2 PC!
