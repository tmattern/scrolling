;------------------------------------------------------------------------------
; INITIALISATION ET VARIABLES EN PAGE DIRECTE
;------------------------------------------------------------------------------
        setdp   $61      ; Configuration page directe à $61xx
        org     $6100    ; Adresse de début des variables


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
