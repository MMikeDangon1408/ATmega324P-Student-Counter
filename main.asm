;------------------------------------------------------------------------------
; Project: De tai 9 - Thiet ke he thong hien thi so luong sinh vien trong lop hoc
; Microcontroller: ATmega324PA
; Description: Dem so luong sinh vien su dung ngat ngoai (INT)
;              Su dung cac nut nhan (co chong rung) de gia lap nguoi vao/ra
;              Hien thi so SV len 3 LED7Seg bang phuong phap quet
;              LED Green: SV <= 120, LED Red: SV > 120
;              Nut RESET: hien thi "000", Green ON, Red OFF
;------------------------------------------------------------------------------
.EQU OUTPORT = PORTC
.EQU SR_ADR = 0X100
.EQU LIMIT = 120
.EQU DEBOUNCE_DELAY = 200  ; DELAY 20MS
.DEF COUNTL = R24          ; BYTE THAP BIEN DEM
.DEF COUNTH = R25          ; BYTE CAO BIEN DEM 
;------------------------------------------------------------------------------
.ORG 0
    RJMP MAIN

.ORG INT0addr
    RJMP INT0_ENTRY_ISR    ; INT0 (ENTRY)

.ORG INT1addr
    RJMP INT1_EXIT_ISR     ; INT1 (EXIT)

.ORG INT2addr
    RJMP RESET_ISR         ; INT2 (RESET)

.ORG 0X40
MAIN:
    LDI R16, HIGH(RAMEND)  ; DUA STACK LEN DINH SRAM
    OUT SPH, R16
    LDI R16, LOW(RAMEND)
    OUT SPL, R16

    RCALL INIT
    RCALL INTERRUPT_EN
    
MAIN_LOOP:
    RCALL SCAN_3LA
    RJMP MAIN_LOOP

;-------------------------------------------------------
; INIT: Cau hinh I/O
;-------------------------------------------------------
INIT:
    LDI R16, 0X1B          ; PB0, PB1: LE0, LE1; PB3: Green; PB4: Red; PB2: Input
    OUT DDRB, R16
    LDI R16, (1<<2)        ; Cau hinh dien tro keo len cho PB2 (Reset)
    OUT PORTB, R16
    LDI R16, (1<<2)|(1<<3) ; Cau hinh dien tro keo len cho PD2 (INT0), PD3 (INT1)
    OUT PORTD, R16
    LDI R16, 0xFF          ; PORTC = OUTPUT cua 7-segment
    OUT DDRC, R16
    CBI PORTB, 0           ; Lock LE0
    CBI PORTB, 1           ; Lock LE1
    CLR COUNTH             ; Initial count = 0
    CLR COUNTL
    CLR R21
    CLR R20
    RCALL UPDATE_LEDS      ; Cap nhat trang thai LED
    RET

;-------------------------------------------------------
; INTERRUPT_EN: 
;-------------------------------------------------------
INTERRUPT_EN:
    SEI                    ; CHO PHEP NGAT TOAN CUC
    LDI R16, (1<<ISC21)|(1<<ISC11)|(1<<ISC01) ; CHO PHEP NGAT CANH XUONG
    STS EICRA, R16
    LDI R16, (1<<INT2)|(1<<INT1)|(1<<INT0)    ; CHO PHEP NGAT INT0, INT1, INT2
    OUT EIMSK, R16
    RET

;------------------------------------------------------- 
; SCAN_3LA: Hien thi 3 LED AC bang phuong phap quet
; Input: R21, R20 - So BCD nen (R21: hang tram, R20: hang chuc va don vi)
; Su dung: BCD_UNP, DELAY_US, GET_7SEG
; Thanh ghi: R17(temp register), R18(LED scanning counter), R19(ma quet LED), X
;-------------------------------------------------------
SCAN_3LA:
    RCALL BCD_UNP
    LDI R18, 3
    LDI R19, 0xFE
    LDI XH, HIGH(SR_ADR)
    LDI XL, LOW(SR_ADR)

LOOP:
    LDI R17, 0x0F
    OUT OUTPORT, R17
    SBI PORTB, 1
    CBI PORTB, 1
    LD R17, X+
    RCALL GET_7SEG
    OUT OUTPORT, R17
    SBI PORTB, 0
    CBI PORTB, 0
    OUT OUTPORT, R19
    SBI PORTB, 1
    CBI PORTB, 1
    LDI R16, 10
    RCALL DELAY_US
    SEC
    ROL R19
    DEC R18
    BRNE LOOP
    RET

