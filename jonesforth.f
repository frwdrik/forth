\ / keeps just the quotient, left at top of stack by /mod
: / /MOD SWAP DROP ;
\ mod keeps just the remainder, left below top of stack by /mod
: MOD /MOD DROP ;
: '\n' 10 ;
: BL   32 ;
: CR '\n' EMIT ;
: SPACE BL EMIT ;

: NEGATE 0 SWAP - ;
: TRUE 1 ;

: FALSE 0 ;
: NOT 0= ;

: LITERAL IMMEDIATE
          ' LIT ,     \ compile LIT
          ,           \ compile the literal itself from stack
;

: ':'
  [
  CHAR :      \ puts the char ':' on stack
      ]
         LITERAL     \ compiles LIT,':'
;

: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;

\ [COMPILE] reads the next word, looks up its codeword, and adds it as
\ next word. Useful for treating immediates as non-immedites when
\ compiling.
: [COMPILE] IMMEDIATE
  WORD
  FIND
  >CFA
  ,
;

: RECURSE IMMEDIATE LATEST @ >CFA , ;


\ IF checks if top of stack is false/zero, and if so skips forward
\ until after the next THEN word.
: IF IMMEDIATE
  ' 0BRANCH ,  \ compile 0BRANCH
  HERE @       \ save location of the offset on the stack
  0 ,          \ compile a dummy offset
  ;

\ (offsetAddr)

\ THEN works by calculating offset from branch instruction, and
\ replacing the dummy offset by it
: THEN IMMEDIATE
  DUP                         \ (offsetAddr offsetAddr)
  HERE @ SWAP                 \ (offsetAddr HERE offsetAddr)
  -                           \ (offsetAddr HERE-offsetAddr)
  SWAP !                      \ M[offsetAddr] = HERE-offsetAddr
;

\ ELSE works by unconditionally jumping over the THEN-branch.
\ Example: 0 1 < IF ." looks good " ELSE ." not right! " THEN
\ ELSE compiles a jump over [." not right! "], THEN compiles a jump to right before it
: ELSE IMMEDIATE
  ' BRANCH ,
  HERE @           \ (offsetAddr HERE)
  0 ,              \ this will be filled in by next THEN
                   \      now backfill the IF-offset so it can jump past this point
  SWAP             \ (HERE offsetAddr)
  DUP              \ (HERE offsetAddr offsetAddr)
  HERE @ SWAP      \ (HERE offsetAddr HERE offsetAddr)
  -                \ (HERE offsetAddr HERE-offsetAddr)
  SWAP !           \ M[offsetAddr] = HERE-offsetAddr
  \ we leave HERE on the stack so that THEN can backfill it
;

\ : a IF 2 ELSE 3 THEN PT ;
\ true a => prints 2
\ false a => prints 3

\ BEGIN loop-part condition UNTIL
\   -- compiles to: --> loop-part condition 0BRANCH OFFSET
\   where OFFSET points back to loop-part
: BEGIN IMMEDIATE
  HERE @
;

\ if test is true, jump back
: UNTIL IMMEDIATE
  ' 0BRANCH ,
  HERE @ - ,   \ compile offset to jump back to loop-part
;

\ BEGIN loop-part AGAIN
\   -- infinite loop which can only be exited with EXIT
: AGAIN IMMEDIATE
  ' BRANCH ,
  HERE @ - ,
;

\ BEGIN condition WHILE loop-part REPEAT
\   -- compiles to:
\   --> condition 0BRANCH OFFSET2 loop-part BRANCH OFFSET
: WHILE IMMEDIATE
  ' 0BRANCH ,
  HERE @       \ [OFFSET2Addr]
  0 ,          \ placeholder for OFFSET2
;

\ REPEAT backfills offsets, and compiles a jump back to condition
: REPEAT IMMEDIATE
  \ jump back to condition
  ' BRANCH ,       \ [conditionAddr OFFSET2Addr]
  SWAP             \ [OFFSET2Addr conditionAddr]
  HERE @ -         \ [OFFSET2Addr conditionAddr-HERE]
  ,
  DUP              \ [OFFSET2Addr OFFSET2Addr]
  HERE @ SWAP -    \ [OFFSET2Addr HERE-OFFSET2ADDR]
  SWAP !
