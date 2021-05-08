;  College Registration Example         (Regist.asm)

; Simple demonstration of MASM's .IF,
; .ENDIF, and .ELSEIF directives.

INCLUDE Irvine32.inc

;INCLUDE advapi32.INC
INCLUDELIB advapi32.lib

CryptAcquireContextA PROTO :PTR DWORD, :PTR BYTE, :PTR BYTE, :DWORD, :DWORD
CryptGenRandom PROTO :DWORD, :DWORD, :PTR BYTE

.data
xxxx BYTE "Enter: ", 0

TRUE equ 1
FALSE equ 0
INT_MIN_BYTE_LEN equ 128
INT_PADDING_BYTE_LEN equ 4
INT_MIN_PADDED_BYTE_LEN equ INT_MIN_BYTE_LEN + 4
INT_MAX_BYTE_LEN equ 256
INT_MAX_BIT_LEN equ 2048

BIG_ONE BYTE 127 DUP(0), 1
BIG_ZERO BYTE 128 DUP(0)
BIG_ONE_132 BYTE 131 DUP(0), 1

gen BYTE 125 DUP(0), 1, 0, 1
prime BYTE 0cfh, 0cbh, 06fh, 029h, 04ch, 05ch, 03bh, 09eh, 0e3h, 03ch, 01fh, 013h, 0b1h, 0beh, 087h, 0cch
      BYTE 0f6h, 0bah, 056h, 0eeh, 054h, 019h, 010h, 0f5h, 0dfh, 09bh, 003h, 0eah, 0e7h, 088h, 0afh, 080h
      BYTE 064h, 028h, 05ah, 0d0h, 007h, 00ah, 05eh, 0abh, 039h, 06ch, 0fdh, 022h, 021h, 03dh, 026h, 037h
      BYTE 01fh, 0fah, 0b5h, 029h, 0c6h, 07eh, 0c9h, 0f3h, 037h, 006h, 0e1h, 0abh, 0adh, 089h, 007h, 0f6h
      BYTE 0c0h, 0c3h, 0c5h, 001h, 0ech, 0a9h, 0e4h, 094h, 0ach, 00dh, 096h, 038h, 0ebh, 064h, 0f4h, 09dh
      BYTE 0ddh, 022h, 0a3h, 0b1h, 000h, 0cah, 0abh, 0d0h, 0f2h, 045h, 09bh, 0b0h, 09fh, 0b8h, 05fh, 07fh
      BYTE 0f8h, 02bh, 0e2h, 0a0h, 0b2h, 0beh, 0b0h, 01dh, 01bh, 0a4h, 0b9h, 03bh, 04eh, 016h, 0d2h, 006h
      BYTE 0dch, 047h, 0fch, 0f8h, 096h, 0b0h, 000h, 033h, 096h, 009h, 04bh, 053h, 05ah, 050h, 0abh, 081h

.code

;--------------------------------------------------------
BigNum_Shr PROC uses ecx esi, address  : DWORD,
                              num_bytes: DWORD
;
; Shifts a byte array 1 bit to the right
; Arguments: address   : address of the byte array
;            num_bytes : length of the byte array 
;--------------------------------------------------------
    mov esi, address
    mov ecx, num_bytes

; Shift first byte
    sub ecx, 1
    shr byte ptr [esi], 1

; If only one byte, leave
    pushfd
    cmp ecx, 0
    jz DONE
    popfd

; Else, shift the rest
SHIFT:
    rcr byte ptr [esi + 1], 1

    pushfd
    add esi, 1
    popfd

    loop SHIFT
    ret

DONE:
    popfd
    ret
BigNum_Shr ENDP

BigNum_Shl PROC uses ecx esi, address: DWORD,
                              num_bytes: DWORD
;
; Shifts a byte array 1 bit to the left
;
; Arguments: address   : address of the byte array
;            num_bytes : length of the byte array 
;--------------------------------------------------------
    mov esi, address
    mov ecx, num_bytes

; Shift the last byte
    sub ecx, 1
    add esi, ecx
    shl byte ptr [esi], 1

; If only one byte, leave
    pushfd
    cmp ecx, 0
    jz DONE
    popfd

; Else, shift the rest
SHIFT:
    rcl byte ptr [esi - 1], 1
    pushfd
    sub esi, 1
    popfd

    loop SHIFT
    ret

