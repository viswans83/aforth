# aforth
A simplistic FORTH bootstrapped from x86 assembly language

## Compile
    ./build.sh [linux|osx]
    
## Run
    cat aforth.f - | ./aforth

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
linked to compilers and interpreters (like say adding garbage collection or local
variables).

[0]: https://factorcode.org
[1]: https://github.com/AlexandreAbreu/jonesforth
[2]: http://www.retroprogramming.com/2012/06/itsy-forth-compiler.html
