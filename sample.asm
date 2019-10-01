extern ExitProcess
extern MessageBoxA

NULL equ 0
MB_OK equ 0

; Parameter passing:
; RCX, RDX, R8, R9, rest is pushed

section .text
	global main
main:
	sub rsp, 40 ; Allocate stack space for parameters
	
	mov r9, MB_OK
	mov r8, msg
	mov rdx, msg
	mov rcx, NULL
	call MessageBoxA

	xor ecx, ecx
	call ExitProcess

section .data
msg db "Hello World!", 0
len equ $ - msg
section .bss
bytesWritten resd 1