;

: UNLESS IMMEDIATE
  ' NOT ,
  [COMPILE] IF
;

\ COMMENTS. The strategy for ( ... ) comments is to keep track of
\ nesting level, and read character by character, until we hit a ')' that sets the nesting level to zero. We'll use BEGIN-UNTIL
: ( IMMEDIATE
  1          \ starting nesting level
  BEGIN
    KEY
    \ check if it's '(' or ')'
    DUP '(' = IF
        DROP 1+
      ELSE ')' = IF
             1- THEN

      THEN
    DUP 0= UNTIL
  DROP
;

(
  STACK NOTATION

  We use ( ... -- ... ) to show the effects a word has on the stack.
  For example:
  - ( n -- )       means the word consumes an integer n from the stack
  - ( b a -- c )   means the word consumes two integers a and b, where
                     a is at the top of the stack, and pushes an integer
                     c down to the stack
  - ( -- )         means word has no effect on the stack
)

( Some more complicated stack examples )
: NIP ( x y -- y ) SWAP DROP ;
: TUCK ( x y -- y x y ) SWAP OVER ;
: PICK ( x_u ... x_1 x_0 u ... x_1 x_0 x_u )
  1+ 8 * ( index from top of stack, +1 because first element is 2nd
           from top of stack )
  DSP@ + ( add index to stack pointer)
  @
;

( CLEAR resets the stack pointer )
: CLEAR S0 @ DSP! ;

\ BEGIN condition WHILE loop-part REPEAT
: SPACES ( n -- )
  BEGIN
    DUP 0>
  WHILE
    SPACE
    1-
  REPEAT
  DROP
;

: DECIMAL 10 BASE ! ;
: HEX 16 BASE ! ;

( Printing a number is quite natural in a stack-based language, as we
  push each remainder <num> % BASE successively, and then the printing
  will happen in the correct order )
: U. ( u -- )
  BASE @ /MOD ( width rem quot )
  ?DUP IF     ( DUP if nonzero, to pass to recurse )
    RECURSE
  THEN

  ( print the remainder )
  DUP 10 < IF
    '0'
  ELSE
    10 -
    'A'
  THEN
  +
  EMIT
;

( c a b WITHIN returns true if a <= c < b )
: WITHIN ( c a b -- n )
  -ROT OVER         ( b c a c )
  <= IF             ( a <= c )
    > IF            ( b > c )
      TRUE
    ELSE
      FALSE
    THEN
  ELSE
    2DROP           ( b c -- )
    FALSE
  THEN
;
\ (if (zero? quot) (recur [quot rem]) (print rem))

: .S ( -- )
  DSP@
  S0 @ 8-           ( DSP S0-8 )
  BEGIN
    2DUP <= ( check if we reached stack top )
  WHILE
    DUP @ U.
    SPACE
    8-
  REPEAT
  DROP DROP         ( DSP S0 -- )
  CR
;

( Returns number of chars needed to print number )
: UWIDTH ( u -- width )
  BASE @ /
  ?DUP IF     ( basically just count how many times we can divide by
                base until u / BASE = 0 )
    RECURSE 1+
  ELSE
    1
  THEN
;

( Prints an unsigned number, padded to width )
: U.R ( u width -- )
  ( the idea is to first compute padding, call SPACES, then call U. )
  SWAP        ( width u )
  DUP         ( width u u )
  UWIDTH      ( width u uwidth )
  ROT         ( u uwidth width )
  SWAP -      ( u  width-uwidth )
  ( padding = width - uwidth )
  ( u padding )
  SPACES
  U.
;

( Prints signed number, padded to width )
: .R ( n width -- )
  SWAP ( width n )
  DUP 0< IF
    NEGATE      ( width u )
    1           ( width u flag )
    SWAP        ( width flag u )
    ROT         ( flag u width )
    1-          ( flag u width-1 )
  ELSE
    0           ( width u flag )
    SWAP        ( width flag u )
    ROT         ( flag u width )
  THEN
  SWAP DUP           ( flag width u u )
  UWIDTH             ( flag width u uwidth )
  ROT                ( flag u uwidth width )
  SWAP -             ( flag u width-uwidth)
  SPACES             ( flag u )
  SWAP               ( u flag )
  IF
    '-' EMIT
  THEN
  U.
;

: . 0 .R SPACE ;
: U. U. SPACE ;

( ? fetches the integer at an address and prints it )
: ? ( addr -- ) @ . ;

: DEPTH ( -- n )
  S0 @ DSP@ -   ( calculate S0 - DSP )
  8 /
  1-            ( because S0 was on stack when we pushed DSP )
;

: d DEPTH . ;

: ALIGNED ( addr -- addr )
  7 + 7 INVERT AND
;

: ALIGN HERE @ ALIGNED HERE ! ;
(
  STRINGS ------------------------------

  S" string" is used in forth to define strings. It leaves the address
  and length of string on stack. In compile mode we append

    LITSTRING <string length> <string rounded up to 4 bytes>

  while in immediate mode we leave the string at HERE, without
  modifying HERE.
 )

: C, ( n -- )
  HERE @ C!
  1 HERE +!
;

: S" IMMEDIATE ( -- addr len )
  STATE @ IF
    ' LITSTRING ,
    HERE @          ( save the address of the length word on stack )
    0 ,
    BEGIN
      KEY
      DUP '"' <>
    WHILE
      C,
    REPEAT
    DROP
    DUP             ( get the saved address of the word )
    HERE @ SWAP -   ( calculate the length )
    8-              ( as we measured from the start of length word )
    SWAP !
    ALIGN
  ELSE
    HERE @          ( addr )
    BEGIN
      KEY           ( addr char )
      DUP '"' <>    ( addr bool )
    WHILE
      OVER C!       ( addr bool addr ) ( addr )
      1+            ( addr+1 )
    REPEAT
    DROP            ( addr )
    HERE @ -        ( compute length of string )
    HERE @          ( len addr )
    SWAP            ( addr len )
  THEN
;

: ." IMMEDIATE          ( -- )
     STATE @ IF      ( compiling? )
       [COMPILE] S"    ( read the string, and compile LITSTRING, etc. )
       ' TELL ,        ( compile the final TELL )
     ELSE
       ( In immediate mode, just read characters and print them until we get
                  to the ending double quote. )
       BEGIN
         KEY
         DUP '"' = IF
           DROP    ( drop the double quote character )
           EXIT    ( return from this function )
         THEN
         EMIT
       AGAIN
     THEN
;

(
  CONSTANTS AND VARIABLES --------------

  10 CONSTANT VAR
  VARIABLE VAR

  Constants can be read but not written.
  Variables can be read by

    VAR @ .
    VAR ?

  ? is the same as "@ .".

  Variables can be updated by

    20 VAR !

  Constants can be defined to: DOCOL LIT <number> EXIT

  Variables are a little trickier
)

: CONSTANT
  WORD
  CREATE
  DOCOL ,
  ' LIT ,
  ,
  ' EXIT ,
;

: ALLOT ( n -- addr)
  HERE @ SWAP
  HERE +!
;

: CELLS ( n -- n) 8 * ;

: VARIABLE ( )
  1 CELLS ALLOT
  WORD CREATE
  DOCOL ,
  ' LIT ,
  ,
  ' EXIT ,
;

: VALUE ( n -- )
  WORD CREATE
  DOCOL ,
  ' LIT ,
  ,
  ' EXIT ,
;

: TO IMMEDIATE ( n -- )
  WORD
  FIND     ( find variable to update )
  >DFA
  8+
  STATE @ IF
    ( when compiling, emit words that at run-time will set the value
   to whatever is on top of stack )
    ' LIT , ( LIT will push address to stack )
    ,
    ' ! ,   ( ! will pop address and value, and store the new value )
  ELSE
    !
  THEN
;

: +TO IMMEDIATE ( n -- )
  WORD
  FIND     ( find variable to update )
  >DFA
  8+
  STATE @ IF
    ( when compiling, emit words that at run-time will set the value
   to whatever is on top of stack )
    ' LIT , ( LIT will push address to stack )
    ,
    ' +! ,   ( ! will pop address and value, and store the new value )
  ELSE
    +!
  THEN
;

(
  PRINTING THE DICTIONARY --------------

  ID. takes an address of a dictionary entry and prints the word's
  name

)

: ID. ( addr -- )
  \ calculate length of name
  8+
  DUP C@            ( addr+8 flags+len )
  F_LENMASK AND     ( addr+8 len )
  BEGIN
    DUP 0>          ( is len positive? )
  WHILE
      SWAP 1+       ( len addr+8+idx )
      DUP C@        ( len addr+8+idx <char> )
      EMIT
      SWAP 1-       ( addr+8+idx len-- )
  REPEAT
  2DROP
;

: ?HIDDEN
  8+
  C@
  F_HIDDEN AND
;

: ?IMMEDIATE
  8+
  C@
  F_IMMED AND
;

: WORDS
  LATEST @
  BEGIN
    ?DUP
  WHILE
    DUP ?HIDDEN NOT IF
      DUP ID.
      SPACE
    THEN
      @
  REPEAT
  CR
;

: FORGET
  WORD FIND
  DUP @ LATEST !
  HERE !
;

: DUMP          ( addr len -- )
  BASE @ -ROT             ( save the current BASE at the bottom of the stack )
  HEX                     ( and switch to hexadecimal mode )
  BEGIN
    ?DUP            ( while len > 0 )
  WHILE
    OVER 8 U.R      ( print the address )
    SPACE
    ( print up to 16 words on this line )
    2DUP            ( addr len addr len )
    1- 15 AND 1+    ( addr len addr linelen )
    BEGIN
      ?DUP            ( while linelen > 0 )
    WHILE
      SWAP            ( addr len linelen addr )
      DUP C@          ( addr len linelen addr byte )
      2 .R  SPACE      ( print the byte )
      1+ SWAP 1-      ( addr len linelen addr -- addr len addr+1 linelen-1 )
    REPEAT
    DROP            ( addr len )
    ( print the ASCII equivalents )
    2DUP 1- 15 AND 1+ ( addr len addr linelen )
    BEGIN
      ?DUP            ( while linelen > 0)
    WHILE
      SWAP            ( addr len linelen addr )
      DUP C@          ( addr len linelen addr byte )
      DUP 32 128 WITHIN IF    ( 32 <= c < 128? )
        EMIT
      ELSE
        DROP '.' EMIT
      THEN
      1+ SWAP 1-      ( addr len linelen addr -- addr len addr+1 linelen-1 )
    REPEAT
    DROP            ( addr len )
    CR

    DUP 1- 15 AND 1+ ( addr len linelen )
    TUCK            ( addr linelen len linelen )
    -               ( addr linelen len-linelen )
    >R + R>         ( addr+linelen len-linelen )
  REPEAT

  DROP                    ( restore stack )
  BASE !                  ( restore saved BASE )
;

(
  <num> CASE
        test1 OF ... ENDOF
        test2 OF ... ENDOF
        ... ( default case )
        ENDCASE
)

: CASE IMMEDIATE
  0
;

: OF IMMEDIATE
  ' OVER ,      ( <num> test1 <num> )
  ' = ,
  [COMPILE] IF  ( <num> )
  ' DROP ,      ( to be used by the ELSE compiled by ENDOF )
;

: ENDOF IMMEDIATE
  [COMPILE] ELSE
;

: ENDCASE IMMEDIATE
  ' DROP ,          ( <num> -- )
  BEGIN
    ?DUP
  WHILE
    [COMPILE] THEN
  REPEAT
;

: CASE IMMEDIATE
       0               ( push 0 to mark the bottom of the stack )
       ;

: OF IMMEDIATE
     ' OVER ,        ( compile OVER )
     ' = ,           ( compile = )
     [COMPILE] IF    ( compile IF )
       ' DROP ,        ( compile DROP )
       ;

: ENDOF IMMEDIATE
        [COMPILE] ELSE  ( ENDOF is the same as ELSE )
       ;

: ENDCASE IMMEDIATE
          ' DROP ,        ( compile DROP )

          ( keep compiling THEN until we get to our zero marker )
          BEGIN
            ?DUP
          WHILE
            [COMPILE] THEN
REPEAT
;

: a CASE
    1 OF ." is one!" CR ENDOF
    2 OF ." is two!" CR ENDOF
    ." is something else: " . CR
  ENDCASE ;

(
  : CASE/testæøå
    1 a
    2 a
    3 a
  ;

  CASE/testæøå
)

(
  DECOMPILER ---------------------------

  CFA> is the opposite of >CFA. It takes a codeword and tries to find
the matching dictionary definition.

)

: CFA>              ( cfa -- dict_entry )
  LATEST @          ( link_ptr )
  BEGIN
    ?DUP            ( while link_ptr is not null )
  WHILE
    2DUP SWAP       ( cfa curr curr cfa )
    < IF
      NIP           ( curr )
      EXIT
    THEN
    @
  REPEAT
  DROP              ( curr -- )
  0                 ( return 0 when no entry is found )
;


: SEE
  WORD FIND       ( find the dictionary entry to decompile )

  ( Now we search again, looking for the next word in the dictionary.  This gives us
          the length of the word that we will be decompiling.  (Well, mostly it does). )
  HERE @          ( address of the end of the last compiled word )
  LATEST @        ( word last curr )
  BEGIN
    2 PICK          ( word last curr word )
    OVER            ( word last curr word curr )
    <>              ( word last curr word<>curr? )
  WHILE                   ( word last curr )
    NIP             ( word curr )
    DUP @           ( word curr prev (which becomes: word last curr) )
  REPEAT

  DROP            ( at this point, the stack is: start-of-word end-of-word )
  SWAP            ( end-of-word start-of-word )

  ( begin the definition with : NAME [IMMEDIATE] )
  ':' EMIT SPACE DUP ID. SPACE
  DUP ?IMMEDIATE IF ." IMMEDIATE " THEN

  >DFA            ( get the data address, ie. points after DOCOL | end-of-word start-of-data )

  ( now we start decompiling until we hit the end of the word )
  BEGIN           ( end start )
    2DUP >
  WHILE
    DUP @           ( end start codeword )

    CASE
      ' LIT OF                ( is it LIT ? )
        8 + DUP @               ( get next word which is the integer constant )
        .                       ( and print it )
      ENDOF
      ' LITSTRING OF          ( is it LITSTRING ? )
        [ CHAR S ] LITERAL EMIT '"' EMIT SPACE ( print S"<space> )
        8 + DUP @               ( get the length word )
        SWAP 8 + SWAP           ( end start+8 length )
        2DUP TELL               ( print the string )
        '"' EMIT SPACE          ( finish the string with a final quote )
        + ALIGNED               ( end start+8+len, aligned )
        8 -                     ( because we're about to add 8 below )
      ENDOF
      ' 0BRANCH OF              ( is it 0BRANCH ? )
        ." 0BRANCH ( "
        8 + DUP @               ( print the offset )
        .
        ." ) "
      ENDOF
      ' BRANCH OF               ( is it BRANCH ? )
        ." BRANCH ( "
        8 + DUP @               ( print the offset )
        .
        ." ) "
      ENDOF
      ' ' OF                  ( is it ' (TICK) ? )
      [ CHAR ' ] LITERAL EMIT SPACE
      8 + DUP @               ( get the next codeword )
      CFA>                    ( and force it to be printed as a dictionary entry )
      ID. SPACE
      ENDOF
      ' EXIT OF               ( is it EXIT? )
        ( We expect the last word to be EXIT, and if it is then we don't print it
                          because EXIT is normally implied by ;.  EXIT can also appear in the middle
                          of words, and then it needs to be printed. )
        2DUP                    ( end start end start )
        8 +                     ( end start end start+8 )
        <> IF                   ( end start | we're not at the end )
          ." EXIT "
        THEN
      ENDOF
      ( default case: )
      DUP                     ( in the default case we always need to DUP before using )
      CFA>                    ( look up the codeword to get the dictionary entry )
      ID. SPACE               ( and print it )
    ENDCASE

    8 +             ( end start+8 )
  REPEAT

  ';' EMIT CR

  2DROP           ( restore stack )
;

(
  EXECUTION TOKENS ---------------------

  An execution token is something that points to the codeword address.

 )

( :NONAME defines an anonymous word )
: :NONAME
  0 0 CREATE
  HERE @
  DOCOL ,
  ( why go into compile mode here? it's so that at /runtime/, when
    we call :NONAME, the interpreter goes into compile mode )
  [COMPILE] ]
;

: ['] IMMEDIATE
  ' LIT ,
;

( VARIABLE fn
 :NONAME ." boo" ; TO fn
 fn EXECUTE
)

: STRLEN ( str -- len )
  DUP
  BEGIN
    DUP C@ 0<>
  WHILE
    1+
  REPEAT
  SWAP -            ( str end -- end-str )
;

: ARGC
  S0 @ @
;

: ARGV ( n -- str u )
  1+ CELLS S0 @ + ( get address of argv[n] entry )
  @               ( get address of string )
  DUP STRLEN
;

: ENVIRON
  ARGC 2 +          ( skip count and NULL after args )
  CELLS             ( convert to an offset )
  S0 @ +            ( add to base stack offset )
;

: BYE
  0
  SYS_EXIT
  SYSCALL1
;

: GET-BRK ( -- brkpoint )
  0 SYS_BRK SYSCALL1
;

: UNUSED ( -- n )
  GET-BRK
  HERE @
  -
  8 /     ( return number of cells )
;

: BRK ( brkpoint -- new_brkpoint )
  SYS_BRK SYSCALL1
;

: MORECORE ( cells -- )
  CELLS GET-BRK + BRK DROP
;

( NEXT in assembly bytes )
HEX
: NEXT IMMEDIATE 48 C, AD C, FF C, 20 C, ;

( some x86 registers )
: RAX IMMEDIATE 0 ;
: RCX IMMEDIATE 1 ;
: RDX IMMEDIATE 2 ;
: RBX IMMEDIATE 3 ;
: RSP IMMEDIATE 4 ;
: RBP IMMEDIATE 5 ;
: RSI IMMEDIATE 6 ;
: RDI IMMEDIATE 7 ;

( reg -- )
: PUSH IMMEDIATE 50 + C, ;
: POP IMMEDIATE 58 + C, ;

: ;CODE IMMEDIATE
        [COMPILE] NEXT          ( end the word with NEXT macro )
        ALIGN                   ( machine code is assembled in bytes so isn't necessarily aligned at the end )
        LATEST @ DUP
        HIDDEN                  ( unhide the word )
        DUP >DFA SWAP           ( dfa word_start )
        ( change the codeword to point to the data area )
        >CFA !                  ( dfa word_start -- dfa cfa -- )
        [COMPILE] [             ( go back to immediate mode )
;

HEX
: =NEXT         ( addr -- next? )
           DUP C@ 48 <> IF DROP FALSE EXIT THEN
        1+ DUP C@ AD <> IF DROP FALSE EXIT THEN
        1+ DUP C@ FF <> IF DROP FALSE EXIT THEN
        1+     C@ 20 <> IF      FALSE EXIT THEN
        TRUE
;
DECIMAL

( (INLINE) is the lowlevel inline function. )
: (INLINE)      ( cfa -- )
        @                       ( remember codeword points to the code )
        BEGIN                   ( copy bytes until we hit NEXT macro )
                DUP =NEXT NOT
        WHILE
                DUP C@ C,
                1+
        REPEAT
        DROP
;

: INLINE IMMEDIATE
        WORD FIND               ( find the word in the dictionary )
        >CFA                    ( codeword )

        DUP @ DOCOL = IF        ( check codeword <> DOCOL (ie. not a FORTH word) )
                ." Cannot INLINE FORTH words" CR \ ABORT
        THEN

        (INLINE)
;

(
: b WORD FIND ;
: a INLINE DROP INLINE DROP ;CODE
)

(
  EXCEPTIONS ---------------------------

  We now implement THROW and CATCH. The way it will work is that CATCH
  will put an exception frame on the stack, then run an execution
  token. If during that execution some code calls THROW, we'll unwind
  the stack until the point marked by CATCH, leaving an error code on
  the stack, and resume execution from after the CATCH. If the
  execution does not call THROW, it will return as normal, and CATCH
  will leave 0 on the stack to indicate no errors.

)

: EXCEPTION-MARKER
  RDROP
  0
;

: CATCH ( xt -- exn? )
  DSP@ 8+ >R        ( save parameter stack pointer, one below xt )
  ' EXCEPTION-MARKER 8+ ( push the address of the RDROP )
  >R
  EXECUTE
;

: THROW ( n -- )
  ?DUP IF
    RSP@
    BEGIN
      DUP R0 8- <
    WHILE
      DUP @
      ' EXCEPTION-MARKER 8+ = IF
        8+ RSP!     ( if we found the exception marker, skip it )

        ( Restore the parameter stack )
        DUP DUP DUP
        R>          ( get the saved parameter stack pointer | n dsp )
        8-          ( reserve space on the stack to store n )
        SWAP OVER   ( dsp n dsp )
        !           ( write n on the stack )
        DSP! EXIT   ( restore the parameter stack pointer, and exit )
      THEN
      8+
    REPEAT

    DROP

    CASE
      0 1- OF
        ." ABORTED" CR
      ENDOF
      ." UNCAUGHT THREW "
      DUP . CR
    ENDCASE
    QUIT
  THEN
;

(
: FOO DUP 0= IF 1 THROW THEN 5 / ;
: T ( n - m )
  ['] FOO CATCH
  ?DUP 1 = IF
    ." FOO threw exception: Cannot divide by zero" CR
    DROP
  THEN
;
)

(
  C STRINGS ----------------------------

  Forth strings are represented by start address and length. We need
  support for C strings in our Forth so we can make syscalls and
  interface with other programs that use zero-terminated strings.

  Operation      Description
  ---------------------------------------------------
  S" ..."        Create Forth string literal
  Z" ..."        Create C string literal
  DUP STRLEN     Convert from C string to Forth string
  CSTRING        Convert from Forth string to C string
)

: Z" IMMEDIATE
  STATE @ IF
    ' LITSTRING ,
    HERE @          ( we still need length for LITSTRING )
    0 ,             ( dummy length )
    BEGIN
      KEY
      DUP '"' <>
    WHILE
      HERE @ C!
      1 HERE +!
    REPEAT
    0 HERE @ C!     ( null-terminate the string )
    1 HERE +!
    DROP
    DUP
    HERE @ SWAP -
    8-
    SWAP !
    ALIGN
    ' DROP ,
  ELSE
    HERE @
    BEGIN
      KEY
      DUP '"' <>
    WHILE
      OVER C!
      1+
    REPEAT
    DROP
    0 SWAP C!
    HERE @
  THEN
;

( STRLEN computes the length of a zero-terminated string )
: STRLEN ( str -- len )
  DUP
  BEGIN
    DUP C@ 0<>
  WHILE
    1+
  REPEAT
  SWAP -
;

: CSTRING ( addr len -- c-addr )
  SWAP OVER         ( len saddr len )
  HERE @ SWAP       ( len saddr daddr len )
  CMOVE             ( len saddr daddr len - len )
  HERE @ +          ( daddr+len )
  0 SWAP C!              ( daddr+len 0 -- )
  HERE @
;

(
S" 1 2 3" CSTRING DUP STRLEN TELL
)


: R/O ( -- fam ) O_RDONLY ;
: R/W ( -- fam ) O_RDWR ;

: OPEN-FILE ( addr u fam -- fd 0 (if successful)
              addr u fam -- fd errno (if error) )
  -ROT              ( fam addr u )
  CSTRING           ( fam cstring )
  SYS_OPEN SYSCALL2 ( open(filename, flags) )
  DUP               ( fd fd )
  DUP 0< IF
    NEGATE          ( fd errno )
  ELSE
    DROP 0          ( fd 0 )
  THEN
;

: CREATE-FILE ( addr u fam )
  O_CREAT OR O_TRUNC OR
  -ROT
  CSTRING
  420 -ROT          ( 0644 fam cstring )
  SYS_OPEN SYSCALL3
  DUP
  DUP 0< IF
    NEGATE
  ELSE
    DROP 0
  THEN
;

: CLOSE-FILE ( fd -- 0/errno )
  SYS_CLOSE SYSCALL1
  NEGATE
;

( Pops a Forth string from stack, converts it to a C string, calls
 open, pushes the fd on the key_stack. This notifies next call to _KEY
 to read from that file.
)
: LOAD-FILE ( addr u -- )
  2DUP
  R/O OPEN-FILE         ( addr u fam -- fd status )
  DUP 0<> IF
    ." Error loading file: "
    CASE
      1 OF ." operation not permitted" ENDOF
      2 OF ." file not found: " -ROT 2DUP TELL ENDOF
      13 OF ." no access" ENDOF
      ." error code: " .
      ENDCASE
    CR
    DROP 2DROP
    EXIT
  THEN
  DROP
  PUSH-KEY-STACK
  2DROP
;


( Print a stack trace by walking up the return stack. )
: PRINT-STACK-TRACE
        RSP@                            ( start at caller of this function )
        BEGIN
                DUP R0 8- <             ( RSP < R0 )
        WHILE
                DUP @                   ( get the return stack entry )
                                        ( rsp_0 rsp_n )
                CASE
                ' EXCEPTION-MARKER 8+ OF        ( is it the exception stack frame? )
                        ." CATCH ( DSP="
                        8+ DUP @ U.             ( print saved stack pointer )
                        ." ) "
                ENDOF
                                                ( default case )
                        DUP                     ( rsp_n rsp_n )
                        .S
                        CFA>                    ( look up the codeword to get the dictionary entry )
                        ?DUP IF                 ( and print it )
                                2DUP                    ( dea addr dea )
                                ID.                     ( print word from dictionary entry )
                                [ CHAR + ] LITERAL EMIT
                                SWAP >DFA 8+ - .        ( print offset )
                        THEN
                ENDCASE
                8+                      ( move up the stack )
        REPEAT
        DROP
        CR
;

: WELCOME
  S" TEST-MODE" FIND NOT IF
    ." JONESFORTH VERSION " VERSION . CR
    UNUSED . ." CELLS REMAINING" CR
    \ ." OK "
    THEN
;

: READ-FILE ( addr u fd -- u2 0 )
  >R SWAP R>        ( u addr fd )
  SYS_READ SYSCALL3 ( u2 )
  DUP
  DUP 0< IF
    NEGATE
  ELSE
      DROP 0
  THEN

;

(
S" hola.txt" 0 CREATE-FILE
DROP CLOSE-FILE .
)

: read-test
  S" hola.txt" 0 OPEN-FILE
  DROP                ( fd )
  40 ALLOT DUP        ( fd addr addr )
  -ROT                ( addr fd addr )
  40                  ( addr fd addr u )
  ROT                 ( addr addr u fd )
  READ-FILE           ( addr u2 ok )
  DROP                ( addr u2 )
  ALIGNED DUMP
;

WELCOME
HIDE WELCOME

S" sock.f" LOAD-FILE
\ S" sock_test.f" LOAD-FILE
