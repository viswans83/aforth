%ifdef OSX
%define STARTSYMBOL start
%else
%define STARTSYMBOL _start        
%endif        
        
;; linux 32-bit style syscall abi handler:
;; * params in: ebx, ecx, edx
;; * supports a maximum of 3 parameters
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

	primitive DROP, 'DROP', 0
	pop eax
	next

	primitive DROP2, '2DROP', 0
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

        primitive LIT, 'LIT', 0
        push dword [esi]
        add esi, 4
        next

	primitive BRANCH, 'BRANCH', 0
	pop eax
	lea esi, [esi + 4*eax]
	next

	primitive BRANCHZ, '0BRANCH', 0
	pop eax			; offset
	pop ebx			; value
	cmp ebx, 0
	jz BRANCHZ_jump
	next
BRANCHZ_jump:
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

section .data
internal_var_eof:
	dd 0
section .text	
	
	primitive EMIT, 'EMIT', 0
	mov ebx, 1
        mov ecx, esp		; cbuf is 1 character on the stack
	mov edx, 1
        mov eax, 4
	systemcall
	pop eax			; remove character from stack
        next

	primitive KEY, 'KEY', 0
	push 0			; make room on stack for character
	mov ebx, 1
        mov ecx, esp		; cbuf
	mov edx, 1
        mov eax, 3
	systemcall
	mov dword [internal_var_eof], eax
        next

	primitive EOF, 'EOF', 0
	push dword [internal_var_eof]
	next

;;;
;;; FORTH words
;;;

	
	forthword DISCARD, 'DISCARD', 0
	dd KEY, DUP2, EQUALP
	dd LIT, -6, BRANCHZ
	dd NIP, EXIT

        forthword HELLO, 'HELLO', 0
	dd LIT, 72, EMIT	; H
	dd LIT, 69, EMIT	; E
	dd LIT, 76, EMIT        ; L
	dd LIT, 76, EMIT	; L
	dd LIT, 79, EMIT	; O
	dd LIT, 10, EMIT	; \n
	dd EXIT

	variable TEST
	
	forthword MAIN, 'MAIN', 0
	dd LIT, 5
	dd LIT, 5, TEST, STORE4	; store 5 in TEST
	dd TEST, READ4, PLUS	; TEST + 5 = 10
	dd HELLO, ONEMINUS	; loop step and decrement count
	dd DUP, LIT, 3, BRANCHZ	; break loop
	dd LIT, -9, BRANCH	; loop
	dd QUIT

	forthword MAIN2, 'MAIN2', 0
	dd LIT, 32, DISCARD
	dd EMIT
	dd QUIT

bootstrap:
	dd MAIN
STARTSYMBOL:
        mov ebp, return_stack_base	
        mov esi, bootstrap
        next

	
section .bss
return_stack_base:
        resw 1	 	; return stack with a capacity of 200 items
        resw 200 	; (grows downwards, i.e. low memory -> high memory)
alloc_base:	
	resw 1000	; space for 1000 double words
