;**************************************************
;
; ReadStudentDetails
;
; This simple program prompts an user to
; enter their ID, password, first name,
; last name, and date of birth, validates
; their password, encrypts it, and saves it
; to a file called 'out.txt'
;
; Govind Reghunandanan
; 15/05/2021

include Irvine32.inc
includelib advapi32.lib

CryptAcquireContextA    proto :ptr dword,   :ptr byte,  :ptr byte, :dword, :dword
CryptGenRandom          proto :dword,       :dword,     :ptr byte

;MyFun                   proto :dword,       :dword
Hash                    proto :ptr byte,    :ptr byte
BigNum_Cmp              proto :ptr byte,    :ptr byte,  :dword

.data
test_input byte "abcdefg", 0
test_output byte 1024 dup(?)

password_len            = 20
id_len                  = 3
surname_len             = 21
first_name_len          = 21
dob_len                 = 11
crypt_verify_context    = 0F0000000h
prov_rsa_full           = 1
backslash               = 47

random_byte             byte    ?
h_provider              dword   ?
hex_lookup              byte    "0123456789ABCDEF", 0

greeting                byte    "Welcome! Please enter the following details", 10, 0
confirmation_prompt     byte    10, "Here's a confirmation of your details:", 10, 0
continue_prompt         byte    "Is this ok? [Y/n]: ", 0
y_n                     byte    2 dup(?)

invalid_id_message      byte    "Sorry, the ID must be in the range 1 - 30. ", 0
invalid_pwd_message     byte    10, "The password you entered is incorrect, please try again.", 10, 0
invalid_date_message    byte    10, "Sorry, the date you entered is in the wrong format. The expected format is DD/MM/YYYY. Please try again.", 10, 0

password_buf            byte    password_len dup(0)
password_hash_buf       byte    128 dup(?), 0
password_hash           byte    01ah, 0deh, 05dh, 02ah, 04ch, 012h, 080h, 0b8h, 0b7h, 00fh, 017h, 0c7h, 044h, 0a3h, 0f5h, 098h
                        byte    09dh, 001h, 00eh, 02ch, 0aah, 044h, 0c0h, 0afh, 0dfh, 063h, 0f4h, 0c1h, 09ah, 07ch, 0adh, 083h
                        byte    008h, 095h, 063h, 00dh, 036h, 030h, 0d6h, 09ch, 0eeh, 0e5h, 049h, 016h, 0b3h, 022h, 099h, 090h
                        byte    0f5h, 011h, 00fh, 05ah, 0bbh, 041h, 05fh, 052h, 088h, 084h, 057h, 082h, 03dh, 0deh, 010h, 0b2h
                        byte    0a8h, 00ch, 05eh, 0c7h, 07dh, 079h, 068h, 094h, 04fh, 0e1h, 099h, 094h, 05eh, 058h, 037h, 0fdh
                        byte    086h, 0e6h, 0eah, 08bh, 0adh, 03ah, 019h, 0feh, 0afh, 022h, 004h, 0f5h, 091h, 0fdh, 015h, 035h
                        byte    05ch, 024h, 00ch, 05eh, 0beh, 02ah, 058h, 0b8h, 0fah, 0a1h, 098h, 028h, 030h, 0e1h, 0ceh, 0feh
                        byte    0c8h, 0dfh, 0fdh, 068h, 09bh, 031h, 00eh, 0a4h, 03ch, 0e7h, 0e6h, 004h, 015h, 00fh, 030h, 04dh

id_prompt               byte    "Your Student ID: ", 0
id_buf                  byte    id_len dup(0)
password_prompt         byte    "Your password: ", 0
password_hash_printable byte    256 dup(?), 0
surname_prompt          byte    10, "Your surname: ", 0
surname_buf             byte    surname_len dup(0)
first_name_prompt       byte    "Your first name: ", 0
first_name_buf          byte    first_name_len dup(0)
dob_prompt              byte    "Your Date of Birth (DD/MM/YYYY): ", 0
dob_buf                 byte    dob_len dup(0)

collated_data_len       =       $ - offset id_prompt + 4    ; 4 newlines
collated_data           byte    collated_data_len dup(0)

file_name               byte    "out.txt", 0

.code
date_space      equ 1
month_space     equ date_space + 1
total_space     equ month_space + 2

date            equ [ebp - date_space]
month           equ [ebp - month_space]
year            equ [ebp - total_space]

;--------------------------------------------------------------------------------------------
;
; Validates a date string of the format DD/MM/YYYY
;
; Arguments :   buf     : pointer to the date string
;
; Returns   :   al      : 0 if the date format was correct, 1 if the date format was incorrect
;
;---------------------------------------------------------------------------------------------
ValidateDate    proc   uses ecx edx esi, buf: ptr byte
                sub    esi, total_space

                mov    esi, buf
                mov    ecx, 2