DONE:
    popfd
    ret
BigNum_Shl ENDP

BigNum_Add PROC uses eax ebx ecx esi edi, arg1: PTR BYTE,
                                          arg2: PTR BYTE,
                                          dest: PTR BYTE,
                                          num_bytes: DWORD,
                                          skip_first_byte: BYTE
;
; Writes the sum of two big numbers into an address
;
; Arguments: arg1            : address of the first number
;            arg2            : address of the second number
;            dest            : address where the sum will be saved to
;            num_bytes       : maximum length of the numbers in bytes
;            skip_first_byte : set to 1 to not propagate carry to most significant byte (Useful for subtraction)
;---------------------------------------------------------------------------------------------------------------
    mov esi, arg1
    mov edi, arg2
    mov ebx, dest
    mov ecx, num_bytes

    add esi, ecx
    add edi, ecx
    add ebx, ecx

    sub esi, 1
    sub edi, 1
    sub ebx, 1
    clc

KEEP_ADDING:
    mov al, [esi]
    adc al, [edi]

    pushfd
    mov [ebx], al
    sub esi, 1
    sub edi, 1
    sub ebx, 1
    popfd

    loop KEEP_ADDING

; If requested, don't propagate carry to most significant byte
    cmp skip_first_byte, FALSE
    jnz DONE

    mov byte ptr [ebx], 0
    adc byte ptr [ebx], 0
    
DONE:
    ret
BigNum_Add ENDP

;------------------------------------------------------------------------------------------
BigNum_Mul PROC uses eax ebx ecx edx esi edi, n1: PTR BYTE,
                                              n2: PTR BYTE,
                                              n3: PTR BYTE
;
; Writes the product of two 1024-bit numbers to an address
; Arguments: n1 : address of the first number
;            n2 : address of the second number 
;            n3 : address where the product will be written to (must be at least 2048 bits)
;------------------------------------------------------------------------------------------
    other_var_space_ext_mul equ 6 * 4
    n1_space_ext_mul equ other_var_space_ext_mul + INT_MAX_BYTE_LEN
    n2_space_ext_mul equ n1_space_ext_mul + INT_MAX_BYTE_LEN
    total_space_ext_mul equ n2_space_ext_mul + INT_MAX_BYTE_LEN

; Reserve space for n1_var (copy of n1), n2_var (copy of n2), and dst_var (copy of n3)
    n1_var equ [ebp - n1_space_ext_mul]
    n2_var equ [ebp - n2_space_ext_mul]
    dst_var equ [ebp - total_space_ext_mul]

    sub esp, total_space_ext_mul

; Null out the first 128 bytes of n1_var
    mov ecx, INT_MIN_BYTE_LEN
    lea edi, n1_var
    mov al, 0
    rep stosb

; Copy (the 128 bytes of) n1 to the remaining 128 bytes of n1_var
    mov ecx, INT_MIN_BYTE_LEN
    mov esi, n1
    rep movsb

; Null out the first 128 bytes of n2_var
    mov ecx, INT_MIN_BYTE_LEN
    lea edi, n2_var
    mov al, 0
    rep stosb

; Copy (the 128 bytes of) n2 to the remaining 128 bytes of n2_var
    mov ecx, INT_MIN_BYTE_LEN
    mov esi, n2
    rep movsb

; Null out 256 bytes of dst_var
    mov ecx, INT_MAX_BYTE_LEN
    lea edi, dst_var
    mov al, 0
    rep stosb

    mov ecx, INT_MAX_BIT_LEN

EXTRACT_LSB:
    Invoke BigNum_Shr, addr n2_var, INT_MAX_BYTE_LEN
    jnc CONTINUE

    Invoke BigNum_Add, addr dst_var, addr n1_var, addr dst_var, INT_MAX_BYTE_LEN, FALSE

CONTINUE:
    Invoke BigNum_Shl, addr n1_var, INT_MAX_BYTE_LEN
    LOOP EXTRACT_LSB

; Write the result to n3
    mov ecx, INT_MAX_BYTE_LEN
    lea esi, dst_var
    mov edi, n3
    rep movsb
    
    add esp, total_space_ext_mul
    ret
BigNum_Mul ENDP

