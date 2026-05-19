        include "lib/hw/to8_hw.inc"
        include "lib/hw/to8_rom.inc"
        include "lib/variables.asm"


; ============================================================
; TO8 horizontal scrolling demo
; 6809 strict
; viewport: 32x10 tiles
; map     : 400x10 tiles
; tiles   : 32 tiles, 8x8, 1bpp
; preshift: 8 horizontal phases, 2 bytes per line
; plans   : alternating A/B
;
; IMPORTANT:
; - Fill exact TO8 video constants below
; - Macro syntax may need minor adaptation depending on assembler
; ============================================================

; ============================================================
; TO8 PARAMS TO FILL
; ============================================================

GATE_MODE       EQU $46
BORDER_COLOR    EQU $00

VRAM_PLAN_A     EQU $4000
VRAM_PLAN_B     EQU $6000
SCREEN_STRIDE   EQU 40

; ============================================================
; CONSTANTS
; ============================================================

NUM_TILES       EQU 32
VIEW_W_TILES    EQU 32
VIEW_H_TILES    EQU 10
MAP_W           EQU 400
MAP_H           EQU 10

LINE_ADVANCE    EQU SCREEN_STRIDE
TILE_SHIFT_SIZE EQU 16           ; 8 lines * 2 bytes
TILE_PRESH_SIZE EQU 128          ; 8 shifts * 16 bytes

TILE_EMPTY      EQU 0
TILE_SKY        EQU 1
TILE_SKY2       EQU 2
TILE_CLOUD      EQU 3
TILE_DIRT       EQU 4
TILE_GRASS_TOP  EQU 5
TILE_GRASS_L    EQU 6
TILE_GRASS_R    EQU 7
TILE_DIRT_1     EQU 8
TILE_DIRT_2     EQU 9
TILE_SLOPE_UP1  EQU 10
TILE_SLOPE_UP2  EQU 11
TILE_SLOPE_DN1  EQU 12
TILE_SLOPE_DN2  EQU 13
TILE_PLAT_M     EQU 14
TILE_PLAT_L     EQU 15
TILE_PLAT_R     EQU 16
TILE_PILLAR     EQU 17
TILE_TREE_TRUNK EQU 18
TILE_TREE_TOP   EQU 19
TILE_ROCK       EQU 20
TILE_FLOWER     EQU 21
TILE_RING       EQU 22
TILE_SPRING     EQU 23
TILE_SIGN       EQU 24
TILE_BUSH1      EQU 25
TILE_BUSH2      EQU 26
TILE_MOTIF1     EQU 27
TILE_MOTIF2     EQU 28
TILE_MOTIF3     EQU 29
TILE_MOTIF4     EQU 30
TILE_MOTIF5     EQU 31


; ============================================================
; CODE
; ============================================================

                ORG $A000

start:
                JSR init_video
                JSR init_engine

main_loop:
                JSR update_camera_auto
                JSR render_viewport_optimized
                BRA main_loop

init_video:
                LDA #GATE_MODE
                STA DISPLAY_CTRL
                LDA #BORDER_COLOR
                STA GA_SYS2
                RTS

init_engine:
                CLRA
                CLRB
                STD cam_x
                RTS

; cam_x += 1 until end
; max x = (400 - 32) * 8 = 2944
update_camera_auto:
                LDD cam_x
                CMPD #2944
                BHS update_camera_done
                ADDD #1
                STD cam_x
update_camera_done:
                RTS

compute_camera:
                ; shift_x = cam_x & 7
                LDA cam_x+1
                ANDA #7
                STA shift_x

                ; tile_x = cam_x >> 3
                LDD cam_x
                LSRA
                RORB
                LSRA
                RORB
                LSRA
                RORB
                STD tile_x
                RTS

render_viewport_optimized:
                JSR compute_camera

                LDA #0
                STA row_counter

rv_row_loop:
                ; map row base
                LDA row_counter
                ASLA
                TFR A,B
                CLRA
                ADDD #map_row_table
                TFR D,X
                LDD ,X
                ADDD tile_x
                STD map_ptr

                ; screen row base A
                LDA row_counter
                ASLA
                TFR A,B
                CLRA
                ADDD #screen_row_table_a
                TFR D,X
                LDD ,X
                STD dst_ptr_a

                ; screen row base B
                LDA row_counter
                ASLA
                TFR A,B
                CLRA
                ADDD #screen_row_table_b
                TFR D,X
                LDD ,X
                STD dst_ptr_b

                ; world_col = tile_x
                LDD tile_x
                STD world_col

                LDA #VIEW_W_TILES
                STA col_counter

