; You may customize this and other start-up templates; 
; The location of this template is c:\emu8086\inc\0_com_template.txt

org 100h

name "kernel"
; this is a very basic example
; of a tiny operating system.
;
; this is kernel module!
;
; it is assumed that this machine
; code is loaded by 'micro-os_loader.asm'
; from floppy drive from:
;   cylinder: 0
;   sector: 2
;   head: 0


;=================================================
; how to test micro-operating system:
;   1. compile micro-os_loader.asm
;   2. compile micro-os_kernel.asm
;   3. compile writebin.asm
;   4. insert empty floppy disk to drive a:
;   5. from command prompt type:
;        writebin loader.bin
;        writebin kernel.bin /k
;=================================================

; directive to create bin file:
#make_bin#

; where to load? (for emulator. all these values are saved into .binf file)
#load_segment=0800#
#load_offset=0000#

; these values are set to registers on load, actually only ds, es, cs, ip, ss, sp are
; important. these values are used for the emulator to emulate real microprocessor state 
; after micro-os_loader transfers control to this kernel (as expected).
#al=0b#
#ah=00#
#bh=00#
#bl=00#
#ch=00#
#cl=02#
#dh=00#
#dl=00#
#ds=0800#
#es=0800#
#si=7c02#
#di=0000#
#bp=0000#
#cs=0800#
#ip=0000#
#ss=07c0#
#sp=03fe#



; this macro prints a char in al and advances
; the current cursor position:
putc    macro   char
        push    ax
        mov     al, char
        mov     ah, 0eh
        int     10h     
        pop     ax
endm


; sets current cursor position:
gotoxy  macro   col, row
        push    ax
        push    bx
        push    dx
        mov     ah, 02h
        mov     dh, row
        mov     dl, col
        mov     bh, 0
        int     10h
        pop     dx
        pop     bx
        pop     ax
endm


print macro x, y, attrib, sdat
LOCAL   s_dcl, skip_dcl, s_dcl_end
    pusha
    mov dx, cs
    mov es, dx
    mov ah, 13h
    mov al, 1
    mov bh, 0
    mov bl, attrib
    mov cx, offset s_dcl_end - offset s_dcl
    mov dl, x
    mov dh, y
    mov bp, offset s_dcl
    int 10h
    popa
    jmp skip_dcl
    s_dcl DB sdat
    s_dcl_end DB 0
    skip_dcl:    
endm



; kernel is loaded at 0800:0000 by micro-os_loader
org 0000h

; skip the data and function delaration section:
jmp start 
; The first byte of this jump instruction is 0E9h
; It is used by to determine if we had a sucessful launch or not.
; The loader prints out an error message if kernel not found.
; The kernel prints out "F" if it is written to sector 1 instead of sector 2.
           



;==== data section =====================

; welcome message:
msg  db "Projemize Ho",159,"geldiniz!", 0 

cmd_size        equ 20    ; size of command_buffer
command_buffer  db cmd_size dup("b")
clean_str       db cmd_size dup(" "), 0
prompt          db ">", 0

; commands:
chelp    db "help", 0
chelp_tail:
ccls     db "cls", 0
ccls_tail:
cquit    db "quit", 0
cquit_tail:
cexit    db "exit", 0
cexit_tail:
ccount    db "count", 0
ccount_tail:
creboot  db "reboot", 0
creboot_tail:         
cpicture    db "picture", 0
cpicture_tail: 
cpreparers    db "preparers", 0
cpreparers_tail:
cexcess    db "excess", 0
cexcess_tail: 
cbinary    db "binary", 0
cbinary_tail: 

;/////////////////////////////
cda    db "da", 0
cda_tail:

help_msg db "Micro-os'u tercih etti",167,"iniz i",135,"in te",159,"ekk",129,"r ederiz!", 0Dh,0Ah
         db "Desteklenen komutlar",141,"n k",141,"sa listesi:", 0Dh,0Ah
         db "help   - bu listenin ",135,"",141,"kt",141,"s",141,"n",141," al",141,"n.", 0Dh,0Ah
         db "cls    - ekran",141," temizleyin.", 0Dh,0Ah
         db "reboot - makineyi yeniden ba",159,"lat",141,"n.", 0Dh,0Ah
         db "quit   - yeniden ba",159,"latma ile ayn",141,".", 0Dh,0Ah 
         db "exit   - ",135,"",141,"k",141,"",159," yapmakla ayn",141,".", 0Dh,0Ah 
         db "picture   - resim ",135,"izer", 0Dh,0Ah          
         db "count - çklavyede bas",141,"lan tu",159," say",141,"s",141,"n",141," yazd",141,"r",141,"r", 0Dh,0Ah
         db "excess   - klavyede a",159,"",141,"m olunca alarm ",135,"alar", 0Dh,0Ah 
         db "binary   - onluk say",141,"y",141," ikilik sisteme d",148,"n",129,"",159,"t",129,"r",129,"r", 0Dh,0Ah
         db "preparers   - haz",141,"rlayanlar",141," g",148,"sterir", 0Dh,0Ah
         db "daha fazlas",141," gelecek!", 0Dh,0Ah, 0

