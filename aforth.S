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
%ifdef OSX
        push edx
        push ecx
        push ebx
        push eax
%endif
        int 0x80
%ifdef OSX
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
;;; keep track of the last defined word in assembly
;;; in order to maintain a chain of words in the
;;; forth dictionary
;;; 
%define lastword 0

;;;
;;; how words are structured in the `aforth` dictionary:
;;; +-----------------------------------------------------------+
;;; | link | name | flags | interpreter | definition ...        |
;;; +-----------------------------------------------------------+
;;;
;;; link        : address to the previously defined word (4 bytes)
;;; name        : max 15 bytes (0 padded on the right) (16 bytes)
;;; flags       : to control behaviour of this word (1 byte)
;;; interpreter : pointer to x86 code that can execute this word (4 bytes)
;;; definition  : either x86 code or a pointers to other words (variable size)
;;; 
        
;;;
;;; macro: primitive asmname, 'wordname', flags
;;; 
;;; primitive words do not need an interpreter, so their
;;; interpreter pointer simply points to the start of their
;;; x86 instructions
;;;
%macro primitive 3
%1_dict_entry:        
        dd lastword
%1_name:
        db %2
        times 15-($-%1_name) db 0
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
%macro forthword 3
%1_dict_entry:   
        dd lastword
%1_name:
        db %2
        times 15-($-%1_name) db 0
        db %3
%1:
        dd interpreter
%define lastword %1
%endmacro

;;;
;;; macro: stringconst asmname, 'wordname'
;;;
;;; this macro defines a forth word that when executed simply places
;;; on the stack (a) the address of the string buffer, (b) the string length
;;; 
%macro stringconst 2
section .data
str_data_%1:	db %2
str_len_%1:     equ $-str_data_%1
section .text
	%defstr variable_name %1
	primitive %1, variable_name, 0
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
%macro variable 1
section .bss
var_data_%1:	
	resd 1
section .text
	%defstr variable_name %1
	primitive %1, variable_name, 0
	push var_data_%1
	next
%endmacro	

        
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
        
	primitive exit, 'exit', 0
	poprs esi
	next

        primitive swap, 'swap', 0
        pop eax
        pop ebx
        push eax
        push ebx
        next

        primitive swap2, '2swap', 0
        pop ebx
        pop eax
        pop edx
        pop ecx
        push eax
        push ebx
        push ecx
        push edx
        next

        primitive swapd, 'swapd', 0
        pop eax
        pop ebx
        pop ecx
        push ebx
        push ecx
        push eax
        next
        
	primitive dup, 'dup', 0
	mov eax, dword [esp]
	push eax
	next

	primitive dup2, '2dup', 0
	mov eax, dword [esp+4]
	push eax
	mov eax, dword [esp+4]
	push eax
	next

        primitive dup3, '3dup', 0
        mov eax, dword [esp+8]
	push eax
	mov eax, dword [esp+8]
	push eax
	mov eax, dword [esp+8]
	push eax
        next

	primitive drop, 'drop', 0
	pop eax
	next

	primitive drop2, '2drop', 0
	pop eax
	pop eax
	next

        primitive drop3, '3drop', 0
        pop eax
        pop eax
        pop eax
        next

	primitive over, 'over', 0
	mov eax, dword [esp + 4]
	push eax
	next

	primitive nip, 'nip', 0
	pop eax
	pop ebx
	push eax
	next

        primitive rot, 'rot', 0
        pop ecx
        pop ebx
        pop eax
        push ebx
        push ecx
        push eax
        next

        primitive rotr, '-rot', 0
        pop ecx
        pop ebx
        pop eax
        push ecx
        push eax
        push ebx
        next

        primitive pick, 'pick', 0
        pop eax
        mov ebx, dword [esp + 4*eax]
        push ebx
        next

        
;;;
;;; comparison words
;;; 
        
        
	primitive equalp, '=', 0
	pop eax
	pop ebx
	cmp eax, ebx
	jz equalp_true
	push 1
	next
