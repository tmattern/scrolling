InitScreen:
    pshs   a
    clr    current_page

    LDA     #%00000000  ; mode TO7/70 sans l'horrible transcodage en ramb
    STA     DISPLAY_CTRL

    bra    WaitVBL_AffichePage0_MappePage3Cartouche


; === Routine d'attente VBL + switch buffer ===
WaitVBLAndSwitchBuffer:
    pshs  a

    ; Changer couleur du tour pour debug (rouge = 2)
    ;lda   $E7E4
    ;ora   #2              ; Mets rouge (2)
    ;sta   GA_SYS2

    ; -- Attendre que le bit 7 de VIDEO_STATUS passe à 1 (VBL active) --
WaitVBL_Loop:
    lda   LIGHT_PEN_4
    bpl   WaitVBL_Loop

    ; -- Attendre la fin de VBL (évite plusieurs déclenchements) --
WaitVBL_End:
    lda   LIGHT_PEN_4
    bmi   WaitVBL_End

    ; -- Inverser la page --
    lda   current_page
    eora  #1
    sta   current_page
    bne   WaitVBL_AffichePage3_MappePage0Cartouche

WaitVBL_AffichePage0_MappePage3Cartouche:
    lda   #%00000000
    sta   GA_SYS2

    lda   #%01100011
    sta   GA_CART_RAM
    puls  a,pc

WaitVBL_AffichePage3_MappePage0Cartouche:
    lda   #%11000000
    sta   GA_SYS2

    lda   #%01100000
    sta   GA_CART_RAM
    puls  a,pc