unknown  db "bilinmeyen komut: " , 0
     
                              
;======================================

start:

; set data segment:
push    cs
pop     ds

; set default video mode 80x25:
mov     ah, 00h
mov     al, 03h
int     10h

; blinking disabled for compatibility with dos/bios,
; emulator and windows prompt never blink.
mov     ax, 1003h
mov     bx, 0      ; disable blinking.
int     10h


; *** the integrity check  ***
cmp [0000], 0E9h
jz integrity_check_ok
integrity_failed:  
mov     al, 'F'
mov     ah, 0eh
int     10h  
; wait for any key...
mov     ax, 0
int     16h
; reboot...
mov     ax, 0040h
mov     ds, ax
mov     w.[0072h], 0000h
jmp	0ffffh:0000h	 
integrity_check_ok:
nop
; *** ok ***
              


; clear screen:
call    clear_screen
                     
                       
; print out the message:
lea     si, msg
call    print_string


eternal_loop:
call    get_command

call    process_cmd  



; make eternal loop:
jmp eternal_loop


;===========================================
get_command proc near

; set cursor position to bottom
; of the screen:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]

gotoxy  0, al

; clear command line:
lea     si, clean_str
call    print_string

gotoxy  0, al

; show prompt:
lea     si, prompt 
call    print_string


; wait for a command:
mov     dx, cmd_size    ; buffer size.
lea     di, command_buffer
call    get_string


ret
get_command endp
;===========================================

process_cmd proc    near

;//// check commands here ///
; set es to ds
push    ds
pop     es

cld     ; forward compare.

; compare command buffer with 'help'
lea     si, command_buffer
mov     cx, chelp_tail - offset chelp   ; size of ['help',0] string.
lea     di, chelp
repe    cmpsb
je      help_command

; compare command buffer with 'cls'
lea     si, command_buffer
mov     cx, ccls_tail - offset ccls  ; size of ['cls',0] string.
lea     di, ccls
repe    cmpsb
jne     not_cls
jmp     cls_command
not_cls:

; compare command buffer with 'quit'
lea     si, command_buffer
mov     cx, cquit_tail - offset cquit ; size of ['quit',0] string.
lea     di, cquit
repe    cmpsb
je      reboot_command

; compare command buffer with 'count'
lea     si, command_buffer
mov     cx, ccount_tail - offset ccount ; size of ['quit',0] string.
lea     di, ccount
repe    cmpsb
je      count_command

; compare command buffer with 'exit'
lea     si, command_buffer
mov     cx, cexit_tail - offset cexit ; size of ['exit',0] string.
lea     di, cexit
repe    cmpsb
je      reboot_command

; compare command buffer with 'reboot'
lea     si, command_buffer
mov     cx, creboot_tail - offset creboot  ; size of ['reboot',0] string.
lea     di, creboot
repe    cmpsb
je      reboot_command     

; compare command buffer with 'picture'
lea     si, command_buffer
mov     cx, cpicture_tail - offset cpicture   ; ['picture',0] dizisinin boyutu.
lea     di, cpicture
repe    cmpsb
je      draw_picture

; compare command buffer with 'picture'
lea     si, command_buffer
mov     cx, cpreparers_tail - offset cpreparers   ; ['preparers',0] dizisinin boyutu.
lea     di, cpreparers
repe    cmpsb
je      preparers 

; compare command buffer with 'excess'
lea     si, command_buffer
mov     cx, cexcess_tail - offset cexcess   ; ['excess',0] dizisinin boyutu.
lea     di, cexcess
repe    cmpsb
je      excess_command   

; compare command buffer with 'binary'
lea     si, command_buffer
mov     cx, cbinary_tail - offset cbinary   ; ['binary',0] dizisinin boyutu.
lea     di, cbinary
repe    cmpsb
je      binary_command




