: LIT,
  LIT LIT , , ;

: \
  SCANTOKEN WORD LIT,
  ; IMMEDIATE

: /
  /MOD DROP ;

: MOD
  /MOD NIP ;

: BRANCHZ,
  0 LIT,
  LIT BRANCHZ ,
  HERE @ 8 - ;

: BRANCHNZ,
  0 LIT,
  LIT BRANCHNZ ,
  HERE @ 8 - ;

: BRANCH,
  0 LIT,
  LIT BRANCH ,
  HERE @ 8 - ;

: IF
  BRANCHNZ,
  ; IMMEDIATE

: UNLESS
  BRANCHZ,
  ; IMMEDIATE
    
: BRANCHOFF!
  HERE @ OVER
  - 4 / 2 -
  SWAP ! ;

: ELSE
  BRANCH, SWAP
  BRANCHOFF!
  ; IMMEDIATE

: END
  BRANCHOFF!
  ; IMMEDIATE

: CHAR:
  SCANTOKEN DROP C@ LIT,
  ; IMMEDIATE

: NEG
  0 - ;

: RECUR
  LIT LIT ,
  LATESTWORD HERE @ - 4 / 1- ,
  LIT BRANCH ,
  ; IMMEDIATE

: //
  KEY 10 =
  UNLESS RECUR END
  ; IMMEDIATE

// Now we gain the ability to insert comments in a forth program

: ) ;

: (
  SCANTOKEN
  \ ) WORD>STR
  STR= UNLESS
    RECUR
  END
  ; IMMEDIATE

// ( x y -- z ) are used to place a stack comment
// to indicate the input and output stacks of a word

