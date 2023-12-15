\ 32 MK-BUFFER CONSTANT buf
\ now buf points to the memory address of the buffer
\
\ What in C we'd write as
\   buf[n] = x
\ we will in forth write as
\ x n buf ASET


: MK-BUFFER ( byte_size -- addr )
  ( +1 cell for size header )
  DUP 8+         ( byte_size array_len )
  ALLOT          ( byte_size addr )
  DUP -ROT !     ( addr )
;

\ returns address of byte written to
: ASET ( x n buf -- buf+n )
  DUP C@            ( x n buf array_len )
  ROT TUCK          ( x buf n array_len n)
  <= IF
    2DROP DROP -1 EXIT
  ELSE
    8+ + TUCK C!         ( &buf[n] )
  THEN
;

: AF_INET 2 ;
: SOCK_STREAM 1 ;

: CREATE-SOCKET ( -- fd )
  \ This function performs the syscall:
  \   socket(int socket_family, int socket_type, int protocol)
  \
  \ socket_family is AF_INET
  \ socket_type is SOCK_STREAM
  \ protocol is 0
  0 SOCK_STREAM AF_INET SYS_SOCKET SYSCALL3
;

: CONNECT ( sockaddr sockfd -- )
  \ connect(fd, struct sockaddr *addr, socklen)
  \ struct sockaddr_in has total size 16 bytes
  \  - u16 sin_family
  \  - u16 port
  \  - u32 address
  \  - 8 byte padding
  \ socklen is u32, value is 16 (bytes)
  16 -ROT SYS_CONNECT SYSCALL3
  ?DUP 0<>
    IF ." error in connect(): " . CR
    ELSE ." success in connect()" CR
    THEN
;

: SOCK-READ ( buf_len buf sockfd -- bytes_read )
  SYS_READ SYSCALL3
  DUP ." read " . ." bytes" CR
;

: SOCK-WRITE ( buf_len buf sockfd -- bytes_written )
  SYS_WRITE SYSCALL3
  DUP 0<
    IF ." Write error: " . EXIT
    THEN
  DUP ." wrote " . ." bytes" CR
;