; ignore empty lines
cmp     command_buffer, 0
jz      processed


;////////////////////////////

; if gets here, then command is
; unknown...

mov     al, 1
call    scroll_t_area

; set cursor position just
; above prompt line:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]
dec     al
gotoxy  0, al

lea     si, unknown
call    print_string

lea     si, command_buffer
call    print_string

mov     al, 1
call    scroll_t_area

jmp     processed

; +++++ 'help' command ++++++
help_command:

; scroll text area 9 lines up:
mov     al, 9
call    scroll_t_area

; set cursor position 9 lines
; above prompt line:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]
sub     al, 9
gotoxy  0, al

lea     si, help_msg
call    print_string

mov     al, 1
call    scroll_t_area

jmp     processed     

;////////////////////////////////////////

; +++++ 'picture' command ++++++
draw_picture proc near    
    call clear_screen
    gotoxy 3, 2   ; imlec konumunu ayarla (ihtiyac duydugunuzda ayarlayin)
    ; picture cizimi:
    ; ornek picture cizimi:
    print 3, 2, 1100_0111b,"****************************************************************************"   
    print 3, 3, 1100_0111b,"****************************************************************************"  
    print 3, 4, 1100_0111b,"****************************               *********************************" 
    print 3, 5, 1100_0111b,"***********************         ***********     ****************************"   
    print 3, 6, 1100_0111b,"********************          ******************  **************************"
    print 3, 7, 1100_0111b,"*****************          ********************** **************************"
    print 3, 8, 1100_0111b,"****************          **************************************************"
    print 3, 9, 1100_0111b,"***************          ****************************** ********************"
    print 3, 10, 1100_0111b,"**************          ******************************   *******************"
    print 3, 11, 1100_0111b,"**************         ******************************     ******************"
    print 3, 12, 1100_0111b,"*************          **************************             **************"  
    print 3, 13, 1100_0111b,"*************          *****************************       *****************" 
    print 3, 14, 1100_0111b,"**************         ****************************   ***   ****************" 
    print 3, 15, 1100_0111b,"**************          **************************  *******  ***************" 
    print 3, 16, 1100_0111b,"***************          ***************************************************" 
    print 3, 17, 1100_0111b,"****************          **************************************************" 
    print 3, 18, 1100_0111b,"*****************          ********************** **************************"
    print 3, 19, 1100_0111b,"********************         ******************  ***************************"
    print 3, 20, 1100_0111b,"***********************         ***********     ****************************"
    print 3, 21, 1100_0111b,"****************************               *********************************"
    print 3, 22, 1100_0111b,"****************************************************************************"
    print 3, 23, 1100_0111b,"****************************************************************************" 
            
    ; Tusa basilmasini bekliyor:
    mov ax, 0  ; wait for any key....
    int 16h
    ret
    draw_picture endp

;////////////////////////////////////////  
                
;+++++ 'preparers' command ++++++
preparers proc near
    call clear_screen
   ; print a welcome message:
	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgzend - offset msgz 
	mov dl, 0
	mov dh, 0
	push cs
	pop es
	mov bp, offset msgz
	mov ah, 13h
	int 10h             
                                                                                        
 

	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgxend - offset msgx
	mov dl, 0
	mov dh, 2
	push cs
	pop es
	mov bp, offset msgx
	mov ah, 13h
	int 10h             
                 


	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgqend - offset msgq 
	mov dl, 0
	mov dh, 4
	push cs
	pop es
	mov bp, offset msgq
	mov ah, 13h
	int 10h             
             
 mov ax, 0  ; wait for any key....
int 16h        
ret               
    
            
msgz db "Haz",141,"rlayanlar:", 0Dh,0Ah, 
msgzend:             

msgq db "Furkan Do",167,"an", 0Dh,0Ah, 
msgqend:     
                    
msgx db "Hasbiyenur ",128,"oban", 0Dh,0Ah, 
msgxend:            
     
preparers endp
jmp     processed                  
                  
;//////////////////////////////////////////                

; +++++ 'cls' command ++++++
cls_command:
call    clear_screen
jmp     processed





; +++ 'quit', 'exit', 'reboot' +++
reboot_command:
call    clear_screen

    mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgtend - offset msgt
	mov dl, 0
	mov dh, 0
	push cs
	pop es
	mov bp, offset msgt
	mov ah, 13h
	int 10h 
	
	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgrend - offset msgr
	mov dl, 0
	mov dh, 2
	push cs
	pop es
	mov bp, offset msgr
	mov ah, 13h
	int 10h
	         