equalp_true:
	push 0
	next

	forthword notequalp, '!=', 0
	dd equalp, boolnot
        dd exit

        primitive lessthanp, '<', 0
        pop ebx
        pop eax
        cmp eax, ebx
        jl lessthanp_true
        push 1
        next
lessthanp_true:
        push 0
        next

        forthword greaterthanp, '>', 0
        dd dup2, lessthanp
        dd rotr, equalp
        dd boolor, boolnot
        dd exit
        
        primitive lit, 'lit', 0
        push dword [esi]
        add esi, 4
        next

	primitive branch, 'branch', 0
	pop eax
	lea esi, [esi + 4*eax]
	next

	primitive branchz, 'branchz', 0
	pop eax			; offset
	pop ebx			; value
	cmp ebx, 0
	jz branchz_jump
	next
branchz_jump:
	lea esi, [esi + 4*eax]
	next

        primitive branchnz, 'branchnz', 0
	pop eax			; offset
	pop ebx			; value
	cmp ebx, 0
	jnz branchz_jump
	next
branchnz_jump:
	lea esi, [esi + 4*eax]
	next

        forthword choose, '?', 0
        dd lit, 2, branchnz
        dd drop, exit
        dd nip, exit

        forthword choose2, '2?', 0
        dd lit, 2, branchnz
        dd drop2, exit
        dd rot, drop
        dd rot, drop
        dd exit


;;;
;;; system words
;;;

        primitive quit, 'quit', 0
        mov ebx, 0
        mov eax, 1
	systemcall
        next

        primitive errorquit, 'errorquit', 0
        mov ebx, 1
        mov eax, 1
        systemcall
        next

        forthword fail, 'fail', 0
        dd write, errorquit

        
;;; 
;;; arithmetic words
;;; 

	primitive oneplus, '1+', 0
	inc dword [esp]
	next

	primitive oneminus, '1-', 0
	dec dword [esp]
	next

	primitive plus, '+', 0
	pop eax
	add dword [esp], eax
	next

	primitive minus, '-', 0
	pop eax
	sub dword [esp], eax
	next

        primitive multiply, '*', 0
        pop eax
        pop ebx
        imul ebx
        push eax
        next

        primitive divmod, '/mod', 0
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

        primitive booland, 'and', 0
        pop ebx
        pop eax
        cmp eax, 0
        je booland_2nd
        push eax
        next
booland_2nd:
        push ebx
        next

        primitive boolor, 'or', 0
        pop ebx
        pop eax
        cmp eax, 0
        jne boolor_2nd
        push eax
        next
boolor_2nd:
        push ebx
        next

        primitive boolnot, 'not', 0
        pop eax
        cmp eax, 0
        je boolnot_true
        push dword 0
        next
boolnot_true:
        push dword 1
        next

        primitive true, 'true', 0
        push dword 0
        next

        primitive false, 'false', 0
        push dword 1
        next

        
;;;
;;; bitwise operation words
;;;


        primitive bitor, '|', 0
        pop ebx     
        pop eax
        or eax, ebx
        push eax
        next

        primitive bitand, '&', 0
        pop ebx
        pop eax
        and eax, ebx
        push eax
        next

        primitive bitnot, 'invert', 0
        pop eax
        not eax
        push eax
        next
        
        
;;;
;;; string manipulation words
;;;


        primitive strcpy, 'strcpy', 0
        mov eax, esi
        pop edi
        pop ecx
        pop esi
        rep movsb
        mov esi, eax
        next
        
        primitive charindex, 'charindex', 0
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

        primitive cstrlen, 'cstrlen', 0
        pop edi
        mov al, 0
        mov ecx, 15
        repne scasb
        mov eax, 15
        sub eax, ecx
        dec eax
        push eax
        next

        primitive streqp, 'str=', 0
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

        stringconst whitespace, {32, 13, 10, 9}

        forthword whitespacep, 'whitespace?', 0
        dd whitespace, rot, charindex
        dd lit, -1, notequalp
        dd exit

        
