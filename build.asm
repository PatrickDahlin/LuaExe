extern printf
extern ExitProcess

section .text
	global main
main:
	sub rsp, 32
	mov rdx, -1
	sub rsp, qword 64		;stack alloc for a
	mov rax, qword 19		;
	mov qword [rsp+0], rax		;Load immediate to stack
	sub rsp, qword 64		;stack alloc for b
	mov rax, qword [rsp+64]		;Prep a
	mov r10, qword 1		;Prep b
	add rax, r10		;Perform arith
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], rax		;Result into stack
	mov qword [rsp+64], rax		;Store rax temp into stack
	mov rdx, rax
	mov rcx, msg
	call printf
	xor ecx,ecx
	call ExitProcess
section .data
msg db "End of program %i",0
section .bss
