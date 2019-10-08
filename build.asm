extern printf
extern ExitProcess

section .text
	global main
main:
	sub rsp, 32
	mov rdx, -1
	sub rsp, qword 64		;stack alloc for a
	sub rsp, qword 64		;stack alloc for 
	mov rax, qword 1		;
	neg rax		;
	mov qword [rsp+0], rax		;
	mov rax, qword 19		;Prep a
	mov r10, qword [rsp+0]		;Prep b
	mul r10		;Perform arith
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], rax		;Result into stack
	mov qword [rsp+128], rax		;Store rax temp into stack
	sub rsp, qword 64		;stack alloc for myvar
	mov rax, qword [rsp+192]		;Prep a
	mov r10, qword [rsp+192]		;Prep b
	mul r10		;Perform arith
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], rax		;Result into stack
	mov rax, qword [rsp+256]		;Prep a
	mov r10, qword [rsp+0]		;Prep b
	mul r10		;Perform arith
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], rax		;Result into stack
	mov qword [rsp+128], rax		;Store rax temp into stack
	mov rdx, rax
	mov rcx, msg
	call printf
	xor ecx,ecx
	call ExitProcess
section .data
msg db "End of program %i",0
section .bss
