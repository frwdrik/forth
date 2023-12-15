\ The purpose of this file is to run an echo client that can talk to a
\ server running on localhost:3005, for example started via
\
\  nc -l -p 3005

16 MK-BUFFER CONSTANT sockaddr_in

: FILL-sockaddr_in
  \ AF_INET 0            - family
  \ 3005                 - port      big-endian
  \ 127 0 0 0            - address   big-endian
  \ 0 0 0 0 0 0 0 0      - padding

  sockaddr_in
  \ little endian
  DUP AF_INET SWAP C!
  1+ DUP 0 SWAP C!

  \ big endian
  \ 3005 = 0x0BBD
  1+ DUP 0xB SWAP C!
  1+ DUP 0xBD SWAP C!

  \ big endian
  1+ DUP 127 SWAP C!
  1+ DUP 0 SWAP C!
  1+ DUP 0 SWAP C!
  1+ DUP 1 SWAP C!

  1+ 0 SWAP !
;

FILL-sockaddr_in

CREATE-SOCKET CONSTANT sock

sockaddr_in sock CONNECT

32 MK-BUFFER CONSTANT read_buf

: sock-test
  BEGIN
    32 read_buf sock SOCK-READ    ( bytes_read )
    DUP 0<
      IF ." Read error, exiting..." . CR EXIT
      THEN
    read_buf sock SOCK-WRITE DROP
  AGAIN
;

32 ALLOT CONSTANT ignore_sigaction
: SIG_IGN 1 ;
SIG_IGN ignore_sigaction !

: IGNORE-SIGPIPE
  \ SIGPIPE = 13
  \ rt_sigaction = 13
  8 0 ignore_sigaction 13 13 SYSCALL4
;

\ IGNORE-SIGPIPE . CR

sock-test
