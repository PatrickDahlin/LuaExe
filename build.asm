extern printf
extern ExitProcess

section .text
	global main
main:
	sub rsp, 32
	mov rdx, -1
	sub rsp, qword 64		;alloc  offset:0
	mov qword [rsp+0], qword 3		;
	sub rsp, qword 64		;alloc a offset:64
	mov rax, qword [rsp+64]		;
	mov qword [rsp+0], rax		;Store into var "a" [64]
	mov rax, qword [rsp+0]		;Prep left from [64]
	mov r10, qword [rsp+0]		;Prep right from [64]
	add rax, r10		;
	sub rsp, qword 64		;alloc  offset:128
	mov qword [rsp+0], rax		;Result into [128]
	sub rsp, qword 64		;alloc  offset:192
	mov qword [rsp+0], qword 2		;
	mov rax, qword [rsp+64]		;Prep left from [128]
	mov r10, qword [rsp+0]		;Prep right from [192]
	mul r10		;
	sub rsp, qword 64		;alloc  offset:256
	mov qword [rsp+0], rax		;Result into [256]
	sub rsp, qword 64		;alloc d offset:320
	mov rax, qword [rsp+64]		;
	mov qword [rsp+0], rax		;Store into var "d" [320]
	mov rdx, rax
	mov rcx, msg
	call printf
	xor ecx,ecx
	call ExitProcess
section .data
msg db "End of program %i",0
section .bss
