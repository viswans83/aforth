;;;
;;; aforth - a simple forth bootstrapped from 32-bit x86 assembly
;;; 
;;; compile: ./build.sh [linux|osx]
;;; run: cat aforth.f - | ./aforth
;;;

        
%ifdef OSX
%define startsymbol start
%else
%define startsymbol _start        
%endif        


;;;
;;; macro definitions
;;; 

        
;;; linux 32-bit style syscall abi handler:
;;; 1) pass syscall number in eax
;;; 2) pass params in the order: ebx, ecx, edx
;;; 3) supports syscalls having upto 3 parameter 
%macro systemcall 0
%ifndef linux
        push edx
        push ecx
        push ebx
        push eax
%endif
        int 0x80
%ifndef linux
        add esp, 16
%endif
%endmacro

;;; 
;;; next macro:
;;; used to transfer control from the currently 
;;; executing primitive word to the next word
;;; 
%macro next 0
        lodsd
        jmp [eax]
%endmacro

;;;
;;; push a value onto the return stack
;;;         
%macro pushrs 1
	add ebp, 4
	mov [ebp], %1
%endmacro

;;;
;;; pop a value from the return stack
;;; 
%macro poprs 1
	mov %1, dword [ebp]
	sub ebp, 4
%endmacro	

        
;;;
;;; how words are structured in the `aforth` dictionary:
;;; +-----------------------------------------------------------+
;;; | link | name | len | flags | interpreter | definition ...  |
;;; +-----------------------------------------------------------+
;;;
;;; link        : address to the previously defined word (4 bytes)
;;; name        : max 256 bytes (variable size)
;;; len         : name length (1 byte)
;;; flags       : to control behaviour of this word (1 byte)
;;; interpreter : pointer to x86 code that can execute this word (4 bytes)
;;; definition  : either x86 code or a pointers to other words (variable size)
;;; 

;;;
;;; keep track of the last defined word in assembly
;;; in order to maintain a chain of words in the
;;; forth dictionary
;;; 
%define lastword 0

;;; 
;;; allowed flags:
;;;   1 => word is immediate
;;;   2 => word is hidden
;;; 
%define F_IMMEDIATE     1
%define F_HIDDEN        2

;;;
;;; macro: primitive asmname, 'wordname', flags
;;; 
;;; primitive words do not need an interpreter, so their
;;; interpreter pointer simply points to the start of their
;;; x86 instructions
;;;
%macro primitive 2-3 0
%1_dict_entry:        
        dd lastword
%1_name:
        db %2
        db $ - %1_name
        db %3
%1:
        dd %1_asm
%1_asm:
%define lastword %1
%endmacro        

;;;
;;; macro: forthword asmname, 'wordname', flags
;;;
;;; non-primitive / compound words are words that are defined
;;; in terms of other words. their definition consists of a
;;; list of pointers to other forth words. thus they cannot be
;;; "executed" directly. their interpreter word thus points to a
;;; simple interpreter (defined further down below) that sets up
;;; some state and jumps to the first word of word definition
;;;
%macro forthword 2-3 0
%1_dict_entry:   
        dd lastword
%1_name:
        db %2
        db $ - %1_name
        db %3
%1:
        dd interpreter
%define lastword %1
%endmacro

;;;
;;; macro: stringconst asmname, 'wordname', flags
;;;
;;; this macro defines a forth word that when executed simply places
;;; on the stack (a) the address of the string buffer, (b) the string length
;;; 
%macro stringconst 2-3 0
section .data
str_data_%1:	db %2
str_len_%1:     equ $-str_data_%1
section .text
	%defstr variable_name %1
	primitive %1, variable_name, %3
	push str_data_%1
        push str_len_%1
	next
%endmacro

;;;
;;; macro: variable wordname
;;;
;;; this macro first reserves 4 bytes of space in the .data section
;;; and defines a forth word that simply places this address on
;;; the stack
;;; 
%macro variable 1-2 0
section .bss
var_data_%1:	
	resd 1
section .text
	%defstr variable_name %1
	primitive %1, variable_name, %2
	push var_data_%1
	next
%endmacro	

%define branch(label) lit, label, branch
%define branchz(label) lit, label, branchz
%define branchnz(label) lit, label, branchnz
        
global startsymbol

section .text

