;;;
;;; aforth - a simple forth bootstrapped from 32-bit x86 assembly
;;; 
;;; compile: ./build.sh [linux|osx]
;;; run: cat aforth.f - | ./aforth
;;;

        
%ifdef OSX
%define STARTSYMBOL start
%else
%define STARTSYMBOL _start        
%endif        


;;;
;;; Macro definitions
;;; 
        
;;; Linux 32-bit style syscall abi handler:
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
;;; Push a value onto the return stack
;;;         
%macro pushrs 1
	add ebp, 4
	mov [ebp], %1
%endmacro

;;;
;;; Pop a value from the return stack
;;; 
%macro poprs 1
	mov %1, dword [ebp]
	sub ebp, 4
%endmacro	

;;;
;;; Keep track of the last defined word in assembly
;;; in order to maintain a chain of words in the
;;; forth dictionary
;;; 
%define lastword 0

;;;
;;; How words are structured in the `aforth` dictionary:
;;; +-----------------------------------------------------------+
;;; | Link | Name | Flags | Interpreter | Definition ...        |
;;; +-----------------------------------------------------------+
;;;
;;; Link        : address to the previously defined word (4 bytes)
;;; Name        : max 15 Bytes (0 padded on the right) (16 bytes)
;;; Flags       : to control behaviour of this word (1 byte)
;;; Interpreter : pointer to x86 code that can execute this word (4 bytes)
;;; Definition  : either x86 code or a pointers to other words (variable size)
;;; 
        
;;;
;;; macro: primitive ASMNAME, 'WORDNAME', FLAGS
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
;;; macro: forthword ASMNAME, 'WORDNAME', FLAGS
;;;
;;; non-primitive / compound words are words that are defined
;;; in terms of other words. Their definition consists of a
;;; list of pointers to other forth words. Thus they cannot be
;;; "executed" directly. Their interpreter word thus points to a
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
        dd INTERPRETER
%define lastword %1
%endmacro

;;;
;;; macro: stringconst ASMNAME, 'WORDNAME'
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
;;; macro: variable WORDNAME
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

        
global STARTSYMBOL

section .text

;;;
;;; Interpreter for forth words
;;; 1) Push the next word to be executed onto the return stack
;;; 2) Sets up the next word to be executed as the first word 
;;;    from the currently executing words definition
;;; 3) Execute next word
;;; 
INTERPRETER:  
	pushrs esi
	lea esi, [eax+4]
	next

;;;
;;; Core words
;;; 
        
	primitive EXIT, 'EXIT', 0
	poprs esi
	next

        primitive SWAP, 'SWAP', 0
        pop eax
        pop ebx
        push eax
        push ebx
        next

        primitive SWAP2, '2SWAP', 0
        pop ebx
        pop eax
        pop edx
        pop ecx
        push eax
        push ebx
        push ecx
        push edx
        next

        primitive SWAPD, 'SWAPD', 0
        pop eax
        pop ebx
        pop ecx
        push ebx
        push ecx
        push eax
        next
        
	primitive DUP, 'DUP', 0
	mov eax, dword [esp]
	push eax
	next

	primitive DUP2, '2DUP', 0
	mov eax, dword [esp+4]
	push eax
	mov eax, dword [esp+4]
	push eax
	next

        primitive DUP3, '3DUP', 0
        mov eax, dword [esp+8]
	push eax
	mov eax, dword [esp+8]
	push eax
	mov eax, dword [esp+8]
	push eax
        next

	primitive DROP, 'DROP', 0
	pop eax
	next

	primitive DROP2, '2DROP', 0
	pop eax
	pop eax
	next

        primitive DROP3, '3DROP', 0
        pop eax
        pop eax
        pop eax
        next

	primitive OVER, 'OVER', 0
	mov eax, dword [esp + 4]
	push eax
	next

	primitive NIP, 'NIP', 0
	pop eax
	pop ebx
	push eax
	next

        primitive ROT, 'ROT', 0
        pop ecx
        pop ebx
        pop eax
        push ebx
        push ecx
        push eax
        next

        primitive ROTR, '-ROT', 0
        pop ecx
        pop ebx
        pop eax
        push ecx
        push eax
        push ebx
        next

        primitive PICK, 'PICK', 0
        pop eax
        mov ebx, dword [esp + 4*eax]
        push ebx
        next

        
