
global main

section .data
arg_msg:
    db "Usage: program frac1 frac2,", 10
    db "where frac can be either nat or nat/nat", 10, 0

num_msg:
    db "NaN (",34,"not a number",34,")", 10, 0
; After maybe 20 tries of numbers i found out that 34 = "
zero_msg:
    db "0",10,0
one_msg:
    db `%ld\n\0`
frac_msg:
    db `%ld/%ld\n\0`
; UTF-8 strings provided by the assignment for +infinity and -infinity.
fmt_plus_infinity:
    db 0x2b, 0xe2, 0x88, 0x9e, 0x0a, 0x00

fmt_minus_infinity:
    db 0x2d, 0xe2, 0x88, 0x9e, 0x0a, 0x00

section .bss
argc:
	resq 1
argv:
	resq 1
first_num_num: ; numerator for the first number
    resq 1
first_num_den: ; denominator for the first number
    resq 1
second_num_num: ; numerator for the second number
    resq 1
second_num_den: ; denominator for the second number
    resq 1
final_num_num:
    resq 1
final_num_den:
    resq 1
section .text


extern printf, fprintf, stderr, exit
; stderr for homework requirement

main:
	push rbp		; save the old frame-pointer - Code stolen from the examples we have in the moodle :D
	mov rbp, rsp		; set RBP to the base of the new frame
	and rsp, -16		; align the stack downward at the 16-byte level

	mov qword [argc], rdi	; first argument: argc
	mov qword [argv], rsi	; second argument: argv
    mov rdi, qword [argc]
    cmp rdi, 3 ; check if args are 2 (excluding the program name)
    jne .args_problem ; the args are not exactly two
    mov rbx, qword [argv]
    mov rbx, qword [rbx + 8*1] ; parse the first argument
    mov r10, 0 ; first_number
    call .parse_fraction
    mov rbx, qword [argv]
    mov rbx, qword [rbx + 8*2] ; parse the second
    mov r10, 1 ; second_number
    call .parse_fraction
    call .after_parse
    cmp qword[final_num_den], 0 ; if denominator = 0
    je .den_zero
    cmp qword[final_num_num], 0 ; if numerator = 0
    je .print_zero
    mov rax, [final_num_num]
    call .test_sign_rax
    mov rbx, [final_num_den]
    call .gcd
    cmp qword[final_num_den], 1 ; if the denominator = 1 then we print without it
    je .print_one
    jmp .print_frac


.done:
	mov rax, 0		; return value from main: Everything is OK
	mov rsp, rbp		; restore the old stack-pointer
	pop rbp			; restore the old frame-pointer
	ret
.test_sign_rax:
    cmp rax, 0
    jl .flip_rax
    ret
.gcd: ; calculate the gcd and put it in rax, rax = numerator , rbx = denominator
    cmp rbx, 0
    je .done_gcd ; we found the gcd
    mov rcx, rbx
    cqo ; extend rax to rdx:rax
    idiv rbx
    mov rax, rcx
    mov rbx, rdx ; rdx has the reminder
    jmp .gcd

.done_gcd:
    mov rcx, rax ; store the gcd in rcx to reuse later
    mov rbx, rcx
    mov rax, [final_num_num]
    cqo
    idiv rbx
    mov [final_num_num], rax
    mov rbx, rcx
    mov rax, [final_num_den]
    cqo
    idiv rbx
    mov [final_num_den], rax
    ret

.den_zero: ; if the denominator is 0 then 0/0 is not allowed and we see if its +-inf
    cmp qword[final_num_num], 0
    je .num_problem
    cmp qword[final_num_num], 0
    jl .print_inf_minus
    jmp .print_inf

.after_parse:; final_num = first_num * second_den + second_num * first_den
    mov rax, [first_num_num] ; first_num * second_den
    imul rax, [second_num_den]
    mov [final_num_num], rax
    mov rax, [second_num_num] ; second_num * first_den
    imul rax, [first_num_den]
    add [final_num_num], rax ; adding them
    call .check_den ; make sure its not 0 * 0
    mov rax, [first_num_den] ; final_den = first_den * second_den
    imul rax, [second_num_den]
    mov [final_num_den], rax
    ret

.check_den: ; check if first denominator is 0
    cmp qword[first_num_den], 0
    je .check_other_den
    ret
.check_other_den: ; check the second
    cmp qword[second_num_den], 0
    je .num_problem
    ret