;------------------------------------------------------- 
/* Chuong trinh con BCD_UNP: co chuc nang chuyen 2 so BCD nen trong thanh ghi 
R20 (chuc_don vi) v  R21 (ngan_tram) thanh 3 so BCD khong nen. Ket qua tuong ung voi 
hang don vi, hang chuc, hang tram, ngan duoc luu lan luot trong 3 o nho SRAM co addr: 
SR_ADR, SR_ADR + 1, SR_ADR + 2    */
;-------------------------------------------------------
BCD_UNP:
    LDI XH, HIGH(SR_ADR)   ;X tro dia chi dauu SRAM
    LDI XL, LOW(SR_ADR)    
    MOV R17, R20           ;lay so BCD nen trong so thap
    ANDI R17, 0x0F         ;lay so BCD thap
    ST X+, R17             ;cat vao SRAM, tang dia chi SRAM
    MOV R17, R20           ;lay lai so BCD
    SWAP R17               ;hoan vi 2 so BCD
    ANDI R17, 0x0F         ;lay so BCD cao
    ST X+, R17             ;cat vao SRAM, tang dia chi SRAM
    MOV R17, R21           ;lay so BCD nen trong so cao
    ANDI R17, 0x0F         ;lay so BCD thap
    ST X+, R17             ;cat vao SRAM, tang dia chi SRAM
    RET

;------------------------------------------------------- 
;GET_7SEG tra ma 7 doan tu data doc vao
;Input R17=ma Hex,Output R17=ma 7 doan
;-------------------------------------------------------
GET_7SEG:
    LDI ZH, HIGH(TAB_7SA<<1)
    LDI ZL, LOW(TAB_7SA<<1)
    ADD R30, R17
    LDI R17, 0
    ADC R31, R17
    LPM R17, Z
    RET

;-------------------------------------------------------
; BIN16_BCD_3DIGIT: Chuyen so [BIN] 16bit sang so BCD 3 digit
; Input: R19:R18 = so nhi phan 16-bit
; Output: R20,R21 = so BCD nen, R21 trong so cao
; Su dung CTC DIV16_8, R16=10 so chia
;-------------------------------------------------------
BIN16_BCD_3DIGIT:
	CLR R20          ; xoa cac thanh ghi ket qua
	CLR R21
 ; 1st division
    LDI R16, 10      ; so chia R16 = 10
    RCALL DIV16_8    
    MOV R20, R16     ; R20 = so du phep chia dau

 ; 2nd division
    LDI R16, 10      ; so chia R16 = 10
    RCALL DIV16_8
    SWAP R16         ;chuyen du so phep chia lan 2 len 4 bit cao
    OR R20, R16      ;dan du so phep chia lan 2 vao 4 bit cao cua R20

    MOV R21, R18     ;R21=thuong so sau cung
    RET

;-------------------------------------------------------
; DIV16_8: Chia so nhi phan 16 bit cho 8 bit
; Input: R19:R18 = so bi chia, R16 = 10 so chia
; Output: R19:R18 = thuong, R16 = so du 
; Su dung R28, R29, R0
;-------------------------------------------------------
DIV16_8:
    CLR R28         ; R29:R28=thuong so
    CLR R29
    CLR R0
DIV_LOOP:
    CP R18, R16     ; so sanh R19:R18 va 10
    CPC R19, R0
    BRLO END_LOOP   ; ket qua nho hon thi khong chia duoc
    SUB R18, R16    ; so bi chia - so chia
    SBC R19, R0     ; tru Carry vao byte cao
    ADIW R28, 1     ; thuong so + 1
    RJMP DIV_LOOP
END_LOOP:
    MOV R16, R18    ; R16 la so du
    MOV R18, R28    ; Byte thap thuong
    MOV R19, R29    ; Byte cao thuong
    RET

;-------------------------------------------------------    
;DELAY_US: DELAY Td = R16 x 100 (us) (Fosc=8MHz, CKDIV8 = 1)
;Input:R16, HE SO NHAN: 1 -> 255
;-------------------------------------------------------
DELAY_US:
    MOV R15, R16
    LDI R16, 200
L1:
    MOV R14, R16
L2:
    NOP
    DEC R14
    BRNE L2
    DEC R15
    BRNE L1
    RET

