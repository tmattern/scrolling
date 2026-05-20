;------------------------------------------------------------------------------
; INITIALISATION ET VARIABLES EN PAGE DIRECTE
;------------------------------------------------------------------------------
        setdp   $61      ; Configuration page directe à $61xx
        org     $6100    ; Adresse de début des variables

STACK   rmb     2
TMP:    rmb     2        ; Variable temporaire pour calculs d'adresse (16 bits)
CLEAR_SCREEN_START rmb 2


current_page    RMB 1

cam_x           RMB 2
tile_x          RMB 2
shift_x         RMB 1
row_counter     RMB 1
col_counter     RMB 1
map_ptr         RMB 2
src_ptr         RMB 2
dst_ptr_a       RMB 2
dst_ptr_b       RMB 2
world_col       RMB 2
tmp0            RMB 1


