;==============================================================================
; Effacement complet de l'écran graphique 320x200, 1bpp, VRAM $0000-$1F3F
; Utilise : X, A uniquement
;==============================================================================

; Entrée : A = aaaabbbb
; Sortie : B = baaaabbb

TranscodeRamb:
    pshs  b
    eora  #%10001000   ; echange Pastel / Saturation
    sta   TMP
    clrb

    lsra
    rorb

    lsra
    rorb

    lsra
    rorb

    lsra

    lsra
    rorb

    lsra
    rorb

    lsra
    rorb

    lsra
    rorb
    lsrb

    lda   TMP
    bita  #%00001000
    beq   TranscodeRambEnd
    orb   #$80

TranscodeRambEnd:
    tfr   b,a
    puls  b,pc


ClearScreenRAMA:
    pshs  a,b,x,y,u,cc
    ldu   #$0000
    stu   CLEAR_SCREEN_START
    orcc  #$50
    sts   STACK
    ldd   #0
    ldx   #0
    ldy   #0
    ldu   #0
    lds   #$1F40
    bra   CS_Loop

; pattern dans le registre A
ClearScreenRAMB:
    pshs  a,b,x,y,u,cc
    ldu   #$2000
    stu   CLEAR_SCREEN_START
    orcc  #$50
    sts   STACK
    tfr   a,b
    tfr   d,x
    tfr   d,y
    tfr   d,u
    lds   #$3F40
    bra   CS_Loop

    
CS_Loop:
    ; ligne 1
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u

    ; ligne 2
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u

    ; ligne 3
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u

    ; ligne 4
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u

    ; ligne 5
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u
    pshs  a,b,x,y,u

    cmps  CLEAR_SCREEN_START
    bne   CS_Loop
    lds   STACK
    puls  a,b,x,y,u,cc,pc


;==============================================================================
; Effacement d'une zone centrée de 192x120 pixels (24 octets x 120 lignes)
; Centre horizontal = 8 octets (64px) depuis la gauche, vertical = 40 lignes
; Utilise : X, Y, B, A, TMP (RAM)
; Marge haut    $0000   $09E7
; Zone centrée  $0A08   $1EDF
; Marge bas     $1F00   $1FA7
;==============================================================================

ClearZone_Centered:
    pshs  a,b,x,y,u,cc,dp
    clrd
    ldx   #0
    ldy   #0
    tfr   a,dp
    andcc #0
    ldu   #$1EE0
    
CS_Loop_Centered:
    ; ligne 1
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 2
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 3
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 4
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 5
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    cmpu  #$0A08
    leau  -16,u
    bne   CS_Loop_Centered
    puls  a,b,x,y,u,cc,dp,pc
