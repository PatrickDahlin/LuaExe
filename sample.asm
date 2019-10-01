extern ExitProcess
extern MessageBoxA
extern printf

NULL equ 0
MB_OK equ 0

; Parameter passing:
; RCX, RDX, R8, R9, rest is pushed
; another source suggests 5th and 6th param to be following
; [rsp+20h], [rsp+28h]

section .text
	global main
main:
	sub rsp, 40 ; Allocate stack space for parameters
	
	mov r9, MB_OK
	mov r8, msg
	mov rdx, msg
	mov rcx, NULL
	call MessageBoxA

	mov rcx, msg
	call printf

	xor ecx, ecx
	call ExitProcess

section .data
msg db "Hello World!", 0
len equ $ - msg
section .bss