;;;
;;; interpreter for forth words
;;; 1) push the next word to be executed onto the return stack
;;; 2) sets up the next word to be executed as the first word 
;;;    from the currently executing words definition
;;; 3) execute next word
;;; 
interpreter:  
	pushrs esi
	lea esi, [eax+4]
	next

;;;
;;; core words
;;; 
        

	primitive exit, 'exit'
        ;; ( -- )
        ;; return from currently executing forth word
        poprs esi
	next

        primitive swap, 'swap'
        ;; ( x y -- y x )
        pop eax
        pop ebx
        push eax
        push ebx
        next

        primitive swap2, '2swap'
        ;; ( x1 x2 y1 y2 -- y1 y2 x1 x2 )
        pop ebx
        pop eax
        pop edx
        pop ecx
        push eax
        push ebx
        push ecx
        push edx
        next

        primitive swapd, 'swapd'
        ;; ( x y z -- y x z )
        pop eax
        pop ebx
        pop ecx
        push ebx
        push ecx
        push eax
        next
        
	primitive dup, 'dup'
        ;; ( x -- x x )
	mov eax, dword [esp]
	push eax
	next

	primitive dup2, '2dup'
        ;; ( x y -- x y x y )
	mov eax, dword [esp+4]
	push eax
	mov eax, dword [esp+4]
	push eax
	next

        primitive dup3, '3dup'
        ;; ( x y z -- x y z x y z )
        mov eax, dword [esp+8]
	push eax
	mov eax, dword [esp+8]
	push eax
	mov eax, dword [esp+8]
	push eax
        next

        primitive dupd, 'dupd'
        ;; ( x y -- x x y )
        pop ebx
        mov eax, dword [esp]
        push eax
        push ebx
        next

	primitive drop, 'drop'
        ;; ( x -- )
	pop eax
	next

	primitive drop2, '2drop'
        ;; ( x y -- )
	pop eax
	pop eax
	next

        primitive drop3, '3drop'
        ;; ( x y z -- )
        pop eax
        pop eax
        pop eax
        next

        primitive ndrop, 'ndrop'
        ;; 0 ndrop => ( x 0 -- x )
        ;; 1 ndrop => ( x 1 -- )
        ;; 2 ndrop => ( x y 2 -- )
        pop eax
        lea esp, [esp + 4*eax]
        next

	primitive over, 'over'
        ;; ( x y -- x y x )
	mov eax, dword [esp + 4]
	push eax
	next

	primitive nip, 'nip'
        ;; ( x y -- y )
	pop eax
	pop ebx
	push eax
	next

        primitive rot, 'rot'
        ;; ( x y z -- y z x )
        pop ecx
        pop ebx
        pop eax
        push ebx
        push ecx
        push eax
        next

        primitive rotr, '-rot'
        ;; ( x y z --  z x y )
        pop ecx
        pop ebx
        pop eax
        push ecx
        push eax
        push ebx
        next

        primitive pick, 'pick'
        ;; 0 pick => ( x 0 -- x x )
        ;; 1 pick => ( x y 1 -- x y x )
        ;; 2 pick => ( x y z 2 -- x y z x )
        pop eax
        mov ebx, dword [esp + 4*eax]
        push ebx
        next

        
;;;
;;; comparison words
;;; 
        
        
	primitive equalp, '='
        ;; ( x y -- ? )
        ;; 0 => true
        ;; 1 => false
	pop eax
	pop ebx
	cmp eax, ebx
	jz equalp_true
	push 1
	next
equalp_true:
	push 0
	next

	forthword notequalp, '!='
        ;; ( x y -- ? )
	dd equalp, boolnot
        dd exit

        primitive lessthanp, '<'
        ;; ( x y -- ? )
        pop ebx
        pop eax
        cmp eax, ebx
        jl lessthanp_true
        push 1
        next
lessthanp_true:
        push 0
        next

        forthword greaterthanp, '>'
        ;; ( x y -- ? )
        dd dup2, lessthanp
        dd rotr, equalp
        dd boolor, boolnot
        dd exit
        
        primitive lit, 'lit'
        ;; ( -- x )
        ;; treat the following word in definition as
        ;; a literal value and push it onto the stack
        push dword [esi]
        add esi, 4
        next

	primitive branch, 'branch'
        ;; ( addr -- )
        ;; jump to forth addr (address of a cell in a given word)
	pop esi
	next

	primitive branchz, 'branchz'
        ;; ( ? addr -- )
        ;; jump to forth addr if condition is zero
	pop eax			; addr
	pop ebx			; value
	cmp ebx, 0
	jz branchz_jump
	next