;;;
;;; memory access words
;;;
        

        primitive memset, 'memset', 0
        pop eax
        pop ecx
        pop edi
        rep stosb
        next

	primitive read4, '@', 0
	pop eax
	push dword [eax]
	next

	primitive store4, '!', 0
	pop eax			; address
	pop ebx			; value
	mov dword [eax], ebx
	next

	primitive read1, 'c@', 0
	pop eax
	mov bl, byte [eax]
	and ebx, 0xff
	push ebx
	next

	primitive store1, 'c!', 0
	pop eax			; address
	pop ebx			; value
	mov byte [eax], bl
	next

        forthword addstore4, '+!', 0
        dd swap, over, read4, plus 
        dd swap, store4
        dd exit

	
;;; 
;;; i/o words
;;;

section .bss
internal_var_eof:
	resd 1
section .text	
	
	primitive emit, 'emit', 0
	mov ebx, 1
        mov ecx, esp    	; cbuf is 1 character on the stack
	mov edx, 1
        mov eax, 4
	systemcall
	pop eax			; remove character from stack
        next

        forthword nl, 'nl', 0
        dd lit, 10, emit
        dd exit

	primitive key, 'key', 0
	push dword 0		; make room on stack for character
	mov ebx, 0
        mov ecx, esp            ; cbuf
	mov edx, 1
        mov eax, 3
	systemcall
        mov dword [internal_var_eof], eax
        next

	primitive eof, 'eof', 0
	push dword [internal_var_eof]
	next

        primitive write, 'write', 0
        mov ebx, 1
        pop edx
        pop ecx
        mov eax, 4
        systemcall
        next

        forthword discard, 'discard', 0
	dd key, eof, lit, 2, branchnz
        dd eof, exit
        dd dup3, charindex, lit, -1, equalp
        dd lit, 4, branchnz
        dd nip, nip, eof, exit
        dd drop, lit, -23, branch


;;;
;;; compiler words
;;;


        variable here

        variable mode

        forthword comma, ',', 0
        dd here, read4, store4
        dd lit, 4, here, addstore4 
        dd exit

        forthword ccomma, 'c,', 0
        dd here, read4, store1
        dd lit, 1, here, addstore4 
        dd exit

        forthword copycomma, 'copy,', 0
        dd swap, over
        dd here, read4, strcpy 
        dd here, addstore4
        dd exit

        forthword zeroscomma, 'zeros,', 0
        dd here, read4, over, lit, 0, memset
        dd here, addstore4
        dd exit

        forthword create, 'create', 0
        dd swap, over
        dd latestword, comma                    
        dd copycomma, lit, 16, swap, minus, zeroscomma
        dd here, read4, latest, store4        
        dd lit, interpreter, comma                    
        dd exit

        forthword compilemode, ']', 0
        dd lit, 1, mode, store4 
        dd exit

        forthword interpretmode, '[', 1
        dd lit, 0, mode, store4 
        dd exit

        forthword colon, ':', 0
        dd scantoken, create, compilemode
        dd exit

        forthword immediate, 'immediate', 0
        dd latestword, oneminus, dup 
        dd read1, lit, 1, bitor, swap, store1
        dd exit

        forthword semicolon, ';', 1
        dd lit, exit, comma, interpretmode
        dd exit
        
        
;;;
;;; outer interpreter
;;; 

        
section .bss
internal_var_tokbuff:
        resb 256