;;;
;;; Comparison words
;;; 
        
        
	primitive EQUALP, '=', 0
	pop eax
	pop ebx
	cmp eax, ebx
	jz EQUALP_true
	push 1
	next
EQUALP_true:
	push 0
	next

	forthword NOTEQUALP, '!=', 0
	dd EQUALP, BOOLNOT
        dd EXIT

        primitive LESSTHANP, '<', 0
        pop ebx
        pop eax
        cmp eax, ebx
        jb LESSTHANP_true
        push 1
        next
LESSTHANP_true:
        push 0
        next

        forthword GREATERTHANP, '>', 0
        dd DUP2, LESSTHANP
        dd ROTR, EQUALP
        dd BOOLOR, BOOLNOT
        dd EXIT
        
        primitive LIT, 'LIT', 0
        push dword [esi]
        add esi, 4
        next

	primitive BRANCH, 'BRANCH', 0
	pop eax
	lea esi, [esi + 4*eax]
	next

	primitive BRANCHZ, 'BRANCHZ', 0
	pop eax			; offset
	pop ebx			; value
	cmp ebx, 0
	jz BRANCHZ_jump
	next
BRANCHZ_jump:
	lea esi, [esi + 4*eax]
	next

        primitive BRANCHNZ, 'BRANCHNZ', 0
	pop eax			; offset
	pop ebx			; value
	cmp ebx, 0
	jnz BRANCHZ_jump
	next
BRANCHNZ_jump:
	lea esi, [esi + 4*eax]
	next

        forthword CHOOSE, '?', 0
        dd LIT, 2, BRANCHNZ
        dd DROP, EXIT
        dd NIP, EXIT

        forthword CHOOSE2, '2?', 0
        dd LIT, 2, BRANCHNZ
        dd DROP2, EXIT
        dd ROT, DROP
        dd ROT, DROP
        dd EXIT


;;;
;;; System words
;;;

        primitive QUIT, 'QUIT', 0
        mov ebx, 0
        mov eax, 1
	systemcall
        next

        primitive ERRORQUIT, 'ERRORQUIT', 0
        mov ebx, 1
        mov eax, 1
        systemcall
        next

        forthword FAIL, 'FAIL', 0
        dd WRITE, ERRORQUIT

        
;;; 
;;; Arithmetic words
;;; 

	primitive ONEPLUS, '1+', 0
	inc dword [esp]
	next

	primitive ONEMINUS, '1-', 0
	dec dword [esp]
	next

	primitive PLUS, '+', 0
	pop eax
	add dword [esp], eax
	next

	primitive MINUS, '-', 0
	pop eax
	sub dword [esp], eax
	next

        primitive MULTIPLY, '*', 0
        pop eax
        pop ebx
        imul ebx
        push eax
        next

        primitive DIVMOD, '/MOD', 0
        pop ebx
        pop eax
        cdq
        idiv ebx
        push eax
        push edx
        next


;;;
;;; Boolean logic words
;;;

        primitive BOOLAND, 'AND', 0
        pop ebx
        pop eax
        cmp eax, 0
        je BOOLAND_2nd
        push eax
        next
BOOLAND_2nd:
        push ebx
        next

        primitive BOOLOR, 'OR', 0
        pop ebx
        pop eax
        cmp eax, 0
        jne BOOLOR_2nd
        push eax
        next
BOOLOR_2nd:
        push ebx
        next

        primitive BOOLNOT, 'NOT', 0
        pop eax
        cmp eax, 0
        je BOOLNOT_true
        push dword 0
        next
BOOLNOT_true:
        push dword 1
        next

        primitive TRUE, 'TRUE', 0
        push dword 0
        next

        primitive FALSE, 'FALSE', 0
        push dword 1
        next

        
