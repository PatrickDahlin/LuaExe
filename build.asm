extern printf
extern ExitProcess

section .text
	global main
main:
	sub rsp, 32
	mov rdx, -1
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], qword 3		;
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], qword 2		;
	mov rax, qword [rsp+64]		;Prep left
	mov r10, qword [rsp+0]		;Prep right
	mul r10		;
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], rax		;Result into stack
	sub rsp, qword 64		;stack alloc for a
	mov qword [rsp+0], rax		;Store rax temp into stack
	sub rsp, qword 64		;stack alloc for 
	mov rax, qword 2		;
	neg rax		;
	mov qword [rsp+0], rax		;
	mov rax, qword [rsp+64]		;Prep left
	mov r10, qword [rsp+0]		;Prep right
	add rax, r10		;
	sub rsp, qword 64		;stack alloc for 
	mov qword [rsp+0], rax		;Result into stack
	sub rsp, qword 64		;stack alloc for c
	mov qword [rsp+0], rax		;Store rax temp into stack
	mov rdx, rax
	mov rcx, msg
	call printf
	xor ecx,ecx
	call ExitProcess
section .data
msg db "End of program %i",0
section .bss
