; ============================================================================
; Thomson TO8 - Cartographie Hardware & Registres spéciaux (E7E4-E7FF inclus)
; Basé sur le manuel technique TO8, docs DCMOTO/MAME, 2024
; Exploitable 6809 assembly (big-endian). Registres détaillés, bits commentés.
; ============================================================================

; TO7/70 PALETTE (hardware order)
COLOR_BLACK         equ $0   ; Black
COLOR_RED           equ $1   ; Red
COLOR_GREEN         equ $2   ; Green
COLOR_YELLOW        equ $3   ; Yellow
COLOR_BLUE          equ $4   ; Blue
COLOR_MAGENTA       equ $5   ; Magenta
COLOR_CYAN          equ $6   ; Cyan
COLOR_WHITE         equ $7   ; White
COLOR_GREY          equ $8   ; Grey
COLOR_ORANGE        equ $9   ; Orange
COLOR_LIGHT_GREEN   equ $A   ; Light Green
COLOR_LIGHT_YELLOW  equ $B   ; Light Yellow
COLOR_LIGHT_BLUE    equ $C   ; Light Blue
COLOR_LIGHT_MAGENTA equ $D   ; Light Magenta
COLOR_LIGHT_CYAN    equ $E   ; Light Cyan
COLOR_BRIGHT_WHITE  equ $F   ; Bright White

; ---------------------------------------------------------------------------
; 6522 VIA #1 (VIDEO) - $E7C0-$E7CF
; ---------------------------------------------------------------------------
VIA1_PORTA      equ $E7C0 ; [RW] Port A - Contrôle mode graphique/page affichée
;   Bit 0-1 : Mode graphique
;      00 = 320x200 16 couleurs
;      01 = 320x200 4 couleurs
;      10 = 160x200 16 couleurs
;      11 = 160x200 4 couleurs
;   Bit 2 : Page vidéo affichée (0: $C000, 1: $8000)
;   Bit 3-7 : Réservés (toujours 0)
VIA1_PORTB      equ $E7C1 ; [RW] Couleur bordure (bits 0-3)
VIA1_DDRA       equ $E7C2 ; [RW] Direction Port A
VIA1_DDRB       equ $E7C3 ; [RW] Direction Port B
VIA1_T1CL       equ $E7C4 ; [RW] Timer 1 Counter Low
VIA1_T1CH       equ $E7C5 ; [RW] Timer 1 Counter High
VIA1_T1LL       equ $E7C6 ; [W]  Timer 1 Latch Low
VIA1_T1LH       equ $E7C7 ; [W]  Timer 1 Latch High
VIA1_T2CL       equ $E7C8 ; [RW] Timer 2 Counter Low
VIA1_T2CH       equ $E7C9 ; [RW] Timer 2 Counter High
VIA1_SR         equ $E7CA ; [RW] Shift Register
VIA1_ACR        equ $E7CB ; [RW] Aux Control (timers, shift)
VIA1_PCR        equ $E7CC ; [RW] Peripheral Control Register
VIA1_IFR        equ $E7CD ; [R]  Interrupt Flag Register
VIA1_IER        equ $E7CE ; [RW] Interrupt Enable Register
VIA1_PORTA_NH   equ $E7CF ; [RW] Port A no handshake (non bufferisé)

; ---------------------------------------------------------------------------
; 6522 VIA #2 (IMPRIMANTE/EXT/LEP) - $E7D0-$E7DF
; ---------------------------------------------------------------------------
VIA2_PORTA      equ $E7D0
VIA2_PORTB      equ $E7D1
VIA2_DDRA       equ $E7D2
VIA2_DDRB       equ $E7D3
VIA2_T1CL       equ $E7D4
VIA2_T1CH       equ $E7D5
VIA2_T1LL       equ $E7D6
VIA2_T1LH       equ $E7D7
VIA2_T2CL       equ $E7D8
VIA2_T2CH       equ $E7D9
VIA2_SR         equ $E7DA
VIA2_ACR        equ $E7DB
VIA2_PCR        equ $E7DC
VIA2_IFR        equ $E7DD
VIA2_IER        equ $E7DE
VIA2_PORTA_NH   equ $E7DF

; ---------------------------------------------------------------------------
; 8255 PPI (CLAVIER/SOURIS/JOYSTICK) - $E7E0-$E7E3
; ---------------------------------------------------------------------------
PPI_PORTA       equ $E7E0 ; [R]  Clavier/Joystick A (lecture)
PPI_PORTB       equ $E7E1 ; [W]  Lignes clavier/Joystick (écriture)
PPI_PORTC       equ $E7E2 ; [R]  Souris (X, Y, boutons)
PPI_CTRL        equ $E7E3 ; [W]  Contrôle PPI