; Verify that the first two characters are digits
CheckDate:      mov    al, [esi]
                call   isDigit
                jnz    Failure

                inc    esi
                loop   CheckDate

; Verify that the date is in the range 1 - 31
                mov    edx, buf
                mov    ecx, 2
                invoke ParseDecimal32

                cmp    eax, 1
                jb     Failure
                cmp    eax, 31
                ja     Failure

                mov    date, al

; Verify that the next character is a backslash
                mov    al, [esi]
                cmp    al, backslash
                jnz    Failure

                inc    esi
                mov    ecx, 2

; Verify that the next two characters are digits
CheckMonth:     mov    al, [esi]
                call   isDigit
                jnz    Failure

                inc    esi
                loop   CheckMonth

                lea    edx, [esi - 2]
                mov    ecx, 2
                invoke ParseDecimal32

; Verify that the month is in the range 1 - 12
                cmp    eax, 1
                jb     Failure
                cmp    eax, 12
                ja     Failure

                mov    month, al

; Verify that the next character is a backslash
                mov    al, [esi]
                cmp    al, 47
                jnz    Failure

                inc    esi
                mov    ecx, 4

; Verify that the next 4 characters are digits
CheckYear:      mov    al, [esi]
                call   isDigit
                jnz    Failure

                inc    esi
                loop   CheckYear

                lea    edx, [esi - 4]
                mov    ecx, 2
                invoke ParseDecimal32
                mov    year, ax

; Verify that the date for each month is within its accepted range
                movzx  edx, byte ptr month
                movzx  ebx, byte ptr date

                cmp    edx, 2
                je     CheckFeb

                cmp    edx, 1
                je     Success
                cmp    edx, 3
                je     Success
                cmp    edx, 5
                je     Success
                cmp    edx, 7
                je     Success
                cmp    edx, 8
                je     Success
                cmp    edx, 10
                je     Success
                cmp    edx, 12
                je     Success

                cmp    ebx, 30
                ja     Failure
                jmp    Success

; Verify that February's date is in its accepted range
CheckFeb:       mov    ecx, 28
                test   eax, 3
                jnz    NotLeapYear                      ; Add 1 for a leap year
                inc    ecx

; This was not a leap year, so February can have at most 28 days
NotLeapYear:    cmp    ebx, ecx
                ja     Failure

Success:        mov    al, 0
                jmp    Done

Failure:        mov    al, 1

Done:           add    esp, total_space
                ret
ValidateDate    endp

;--------------------------------------------------------------------------------------------
;
; Converts a byte to its ASCII decimal representation and writes it to a destination buffer.
; Ensure that the destination buffer is wide enough to accomodate the null terminator. 
;
; Arguments :   num     : the byte to covert
;               buf     : pointer to the destination buffer
;               buf_len : size of the destination buffer
;
; Returns   :   al      : 0 if the date format was correct, 1 if the date format was incorrect
;
;---------------------------------------------------------------------------------------------
IntToDec        proc   uses eax ecx esi, num: byte, buf: ptr byte, buf_len: word
                movzx  eax, num
                mov    cl,  10

                mov    esi, buf                 
                add    si,  buf_len                     ; Point to the end of the buffer
                sub    si,  1
                mov    byte ptr [esi], 0                ; Null terminate it

; Keep dividing the number by 10 to extract the least significant decimal
KeepDividing:   sub    esi, 1
                div    cl

                add    ah, '0'                          ; Add offset of ASCII '0'
                mov    [esi], ah

                xor    ah,  ah
                cmp    eax, 0
                jnz    KeepDividing

                ret
IntToDec        endp

;--------------------------------------------------------------------------------------------
;
; Converts a byte array into its hexadecimal representation in ASCII and writes it to a
; destination buffer.
;
; Arguments :   num     : the byte to covert
;
; Returns   :   al      : 0 if the date format was correct, 1 if the date format was incorrect
;
;---------------------------------------------------------------------------------------------
BytesToHex      proc   uses ecx, source: ptr byte, dest: ptr byte, num_bytes: dword
                mov    esi, source
                mov    edi, dest
                mov    ecx, num_bytes
                mov    ebx, offset hex_lookup

KeepConverting: movzx  eax, byte ptr [esi]
                ror    al,  4
                and    al,  15
                mov    al,  byte ptr [ebx + eax]
                mov    [edi], al

                inc    edi
                movzx  eax, byte ptr [esi]
                and    al,  15
                mov    al,  byte ptr [ebx + eax]
                mov    [edi], al

                inc    esi
                inc    edi
                loop   KeepConverting

                mov    byte ptr [edi], 0

                ret
BytesToHex      endp

main            proc
; Greetings
                mov    edx, offset greeting
                call   WriteString

PromptID:       mov    edx, offset id_prompt
                call   WriteString

; Null out id buffer
                mov    al,  0
                mov    edi, offset id_buf
                mov    ecx, id_len
                rep    stosb