mov ax, 0  ; wait for any key....
int 16h

; store magic value at 0040h:0072h:
;   0000h - cold boot.
;   1234h - warm boot.
mov     ax, 0040h
mov     ds, ax
mov     w.[0072h], 0000h ; cold boot.
jmp	0ffffh:0000h	 ; reboot!

; ++++++++++++++++++++++++++

processed:
ret  

msgt db " l",129,"tfen t",129,"m disketleri ",135,"",141,"kar",141,"n ", 0Dh,0Ah, 
msgtend: 
         
msgr db " ve yeniden ba",159,"latmak i",135,"in herhangi bir tu",159,"a bas",141,"n... ", 0Dh,0Ah, 
msgrend:  


;===========================================

; scroll all screen except last row
; up by value specified in al

scroll_t_area   proc    near

mov dx, 40h
mov es, dx  ; for getting screen parameters.
mov ah, 06h ; scroll up function id.
mov bh, 07  ; attribute for new lines.
mov ch, 0   ; upper row.
mov cl, 0   ; upper col.
mov di, 84h ; rows on screen -1,
mov dh, es:[di] ; lower row (byte).
dec dh  ; don't scroll bottom line.
mov di, 4ah ; columns on screen,
mov dl, es:[di]
dec dl  ; lower col.
int 10h

ret
scroll_t_area   endp

;===========================================




; get characters from keyboard and write a null terminated string 
; to buffer at DS:DI, maximum buffer size is in DX.
; 'enter' stops the input.
get_string      proc    near
push    ax
push    cx
push    di
push    dx

mov     cx, 0                   ; char counter.

cmp     dx, 1                   ; buffer too small?
jbe     empty_buffer            ;

dec     dx                      ; reserve space for last zero.


;============================
; eternal loop to get
; and processes key presses:

wait_for_key:

mov     ah, 0                   ; get pressed key.
int     16h

cmp     al, 0Dh                 ; 'return' pressed?
jz      exit


cmp     al, 8                   ; 'backspace' pressed?
jne     add_to_buffer
jcxz    wait_for_key            ; nothing to remove!
dec     cx
dec     di
putc    8                       ; backspace.
putc    ' '                     ; clear position.
putc    8                       ; backspace again.
jmp     wait_for_key

add_to_buffer:

        cmp     cx, dx          ; buffer is full?
        jae     wait_for_key    ; if so wait for 'backspace' or 'return'...

        mov     [di], al
        inc     di
        inc     cx
        
        ; print the key:
        mov     ah, 0eh
        int     10h

jmp     wait_for_key
;============================

exit:

; terminate by null:
mov     [di], 0

empty_buffer:

pop     dx
pop     di
pop     cx
pop     ax
ret
get_string      endp




; print a null terminated string at current cursor position, 
; string address: ds:si
print_string proc near
push    ax      ; store registers...
push    si      ;

next_char:      
        mov     al, [si]
        cmp     al, 0
        jz      printed
        inc     si
        mov     ah, 0eh ; teletype function.
        int     10h
        jmp     next_char
printed:

pop     si      ; re-store registers...
pop     ax      ;

ret
print_string endp



; clear the screen by scrolling entire screen window,
; and set cursor position on top.
; default attribute is set to white on blue.
clear_screen proc near
        push    ax      ; store registers...
        push    ds      ;
        push    bx      ;
        push    cx      ;
        push    di      ;

        mov     ax, 40h
        mov     ds, ax  ; for getting screen parameters.
        mov     ah, 06h ; scroll up function id.
        mov     al, 0   ; scroll all lines!
        mov     bh, 1111_0000b  ; attribute for new lines.
        mov     ch, 0   ; upper row.
        mov     cl, 0   ; upper col.
        mov     di, 84h ; rows on screen -1,
        mov     dh, [di] ; lower row (byte).
        mov     di, 4ah ; columns on screen,
        mov     dl, [di]
        dec     dl      ; lower col.
        int     10h

        ; set cursor position to top
        ; of the screen:
        mov     bh, 0   ; current page.
        mov     dl, 0   ; col.
        mov     dh, 0   ; row.
        mov     ah, 02
        int     10h

        pop     di      ; re-store registers...
        pop     cx      ;
        pop     bx      ;
        pop     ds      ;
        pop     ax      ;

        ret   
        
        
        
clear_screen endp