;-----------------------------------------------------
BigNum_Not PROC uses eax ecx esi, a: PTR BYTE,
                                  num_bytes: DWORD
;
; Complements (NOTs) a big number
;
; Arguments: address   : address of the number
;            num_bytes : length of the number in bytes 
;-----------------------------------------------------
    mov ecx, num_bytes
    mov esi, a

L1:
    not BYTE PTR [esi]
    add esi, 1
    loop L1

    ret
BigNum_Not ENDP

;---------------------------------------------------------
BigNum_Cmp PROC uses eax ebx ecx esi edi, a: PTR BYTE,
                                          b: PTR BYTE,
                                          num_bytes: DWORD
;
; Compares two big numbers and sets flags accordingly
;
; Arguments: a         : address of the first number
;            b         : address of the second number
;            num_bytes : length of the number in bytes 
;---------------------------------------------------------
    mov esi, a
    mov edi, b
    mov ecx, num_bytes

L1:
    mov al, BYTE PTR [esi]
    mov bl, BYTE PTR [edi]
    cmp al, bl
    je L2
    ret
L2:
    pushfd
    add esi, 1
    add edi, 1
    popfd
    loop L1
    ret
BigNum_Cmp ENDP

;----------------------------------------------------------------
BigNum_Mod PROC uses eax ebx ecx edx esi edi, n: PTR BYTE,
                                              d: PTR BYTE,
                                              r: PTR BYTE
;
; Divides a 2048-bit dividend by a 1024-bit divisor
; and stores the remainder in an address
;
; Arguments: n : address of the dividend
;            d : address of the divisor
;            r : address where the remainder should be written to
;----------------------------------------------------------------
    ;TODO divide by zero

    other_vars_space_ext_div equ 6 * 4
    n_var_space_ext_div equ other_vars_space_ext_div + INT_MAX_BYTE_LEN
    d_var_space_ext_div = n_var_space_ext_div + INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN
    total_space_ext_div = d_var_space_ext_div + INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN

; Reserve space for n_var (copy of n), d_var (copy of d), and r_var (copy of r)
    n_var equ [ebp - n_var_space_ext_div]
    d_var equ [ebp - d_var_space_ext_div]
    r_var equ [ebp - total_space_ext_div]

    sub esp, total_space_ext_div

; Copy n to n_var
    mov ecx, INT_MAX_BYTE_LEN
    mov esi, n
    lea edi, n_var
    rep movsb

; Add 4 bytes of padding for d (as the divisor needs to be more than 1024 bits for the algorithm)
    mov ecx, INT_PADDING_BYTE_LEN
    mov al, 0
    lea edi, d_var
    rep stosb

; Copy the rest of the divisor
    mov ecx, INT_MIN_BYTE_LEN
    mov esi, d
    rep movsb

    mov ecx, INT_MIN_BYTE_LEN
    add ecx, INT_PADDING_BYTE_LEN
    lea edi, r_var
    mov al, 0
    rep stosb

    mov ecx, INT_MAX_BIT_LEN

KEEP_SHIFTING:
    sub ecx, 1
    Invoke BigNum_Shl, addr n_var, INT_MAX_BYTE_LEN
    jnc KEEP_SHIFTING
    
    setc al
    add ecx, 1
L1:
    push ecx

    lea esi, r_var
    Invoke BigNum_Shl, esi, INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN

    or BYTE PTR [esi + INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN - 1], al

    mov ecx, 4
    mov al, 0
    lea edi, d_var
    rep stosb

    mov ecx, INT_MIN_BYTE_LEN
    mov esi, d
    rep movsb

    lea eax, d_var
    ;lea esi, r_var
    Invoke BigNum_Cmp, addr r_var, eax, INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN
    jb L2

    lea esi, d_var
    lea eax, r_var
    Invoke BigNum_Not, esi, INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN
    Invoke BigNum_Add, esi, offset BIG_ONE_132, esi, INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN, TRUE
    Invoke BigNum_Add, eax, esi, eax, INT_MIN_BYTE_LEN + INT_PADDING_BYTE_LEN, TRUE

L2:
    Invoke BigNum_Shl, addr n_var, INT_MAX_BYTE_LEN
    setc al

    pop ecx
    dec ecx
    jnz L1

    mov ecx, INT_MIN_BYTE_LEN
    lea esi, r_var
    add esi, INT_PADDING_BYTE_LEN
    mov edi, r
    rep movsb

    add esp, total_space_ext_div

    ret