branchz_jump:
	mov esi, eax
	next

        primitive branchnz, 'branchnz'
        ;; ( ? addr -- )
        ;; jump to forth addr if condition is non-zero
	pop eax			; addr
	pop ebx			; value
	cmp ebx, 0
	jnz branchz_jump
	next
branchnz_jump:
	mov esi, eax
	next

        forthword choose, '?'
        ;; ( x y ? -- x/y )
        ;; choose x if top of stack is true (zero)
        ;; choose y if top of stack is false (non-zero)
        dd branchnz(choose_false)
        dd drop, exit
choose_false:     
        dd nip, exit

        forthword choose2, '2?'
        ;; ( x1 y1 x2 y2 ? -- x1/x2 y1/y2 )
        ;; choose x1 y1 if top of stack is true (zero)
        ;; choose x2 y2 if top of stack is false (non-zero)
        dd branchnz(choose2_false)
        dd drop2, exit
choose2_false:    
        dd rot, drop
        dd rot, drop
        dd exit


;;;
;;; system words
;;;

        primitive quit, 'quit'
        ;; ( -- )
        ;; terminate program with 0 return code
        mov ebx, 0
        mov eax, 1
	systemcall
        next

        primitive errorquit, 'errorquit'
        ;; ( -- )
        ;; terminate program with 1 return code
        mov ebx, 1
        mov eax, 1
        systemcall
        next

        forthword fail, 'fail'
        ;; ( buff len -- )
        ;; write string to stdout and terminate with failure
        ;; return code
        dd write, errorquit

        
;;; 
;;; arithmetic words
;;; 

	primitive oneplus, '1+'
        ;; ( x -- x+1 )
	inc dword [esp]
	next

	primitive oneminus, '1-'
        ;; ( x -- x-1 )
	dec dword [esp]
	next

	primitive plus, '+'
        ;; ( x y -- x+y )
	pop eax
	add dword [esp], eax
	next

	primitive minus, '-'
        ;; ( x y -- x-y )
	pop eax
	sub dword [esp], eax
	next

        primitive multiply, '*'
        ;; ( x y -- x*y )
        pop eax
        pop ebx
        imul ebx
        push eax
        next

        primitive divmod, '/mod'
        ;; ( x y -- q r )
        ;; divide x by y producing quotient q and remainder r
        pop ebx
        pop eax
        cdq
        idiv ebx
        push eax
        push edx
        next


;;;
;;; boolean logic words
;;;

        primitive booland, 'and'
        ;; ( x y -- x&&y )
        pop ebx
        pop eax
        cmp eax, 0
        je booland_2nd
        push eax
        next
booland_2nd:
        push ebx
        next

        primitive boolor, 'or'
        ;; ( x y -- x||y )
        pop ebx
        pop eax
        cmp eax, 0
        jne boolor_2nd
        push eax
        next
boolor_2nd:
        push ebx
        next

        primitive boolnot, 'not'
        ;; ( x -- !x )
        pop eax
        cmp eax, 0
        je boolnot_true
        push dword 0
        next
boolnot_true:
        push dword 1
        next

        primitive true, 'true'
        ;; ( -- ? )
        push dword 0
        next

        primitive false, 'false'
        ;; ( -- ? )
        push dword 1
        next

        
