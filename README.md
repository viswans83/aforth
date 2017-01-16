# aforth
A simplistic FORTH bootstrapped from x86 assembly language

## Compile
    ./build.sh [linux|osx]

## Run
    cat aforth.f - | ./aforth

## Sample aforth code
Add two numbers and display the result:
````
    12 34   // place two numbers on the stack
    +       // the `+` word removes two numbers from the stack, adds them
            //    and places the result on the stack
    .       // the `.` word outputs it
    46
````
Show all words present in the dictionary:
````
    // the `words.` word displays all known words in the dictionary
    words.
    . words. word. spc num>str 1+@ 1-@ var: alloc bytes cells str: neg? neg
    char: ( ) // \ recur loop until while end else unless if mod / word
    latestword latest word>str hide hidden? immediate? prevword str>num
    execute scantoken readtoken discard ; immediate : [ ] create copy, c, ,
    mode here write eof key nl emit +! c! c@ ! @ whitespace? whitespace str=
    charindex strcpy bit invert & | false true not or and /mod * - + 1- 1+
    fail errorquit quit 2? ? branchnz branchz branch lit > < != = pick -rot
    rot nip over ndrop 3drop 2drop drop 3dup 2dup dup swapd 2swap swap exit
````
Print the multiplication table of a number upto 10:
````
// define a word *table that consumes one parameter
// off the stack and outputs a multiplication table
// for that number

: *table ( n -- )
  1                         // place index on stack
  false until               // initialize loop boolean and begin until loop
    over num>str write spc  // display n
    char: * emit spc        // display *
    dup num>str write spc   // display index
    char: = emit spc        // display =
    2dup * .                // multiply and display result
    1+ dup 10 >             // increment index and setup loop boolean
  loop
  2drop ;

// show table for number 11
11 *table
11 * 1 = 11
11 * 2 = 22
11 * 3 = 33
11 * 4 = 44
11 * 5 = 55
11 * 6 = 66
11 * 7 = 77
11 * 8 = 88
11 * 9 = 99
11 * 10 = 110

// show table for number 5
5 *table
5 * 1 = 5
5 * 2 = 10
5 * 3 = 15
5 * 4 = 20
5 * 5 = 25
5 * 6 = 30
5 * 7 = 35
5 * 8 = 40
5 * 9 = 45
5 * 10 = 50
````

## Did you know?
- In FORTH, functions are called words. All words take their inputs from the
  stack and place their outputs on the same stack. Thus a word in forth is
  defined as a list of other words that need to be called. e.g.
  `: double 2 * ;` and `: quadruple double double ;`.
- The word `//` defines a comment, and is defined in forth.
- `if`, `else`, `while`, `until` are all simply forth words. They are defined in
  terms of other primitive forth words like `branchz` and `branch` that are
  defined in x86 assembly.
- The word `:` or `COLON` is a forth word that creates other forth words. It has
  a very simple definition, again written in forth

## Why I built this
The [Factor][0] programming language was my first exposure to concatenative or
stack based programming languages. After seeing that all syntax in Factor was
runtime defined, I was impressed. I mean, I had never come across a language
that had no fixed syntax. Even LISP (ignoring reader macros) had parenthesis.

So I spent a lot of time learning more about concatenative languages and FORTH.
I also came across [JonesForth][1] and [Itsy Forth][2], and through them I
realized bootstrapping a forth could be very simple.

I build this to clarify for myself what I learnt about FORTH from studying these
implementations, to see for myself if I could build a forth and to be able to
better appreciate what makes FORTH so simple but extremely low level and high
level at the same time. I mean you start out with x86 assembly language and very
soon you are representing FORTH words within assembly language (using macros),
and then you write a parser using the FORTH words you have, which then enables
you to write more FORTH, building up a language as you go.

## Is it useful software?
Not really.

## Do I have plans to improve it?
Not at the moment. I might come back to it to try building out other concepts
linked to compilers and interpreters (like say adding garbage collection or
local variables).

[0]: https://factorcode.org
[1]: https://github.com/AlexandreAbreu/jonesforth
[2]: http://www.retroprogramming.com/2012/06/itsy-forth-compiler.html