section .text
        
        primitive tokenbuff, 'tokenbuff', 0
        push internal_var_tokbuff
        next
        
        stringconst errlongtok, {'err: token too long (limit 15)', 10}

        forthword readtoken, 'readtoken', 0
        dd lit, 4, branchnz
        dd tokenbuff, lit, 0, exit
        dd lit, 0
        dd dup, tokenbuff, plus, swapd, store1, oneplus
        dd dup, lit, 16, lessthanp, lit, 2, branchz
        dd errlongtok, fail
        dd key, eof, lit, 4, branchnz
        dd drop, tokenbuff, swap, exit
        dd dup, whitespacep, lit, 4, branchnz
        dd drop, tokenbuff, swap, exit
        dd swap, lit, -37, branch

        forthword scantoken, 'scantoken', 0
        dd whitespace, discard, readtoken
        dd exit

        primitive execute, 'execute', 0
        pop eax
        jmp dword [eax]

        stringconst errnotanum, 'err: not a number'
        
        forthword signandnumstr, 'signandnumstr', 0
        dd over, read1, lit, 45, equalp, lit, 14, branchnz
        dd dup, lit, 1, equalp, lit, 2, branchnz
        dd errnotanum, fail
        dd lit, 1, lit, 2, branch
        dd lit, 0
        dd rotr
        dd lit, 2, pick, minus
        dd swap, lit, 2, pick, plus
        dd swap, exit

        forthword strtoposint, 'strtoposint', 0
        dd lit, 0, dup
        dd lit, 3, pick, over, plus, read1
        dd dup, lit, 48, lessthanp, lit, 2, branchnz
        dd errnotanum, fail
        dd dup, lit, 57, greaterthanp, lit, 2, branchnz
        dd errnotanum, fail
        dd lit, 48, minus
        dd rot, lit, 10, multiply, plus, swap, oneplus
        dd lit, 2, pick, over, greaterthanp
        dd lit, -42, branchz
        dd drop, rotr, drop2
        dd exit

        forthword signed, 'signed', 0
        dd swap, lit, 1, branchnz
        dd exit
        dd lit, -1, multiply, exit

        forthword strtonum, 'str>num', 0
        dd signandnumstr, strtoposint, signed
        dd exit

        forthword prevword, 'prevword', 0
        dd lit, 20, minus, read4
        dd exit

        forthword wordtoflags, 'word>flags', 0
        dd oneminus, read1, exit

        forthword immediatep, 'immediate?', 0
        dd wordtoflags, lit, 1, bitand
        dd bitnot, lit, 1, bitand
        dd exit

        forthword wordtostr, 'word>str', 0
        dd lit, 16, minus
        dd dup, cstrlen
        dd exit

        forthword findword, 'findword', 0
        dd dup, lit, 3, branchnz
        dd nip, nip, exit
        dd dup, prevword
        dd over, wordtostr
        dd lit, 5, pick, lit, 5, pick
        dd streqp
        dd lit, 4, branchnz
        dd drop, nip, nip, exit
        dd nip, lit, -29, branch

        variable latest

        forthword latestword, 'latestword', 0
        dd latest, read4
        dd exit
        
        forthword wordf, 'word', 0
        dd latestword, findword
        dd exit

        forthword executeorcomma, 'executeorcomma', 0
        dd dup, immediatep
        dd lit, 5, branchz
        dd mode, read4
        dd lit, 2, branchnz
        dd execute, exit
        dd comma, exit

        forthword numorcomma, 'numorcomma', 0
        dd mode, read4
        dd lit, 1, branchnz
        dd exit
        dd lit, lit, comma, comma, exit

        forthword repl, 'repl', 0
        dd scantoken, dup, lit, 1, branchnz
        dd quit
        dd dup2, wordf
        dd dup, lit, 6, branchz
        dd nip, nip, executeorcomma, lit, 3, branch
        dd drop, strtonum, numorcomma
        dd lit, -24, branch
        
        
;;;
;;; main
;;;


bootstrap:
	dd repl

startsymbol:
        ;; set up dictionary pointer
        mov eax, lastword
        mov dword [var_data_latest], eax

        ;; set up here pointer
        mov eax, alloc_base
        mov dword [var_data_here], eax

        ;; set up outer interpreter mode
        mov eax, 0
        mov dword [var_data_mode], eax

        ;; set up return stack
        mov ebp, return_stack_base	

        ;; set up the first forth word that will be
        ;; interpreted
        mov esi, bootstrap

        ;; jump to forth
        next

	
section .bss
return_stack_base:
        resd 1	 	; return stack with a capacity of 200 items
        resd 200 	; (grows downwards, i.e. low memory -> high memory)
alloc_base:	
	resd 20000	; space for 20000 cells
        
