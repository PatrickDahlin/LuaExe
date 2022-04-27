extern printf
extern ExitProcess

section .text
	global main
main:
	sub rsp, 32
	mov rdx, -1
	mov rdx, rax
	mov rcx, msg
	call printf
	xor ecx,ecx
	call ExitProcess
section .data
msg db "End of program %i",0
section .bss
