%ifdef OSX
%define STARTSYMBOL start
%else
%define STARTSYMBOL _start        
%endif        

;; linux 32-bit style syscall abi handler:
;; * pass syscall number in eax
;; * pass params in: ebx, ecx, edx
;; * supports syscalls having upto 3 parameter 
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
        
%macro next 0
        lodsd
        jmp [eax]
%endmacro

%macro pushrs 1
	add ebp, 4
	mov [ebp], %1
%endmacro

%macro poprs 1
	mov %1, dword [ebp]
	sub ebp, 4
%endmacro	

%define lastword 0
        
;;
;; primitive ASMNAME, 'WORDNAME', FLAGS
;;
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
        
global STARTSYMBOL

section .text
	primitive DOCOL, 'DOCOL', 0
	pushrs esi
	lea esi, [eax+4]
	next

	primitive EXIT, 'EXIT', 0
	poprs esi
	next

;;
;; forthword ASMNAME, 'WORDNAME', FLAGS
;;
%macro forthword 3
%1_dict_entry:   
        dd lastword
%1_name:
        db %2
        times 15-($-%1_name) db 0
        db %3
%1:
        dd DOCOL_asm
%define lastword %1
%endmacro

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
        dd NL, WRITE, NL, ERRORQUIT

        primitive SWAP, 'SWAP', 0
        pop eax
        pop ebx
        push eax
        push ebx
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

        primitive NIP2, '2NIP', 0
        pop ebx
        pop eax
        add esp, 8
        push eax
        push ebx
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

	primitive NOTEQUALP, '!=', 0
	pop eax
	pop ebx
	cmp eax, ebx
	jz NOTEQUALP_true
	push 0
	next
NOTEQUALP_true:
	push 1
	next

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

        primitive GREATERTHANP, '>', 0
        pop ebx
        pop eax
        cmp eax, ebx
        ja GREATERTHANP_true
        push 1
        next
GREATERTHANP_true:
        push 0
        next

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
        dd NIP2, EXIT

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

        primitive MULTIPLY, 'MUL', 0
        pop eax
        pop ebx
        mul ebx
        push eax
        next


;;;
;;; Logic words
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

;;;
;;; String words
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
;;; Memory access
;;;

	primitive READ4, '@', 0
	pop eax
	push dword [eax]
	next

	primitive STORE4, '!', 0
	pop eax			; address
	pop ebx			; value
	mov dword [eax], ebx
	next

	primitive READ1, 'c@', 0
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
	mov ebx, 1
        mov ecx, esp            ; cbuf
	mov edx, 1
        mov eax, 3
	systemcall
        mov dword [internal_var_eof], eax
        next

	primitive EOF, 'EOF', 0
	push dword [internal_var_eof]
	next

        forthword WRITE, 'WRITE', 0
        dd DUP, LIT, 1, BRANCHNZ
        dd EXIT
        dd LIT, 0
        dd LIT, 2, PICK, OVER
        dd PLUS, READ1, EMIT, ONEPLUS
        dd DUP2, EQUALP, LIT, -13, BRANCHNZ
        dd DROP3, EXIT

        forthword DISCARD, 'DISCARD', 0
	dd KEY, EOF, LIT, 2, BRANCHNZ
        dd EOF, EXIT
        dd DUP3, CHARINDEX, LIT, -1, EQUALP
        dd LIT, 4, BRANCHNZ
        dd NIP, NIP, EOF, EXIT
        dd DROP, LIT, -23, BRANCH


;;;
;;; Outer interpreter
;;; 

        
section .bss
internal_var_tokbuff:
        resb 16

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
        jmp [eax]

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

        forthword WORDTONAME, 'WORD>NAME', 0
        dd LIT, 16, MINUS
        dd EXIT

        forthword WORDTOSTR, 'WORD>STR', 0
        dd WORDTONAME, DUP, CSTRLEN
        dd EXIT

        forthword FINDWORD, 'FINDWORD', 0
        dd DUP, LIT, 3, BRANCHNZ
        dd NIP, NIP, EXIT
        dd DUP, PREVWORD
        dd OVER, WORDTONAME, LIT, 3, PICK
        dd LIT, 5, PICK, LIT, 5, PICK
        dd STREQP
        dd LIT, 4, BRANCHNZ
        dd DROP, NIP, NIP, EXIT
        dd NIP, LIT, -32, BRANCH

        variable LATEST

        forthword LATESTWORD, 'LATESTWORD', 0
        dd LATEST, READ4
        dd EXIT
        
        forthword WORDF, 'WORD', 0
        dd LATESTWORD, FINDWORD
        dd EXIT

        forthword REPL, 'REPL', 0
        dd SCANTOKEN, DUP, LIT, 1, BRANCHNZ
        dd QUIT
        dd DUP2, WORDF
        dd DUP, LIT, 6, BRANCHZ
        dd NIP, NIP, EXECUTE, LIT, 2, BRANCH
        dd DROP, STRTONUM
        dd LIT, -23, BRANCH
        
        
;;;
;;; Main
;;;

bootstrap:
	dd REPL

STARTSYMBOL:
        mov eax, lastword
        mov dword [var_data_LATEST], eax
        mov ebp, return_stack_base	
        mov esi, bootstrap
        next

	
section .bss
return_stack_base:
        resd 1	 	; return stack with a capacity of 200 items
        resd 200 	; (grows downwards, i.e. low memory -> high memory)
alloc_base:	
	resd 1000	; space for 1000 double words
