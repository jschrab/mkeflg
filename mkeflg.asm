    processor 6502
    include vcs.h
    include macro.h

;==============================================================================
; MKEFLG - Render The People's Flag of Milwaukee
;
; Kernel pattern and many tips from:
; https://www.randomterrain.com/atari-2600-memories-tutorial-andrew-davie-01.html
; 
; JDS - 18-Jan-2020
;==============================================================================
; Top half of flag "Orange" is #FFA500
; 2600 NTSC $2A = #FF8900
; 2600 NTSC $2C = #FFB100 (closer)

FLAG_COLOR_TOP  = $2C ; Orange
SUN_COLOR_TOP   = $0E ; "White"

; Bottom half of flag "Navy Blue" is #052241
; 2600 NTSC $80 = #050077

FLAG_COLOR_BTM  = $80   ; Blue
SUN_COLOR_BTM   = $98   ; Light Blue

SCREEN_HALF = ((192/2) / 8)

;==============================================================================
; START
;
                SEG
                ORG $F000  ; Starting location of ROM
Start           SEI        ; Disable any interrupts

;==============================================================================
; RESET
;
Reset           CLD        ; Clear BCD math bit

                LDX #$FF
                TXS        ; Set stack to beginning

                LDA #0     ; Loop backwards from $FF to $00
.ClearLoop      STA $00,X  ; and clear each memory location
                DEX
                BNE .ClearLoop

;==============================================================================
; INIT
;
Initialize      LDA #FLAG_COLOR_TOP
                STA COLUBK

                LDA #SUN_COLOR_TOP
                STA COLUPF             ; set the playfield color

                LDA #%00000001
                STA CTRLPF             ; reflect playfield

;==============================================================================
; MAIN LOOP
;
MainLoop        JSR VerticalSync
                JSR VerticalBlank
                JSR FrameSetup
                JSR Scanline
                JSR OverScan
                JMP MainLoop

;==============================================================================
; V-SYNC (3 Scanlines)
;
; Reset TV Signal to indicate new frame
; D1 but must be enabled here which is 00000010 (e.g 2 in dec.)
;
VerticalSync    LDA #0
                STA VBLANK

                LDA #2
                STA VSYNC  ; Begin VSYNC period

                STA WSYNC  ; Halt 6502 until end of scanline 1
                STA WSYNC  ; Halt 6502 until end of scanline 2
                RTS

;==============================================================================
; V-BLANK (37 Scanlines)
;
; Start a timer for enough cycles to approximate 36 scanlines
; Ideally, we're putting logic here instead.
; At 228 clock counts per scan line, we get 36 * 228 = 8208
; therefore 6502 instruction count would be 8208 / 3 = 2736
; 42 * 64 = 2688 (close enough, we'll fix it on the last line)
;
VerticalBlank   LDA #42
                STA TIM64T  ; Start the timer with 42 ticks

                LDA #$00
                STA WSYNC  ; Halt 6502 until end of scanline 3
                STA VSYNC  ; End VSYNC period
                RTS

;==============================================================================
; FRAME SETUP
;
FrameSetup      LDA #FLAG_COLOR_TOP
                STA COLUBK

                LDA #$00
                STA PF0 ; Stays unchanged throughout execution
                STA PF1 ; Stays unchanged throughout execution
                STA PF2

                RTS
                ; V-BLANK is finished at start of Scanline

;==============================================================================
; SCANLINE (192 Scanlines)
;
Scanline        LDA INTIM ; Loop until the V-Blank timer finishes
                BNE Scanline

                LDA #SUN_COLOR_TOP
                STA COLUPF ; set the playfield color

                LDX #SCREEN_HALF;
                LDY #$00

                LDA #$00 ; End V-BLANK period with 0
                STA WSYNC ; Halt 6502 until end of scanline
                STA VBLANK ; Begin drawing to screen again

.TopHalfLoop    LDA PFData2,Y
                STA PF2

                STA WSYNC ; Halt 6502 until end of scanline
                STA WSYNC ; Halt 6502 until end of scanline
                STA WSYNC ; Halt 6502 until end of scanline
                STA WSYNC ; Halt 6502 until end of scanline

                STA WSYNC ; Halt 6502 until end of scanline
                STA WSYNC ; Halt 6502 until end of scanline
                STA WSYNC ; Halt 6502 until end of scanline
                STA WSYNC ; Halt 6502 until end of scanline

                INY

                DEX
                BNE .TopHalfLoop

                ;==================================
                STA WSYNC ; Halt 6502 until end of scanline
                LDA #FLAG_COLOR_BTM
                STA COLUBK

                LDA #FLAG_COLOR_BTM
                STA COLUP0

                LDA #SUN_COLOR_BTM
                STA COLUPF ; set the playfield color
 
                ;==================================

                LDX #SCREEN_HALF;
.BtmHalfLoop    LDA PFData2,Y
                STA PF2

                STA WSYNC  ; Halt 6502 until end of scanline
                STA WSYNC  ; Halt 6502 until end of scanline
                STA WSYNC  ; Halt 6502 until end of scanline
                STA WSYNC  ; Halt 6502 until end of scanline

                STA WSYNC  ; Halt 6502 until end of scanline
                STA WSYNC  ; Halt 6502 until end of scanline
                STA WSYNC  ; Halt 6502 until end of scanline
                STA WSYNC  ; Halt 6502 until end of scanline

                INY

                DEX
                BNE .BtmHalfLoop
                ;==================================
                ; End
                ;
                LDA #2
                STA VBLANK ; Suppress drawing to screen
                RTS

;==============================================================================
; OVERSCAN (30 Scanlines)
;
OverScan        LDX #30 ; x = 30;
                LDA #2
.OSLoop         STA WSYNC ; Halt 6502 until end of scanline
                DEX ; x--
                BNE .OSLoop ; if x !== 0 goto .OSLoop
                RTS

;==============================================================================
; Rising sun data
;
;==============================================================================
PFData2
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%11100000
            .byte #%11110000
            .byte #%11111000
            .byte #%11111100

            .byte #%00000000
            .byte #%11111100
            .byte #%00000000
            .byte #%11111000
            .byte #%00000000
            .byte #%11100000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000
            .byte #%00000000

;==============================================================================
; INTERRUPT VECTORS
;
                org $FFFC ; 6502 looks here to start execution

                .word Start ; NMI
                .word Start ; Reset
                .word Start ; IRQ