rv_col_loop:
                LDX map_ptr
                LDA ,X
                STA tmp0

                JSR get_tile_shift_ptr

                ; parity on world column
                LDD world_col
                ANDB #1
                BEQ rv_to_a

rv_to_b:
                LDY dst_ptr_b
                JSR draw_tile_8x8_2bytes
                BRA rv_after

rv_to_a:
                LDY dst_ptr_a
                JSR draw_tile_8x8_2bytes

rv_after:
                LDD map_ptr
                ADDD #1
                STD map_ptr

                LDD world_col
                ADDD #1
                STD world_col

                LDD dst_ptr_a
                ADDD #2
                STD dst_ptr_a

                LDD dst_ptr_b
                ADDD #2
                STD dst_ptr_b

                DEC col_counter
                BNE rv_col_loop

                INC row_counter
                LDA row_counter
                CMPA #VIEW_H_TILES
                LBNE rv_row_loop
                RTS

get_tile_shift_ptr:
                ; tile pointer table lookup
                LDA tmp0
                ASLA
                TFR A,B
                CLRA
                ADDD #tile_addr_table
                TFR D,X

                LDD ,X
                STD src_ptr

                ; add shift_x * 16
                LDA shift_x
                LDB #16
                MUL
                ADDD src_ptr
                TFR D,X
                RTS

; input:
;   X = source tile shift block (16 bytes)
;   Y = destination
;
; verified twice:
; - X increments by 2 each line
; - Y increments by SCREEN_STRIDE each line
; - D carries 2 bytes
; - LDD/STD preserve big-endian order
draw_tile_8x8_2bytes:
                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                LEAY LINE_ADVANCE,Y

                LDD ,X++
                STD ,Y
                RTS

; ============================================================
; TABLES
; ============================================================

screen_row_table_a:
                FDB VRAM_PLAN_A + 0*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 1*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 2*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 3*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 4*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 5*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 6*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 7*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 8*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_A + 9*(8*SCREEN_STRIDE)

screen_row_table_b:
                FDB VRAM_PLAN_B + 0*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 1*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 2*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 3*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 4*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 5*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 6*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 7*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 8*(8*SCREEN_STRIDE)
                FDB VRAM_PLAN_B + 9*(8*SCREEN_STRIDE)

map_row_table:
                FDB level_map + 0*MAP_W
                FDB level_map + 1*MAP_W
                FDB level_map + 2*MAP_W
                FDB level_map + 3*MAP_W
                FDB level_map + 4*MAP_W
                FDB level_map + 5*MAP_W
                FDB level_map + 6*MAP_W
                FDB level_map + 7*MAP_W
                FDB level_map + 8*MAP_W
                FDB level_map + 9*MAP_W

tile_addr_table:
                FDB tile_0
                FDB tile_1
                FDB tile_2
                FDB tile_3
                FDB tile_4
                FDB tile_5
                FDB tile_6
                FDB tile_7
                FDB tile_8
                FDB tile_9
                FDB tile_10
                FDB tile_11
                FDB tile_12
                FDB tile_13
                FDB tile_14
                FDB tile_15
                FDB tile_16
                FDB tile_17
                FDB tile_18
                FDB tile_19
                FDB tile_20
                FDB tile_21
                FDB tile_22
                FDB tile_23
                FDB tile_24
                FDB tile_25
                FDB tile_26
                FDB tile_27
                FDB tile_28
                FDB tile_29
                FDB tile_30
                FDB tile_31

; ============================================================
; MACROS LWASM-COMPATIBLE TO GENERATE PRESHIFTED TILE DATA
; Parameters are referenced with \1..\9
; ============================================================

SHIFT0  MACRO
        FCB \1,0
        FCB \2,0
        FCB \3,0
        FCB \4,0
        FCB \5,0
        FCB \6,0
        FCB \7,0
        FCB \8,0
        ENDM

SHIFT1  MACRO
        FCB (\1/2),((\1%2)*128)
        FCB (\2/2),((\2%2)*128)
        FCB (\3/2),((\3%2)*128)
        FCB (\4/2),((\4%2)*128)
        FCB (\5/2),((\5%2)*128)
        FCB (\6/2),((\6%2)*128)
        FCB (\7/2),((\7%2)*128)
        FCB (\8/2),((\8%2)*128)
        ENDM