;;;
;;; Bitwise operation words
;;;


        primitive BITOR, '|', 0
        pop ebx     
        pop eax
        or eax, ebx
        push eax
        next

        primitive BITAND, '&', 0
        pop ebx
        pop eax
        and eax, ebx
        push eax
        next

        primitive BITNOT, 'INVERT', 0
        pop eax
        not eax
        push eax
        next
        
        
;;;
;;; String manipulation words
;;;


        primitive STRCPY, 'STRCPY', 0
        mov eax, esi
        pop edi
        pop ecx
        pop esi
        rep movsb
        mov esi, eax
        next
        
        forthword CHARINDEX, 'CHARINDEX', 0
        dd ROT
        dd LIT, 0
        dd DUP2, PLUS, READ1
        dd LIT, 3, PICK, EQUALP
        dd LIT, 4, BRANCHNZ
        dd NIP, NIP, NIP, EXIT
        dd ONEPLUS, LIT, 3, PICK, OVER, GREATERTHANP
        dd LIT, 5, BRANCHZ
        dd DROP2, DROP2, LIT, -1, EXIT
        dd LIT, -31, BRANCH

        primitive CSTRLEN, 'CSTRLEN', 0
        pop edi
        mov al, 0
        mov ecx, 15
        repne scasb
        mov eax, 15
        sub eax, ecx
        dec eax
        push eax
        next

        primitive STREQP, 'STR=', 0
        push ebp
        mov ebp, esp
        push esi
        mov ebx, dword [ebp+4]
        mov edi, dword [ebp+8]
        mov eax, dword [ebp+12]
        mov esi, dword [ebp+16]
        cmp eax, ebx
        jne STREQP_notequal
        mov ecx, eax
        repe cmpsb
        jne STREQP_notequal
        mov eax, 0
        jmp STREQP_done
STREQP_notequal:
        mov eax, 1
STREQP_done:
        pop esi
        pop ebp
        add esp, 16
        push eax
        next

        stringconst WHITESPACE, {32, 13, 10, 9}

        forthword WHITESPACEP, 'WHITESPACE?', 0
        dd WHITESPACE, ROT, CHARINDEX
        dd LIT, -1, NOTEQUALP
        dd EXIT

        
;;;
;;; Memory access words
;;;
        

        primitive MEMSET, 'MEMSET', 0
        pop eax
        pop ecx
        pop edi
        rep stosb
        next

	primitive READ4, '@', 0
	pop eax
	push dword [eax]
	next

	primitive STORE4, '!', 0
	pop eax			; address
	pop ebx			; value
	mov dword [eax], ebx
	next

	primitive READ1, 'C@', 0
	pop eax
	mov bl, byte [eax]
	and ebx, 0xFF
	push ebx
	next

	primitive STORE1, 'c!', 0
	pop eax			; address
	pop ebx			; value
	mov byte [eax], bl
	next

        forthword ADDSTORE4, '+!', 0
        dd SWAP, OVER, READ4, PLUS 
        dd SWAP, STORE4
        dd EXIT

	
;;; 
;;; I/O words
;;;

section .bss
internal_var_eof:
	resd 1
section .text	
	
	primitive EMIT, 'EMIT', 0
	mov ebx, 1
        mov ecx, esp    	; cbuf is 1 character on the stack
	mov edx, 1
        mov eax, 4
	systemcall
	pop eax			; remove character from stack
        next

        forthword NL, 'NL', 0
        dd LIT, 10, EMIT
        dd EXIT

	primitive KEY, 'KEY', 0
	push dword 0		; make room on stack for character
	mov ebx, 0
        mov ecx, esp            ; cbuf
	mov edx, 1
        mov eax, 3
	systemcall
        mov dword [internal_var_eof], eax
        next

	primitive EOF, 'EOF', 0
	push dword [internal_var_eof]
	next

        primitive WRITE, 'WRITE', 0
        mov ebx, 1
        pop edx
        pop ecx
        mov eax, 4
        systemcall
        next

        forthword DISCARD, 'DISCARD', 0
	dd KEY, EOF, LIT, 2, BRANCHNZ
        dd EOF, EXIT
        dd DUP3, CHARINDEX, LIT, -1, EQUALP
        dd LIT, 4, BRANCHNZ
        dd NIP, NIP, EOF, EXIT
        dd DROP, LIT, -23, BRANCH


