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
  here @ true
  ; immediate

: until
  here @ false
  ; immediate

: do
  if
    branchnz,
  else
    branchz,
  end
  ; immediate

: done
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

// -------------------------------------------------------------
// now we gain the ability to insert comments in a forth program
// -------------------------------------------------------------

: */ ;

: /*
  scantoken
  \ */ word>str
  str= unless
    recur
  end
  ; immediate

/* --------------------------------------------------------------
   now we gain the ability to place multi-line comments like this
   -------------------------------------------------------------- */

: ) ;

: (
  scantoken
  \ ) word>str
  str= unless
    recur
  end
  ; immediate

// stack effect signatures ( x y -- z ) are like function signatures
// and are used indicate the input and output stack effects of a word

// 
// general utility words
// 

: on ( var -- )
  true swap ! ;

: off ( var -- )
  false swap ! ;

: >= ( n1 n2 -- ? )
  < not ;

: <= ( n1 n2 -- ? )
  > not ;

: / ( n1 n2 -- quot )
  /mod drop ;

: mod ( n1 n2 -- rem )
  /mod nip ;

: neg ( x -- -x )
  0 swap - ;

: neg? ( x -- ? )
  0 < ;

: 1+@ ( var -- ) // increment variable
  dup @ 1+
  swap ! ;

: 1-@ ( var -- ) // decrement variable
  dup @ 1-
  swap ! ;

//
// utility words related to memory sizing
//

: cell ( n -- )
  4 * ;

: cells ( n -- )
  4 * ;

: byte ( n -- ) ;

: bytes ( n -- ) ;

: kb ( n -- n )
  1024 * ;

//
// character literal support
//
// usage:
//   char: a emit char: b emit char: c emit
//

: char:
  scantoken drop c@
  mode @ unless
    lit,
  end
  ; immediate

//
// accept character strings from stdin
//

: accept-more? ( buff max ptr -- ? )
  over -1 = if
    true
  else
    rot - >
  end ;

: escape? ( ch -- ? )
  char: \ = ;

: buff,c ( buff ch -- buff+1 )
  over c! 1+ ;
  
: finish-accept ( delim buff max ptr -- buff len )
  nip over -
  rot drop ;

: accept ( delim buff max -- buff len )
  over
  while 3dup accept-more? do
    key dup escape?
    if
      drop key drop 
      key buff,c
    else
      ( delim buff max ptr ch )
      dup 5 pick =
      unless
        buff,c
      else
        drop finish-accept
        exit
      end
    end
  done
  finish-accept ;

\ accept-more? hide
\ escape? hide
\ buff,c hide
\ finish-accept hide

//
// support runtime variables
//
// usage:
//   var a 1 cell alloc
//

: var ( -- var-sizeof-addr )
  scantoken create
  here @ 3 cells + lit,
  lit exit ,
  ; immediate

: alloc ( n -- )
  here +! ;

//
// support runtime string constants
//
// usage:
//   stringconst abcd "abcd"
//

: stringconst ( -- )
  scantoken
  whitespace discard drop
  here @ 100 accept
  ( word wlen buff blen )
  dup here +!
  2swap create swap
  lit, lit, lit exit ,
  ; immediate

//
// support allocating buffers to hold runtime input
//
// usage:
//   buffer userinput 100
//   userinput readln
//

: buffer ( -- )
  scantoken create
  here @ 5 cells + lit,
  scantoken str>num dup lit,
  lit exit , alloc
  ; immediate

: readln ( buff max -- buff len )
  10 -rot accept ;

//
// words to convert numbers to strings
//

var n>s_buff 15 bytes alloc
var n>s_ptr   1 cells alloc

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
  until dup do
    10 /mod
    char: 0 +
    n>s_ptr 1-@
    n>s_ptr @ c!
  done drop
  if
    n>s_ptr 1-@
    char: - n>s_ptr @ c!
  end
  n>s_ptr @
  n>s_buff 15 + n>s_ptr @ - ;

\ n>s_buff hide
\ n>s_ptr hide

//
// words to output stuff
//

: spc ( -- )
  32 emit ;

: write. ( buff str -- )
  write nl ;

: word. ( word -- )
  word>str write nl ;

: words. ( -- )
  latestword
  until dup do
    dup hidden? unless
      dup word>str write spc
    end
    prevword
  done
  drop nl ;

: . ( n -- )
  num>str write. ;

//
// words to inspect the parameter & return stacks
//

stringconst s_bot "---------"
stringconst s_top "-- top --"

: s. ( -- )
  psbase ps = if 
    exit 
  end
  s_bot write.
  psbase while ps over < do
    dup @ .
    1 cells -
  done drop
  s_top write. ;

: rframe. ( rs -- )
  latestword
  until 2dup swap < do
    prevword
  done
  word. drop ;

: r. ( -- )
  s_bot write.
  rsbase
  while rs over >= do
    dup @ rframe.
    1 cells +
  done drop
  s_top write. ;

\ s_bot hide
\ s_top hide

//
// words to inspect free memory
//

stringconst bytes_str "bytes"
stringconst kb_str "kb"
stringconst free_str "free"

: mem. ( -- )
  mem 1 kb >= if
    mem 1 kb / num>str write
    spc kb_str write
  else
    mem num>str write
    spc bytes_str write
  end
  spc free_str write nl ;

\ bytes_str hide
\ kb_str hide
\ free_str hide

//
// hide internal words
//

\ lit, hide
\ dup, hide
\ branchz, hide
\ branchnz, hide
\ branch, hide
\ branchoff! hide

stringconst welcome "aforth v0.0.1 ready"
welcome write.

\ welcome hide

prompt on
