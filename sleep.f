: NANO-SLEEP ( ns s -- ret )
  \ the nanosleep syscall takes in a `struct timespec *req`, which
  \ contains two longs, for second and nanosecond
  ( create space for two longs )
  SWAP
  16 CELLS ALLOT DUP ( s ns addr addr )
  -ROT               ( s addr ns addr )
  !                  ( s addr )
  DUP -ROT 8+ !      ( s addr addr -- addr s addr+8 -- addr)
  0 SWAP SYS_NANOSLEEP SYSCALL2
;

: MS-SLEEP ( ms -- ret )
  1000 /MOD         ( millisecond second )
  SWAP 1000000 /    ( second nanosecond )
  NANO-SLEEP
;

(
." sleeping..." CR
1500 MS-SLEEP .S
)
