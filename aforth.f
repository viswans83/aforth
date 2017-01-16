: /
  /mod drop ;

: mod
  /mod nip ;

: lit,
  lit lit , , ;

: dup,
  lit dup , ;

: branchz,
  0 lit,
  lit branchz ,
  here @ 8 - ;

: branchnz,
  0 lit,
  lit branchnz ,
  here @ 8 - ;

: branch,
  0 lit,
  lit branch ,
  here @ 8 - ;

: branchoff!
  over
  - 4 / 2 -
  swap ! ;

: if
  branchnz,
  ; immediate

: unless
  branchz,
  ; immediate

: else
  branch, swap
  here @ branchoff!
  ; immediate

: end
  here @ branchoff!
  ; immediate

: while
  here @
  branchnz,
  ; immediate

: until
  here @
  branchz,
  ; immediate

: loop
  branch, rot branchoff!
  here @ branchoff!
  ; immediate

: recur
  branch, latestword 4 +
  branchoff!
  ; immediate

: \
  scantoken word
  mode @ unless
    lit,
  end
  ; immediate

: //
  key 10 =
  unless recur end
  ; immediate

// now we gain the ability to insert comments in a forth program

: ) ;

: (
  scantoken
  \ ) word>str
  str= unless
    recur
  end
  ; immediate

// ( x y -- z ) are used to place a stack comment
// to indicate the input and output stacks of a word

: char:
  scantoken drop c@
  mode @ unless
    lit,
  end
  ; immediate

: neg ( x -- -x )
  0 swap - ;

: neg? ( x -- ? )
  0 < ;

: key="? ( -- ch ? )
  key dup
  char: "
  = ;

: acceptstr ( -- buff len )
  here @
  key="? until     // drop chars until first "
    drop key="?
  loop drop
  key="? until     // append chars until next "
    c, key="?
  loop drop
  dup here @ swap -
  ;

: str: ( -- )
  scantoken acceptstr 2swap
  create swap lit, lit,
  lit exit ,
  ; immediate

// now we are able to create string constants like below:
//   str: greeting "welcome to aforth!"
//   greeting write nl
// this will output:
//   welcome to aforth!

: cells ( n -- )
  4 * ;

: bytes ( n -- ) ;

: alloc ( n -- )
  here +! ;

: var: ( -- )
  scantoken create
  here @ 3 cells +  // space for lit, xxxxx, exit
  lit, lit exit ,
  ; immediate

// now we can create variables at runtime like below:
//   var: a 1 cells alloc
//   var: b 15 bytes alloc

var: n>s_buff 15 bytes alloc
var: n>s_ptr   1 cells alloc

: 1-@ ( var -- )
  dup @ 1- swap ! ;

: 1+@ ( var -- )
  dup @ 1+ swap ! ;

: num>str ( n -- buff len )
  dup if
    drop
    char: 0 n>s_buff c!
    n>s_buff 1 exit
  end
  n>s_buff 15 + n>s_ptr !
  dup neg? if
    neg true
  else
    false
  end swap
  dup until
    10 /mod
    char: 0 +
    n>s_ptr 1-@
    n>s_ptr @ c!
    dup
  loop drop
  if
    n>s_ptr 1-@
    char: - n>s_ptr @ c!
  end
  n>s_ptr @
  n>s_buff 15 + n>s_ptr @ - ;

: spc ( -- )
  32 emit ;

: word. ( word -- )
  word>str write nl ;

: words. ( -- )
  latestword
  dup until
    dup hidden? if
      prevword
    else
      dup word>str write spc
      prevword
    end dup
  loop
  drop nl ;

: . ( n -- )
  num>str write nl ;

// hide implementation specific words

\ lit, hide
\ dup, hide
\ branchz, hide
\ branchnz, hide
\ branch, hide
\ branchoff! hide
\ key="? hide
\ acceptstr hide
\ n>s_buff hide
\ n>s_ptr hide