;;;
;;; Compiler words
;;;


        variable HERE

        variable MODE

        forthword COMMA, ',', 0
        dd HERE, READ4, STORE4
        dd LIT, 4, HERE, ADDSTORE4 
        dd EXIT

        forthword CCOMMA, 'C,', 0
        dd HERE, READ4, STORE1
        dd LIT, 1, HERE, ADDSTORE4 
        dd EXIT

        forthword COPYCOMMA, 'COPY,', 0
        dd SWAP, OVER
        dd HERE, READ4, STRCPY 
        dd HERE, ADDSTORE4
        dd EXIT

        forthword ZEROSCOMMA, 'ZEROS,', 0
        dd HERE, READ4, OVER, LIT, 0, MEMSET
        dd HERE, ADDSTORE4
        dd EXIT

        forthword CREATE, 'CREATE', 0
        dd SWAP, OVER
        dd LATESTWORD, COMMA                    
        dd COPYCOMMA, LIT, 16, SWAP, MINUS, ZEROSCOMMA
        dd HERE, READ4, LATEST, STORE4        
        dd LIT, INTERPRETER, COMMA                    
        dd EXIT

        forthword COMPILEMODE, ']', 0
        dd LIT, 1, MODE, STORE4 
        dd EXIT

        forthword INTERPRETMODE, '[', 1
        dd LIT, 0, MODE, STORE4 
        dd EXIT

        forthword COLON, ':', 0
        dd SCANTOKEN, CREATE, COMPILEMODE
        dd EXIT

        forthword IMMEDIATE, 'IMMEDIATE', 0
        dd LATESTWORD, ONEMINUS, DUP 
        dd READ1, LIT, 1, BITOR, SWAP, STORE1
        dd EXIT

        forthword SEMICOLON, ';', 1
        dd LIT, EXIT, COMMA, INTERPRETMODE
        dd EXIT
        
        
;;;
;;; Outer interpreter
;;; 

        
section .bss
internal_var_tokbuff:
        resb 256