;;;
;;; bitwise operation words
;;;


        primitive bitor, '|'
        ;; ( x y -- x|y )
        pop ebx     
        pop eax
        or eax, ebx
        push eax
        next

        primitive bitand, '&'
        ;; ( x y -- x&y )
        pop ebx
        pop eax
        and eax, ebx
        push eax
        next

        primitive bitxor, '^'
        ;; ( x y -- x^y )
        pop ebx
        pop eax
        xor eax, ebx
        push eax
        next

        primitive bitnot, 'invert'
        ;; ( x -- x' )
        pop eax
        not eax
        push eax
        next

        forthword bit, 'bit'
        ;; ( value index -- ? )
        dd bitand, boolnot, boolnot
        dd exit
        
        
;;;
;;; words to work with strings
;;;


        primitive strcpy, 'strcpy'
        ;; ( src length dest -- )
        mov eax, esi
        pop edi
        pop ecx
        pop esi
        rep movsb
        mov esi, eax
        next
        
        primitive charindex, 'charindex'
        ;; ( buff len ch -- index/-1 )
        pop eax
        pop ecx
        pop edi
        mov ebx, edi
        repne scasb
        jz charindex_found
        mov eax, -1
        push eax
        next
charindex_found:
        sub edi, ebx
        dec edi
        push edi
        next

        primitive streqp, 'str='
        ;; ( buff1 len1 buff2 len2 -- ? )
        push ebp
        mov ebp, esp
        push esi
        mov ebx, dword [ebp+4]
        mov edi, dword [ebp+8]
        mov eax, dword [ebp+12]
        mov esi, dword [ebp+16]
        cmp eax, ebx
        jne streqp_notequal
        mov ecx, eax
        repe cmpsb
        jne streqp_notequal
        mov eax, 0
        jmp streqp_done
streqp_notequal:
        mov eax, 1
streqp_done:
        pop esi
        pop ebp
        add esp, 16
        push eax
        next

        ;; a string containing the characters:
        ;;   space(32) newline(10) tab(9)
        stringconst whitespace, {32, 10, 9}

        forthword whitespacep, 'whitespace?'
        ;; ( ch -- ? )
        dd whitespace, rot, charindex
        dd lit, -1, notequalp
        dd exit

        ;; a string containing the characters:
        ;;   space(32) tab(9)
        stringconst spaces, {32, 9}
        
        forthword spacesp, 'spaces?'
        ;; ( ch -- ? )
        dd spaces, rot, charindex
        dd lit, -1, notequalp
        dd exit

        forthword spcp, 'spc?'
        ;; ( ch -- ? )
        dd lit, 32, equalp
        dd exit

        forthword nlp, 'nl?'
        ;; ( ch -- ? )
        dd lit, 10, equalp
        dd exit

        
;;;
;;; words to work with numbers
;;;


        stringconst errnotanum, 'err: not a number', F_HIDDEN

        primitive parsenum, 'parsenum', F_HIDDEN
        ;; ( buff len -- num? valid? )
        mov edx, 0              ; edx will hold sign, edx = 0 indicates positive
        mov ebx, 0              ; ebx will hold +ve value
        pop ecx                 ; len
        pop edi
        push esi
        mov esi, edi            ; esi points to buff
        pop edi                 ; edi holds next word address
        mov eax, 0              ; eax will hold each digit as they are processed
        lodsb
        cmp al, 45              ; starts with - sign?
        jnz parsenum_loop
        mov edx, 1              ; edx = 1 indicates negative
        dec ecx
        jz parsenum_invalid     ; buff containd only a minus sign
        lodsb
parsenum_loop:
        cmp al, 48              ; less than ascii 0?
        jb parsenum_invalid
        cmp al, 57
        ja parsenum_invalid     ; greater than ascii 9?
        sub al, 48
        imul ebx, 10
        add ebx, eax
        dec ecx
        jz parsenum_done_digits
        lodsb
        jmp parsenum_loop
parsenum_done_digits:
        cmp edx, 1              ; handle negative sign
        jnz parsenum_done
        imul ebx, -1
parsenum_done:
        mov esi, edi            ; restore next word address
        push ebx                ; parsed number
        push dword 0            ; valid = true
        next
parsenum_invalid:
        push dword 0            ; dummy number
        push dword 1            ; valid = false
        next

        forthword strtonum, 'str>num'
        ;; ( buff len -- num )
        dd parsenum, branchnz(strtonum_invalid)
        dd exit
strtonum_invalid: 
        dd errnotanum, fail

        
;;;
;;; memory access words
;;;
        

        primitive read4, '@'
        ;; ( addr -- x )
	pop eax
	push dword [eax]
	next

	primitive store4, '!'
        ;; ( x addr -- )
	pop eax			; address
	pop ebx			; value
	mov dword [eax], ebx
	next

	primitive read1, 'c@'
        ;; ( addr -- ch )
	pop eax
	mov bl, byte [eax]
	and ebx, 0xff
	push ebx
	next

	primitive store1, 'c!'
        ;; ( ch addr -- )
	pop eax			; address
	pop ebx			; value
	mov byte [eax], bl
	next

        forthword addstore4, '+!'
        ;; ( x addr -- )
        ;; add x to value at addr
        dd swap, over, read4, plus 
        dd swap, store4
        dd exit

        forthword mem, 'mem'
        ;; ( -- n )
        ;; returns free memory available for runtime allocation
        ;; in bytes
        dd lit, alloc_end
        dd here, read4
        dd minus
        dd exit

	
;;;
;;; words to work with the return stack
;;;


        primitive rsbase, 'rsbase'
        ;; ( -- addr )
        push return_stack_base
        next

        primitive peekrs, 'rs'
        ;; ( -- addr )
        push ebp
        next

        primitive pushrsp, '>rs'
        ;; ( n -- )
        pop eax
        pushrs eax
        next

        primitive poprsp, 'rs>'
        ;; ( -- n )
        poprs eax
        push eax
        next


;;;
;;; words to work with the parameter stack
;;;

        
section .bss
parameter_stack_base:
        resd 1
section .text

        primitive psbase, 'psbase'
        mov eax, dword [parameter_stack_base]
        push eax
        next

        primitive ps, 'ps'
        mov eax, esp
        push eax
        next


;;; 
;;; i/o words
;;;

section .bss
internal_var_eof:
	resd 1
section .text	
	
	primitive emit, 'emit'
        ;; ( ch -- )
        ;; write one character to stdout
	mov ebx, 1
        mov ecx, esp    	; cbuf is 1 character on the stack
	mov edx, 1
        mov eax, 4
	systemcall
	pop eax			; remove character from stack
        next

        forthword nl, 'nl'
        ;; ( -- )
        ;; write new line to stdout
        dd lit, 10, emit
        dd exit

	primitive key, 'key'
        ;; ( -- ch/0 )
        ;; reads a character from stdin
        ;; if end of stream is reached, eof is set to true and the
        ;; character placed on top of stack should be discarded
	push dword 0		; make room on stack for character
	mov ebx, 0
        mov ecx, esp            ; cbuf
	mov edx, 1
        mov eax, 3
	systemcall
        mov dword [internal_var_eof], eax
        next

	primitive eof, 'eof'
        ;; ( -- ? )
	push dword [internal_var_eof]
	next

        primitive write, 'write'
        ;; ( buff len -- )
        ;; write string starting at buff and length len to stdout
        mov ebx, 1
        pop edx
        pop ecx
        mov eax, 4
        systemcall
        next


;;;
;;; compiler words
;;;


        ;; points to start of free memory
        variable here

        ;; compile / interpret mode
        ;; 0 => interpret mode
        ;; 1 => compile mode
        variable mode

        forthword comma, ','
        ;; ( x -- )
        ;; store x at here, advance here by 1 cell
        dd here, read4, store4
        dd lit, 4, here, addstore4 
        dd exit

        forthword ccomma, 'c,'
        ;; ( ch -- )
        ;; store ch at here, advance here by 1 byte
        dd here, read4, store1
        dd lit, 1, here, addstore4 
        dd exit

        forthword copycomma, 'copy,'
        ;; ( addr len -- )
        ;; copy len bytes starting at addr to here and
        ;; advance here
        dd swap, over
        dd here, read4, strcpy 
        dd here, addstore4
        dd exit

        forthword create, 'create'
        ;; ( buff len -- )
        ;; start a word definition for word named(buff, len) at here
        ;; and advance here
        dd swap, over
        dd latestword, comma 
        dd copycomma, ccomma
        dd lit, 0, ccomma
        dd here, read4, latest, store4        
        dd lit, interpreter, comma                    
        dd exit

        forthword compilemode, ']'
        ;; ( -- )
        ;; switch to compile mode
        dd lit, 1, mode, store4 
        dd exit

        forthword interpretmode, '[', F_IMMEDIATE
        ;; ( -- )
        ;; switch to interpret mode
        dd lit, 0, mode, store4 
        dd exit

        forthword colon, ':'
        ;; ( -- )
        ;; scan a string from stdin and create a word thus named
        ;; and switch to compile mode
        dd prompt, read4, lit, 1, prompt, store4 
        dd scantoken, create, compilemode
        dd exit

        forthword semicolon, ';', F_IMMEDIATE
        ;; ( -- )
        ;; complete current word definition by compiling the
        ;; exit word and then switch back to interpret mode
        dd lit, exit, comma, interpretmode
        dd prompt, store4
        dd exit


;;;
;;; words to work with words
;;;


        primitive execute, 'execute'
        ;; ( ...a word -- ...b )
        ;; execute word on top of stack
        pop eax
        jmp dword [eax]

        forthword prevword, 'prevword'
        ;; ( word -- prevword )
        dd lit, 2, minus
        dd dup, read1, lit, 4, plus, minus
        dd read4
        dd exit

        forthword wordtoflags, 'word>flags', F_HIDDEN
        ;; ( word -- flags )
        dd oneminus, read1
        dd exit

        forthword setwordflags, 'wordflags!', F_HIDDEN
        ;; ( flags word -- )
        dd oneminus, store1
        dd exit

        forthword immediatep, 'immediate?'
        ;; ( word -- ? )
        dd wordtoflags, lit, F_IMMEDIATE
        dd bit, boolnot
        dd exit

        forthword immediate, 'immediate'
        ;; ( -- )
        ;; set latest word as an immediate word
        dd latestword, oneminus, dup 
        dd read1, lit, 1, bitor, swap, store1
        dd exit

        forthword hiddenp, 'hidden?'
        ;; ( word -- ? )
        dd wordtoflags, lit, F_HIDDEN
        dd bit, boolnot
        dd exit

        forthword hide, 'hide'
        ;; ( word -- )
        dd dup, wordtoflags, lit, F_HIDDEN
        dd bitor, swap, setwordflags
        dd exit

        forthword wordtostr, 'word>str'
        ;; ( word -- buff len )
        dd lit, 2, minus
        dd dup, read1, swap, over
        dd minus, swap
        dd exit

        forthword findword, 'findword', F_HIDDEN
        ;; ( buff len word -- word/0 )
findword_loop: 
        dd dup, branchnz(findword_not_last)
        dd nip, nip, exit
findword_not_last:      
        dd dup, prevword
        dd over, hiddenp
        dd branchnz(findword_not_hidden)
        dd nip, branch(findword_loop)
findword_not_hidden:    
        dd over, wordtostr
        dd lit, 5, pick, lit, 5, pick
        dd streqp
        dd branchnz(findword_not_same)
        dd drop, nip, nip, exit
findword_not_same:      
        dd nip, branch(findword_loop)

        ;; points to the last defined word
        ;; i.e. the begining of the aforth dictionary
        variable latest

        forthword latestword, 'latestword'
        ;; ( -- word )
        ;; places last defined word on top of stack
        dd latest, read4
        dd exit
        
        forthword wordf, 'word'
        ;; ( buff len -- word/0 )
        dd latestword, findword
        dd exit
        
        
;;;
;;; outer interpreter
;;; 

        
section .bss
internal_var_tokbuff:
        resb 256

section .text
        
        primitive tokenbuff, 'tokenbuff', F_HIDDEN
        ;; ( -- addr )
        ;; places start address of the token buffer on stack
        push internal_var_tokbuff
        next

        forthword discard, 'discard'
        ;; ( buff len -- ch/0 eof? )
        ;; read characters from stdin until a character not present
        ;; in the string(buff,len) is encountered. place this non-matching
        ;; character and eof flag on stack. if eof is true, then ch should
        ;; be discarded (its value will be 0)
discard_loop:  
	dd key, eof, branchnz(discard_not_eof)
        ;; ( buff len 0 )
        dd nip, nip, eof, exit
        ;; ( buff len ch )
discard_not_eof:        
        dd dup3, charindex, lit, -1, equalp
        ;; ( buff len ch ? )
        dd branchnz(discard_no_match)
        ;; ( buff len ch )
        dd nip, nip, eof, exit
        ;; ( buff len ch )
discard_no_match:       
        dd drop, branch(discard_loop)

        stringconst errlongtok, {'err: token too long (limit 256)', 10}, F_HIDDEN

        forthword readtoken, 'readtoken', F_HIDDEN
        ;; ( ch -- ws/0 buff len )
        ;; read a token (represented by buff and len) whose first character
        ;; is ch. if end of stream was reached then len will be zero. return
        ;; the token along with the last character read (or zero)
        dd lit, 0
        ;; ( ch index )
readtoken_loop:
        dd dup, tokenbuff, plus, swapd, store1, oneplus
        ;; ( index+1 )
        dd dup, lit, 256, lessthanp, branchz(readtoken_length_ok)
        ;; ( index+1 )
        dd errlongtok, fail
        ;; ( index+1 )
readtoken_length_ok:    
        dd key, eof, branchnz(readtoken_not_eof)
        ;; ( index+1 0 )
        dd tokenbuff, rot, exit
        ;; ( index+1 ch/ws )
readtoken_not_eof:      
        dd dup, whitespacep, branchnz(readtoken_not_ws)
        ;; ( index+1 ws )
        dd tokenbuff, rot, exit
        ;; ( index+1 ch )
readtoken_not_ws:       
        dd swap, branch(readtoken_loop)

        forthword scantoken, 'scantoken'
        ;; ( -- buff len )
        dd whitespace, discard
        dd branchnz(scantoken_not_eof)
        dd dup, exit
scantoken_not_eof:     
        dd readtoken
        dd rot, drop
        dd exit

        forthword executeorcomma, 'executeorcomma', F_HIDDEN
        ;; ( ...a word -- ...b )
        ;; interpret mode: execute word
        ;; compile mode: compiles word into current definition
        dd dup, immediatep
        dd branchz(executeorcomma_execute)
        dd mode, read4
        dd branchnz(executeorcomma_compile)
executeorcomma_execute:       
        dd execute, exit
executeorcomma_compile:   
        dd comma, exit

        forthword numorcomma, 'numorcomma', F_HIDDEN
        ;; ( ...a n -- ...b )
        ;; interpret mode: does nothing
        ;; compile mode: compiles literal n into current definition
        dd mode, read4
        dd branchnz(numorcomma_compile)
        dd exit
numorcomma_compile:        
        dd lit, lit, comma, comma, exit

        ;; controls if the prompt should be displayed or not
        ;; true(0) => show prompt
        ;; false(1) => hide prompt
        variable prompt

        stringconst promptstring, 'ok ', F_HIDDEN

        forthword pshowprompt, '?showprompt', F_HIDDEN
        ;; ( -- )
        dd prompt, read4
        dd branchnz(pshowprompt_no_prompt)
        dd promptstring, write
pshowprompt_no_prompt:  
        dd exit

        forthword processtoken, 'processtoken', F_HIDDEN
        ;; ( ..a buff len -- ..b )
        dd dup2, wordf
        dd dup, branchz(processtoken_not_word)
        dd nip, nip, executeorcomma, branch(processtoken_done)
processtoken_not_word:  
        dd drop, strtonum, numorcomma
processtoken_done:      
        dd exit

        forthword replline, 'repl-line', F_HIDDEN
        ;; ( ..a -- ..b eof )
replline_loop: 
        dd spaces, discard
        dd branchnz(replline_not_eof)
        dd exit
replline_not_eof:       
        dd dup, nlp, branchnz(replline_not_nl)
        dd exit
replline_not_nl:        
        dd readtoken, dup, lit, 0, equalp
        dd branchnz(replline_token_not_empty)
        dd nip, nip, exit
replline_token_not_empty:       
        dd rot, nlp
        dd branchnz(replline_no_nl_after_token)
        dd processtoken
        dd lit, 1, exit
replline_no_nl_after_token:     
        dd processtoken
        dd branch(replline_loop)

        forthword repl, 'repl', F_HIDDEN
        ;; ( ...a -- ...b )
repl_loop:      
        dd pshowprompt, replline
        dd branchnz(repl_loop)
        dd exit
        
        
;;;
;;; main
;;;

        
        forthword bootstrap, 'bootstrap', F_HIDDEN
	dd repl, quit

startsymbol:
        ;; set up dictionary pointer
        ;; (no further words should be defined within assembly)
        mov eax, lastword
        mov dword [var_data_latest], eax

        ;; set up here pointer
        mov eax, alloc_base
        mov dword [var_data_here], eax

        ;; set up outer interpreter mode
        mov eax, 0
        mov dword [var_data_mode], eax

        ;; store parameter stack base
        mov ebx, esp
        sub ebx, 4
        mov dword [parameter_stack_base], ebx

        ;; set up return stack
        mov ebp, return_stack_base - 4

        ;; set up the first forth word that will be
        ;; interpreted
        mov esi, bootstrap + 4

        ;; initialize repl state
        mov dword [var_data_prompt] , 1

        ;; jump to forth
        next

	
section .bss
return_stack_base:
        ;; return stack with a capacity of 200 items
        ;; (grows downwards, i.e. low memory -> high memory)
        resd 200
alloc_base:	
	resd 20000	; space for 20000 cells
alloc_end:
        resd 1          ; unused