BigNum_Mod ENDP

BigNum_Mod_Exp PROC uses eax ecx edx, a: PTR BYTE, e: PTR BYTE, m: PTR BYTE, r: PTR BYTE
    other_var_space_exp equ 3 * 4
    a_space_exp equ other_var_space_exp + INT_MIN_BYTE_LEN
    a_sq_space_exp equ a_space_exp + INT_MAX_BYTE_LEN
    total_space_exp equ a_sq_space_exp + INT_MIN_BYTE_LEN
    
    a_buf equ [ebp - a_space_exp]
    a_sq_buf equ [ebp - a_sq_space_exp]
    y equ [ebp - total_space_exp]

    sub esp, total_space_exp

    Invoke BigNum_Cmp, e, offset BIG_ZERO, INT_MIN_BYTE_LEN
    je L3

    mov ecx, INT_MIN_BYTE_LEN
    mov esi, a
    lea edi, a_buf
    rep movsb

    mov ecx, INT_MIN_BYTE_LEN
    mov esi, offset BIG_ONE
    lea edi, y
    rep movsb

    xor ecx, ecx

L1:
    inc ecx
    lea eax, a_sq_buf
    lea ebx, a_buf
    lea edx, y

    Invoke BigNum_Shr, e, INT_MIN_BYTE_LEN
    jc L2

    Invoke BigNum_Mul, ebx, ebx, eax
    Invoke BigNum_Mod, eax, m, ebx

    jmp CONTINUE
L2:

    Invoke BigNum_Mul, ebx, edx, eax
    Invoke BigNum_Mod, eax, m, edx

    Invoke BigNum_Mul, ebx, ebx, eax
    Invoke BigNum_Mod, eax, m, ebx

CONTINUE:
    Invoke BigNum_Cmp, e, offset BIG_ONE, INT_MIN_BYTE_LEN
    ja L1

    Invoke BigNum_Mul, ebx, edx, eax
    Invoke BigNum_Mod, eax, m, r
    jmp DONE

L3:
    mov ecx, INT_MIN_BYTE_LEN
    mov esi, offset BIG_ONE
    mov edi, r
    rep movsb
DONE:
    add esp, total_space_exp
    ret
BigNum_Mod_Exp ENDP

Print_BigNum PROC uses ecx esi, number: PTR BYTE, num_bytes: DWORD
    mov ecx, num_bytes
    mov esi, number

    xor al, al

L1:
    movzx eax, BYTE PTR [esi]
    mov ebx, 1
    Call WriteHexB

    add esi, 1
    loop L1

    ret
Print_BigNum ENDP

Hash PROC uses eax ecx esi edi, input_string: PTR BYTE, output_hash: PTR BYTE
    total_space_hash equ INT_MIN_BYTE_LEN
    input_string_hash equ [ebp - total_space_hash]

    sub esp, total_space_hash

    mov edx, input_string
    Call StrLength
    push eax

    mov ecx, INT_MIN_BYTE_LEN
    sub ecx, eax
    lea edi, input_string_hash
    mov al, 0
    rep stosb

    pop eax
    mov ecx, eax
    mov esi, input_string
    rep movsb

    mov edi, output_hash
    Invoke BigNum_Mod_Exp, offset gen, addr input_string_hash, offset prime, edi

    add esp, total_space_hash

    ret
Hash ENDP

main PROC
    input_string_space_main equ 32
    total_space_main equ input_string_space_main + INT_MIN_BYTE_LEN
    
    input_string_main equ [ebp - input_string_space_main]
    output_hash equ [ebp - total_space_main]
    sub esp, total_space_main

L1:
    mov edx, offset xxxx
    Invoke WriteString

    mov ecx, 32
    lea edi, input_string_main
    mov al, 0
    rep stosb

    mov ecx, 32
    lea edx, input_string_main
    Invoke ReadString
    
    mov al, 10
    Invoke WriteChar

    Invoke Hash, edx, addr output_hash
    Invoke Print_BigNum, addr output_hash, INT_MIN_BYTE_LEN

    mov al, 10
    Invoke WriteChar

    loop L1
main ENDP

END main