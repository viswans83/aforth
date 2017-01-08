: LIT,
  LIT LIT , , ;

: DUP,
  LIT DUP , ;

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

: BRANCHOFF!
  OVER
  - 4 / 2 -
  SWAP ! ;

: IF
  BRANCHNZ,
  ; IMMEDIATE

: UNLESS
  BRANCHZ,
  ; IMMEDIATE
    
: ELSE
  BRANCH, SWAP
  HERE @ BRANCHOFF!
  ; IMMEDIATE

: END
  HERE @ BRANCHOFF!
  ; IMMEDIATE

: WHILE
  HERE @
  BRANCHNZ,
  ; IMMEDIATE

: UNTIL
  HERE @
  BRANCHZ,
  ; IMMEDIATE

: LOOP
  BRANCH, ROT BRANCHOFF!
  HERE @ BRANCHOFF!
  ; IMMEDIATE

: RECUR
  BRANCH, LATESTWORD 4 +
  BRANCHOFF!
  ; IMMEDIATE

: \
  SCANTOKEN WORD
  MODE @ UNLESS
    LIT,
  END
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

: CHAR:
  SCANTOKEN DROP C@
  MODE @ UNLESS
    LIT,
  END
  ; IMMEDIATE

: NEG ( x -- -x )
  0 - ;

: KEY="? ( -- ch ? )
  KEY DUP
  CHAR: "
  = ;

: ACCEPTSTR ( -- buff len )
  HERE @
  KEY="? UNTIL     // drop chars until first "
    DROP KEY="?
  LOOP DROP
  KEY="? UNTIL     // append chars until next "
    C, KEY="?
  LOOP DROP
  DUP HERE @ SWAP -
  ;

: STRING: ( -- )
  SCANTOKEN ACCEPTSTR 2SWAP
  CREATE SWAP LIT, LIT,
  LIT EXIT ,
  ; IMMEDIATE

// Now we are able to create string constants like below:
//   STRING: Greeting "Welcome to aforth!"
//   Greeting WRITE NL
// this will output:
//   Welcome to aforth!