ret
;++++ 'count'++++++
; Count number of key presses. the result is in bx register.
;
; You must type into the emulator's screen,
; if it closes, press screen button to re-open it.

count_command:
call clear_screen
 

; print welcome message:
	mov al, 1
	mov bh, 0
	mov bl, 0000_1011b
	mov cx, msgcend - offset msgc ; calculate message size. 
	mov dl, 0
	mov dh, 0
	push cs
	pop es
	mov bp, offset msgc
	mov ah, 13h
	int 10h

xor bx, bx ; zero bx register.   

wait:  mov ah, 0   ; wait for any key....
       int 16h

       cmp al, 27  ; if key is 'esc' then exit.
       je stop

       mov ah, 0eh ; print it.
       int 10h

       inc bx ; increase bx on every key press.

       jmp wait


; print result message:
stop:  
	mov al, 1
	mov bh, 0

	mov cx, msgpend - offset msgp ; calculate message size. 
	mov dl, 10
	mov dh, 7
	push cs
	pop es
	mov bp, offset msgp
	mov ah, 13h
	int 10h

mov ax, bx
call print_ax

; wait for any key press:
mov ah, 0
int 16h

ret ; exit to operating system.

msgc db "T",129,"m tu",159,"lara bas",141,"",159,"lar",141,"n",141,"z sayaca",167,"",141,"m. Durdurmak i",135,"in 'Esc'ye bas",141,"n...", 0Dh,0Ah, ""
msgcend:
msgp db 0Dh,0Ah, "Kaydedilen tu",159," bas",141,"",159," say",141,"s",141,": "
msgpend: 




   
print_ax proc
cmp ax, 0
jne print_ax_r
    push ax
    mov al, '0'
    mov ah, 0eh
    int 10h
    pop ax
    ret 
print_ax_r:
    pusha
    mov dx, 0
    cmp ax, 0
    je pn_done
    mov bx, 10
    div bx    
    call print_ax_r
    mov ax, dx
    add al, 30h
    mov ah, 0eh
    int 10h    
    jmp pn_done
pn_done:
    popa  
    ret  
endp

jmp processed    

       
 
 ret
;"+++++'keyboard excess'"  


excess_command:   
call clear_screen

; this sample shows the use of keyboard functions.
; try typing something into emulator screen. 
;
; keyboard buffer is used, when someone types too fast.
;
; for realistic emulation, run this example at maximum speed
;
; this code will loop until you press esc key,
; all other keys will be printed.



; print a welcome message:
	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgdend - offset msgd ; calculate message size. 
	mov dl, 0
	mov dh, 0
	push cs
	pop es
	mov bp, offset msgd
	mov ah, 13h
	int 10h   
	


;============================
; eternal loop to get
; and print keys:

wait_for_key_:

; check for keystroke in
; keyboard buffer:
        mov     ah, 1
        int     16h
        jz      wait_for_key_

; get keystroke from keyboard:
; (remove from the buffer)
mov     ah, 0
int     16h

; print the key:
mov     ah, 0eh
int     10h

; press 'esc' to exit:
cmp     al, 1bh
jz      exitf

jmp     wait_for_key_
;============================

exitf:
ret

msgd  db "Herhangi bir ",159,"ey yaz...", 0Dh,0Ah
     db "[Enter] - sat",141,"r ba",159,"",141,".", 0Dh,0Ah
     db "[Ctrl]+[Enter] - sat",141,"r ilerletme.", 0Dh,0Ah
     db "Tampon doldu",167,"unda bir bip sesi duyabilirsiniz.", 0Dh,0Ah
     db "",128,"",141,"kmak i",135,"in Esc tu",159,"una bas",141,"n.", 0Dh,0Ah,  
msgdend:

endp

jmp processed   

ret   


;++++'decimal to binary'++++

binary_command:
call clear_screen



; this program inputs a decimal number
; and prints out its binary equivalent.

; convertion is done by convert_to_bin procedure,
; all other stuff is just for input/output.


jmp basla

; ascii buffer holds 16 bits of binary equivalent:
result db 16 dup('x'), 'b'
msgf db "Desteklenen de",167,"erler -32768 ila 65535", 0Dh,0Ah
     db "Dumaray",141," girin: " 
msgfend:

msgh db 0Dh,0Ah, "",152,"kiliye d",148,"n",129,"",159,"t",129,"r",129,"lm",129,"",159,": "  
msghend:



basla:
; print the message1:
	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msgfend - offset msgf ; calculate message size. 
	mov dl, 0
	mov dh, 0
	push cs
	pop es
	mov bp, offset msgf
	mov ah, 13h
	int 10h


call scan_num ; get the number to cx.

mov bx, cx

call convert_to_bin ; convert number in bx to result.

; print the message2:
	mov al, 1
	mov bh, 0
	mov bl, 0000_1010b
	mov cx, msghend - offset msgh ; calculate message size. 
	mov dl, 2
	mov dh, 2
	push cs
	pop es
	mov bp, offset msgh
	mov ah, 13h
	int 10h


; print the result string backwards:
mov si, offset result  ; set buffer's address to si.
mov ah, 0eh            ; teletype function of bios.
mov cx, 17             ; print 16 bits + suffix 'b'.
print_me:
	mov al, [si]
	int 10h ; print in teletype mode.
	inc si
loop print_me



; wait for any key....
mov ah, 0
int 16h


ret ; return to operating system.





; procedure to convert number in bx to its binary equivalent.
; result is stored in ascii buffer string.
convert_to_bin    proc     near
pusha

lea di, result

; print result in binary:
mov cx, 16
print: mov ah, 2   ; print function.
       mov [di], '0'
       test bx, 1000_0000_0000_0000b  ; test first bit.
       jz zero
       mov [di], '1'
zero:  shl bx, 1
       inc di
loop print

popa
ret
convert_to_bin   endp




; this macro prints a char in al and advances the current cursor position:
puts    macro   char
        push    ax
        mov     al, char
        mov     ah, 0eh
        int     10h     
        pop     ax
endm

; this procedure gets the multi-digit signed number from the keyboard,
; and stores the result in cx register:
scan_num        proc    near
        push    dx
        push    ax
        push    si
        
        mov     cx, 0

        ; reset flag:
        mov     cs:make_minus, 0

next_digit:

        ; get char from keyboard
        ; into al:
        mov     ah, 00h
        int     16h
        ; and print it:
        mov     ah, 0eh
        int     10h

        ; check for minus:
        cmp     al, '-'
        je      set_minus

        ; check for enter key:
        cmp     al, 13  ; carriage return?
        jne     not_cr
        jmp     stop_input
not_cr:


        cmp     al, 8                   ; 'backspace' pressed?
        jne     backspace_checked
        mov     dx, 0                   ; remove last digit by
        mov     ax, cx                  ; division:
        div     cs:ten                  ; ax = dx:ax / 10 (dx-rem).
        mov     cx, ax
        puts    ' '                     ; clear position.
        puts    8                       ; backspace again.
        jmp     next_digit
backspace_checked:


        ; allow only digits:
        cmp     al, '0'
        jae     ok_ae_0
        jmp     remove_not_digit
ok_ae_0:        
        cmp     al, '9'
        jbe     ok_digit
remove_not_digit:       
        puts    8       ; backspace.
        puts    ' '     ; clear last entered not digit.
        puts    8       ; backspace again.        
        jmp     next_digit ; wait for next input.       
ok_digit:


        ; multiply cx by 10 (first time the result is zero)
        push    ax
        mov     ax, cx
        mul     cs:ten                  ; dx:ax = ax*10
        mov     cx, ax
        pop     ax

        ; check if the number is too big
        ; (result should be 16 bits)
        cmp     dx, 0
        jne     too_big

        ; convert from ascii code:
        sub     al, 30h

        ; add al to cx:
        mov     ah, 0
        mov     dx, cx      ; backup, in case the result will be too big.
        add     cx, ax
        jc      too_big2    ; jump if the number is too big.

        jmp     next_digit

set_minus:
        mov     cs:make_minus, 1
        jmp     next_digit

too_big2:
        mov     cx, dx      ; restore the backuped value before add.
        mov     dx, 0       ; dx was zero before backup!
too_big:
        mov     ax, cx
        div     cs:ten  ; reverse last dx:ax = ax*10, make ax = dx:ax / 10
        mov     cx, ax
        puts    8       ; backspace.
        puts    ' '     ; clear last entered digit.
        puts    8       ; backspace again.        
        jmp     next_digit ; wait for enter/backspace.
        
        
stop_input:
        ; check flag:
        cmp     cs:make_minus, 0
        je      not_minus
        neg     cx
not_minus:

        pop     si
        pop     ax
        pop     dx
        ret
make_minus      db      ?       ; used as a flag.
ten             dw      10      ; used as multiplier.
scan_num        endp