section .text
        
        primitive TOKENBUFF, 'TOKENBUFF', 0
        push internal_var_tokbuff
        next
        
        stringconst ERRLONGTOK, {'ERR: token too long (limit 15)', 10}

        forthword READTOKEN, 'READTOKEN', 0
        dd LIT, 4, BRANCHNZ
        dd TOKENBUFF, LIT, 0, EXIT
        dd LIT, 0
        dd DUP, TOKENBUFF, PLUS, SWAPD, STORE1, ONEPLUS
        dd DUP, LIT, 16, LESSTHANP, LIT, 2, BRANCHZ
        dd ERRLONGTOK, FAIL
        dd KEY, EOF, LIT, 4, BRANCHNZ
        dd DROP, TOKENBUFF, SWAP, EXIT
        dd DUP, WHITESPACEP, LIT, 4, BRANCHNZ
        dd DROP, TOKENBUFF, SWAP, EXIT
        dd SWAP, LIT, -37, BRANCH

        forthword SCANTOKEN, 'SCANTOKEN', 0
        dd WHITESPACE, DISCARD, READTOKEN
        dd EXIT

        primitive EXECUTE, 'EXECUTE', 0
        pop eax
        jmp dword [eax]

        stringconst ERRNOTANUM, 'ERR: not a number'
        
        forthword SIGNANDNUMSTR, 'SIGNANDNUMSTR', 0
        dd OVER, READ1, LIT, 45, EQUALP, LIT, 14, BRANCHNZ
        dd DUP, LIT, 1, EQUALP, LIT, 2, BRANCHNZ
        dd ERRNOTANUM, FAIL
        dd LIT, 1, LIT, 2, BRANCH
        dd LIT, 0
        dd ROTR
        dd LIT, 2, PICK, MINUS
        dd SWAP, LIT, 2, PICK, PLUS
        dd SWAP, EXIT

        forthword STRTOPOSINT, 'STRTOPOSINT', 0
        dd LIT, 0, DUP
        dd LIT, 3, PICK, OVER, PLUS, READ1
        dd DUP, LIT, 48, LESSTHANP, LIT, 2, BRANCHNZ
        dd ERRNOTANUM, FAIL
        dd DUP, LIT, 57, GREATERTHANP, LIT, 2, BRANCHNZ
        dd ERRNOTANUM, FAIL
        dd LIT, 48, MINUS
        dd ROT, LIT, 10, MULTIPLY, PLUS, SWAP, ONEPLUS
        dd LIT, 2, PICK, OVER, GREATERTHANP
        dd LIT, -42, BRANCHZ
        dd DROP, ROTR, DROP2
        dd EXIT

        forthword SIGNED, 'SIGNED', 0
        dd SWAP, LIT, 1, BRANCHNZ
        dd EXIT
        dd LIT, -1, MULTIPLY, EXIT

        forthword STRTONUM, 'STR>NUM', 0
        dd SIGNANDNUMSTR, STRTOPOSINT, SIGNED
        dd EXIT

        forthword PREVWORD, 'PREVWORD', 0
        dd LIT, 20, MINUS, READ4
        dd EXIT

        forthword WORDTOFLAGS, 'WORD>FLAGS', 0
        dd ONEMINUS, READ1, EXIT

        forthword IMMEDIATEP, 'IMMEDIATE?', 0
        dd WORDTOFLAGS, LIT, 1, BITAND
        dd BITNOT, LIT, 1, BITAND
        dd EXIT

        forthword WORDTOSTR, 'WORD>STR', 0
        dd LIT, 16, MINUS
        dd DUP, CSTRLEN
        dd EXIT

        forthword FINDWORD, 'FINDWORD', 0
        dd DUP, LIT, 3, BRANCHNZ
        dd NIP, NIP, EXIT
        dd DUP, PREVWORD
        dd OVER, WORDTOSTR
        dd LIT, 5, PICK, LIT, 5, PICK
        dd STREQP
        dd LIT, 4, BRANCHNZ
        dd DROP, NIP, NIP, EXIT
        dd NIP, LIT, -29, BRANCH

        variable LATEST

        forthword LATESTWORD, 'LATESTWORD', 0
        dd LATEST, READ4
        dd EXIT
        
        forthword WORDF, 'WORD', 0
        dd LATESTWORD, FINDWORD
        dd EXIT

        forthword EXECUTEORCOMMA, 'EXECUTEORCOMMA', 0
        dd DUP, IMMEDIATEP
        dd LIT, 5, BRANCHZ
        dd MODE, READ4
        dd LIT, 2, BRANCHNZ
        dd EXECUTE, EXIT
        dd COMMA, EXIT

        forthword NUMORCOMMA, 'NUMORCOMMA', 0
        dd MODE, READ4
        dd LIT, 1, BRANCHNZ
        dd EXIT
        dd LIT, LIT, COMMA, COMMA, EXIT

        forthword REPL, 'REPL', 0
        dd SCANTOKEN, DUP, LIT, 1, BRANCHNZ
        dd QUIT
        dd DUP2, WORDF
        dd DUP, LIT, 6, BRANCHZ
        dd NIP, NIP, EXECUTEORCOMMA, LIT, 3, BRANCH
        dd DROP, STRTONUM, NUMORCOMMA
        dd LIT, -24, BRANCH
        
        
;;;
;;; Main
;;;


bootstrap:
	dd REPL

STARTSYMBOL:
        ;; set up dictionary pointer
        mov eax, lastword
        mov dword [var_data_LATEST], eax

        ;; set up HERE pointer
        mov eax, alloc_base
        mov dword [var_data_HERE], eax

        ;; set up outer interpreter mode
        mov eax, 0
        mov dword [var_data_MODE], eax

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
        
