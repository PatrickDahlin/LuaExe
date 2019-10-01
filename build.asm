extern printf
extern ExitProcess
; END OF HEADER
section .text
	global main
main:
	mov rdx, -1
	sub rsp, 64; int64
	sub rsp, 64; int64
	sub rsp, 64; int64
	sub rsp, 64; int64
	sub rsp, 64; int64
	mov rcx, msg
	call printf
	xor ecx,ecx
	call ExitProcess
section .data
msg db "End of program %i",0
section .bss