GA_SYS2         equ $E7DD ; [R/W] Système 2: 
;   D7-D6 : Numéro page physique affichée à l'écran (0-3)
;   D5    : Masquage cartouche (MO, non utilisé TO8)
;   D4    : Sélection BASIC (MO, non utilisé TO8)
;   D3-D0 : Couleur du tour (P B V R, cf. palette)

; ---------------------------------------------------------------------------
; ZONE MULTIPLEXÉE $E7E4-$E7E7 : GATE ARRAY, CRAYON OPTIQUE, etc.
; Voir Manuel technique (pages 110-117, 129)
; ---------------------------------------------------------------------------
; Les adresses E7E4 à E7E7 sont MULTIPLEXÉES :
;  - Lecture/écriture de registres système ET crayon optique.
;  - Le registre de sélection lecture (bit D0 de E7EA) commute l'accès.
; ---------------------------------------------------------------------------
; Pour accès "régistres système" (D0 de E7EA = 0) :

GA_DATA_RAM     equ $E7E5 ; [R/W] RAM Données (bank switching) :
;   D7    : Autorisation écriture registre affichage (E7DC) si contrôleur externe
;   D6-D5 : 0
;   D4-D0 : Numéro de page RAM (0-31)

GA_CART_RAM     equ $E7E6 ; [R/W] RAM Cartouche :
;   D6    : Protection écriture page RAM cartouche (1=autorisé)
;   D5    : 1=Espace cartouche recouvert par RAM (D4-D0)
;   D4-D0 : Numéro page RAM pour cartouche

GA_SYS1         equ $E7E7 ; [W] Système 1 :
;   D7    : Contrôleur disque (0=int, 1=ext)
;   D6    : Gestion RAM cartouche (1=par registre E7E6)
;   D5    : Standard vidéo (0=France/624l, 1=export/524l)
;   D4    : Gestion RAM données (1=par registre E7E5)
;   D3-D2 : Type machine (10=TO8)
;   D1-D0 : Type RAM dynamique (00=256Kx1)

; Pour accès "crayon optique" (D0 de E7EA = 1) :
LIGHT_PEN_1     equ $E7E4 ; Crayon optique 1 (T12-T5)
LIGHT_PEN_2     equ $E7E5 ; Crayon optique 2 (T4-T0, E, H2, H4)
LIGHT_PEN_3     equ $E7E6 ; Crayon optique 3 (flags position)
LIGHT_PEN_4     equ $E7E7 ; Crayon optique 4 (INITN, drapeau FIRQN, etc.)


; ---------------------------------------------------------------------------
; CONTRÔLEUR DISQUETTE (FDC WD179X/THMFC1) - $E7E8-$E7EC
; ---------------------------------------------------------------------------
FDC_COMMAND     equ $E7E8 ; [R/W] Commande FDC
FDC_TRACK       equ $E7E9 ; [R/W] Numéro de piste
FDC_SECTOR      equ $E7EA ; [R/W] Numéro de secteur
;     Bit 0 de FDC_SECTOR ($E7EA) = multiplexeur lecture "traitement/crayon optique"
;     (D0=0: lecture registres système, D0=1: lecture crayon optique)
FDC_DATA        equ $E7EB ; [R/W] Donnée
FDC_STATUS      equ $E7EC ; [R]   Statut

; ---------------------------------------------------------------------------
; CARTOUCHE/EXTENSION $E7F0
; ---------------------------------------------------------------------------
CART_IO         equ $E7F0 ; [R/W] Registre extension/cartouche

; ---------------------------------------------------------------------------
; AUTRES EXTENSIONS $E7F1-$E7FE
; ---------------------------------------------------------------------------
; Zone extensions (rarement utilisée)

; ---------------------------------------------------------------------------
; RESET GENERAL I/O $E7FF
; ---------------------------------------------------------------------------
RESET_IO        equ $E7FF ; [W] Reset général I/O (tous périphériques !)

; ---------------------------------------------------------------------------
; REGISTRES VIDEO/PALETTE (EF9369)
; ---------------------------------------------------------------------------
PALETTE_DATA    equ $E7C2 ; [W] Donnée palette (16x12 bits, accès indirect)
PALETTE_ADDR    equ $E7C3 ; [RW] Adresse palette sélectionnée (0-15)

DISPLAY_CTRL    equ $E7DC ; [W] Contrôle affichage (mode, organisation, fréquence pixel)
;   D7-D0 : cf. manuel technique p.124 pour les 9 modes (bitmap 4c, 16c, 80col, etc.)


; ============================================================================
; FIN CARTOGRAPHIE HARDWARE TO8
; ============================================================================