.parse_fraction: ; similar to the loop in code-0016
    mov r9, 0 ; flag: 0 for numerator , 1 for denominator 
    mov rax, 0 ; accumaletor
    mov r8, 1 ; we begin with positive sign

    cmp byte [rbx], `-` ; change sign and must be followed by a number char
    je .negative
    cmp byte [rbx], `+` ; sign must be followed by a number char
    je .positive

.after_sign:
    call .check_if_digit ; must contain at least one number
    call .save_num
    mov rax, 1 ; if absent then its 1
    cmp r9, 0
    je .finish_both
    mov rax, 0 ; reset to 0 (there must be a number)
    call .check_if_digit
    call .save_den
    ret

.finish_both:
    call .save_den
    ret
    
.save_num:
    cmp r10, 0
    je .finish_num_num_first
    mov qword [second_num_num], rax
    ret

.finish_num_num_first:
    mov qword [first_num_num], rax
    ret
.save_den:
    cmp r10, 0
    je .finish_num_den_first
    mov qword [second_num_den], rax
    ret
.finish_num_den_first:
    mov qword [first_num_den], rax
    ret
.negative:
    mov r8, -1 ; change the sign
    inc rbx ; move to number
    jmp .after_sign

.positive:
    inc rbx ; no need to mov sign again just check the number
    jmp .after_sign

.check_if_digit:
    movzx rdi, byte [rbx] ; move exactly one digit to check

    cmp rdi, '0' ; check if its less than 0 or more than 9
    jl .args_problem
    cmp rdi, '9'
    jg .args_problem
    jmp .digit_0_to_9

.digit_0_to_9: ; stolen from code-0016 but changed to base 10
	lea rax, [rax + 4*rax] ; rax = rax*5
	lea rax, [rdi + 2*rax - '0'] ; rax = rax*2 + rdi - char(0)
	jmp .skip_and_continue

.parser_loop:
	movzx rdi, byte [rbx] ; move exactly one digit to check
    cmp rdi, 0 ; end of number
    je .finish_number
    cmp rdi, '/'
    je .finish_and_denom
    cmp rdi, '0' ; check if its less than 0 or more than 9
    jl .args_problem
    cmp rdi, '9'
    jg .args_problem
    jmp .digit_0_to_9

.finish_and_denom:
    cmp r9, 1
    je .num_problem
    mov r9, 1
    inc rbx
    jmp .finish_number

.finish_number:
    cmp r8, -1
    je  .flip_rax
    ret

.flip_rax:
    neg rax
    mov r8, 1
    ret
.skip_and_continue:
	inc rbx
	jmp .parser_loop
.num_problem: ; issues related to the first or second number
    push rbp
    mov rbp, rsp
    and rsp, -16

    mov rdi, num_msg    ; format string
    mov rax, 0          ; required before printf/fprintf
    call printf

    mov rsp, rbp
    pop rbp
    jmp .done


.args_problem: ; issues related to the argumnet count
    mov rdi , [stderr] ; we need to print to stderr
    mov rsi , arg_msg 
    mov rax , 0
    call fprintf ; we need fprintf for FILE * like stderr

    mov rdi , -1
    call exit

.print_zero:
    push rbp
    mov rbp, rsp
    and rsp, -16

    mov rsi, rax        ; not needed
    mov rdi, zero_msg    ; format string
    mov rax, 0          ; required before printf/fprintf
    call printf

    mov rsp, rbp
    pop rbp
    jmp .done
.print_one:
    push rbp
    mov rbp, rsp
    and rsp, -16

    mov rsi, [final_num_num]        
    mov rdi, one_msg    ; format string
    mov rax, 0          ; required before printf/fprintf
    call printf

    mov rsp, rbp
    pop rbp
    jmp .done
.print_frac:
    push rbp
    mov rbp, rsp
    and rsp, -16

    mov rdi, frac_msg
    mov rsi, [final_num_num]
    mov rdx, [final_num_den]
    mov rax, 0
    call printf

    mov rsp, rbp
    pop rbp
    jmp .done
.print_inf:
    push rbp
    mov rbp, rsp
    and rsp, -16

    mov rdi, fmt_plus_infinity    ; format string
    mov rax, 0          ; required before printf/fprintf
    call printf

    mov rsp, rbp
    pop rbp
    jmp .done
.print_inf_minus:
    push rbp
    mov rbp, rsp
    and rsp, -16

    mov rdi, fmt_minus_infinity    ; format string
    mov rax, 0          ; required before printf/fprintf
    call printf

    mov rsp, rbp
    pop rbp
    jmp .done
section .note.GNU-stack noalloc noexec