SHIFT2  MACRO
        FCB (\1/4),((\1%4)*64)
        FCB (\2/4),((\2%4)*64)
        FCB (\3/4),((\3%4)*64)
        FCB (\4/4),((\4%4)*64)
        FCB (\5/4),((\5%4)*64)
        FCB (\6/4),((\6%4)*64)
        FCB (\7/4),((\7%4)*64)
        FCB (\8/4),((\8%4)*64)
        ENDM

SHIFT3  MACRO
        FCB (\1/8),((\1%8)*32)
        FCB (\2/8),((\2%8)*32)
        FCB (\3/8),((\3%8)*32)
        FCB (\4/8),((\4%8)*32)
        FCB (\5/8),((\5%8)*32)
        FCB (\6/8),((\6%8)*32)
        FCB (\7/8),((\7%8)*32)
        FCB (\8/8),((\8%8)*32)
        ENDM

SHIFT4  MACRO
        FCB (\1/16),((\1%16)*16)
        FCB (\2/16),((\2%16)*16)
        FCB (\3/16),((\3%16)*16)
        FCB (\4/16),((\4%16)*16)
        FCB (\5/16),((\5%16)*16)
        FCB (\6/16),((\6%16)*16)
        FCB (\7/16),((\7%16)*16)
        FCB (\8/16),((\8%16)*16)
        ENDM

SHIFT5  MACRO
        FCB (\1/32),((\1%32)*8)
        FCB (\2/32),((\2%32)*8)
        FCB (\3/32),((\3%32)*8)
        FCB (\4/32),((\4%32)*8)
        FCB (\5/32),((\5%32)*8)
        FCB (\6/32),((\6%32)*8)
        FCB (\7/32),((\7%32)*8)
        FCB (\8/32),((\8%32)*8)
        ENDM

SHIFT6  MACRO
        FCB (\1/64),((\1%64)*4)
        FCB (\2/64),((\2%64)*4)
        FCB (\3/64),((\3%64)*4)
        FCB (\4/64),((\4%64)*4)
        FCB (\5/64),((\5%64)*4)
        FCB (\6/64),((\6%64)*4)
        FCB (\7/64),((\7%64)*4)
        FCB (\8/64),((\8%64)*4)
        ENDM

SHIFT7  MACRO
        FCB (\1/128),((\1%128)*2)
        FCB (\2/128),((\2%128)*2)
        FCB (\3/128),((\3%128)*2)
        FCB (\4/128),((\4%128)*2)
        FCB (\5/128),((\5%128)*2)
        FCB (\6/128),((\6%128)*2)
        FCB (\7/128),((\7%128)*2)
        FCB (\8/128),((\8%128)*2)
        ENDM

GENTILE  MACRO
\1:
        SHIFT0 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT1 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT2 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT3 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT4 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT5 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT6 \2,\3,\4,\5,\6,\7,\8,\9
        SHIFT7 \2,\3,\4,\5,\6,\7,\8,\9
        ENDM

; ============================================================
; ALL 32 PRESHIFTED TILES
; ============================================================

        GENTILE tile_0,$00,$00,$00,$00,$00,$00,$00,$00
        GENTILE tile_1,$00,$00,$00,$00,$00,$00,$00,$00
        GENTILE tile_2,$00,$08,$00,$80,$00,$01,$00,$10
        GENTILE tile_3,$00,$18,$3C,$7E,$FF,$7E,$3C,$00
        GENTILE tile_4,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        GENTILE tile_5,$AA,$55,$FF,$FF,$FF,$FF,$FF,$FF
        GENTILE tile_6,$2A,$15,$3F,$3F,$3F,$3F,$3F,$3F
        GENTILE tile_7,$A8,$50,$FC,$FC,$FC,$FC,$FC,$FC
        GENTILE tile_8,$FF,$EF,$FF,$DF,$FD,$FF,$F7,$FF
        GENTILE tile_9,$FF,$FE,$FF,$FB,$FF,$BF,$FF,$FD
        GENTILE tile_10,$03,$07,$0F,$1F,$3F,$7F,$FF,$FF
        GENTILE tile_11,$00,$01,$03,$07,$0F,$1F,$3F,$7F
        GENTILE tile_12,$C0,$E0,$F0,$F8,$FC,$FE,$FF,$FF
        GENTILE tile_13,$00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        GENTILE tile_14,$00,$00,$FF,$FF,$00,$00,$00,$00
        GENTILE tile_15,$00,$00,$3F,$3F,$00,$00,$00,$00
        GENTILE tile_16,$00,$00,$FC,$FC,$00,$00,$00,$00
        GENTILE tile_17,$18,$18,$18,$18,$18,$18,$18,$18
        GENTILE tile_18,$18,$18,$18,$18,$18,$3C,$3C,$3C
        GENTILE tile_19,$18,$3C,$7E,$FF,$FF,$7E,$3C,$18
        GENTILE tile_20,$00,$38,$7C,$FE,$FE,$7C,$38,$00
        GENTILE tile_21,$00,$24,$18,$7E,$18,$18,$3C,$00
        GENTILE tile_22,$00,$3C,$66,$C3,$C3,$66,$3C,$00
        GENTILE tile_23,$00,$3C,$3C,$18,$3C,$7E,$FF,$00
        GENTILE tile_24,$3C,$3C,$3C,$18,$18,$18,$3C,$3C
        GENTILE tile_25,$00,$24,$7E,$FF,$FF,$7E,$24,$00
        GENTILE tile_26,$00,$18,$7E,$FF,$FF,$7E,$18,$00
        GENTILE tile_27,$81,$00,$24,$00,$18,$00,$42,$00
        GENTILE tile_28,$00,$42,$00,$24,$00,$18,$00,$81
        GENTILE tile_29,$10,$00,$20,$00,$04,$00,$08,$00
        GENTILE tile_30,$00,$80,$00,$02,$00,$20,$00,$08
        GENTILE tile_31,$00,$18,$3C,$7E,$3C,$18,$00,$00