; Read integer and validate its range
                call   ReadInt
                cmp    eax, 1
                jb     InvalidID
                cmp    eax, 30
                ja     InvalidID

; Convert integer to its decimal representation in ASCII
                invoke IntToDec, al, offset id_buf, id_len

                jmp    PromptPwd

; ID was out of its accepted range. Prompt user again
InvalidID:      mov    edx, offset invalid_id_message
                call   WriteString
                jmp    PromptID

PromptPwd:      mov    edx, offset password_prompt
                call   WriteString

; Null out password buffer
                mov    al,  0
                mov    edi, offset password_buf
                mov    ecx, password_len - 1
                rep    stosb

                mov    ecx, password_len - 1
                mov    esi, offset password_buf

; Keep reading characters (without echoing them) until a new line is encountered
KeepReading:    call   ReadChar
                cmp    al,  0Dh                         ; Break if new line
                jz     CheckPwd

                cmp    ecx, 0                           ; Don't write anymore characters to buffer. Keep accepting characters from the keyboard, though
                jz     KeepReading

                dec    ecx
                mov    [esi], al
                add    esi, 1

                jmp    KeepReading

CheckPwd:       mov    byte ptr [esi], 0                 ; Null terminate

                invoke  Hash,       offset password_buf,        offset password_hash_buf
                invoke  BytesToHex, offset password_hash_buf,   offset password_hash_printable, 64

                invoke BigNum_Cmp,  offset password_hash_buf,   offset password_hash,           128
                je     PromptRest

; Password was wrong. Prompt user to enter it again
                mov    edx, offset invalid_pwd_message
                call   WriteString
                jmp    PromptPwd

; Prompt user for the remaining details
PromptRest:     mov    edx, offset surname_prompt
                call   WriteString

                mov    edx, offset surname_buf
                mov    ecx, surname_len
                call    ReadString

                mov    edx, offset first_name_prompt
                call    WriteString

                mov    edx, offset first_name_buf
                mov    ecx, first_name_len
                call   ReadString

PromptDOB:      mov    edx, offset dob_prompt
                call   WriteString

                mov    edx, offset dob_buf
                mov    ecx, dob_len
                call   ReadString

                invoke ValidateDate, offset dob_buf

                cmp    al, 0
                je     CollateData

; Invalid date. Prompt user to enter it again
                mov    edx, offset invalid_date_message
                call   WriteString
                jmp    PromptDOB

CollateData:    mov    al,  0
                mov    edi, offset collated_data
                mov    ecx, collated_data_len
                rep    stosb

                mov    esi, offset id_prompt
                mov    edi, offset collated_data
                mov    ecx, lengthof id_prompt
                rep    movsb

                mov    esi, offset id_buf
                mov    ecx, lengthof id_buf
                rep    movsb

                mov    byte ptr [edi], 10               ; Add a new line
                inc    edi

                mov    esi, offset password_prompt
                mov    ecx, lengthof password_prompt
                rep    movsb

                mov    esi, offset password_hash_printable
                mov    ecx, lengthof password_hash_printable
                rep    movsb

                mov    esi, offset surname_prompt
                mov    ecx, lengthof surname_prompt
                rep    movsb

                mov    esi, offset surname_buf
                invoke Str_length, offset surname_buf
                mov    ecx, eax
                inc    ecx
                rep    movsb

                mov    byte ptr [edi], 10               ; Add a new line
                inc    edi

                mov    esi, offset first_name_prompt
                mov    ecx, lengthof first_name_prompt
                rep    movsb

                mov    esi, offset first_name_buf
                invoke Str_length, offset first_name_buf
                mov    ecx, eax
                inc    ecx
                rep    movsb

                mov    byte ptr [edi], 10               ; Add a new line
                inc    edi

                mov    esi, offset dob_prompt
                mov    ecx, lengthof dob_prompt
                rep    movsb

                mov    esi, offset dob_buf
                mov    ecx, lengthof dob_buf
                rep    movsb

                mov    byte ptr [edi], 10               ; Add a new line
                inc    edi

PromptConfirm:  mov    edx, offset confirmation_prompt
                call   WriteString

                mov    ecx, collated_data_len
                mov    esi, offset collated_data

; Print out all collated data except null bytes
KeepWriting:    lodsb
                cmp    al, 0                            ; Don't write null bytes
                jz     SkipWrite                        ; jump to loop instruction so that ecx is decremented
                call   WriteChar
SkipWrite:      loop   KeepWriting

; Ask user if they wish to continue
                mov    edx, offset continue_prompt
                call   WriteString

                mov    ecx, 2
                mov    edx, offset y_n
                call   ReadString

; If they don't wish to continue, prompt for their details again
                cmp    byte ptr [edx], 110
                je     PromptID

; Write all details to a file
                mov    edx, offset file_name
                invoke CreateOutputFile
    
                mov    edx, offset collated_data
                mov    ecx, collated_data_len
                invoke WriteToFile

                ret
main            endp

end             main
