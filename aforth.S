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
%define lastword %1_dict_entry
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
%define lastword %1_dict_entry
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
        dd WRITE, ERRORQUIT

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

        primitive ROT, 'ROT', 0
        pop ecx
        pop ebx
        pop eax
        push ebx
        push ecx
        push eax
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
section .data
var_data_%1:	
	dd 0
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

        
;;;
;;; Main
;;;

        stringconst TOKPROMPT, 'Found Token: '
        
        forthword MAIN, 'MAIN', 0
        dd WHITESPACE, DISCARD, READTOKEN
        dd DUP, LIT, 1, BRANCHNZ
        dd QUIT
        dd TOKPROMPT, WRITE, WRITE, NL
        dd LIT, -15, BRANCH

bootstrap:
	dd MAIN
        
STARTSYMBOL:
        mov ebp, return_stack_base	
        mov esi, bootstrap
        next

	
section .bss
return_stack_base:
        resd 1	 	; return stack with a capacity of 200 items
        resd 200 	; (grows downwards, i.e. low memory -> high memory)
alloc_base:	
	resd 1000	; space for 1000 double words