; ============================================================
; LEVEL MAP 400x10
; ============================================================
; ============================================================
; MAP ROW PATTERN MACROS
; ============================================================

ROW_CLOUDS  MACRO
        FCB 1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,3,1,1,1,1
        ENDM

ROW_SKY2  MACRO
        FCB 1,2,1,1,1,1,2,1,1,1,1,1,2,1,1,1,1,2,1,1,1,1,1,2,1,1,1,1,2,1,1,1
        ENDM

ROW_PLATFORMS  MACRO
        FCB 1,1,1,1,1,15,14,14,16,1,1,1,1,1,1,1,1,1,1,1,15,14,16,1,1,1,1,1,1,1,1,1
        ENDM

ROW_RINGS  MACRO
        FCB 1,1,1,1,1,1,1,1,1,1,22,22,22,1,1,1,1,1,1,1,1,1,1,1,1,22,22,22,1,1,1,1
        ENDM

ROW_DECO_SKY  MACRO
        FCB 1,1,27,1,1,1,28,1,1,1,29,1,1,1,30,1,1,1,31,1,1,1,27,1,1,1,28,1,1,1,29,1
        ENDM

ROW_SPARSE_PROPS  MACRO
        FCB 1,1,1,1,19,1,1,20,1,1,21,1,1,18,1,1,24,1,1,25,1,1,26,1,1,19,1,1,20,1,1,1
        ENDM

ROW_GRASS_MID  MACRO
        FCB 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
        ENDM

ROW_DIRT_A  MACRO
        FCB 8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4
        ENDM

ROW_DIRT_B  MACRO
        FCB 9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4
        ENDM

; ============================================================
; LEVEL MAP 400x10
; ============================================================

level_map:

; row 0 sky
        FILL TILE_SKY,400

; row 1 sparse clouds
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        ROW_CLOUDS
        FCB 1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,3

; row 2 sky with sparse sky2 motifs
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        ROW_SKY2
        FCB 1,2,1,1,1,1,2,1,1,1,1,1,2,1,1,1

; row 3 platforms
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        ROW_PLATFORMS
        FCB 1,1,1,1,1,15,14,14,16,1,1,1,1,1,1,1

; row 4 rings
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        ROW_RINGS
        FCB 1,1,1,1,1,1,1,1,1,1,22,22,22,1,1,1

; row 5 decorative sky
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        ROW_DECO_SKY
        FCB 1,1,30,1,1,1,31,1,1,1,27,1,1,1,28,1

; row 6 sparse props
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        ROW_SPARSE_PROPS
        FCB 1,21,1,1,18,1,1,24,1,1,25,1,1,26,1,1

; row 7 grass line
        FCB 6
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        ROW_GRASS_MID
        FCB 5,5,5,5,5,5,5,5,5,5,5,5,5,5,7
; row 8 dirt
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        ROW_DIRT_A
        FCB 8,4,9,4,8,4,9,4,8,4,9,4,8,4,9,4

; row 9 dirt
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        ROW_DIRT_B
        FCB 9,4,8,4,9,4,8,4,9,4,8,4,9,4,8,4

        END start