;-------------------------------------------------------
; UPDATE_LEDS: ON/OFF GREEN/RED LED
;-------------------------------------------------------
UPDATE_LEDS:
    LDI R17, HIGH(LIMIT+1)
    LDI R16, LOW(LIMIT+1)
    CP COUNTL, R16
    CPC COUNTH, R17
    BRSH LED_RED_ON
    SBI PORTB, 3      ; Green ON
    CBI PORTB, 4      ; Red OFF
    RET
LED_RED_ON:
    CBI PORTB, 3      ; Green OFF
    SBI PORTB, 4      ; Red ON
    RET

;-------------------------------------------------------
; INT0_ENTRY_ISR: ENTRY BUTTON (PD2)
;-------------------------------------------------------
INT0_ENTRY_ISR:
    PUSH R14
    PUSH R15
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    IN R16, SREG
    PUSH R16

NHAN_ENTRY:
    SBIC PIND, 2
    RJMP NHAN_ENTRY
    LDI R16, DEBOUNCE_DELAY
    RCALL DELAY_US
    SBIC PIND, 2
    RJMP NHAN_ENTRY

    ADIW COUNTL, 1
    LDI R17, HIGH(1000)
    LDI R16, LOW(1000)
    CP COUNTL, R16
    CPC COUNTH, R17
    BRLO LESS_THAN_1000
    LDI COUNTH, HIGH(999)
    LDI COUNTL, LOW(999)

LESS_THAN_1000:
NHA_ENTRY:
    SBIS PIND, 2
    RJMP NHA_ENTRY
    LDI R16, DEBOUNCE_DELAY
    RCALL DELAY_US
    SBIS PIND, 2
    RJMP NHA_ENTRY

    MOVW R18, COUNTL
    RCALL BIN16_BCD_3DIGIT
    RCALL UPDATE_LEDS

    POP R16
    OUT SREG, R16
    POP R19
    POP R18
    POP R17
    POP R16
    POP R15
    POP R14
    RETI

;-------------------------------------------------------
; INT1_EXIT_ISR: EXIT BUTTON (PD3)
;-------------------------------------------------------
INT1_EXIT_ISR:
    PUSH R14
    PUSH R15
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    IN R16, SREG
    PUSH R16

NHAN_EXIT:
    SBIC PIND, 3
    RJMP NHAN_EXIT
    LDI R16, DEBOUNCE_DELAY
    RCALL DELAY_US
    SBIC PIND, 3
    RJMP NHAN_EXIT

    SBIW COUNTL, 1
    BRCC ABOVE_ZERO
    CLR COUNTH
    CLR COUNTL

ABOVE_ZERO:
NHA_EXIT:
    SBIS PIND, 3
    RJMP NHA_EXIT
    LDI R16, DEBOUNCE_DELAY
    RCALL DELAY_US
    SBIS PIND, 3
    RJMP NHA_EXIT

    MOVW R18, COUNTL
    RCALL BIN16_BCD_3DIGIT
    RCALL UPDATE_LEDS

    POP R16
    OUT SREG, R16
    POP R19
    POP R18
    POP R17
    POP R16
    POP R15
    POP R14
    RETI

;-------------------------------------------------------
; RESET_ISR: RESET BUTTON (PB2)
;-------------------------------------------------------
RESET_ISR:
    PUSH R14
    PUSH R15
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    IN R16, SREG
    PUSH R16

LOOP_RESET1:
    SBIC PINB, 2
    RJMP LOOP_RESET1
    LDI R16, DEBOUNCE_DELAY
    RCALL DELAY_US
    SBIC PINB, 2
    RJMP LOOP_RESET1

LOOP_RESET2:
    SBIS PINB, 2
    RJMP LOOP_RESET2
    LDI R16, DEBOUNCE_DELAY
    RCALL DELAY_US
    SBIS PINB, 2
    RJMP LOOP_RESET2

    CLR COUNTH
    CLR COUNTL
    MOVW R18, COUNTL
    RCALL BIN16_BCD_3DIGIT
    RCALL UPDATE_LEDS

    POP R16
    OUT SREG, R16
    POP R19
    POP R18
    POP R17
    POP R16
    POP R15
    POP R14
    RETI

;-------------------------------------------------------
TAB_7SA: 
.DB 0XC0,0XF9,0XA4,0XB0,0X99,0X92,0X82,0XF8,0X80,0X90 ; Code LED7SEG AC