;==============================================================================
; bresenham.asm - Algorithme de tracé de ligne optimisé (Bresenham) pour 6809
;
; Copyright (C) 2025 Thibaut Mattern
;
; Ce programme est un logiciel libre : vous pouvez le redistribuer et/ou
; le modifier selon les termes de la Licence Publique Générale GNU publiée par
; la Free Software Foundation, soit la version 3 de la licence, soit (à votre
; choix) toute version ultérieure.
;
; Ce programme est distribué dans l’espoir qu’il sera utile, mais SANS AUCUNE
; GARANTIE ; sans même la garantie implicite de QUALITÉ MARCHANDE ou
; d’ADÉQUATION À UN BUT PARTICULIER. Voir la Licence Publique Générale GNU
; pour plus de détails.
;
; Vous devriez avoir reçu une copie de la Licence Publique Générale GNU
; avec ce programme ; si ce n’est pas le cas, voir <https://www.gnu.org/licenses/>.
;
; Auteur : Thibaut Mattern <tmattern@users.noreply.github.com>
;==============================================================================

;==============================================================================
; ALGORITHME DE BRESENHAM OPTIMISÉ POUR MOTOROLA 6809
;==============================================================================
; 
; Description :
;   Implémentation optimisée de l'algorithme de Bresenham pour le tracé de 
;   lignes droites sur écran graphique 320x200 pixels en mode 1 bit par pixel.
;   
; Spécifications techniques :
;   - Processeur     : Motorola 6809
;   - Résolution     : 320x200 pixels
;   - Profondeur     : 1 bit par pixel (monochrome)
;   - Mémoire vidéo  : $0000-$1F3F (8000 octets)
;   - Page directe   : $61xx
;   - Assembleur     : lwasm compatible
;
; Convention d'appel :
;   Entrées  : X0, Y0, X1, Y1 (coordonnées 16 bits en page directe)
;   Sorties  : Ligne tracée en mémoire vidéo
;   Registres utilisés : A, B, X, Y, U (sauvegardés/restaurés)
;   Variables temporaires : DX, DY, SX, SY, ERR, MASK, ADDR, TMP, PIX_CPT
;
; Optimisations :
;   - 8 routines spécialisées par octant pour éviter les tests dans la boucle
;   - Calculs en 8 bits quand possible pour accélérer les opérations
;   - Gestion optimisée des masques de bits pour l'affichage pixel
;   - Adressage VRAM pré-calculé pour minimiser les calculs en boucle
;
;==============================================================================

;------------------------------------------------------------------------------
; VALEURS DE TEST ET CONSTANTES
;------------------------------------------------------------------------------
X0VAL   equ $0000        ; Coordonnée X de début pour les tests
Y0VAL   equ $0000        ; Coordonnée Y de début pour les tests  
X1VAL   equ $013F        ; Coordonnée X de fin pour les tests (319)
Y1VAL   equ $00C7        ; Coordonnée Y de fin pour les tests (199)


; Routine Bresenham optimisée pour 6809, 320x200, 1bpp, VRAM $0000
; Entrées : X0, Y0, X1, Y1 (16 bits, page directe)
; Variables temporaires : DX, DY, SX, SY, ERR (16 bits), MASK (8 bits)
; Adresse VRAM de travail dans X
; Utilise : A, B, X, Y, U
VRAM_BASE   equ $0000    ; Adresse de base de la mémoire vidéo
LINE_BYTES  equ 40       ; Nombre d'octets par ligne (320 pixels ÷ 8 bits/octet)


; Entrée : X0, Y0, X1, Y1 (16 bits, direct page, big endian)
; Variables : DX, DY (16 bits), SX, SY (8 bits)
; Appelle la bonne routine de tracé par branchement relatif

; PHASE 1 : CALCUL DE DX, SX ET INITIALISATION D'ERR
;------------------------------------------------------------------------------
; Calcule la différence absolue en X, détermine le sens d'incrémentation SX
; et initialise la variable d'erreur ERR à DX/2

DrawLine:
    pshs    d,x,y,u      ; Sauvegarde des registres sur la pile

    ; Calcul de DX = |X1 - X0| et détermination de SX
    ldd     X1           ; D = X1
    subd    X0           ; D = X1 - X0 (différence signée)
    std     DX           ; Sauvegarde temporaire de la différence
    bpl     DX_Pos       ; Si positif, aller à DX_Pos
    ; Si négatif, calculer la valeur absolue par complément à 2
    coma                 ; Inverser tous les bits de A
    comb                 ; Inverser tous les bits de B  
    addd    #1           ; Ajouter 1 pour obtenir le complément à 2
    std     DX           ; DX = |X1 - X0|
    lsra                 ; ERR = DX / 2 (décalage à droite)
    rorb
    std     ERR          ; Initialiser l'erreur Bresenham
    lda     #$FF         ; SX = -1 (mouvement vers la gauche)
    sta     SX
    bra     DY_Calc      ; Continuer avec le calcul de DY
DX_Pos:
    lsra                 ; ERR = DX / 2 (décalage à droite)
    rorb  
    std     ERR          ; Initialiser l'erreur Bresenham
    lda     #1           ; SX = +1 (mouvement vers la droite)
    sta     SX

;------------------------------------------------------------------------------
; PHASE 2 : CALCUL DE DY ET SY  
;------------------------------------------------------------------------------
; Calcule la différence absolue en Y et détermine le sens d'incrémentation SY

DY_Calc:

    ; Calcul de DY = |Y1 - Y0| et détermination de SY
    ldd     Y1           ; D = Y1  
    subd    Y0           ; D = Y1 - Y0 (différence signée)
    std     DY           ; Sauvegarde temporaire de la différence
    bpl     DY_Pos       ; Si positif, aller à DY_Pos
    ; Si négatif, calculer la valeur absolue par complément à 2
    coma                 ; Inverser tous les bits de A
    comb                 ; Inverser tous les bits de B
    addd    #1           ; Ajouter 1 pour obtenir le complément à 2  
    std     DY           ; DY = |Y1 - Y0|
    lda     #$FF         ; SY = -1 (mouvement vers le haut)
    sta     SY
    bra     Dominant     ; Continuer avec le calcul d'adresse
DY_Pos:
    lda     #1           ; SY = +1 (mouvement vers le bas)
    sta     SY

;------------------------------------------------------------------------------
; PHASE 3 : CALCUL DE L'ADRESSE VRAM ET DU MASQUE PIXEL
;------------------------------------------------------------------------------
; Calcule l'adresse de l'octet VRAM contenant le pixel de départ
; et génère le masque de bit correspondant à la position du pixel

Dominant:
; Étape 3.1 : Calcul de l'adresse de début de ligne
    ldb     Y0+1             ; B = coordonnée Y (octet bas, 0..199)
    lda     #40              ; A = nombre d'octets par ligne
    mul                      ; D = Y * 40 (adresse relative de la ligne)
    addd    #VRAM_BASE       ; D = adresse absolue de début de ligne
    std     TMP              ; TMP = adresse de base de la ligne

; Étape 3.2 : Calcul de l'adresse de l'octet contenant le pixel  
    ldd     X0               ; D = coordonnée X (0..319)
    lsra                     ; Décalage à droite de 3 positions pour diviser par 8
    rorb                     ; (rotation du bit de poids fort de A vers B)
    lsrb                     ; Décalage à droite bit 2
    lsrb                     ; Décalage à droite bit 3 => D = X ÷ 8 (0..39)
    addd    TMP              ; D = adresse exacte de l'octet pixel
    std     ADDR             ; ADDR = adresse VRAM de l'octet pixel

; Étape 3.3 : Construction du masque de bit pour le pixel
    ldb     X0+1             ; B = coordonnée X (octet bas)
    andb    #7               ; B = X MOD 8 (position du bit dans l'octet : 0..7)

    ldx     #MASK_TABLE      ; X pointe sur la table des masques
    lda     b,x              ; A = masque correspondant à la position
    sta     MASK             ; MASK = masque de bit prêt pour l'affichage

;------------------------------------------------------------------------------
; PHASE 4 : INITIALISATION DES REGISTRES DE TRACÉ
;------------------------------------------------------------------------------
; Initialise les registres X, Y, U pour le tracé de la ligne

    ldx     X0               ; X = coordonnée X courante
    ldy     Y0               ; Y = coordonnée Y courante  
    ldu     ADDR             ; U = adresse VRAM courante

;------------------------------------------------------------------------------
; PHASE 5 : SÉLECTION DE LA ROUTINE SELON L'OCTANT
;------------------------------------------------------------------------------
; Compare DX et DY pour déterminer l'axe dominant et sélectionner 
; la routine optimisée correspondant à l'octant

    ldd     DX               ; D = DX
    cmpd    DY               ; Comparer DX avec DY
    bhs     X_Dom            ; Si DX >= DY, X est dominant

;==============================================================================
; ROUTINES DE TRACÉ - Y DOMINANT
;==============================================================================
; Ces routines gèrent les cas où DY > DX (ligne plus verticale qu'horizontale)

Y_Dom:
    ldb     SX               ; B = sens d'incrémentation X
    bmi     Yd_Xm            ; Si SX < 0, aller vers les routines X-
    ldb     SY               ; B = sens d'incrémentation Y  
    lbmi    DrawLine_YmXp_8  ; Si SY < 0, octant Y dominant, Y-, X+
    lbra    DrawLine_YpXp_8  ; Sinon, octant Y dominant, Y+, X+
Yd_Xm:
    ldb     SY               ; B = sens d'incrémentation Y
    lbmi    DrawLine_YmXm_8  ; Si SY < 0, octant Y dominant, Y-, X-
    lbra    DrawLine_YpXm_8  ; Sinon, octant Y dominant, Y+, X-

;==============================================================================
; ROUTINES DE TRACÉ - X DOMINANT  
;==============================================================================
; Ces routines gèrent les cas où DX >= DY (ligne plus horizontale que verticale)

X_Dom:
    ldb     SX               ; B = sens d'incrémentation X
    bmi     Xd_Xm            ; Si SX < 0, aller vers les routines X-
    ldb     SY               ; B = sens d'incrémentation Y
    bmi     DrawLine_XpYm_8  ; Si SY < 0, octant X dominant, X+, Y-
    bra     DrawLine_XpYp_8  ; Sinon, octant X dominant, X+, Y+
Xd_Xm:
    ldb     SY               ; B = sens d'incrémentation Y
    lbmi    DrawLine_XmYm_8  ; Si SY < 0, octant X dominant, X-, Y-
    lbra    DrawLine_XmYp_8  ; Sinon, octant X dominant, X-, Y+

;==============================================================================
; ROUTINE OCTANT X+ Y+ (X DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la droite et le bas
; avec X dominant (pente entre 0 et 45 degrés)

DrawLine_XpYp_8:
    lda     DX+1             ; A = DX (octet bas, nombre de pixels à tracer)
    inca                     ; A = DX + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    lda     ,u               ; A = contenu de l'octet VRAM courant
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
XpYp_Loop_8:
    ora     MASK             ; Allumer le pixel dans l'octet VRAM

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     XpYp_EndLine_8   ; Si terminé, aller à la fin

    subb    DY+1             ; ERR -= DY (mise à jour erreur Bresenham)
    bpl     XpYp_NoIncY_X_8  ; Si ERR >= 0, pas d'incrémentation Y
    addb    DX+1             ; ERR += DX (correction erreur)
    sta     ,u               ; Sauvegarder l'octet modifié en VRAM
    leau    LINE_BYTES,u     ; U += 40 (ligne suivante)
    lda     ,u               ; Charger le nouvel octet VRAM
XpYp_NoIncY_X_8:
    lsr     MASK             ; Décaler le masque vers la droite (pixel suivant)
    beq     XpYp_NextByte_X_8 ; Si masque = 0, passer à l'octet suivant
    bra     XpYp_Loop_8      ; Continuer la boucle
XpYp_NextByte_X_8:
    ror     MASK             ; Restaurer le masque au bit 7 ($80)
    sta     ,u               ; Sauvegarder l'octet courant
    leau    1,u              ; U += 1 (octet suivant sur la même ligne)
    lda     ,u               ; Charger le nouvel octet VRAM
    bra     XpYp_Loop_8      ; Continuer la boucle
XpYp_EndLine_8:
    sta     ,u               ; Sauvegarder le dernier octet modifié
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner

;==============================================================================
; ROUTINE OCTANT X+ Y- (X DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la droite et le haut
; avec X dominant (pente entre 0 et -45 degrés)

DrawLine_XpYm_8:
    lda     DX+1             ; A = DX (octet bas, nombre de pixels à tracer)
    inca                     ; A = DX + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    lda     ,u               ; A = contenu de l'octet VRAM courant
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
XpYm_Loop_8:
    ora     MASK             ; Allumer le pixel dans l'octet VRAM

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     XpYm_EndLine_8   ; Si terminé, aller à la fin

    subb    DY+1             ; ERR -= DY (mise à jour erreur Bresenham)
    bpl     XpYm_NoDecY_X_8  ; Si ERR >= 0, pas de décrémentation Y
    addb    DX+1             ; ERR += DX (correction erreur)
    sta     ,u               ; Sauvegarder l'octet modifié en VRAM
    leau    -LINE_BYTES,u    ; U -= 40 (ligne précédente, vers le haut)
    lda     ,u               ; Charger le nouvel octet VRAM
XpYm_NoDecY_X_8:
    lsr     MASK             ; Décaler le masque vers la droite (pixel suivant)
    bne     XpYm_Loop_8      ; Si masque != 0, continuer la boucle

    ror     MASK             ; Restaurer le masque au bit 7 ($80)
    sta     ,u               ; Sauvegarder l'octet courant
    leau    1,u              ; U += 1 (octet suivant sur la même ligne)
    lda     ,u               ; Charger le nouvel octet VRAM
    bra     XpYm_Loop_8      ; Continuer la boucle
XpYm_EndLine_8:
    sta     ,u               ; Sauvegarder le dernier octet modifié
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner

;==============================================================================
; ROUTINE OCTANT X- Y+ (X DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la gauche et le bas
; avec X dominant (pente entre 180 et 135 degrés)

DrawLine_XmYp_8:
    lda     DX+1             ; A = DX (octet bas, nombre de pixels à tracer)
    inca                     ; A = DX + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    lda     ,u               ; A = contenu de l'octet VRAM courant
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
XmYp_Loop_8:
    ora     MASK             ; Allumer le pixel dans l'octet VRAM

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     XmYp_EndLine_8   ; Si terminé, aller à la fin

    subb    DY+1             ; ERR -= DY (mise à jour erreur Bresenham)
    bpl     XmYp_NoIncY_X_8  ; Si ERR >= 0, pas d'incrémentation Y
    addb    DX+1             ; ERR += DX (correction erreur)
    sta     ,u               ; Sauvegarder l'octet modifié en VRAM
    leau    LINE_BYTES,u     ; U += 40 (ligne suivante, vers le bas)
    lda     ,u               ; Charger le nouvel octet VRAM
XmYp_NoIncY_X_8:
    lsl     MASK             ; Décaler le masque vers la gauche (pixel précédent)
    bne     XmYp_Loop_8      ; Si masque != 0, continuer la boucle

    rol     MASK             ; Restaurer le masque au bit 0 ($01)
    sta     ,u               ; Sauvegarder l'octet courant
    leau    -1,u             ; U -= 1 (octet précédent sur la même ligne)
    lda     ,u               ; Charger le nouvel octet VRAM
    bra     XmYp_Loop_8      ; Continuer la boucle
XmYp_EndLine_8:
    sta     ,u               ; Sauvegarder le dernier octet modifié
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner


;==============================================================================
; ROUTINE OCTANT X- Y- (X DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la gauche et le haut
; avec X dominant (pente entre 180 et 225 degrés)

DrawLine_XmYm_8:
    lda     DX+1             ; A = DX (octet bas, nombre de pixels à tracer)
    inca                     ; A = DX + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    lda     ,u               ; A = contenu de l'octet VRAM courant
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
XmYm_Loop_8:
    ora     MASK             ; Allumer le pixel dans l'octet VRAM

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     XmYm_EndLine_8   ; Si terminé, aller à la fin

    subb    DY+1             ; ERR -= DY (mise à jour erreur Bresenham)
    bpl     XmYm_NoDecY_X_8  ; Si ERR >= 0, pas de décrémentation Y
    addb    DX+1             ; ERR += DX (correction erreur)
    sta     ,u               ; Sauvegarder l'octet modifié en VRAM
    leau    -LINE_BYTES,u    ; U -= 40 (ligne précédente, vers le haut)
    lda     ,u               ; Charger le nouvel octet VRAM
XmYm_NoDecY_X_8:
    lsl     MASK             ; Décaler le masque vers la gauche (pixel précédent)
    bne     XmYm_Loop_8      ; Si masque != 0, continuer la boucle

    rol     MASK             ; Restaurer le masque au bit 0 ($01)
    sta     ,u               ; Sauvegarder l'octet courant
    leau    -1,u             ; U -= 1 (octet précédent sur la même ligne)
    lda     ,u               ; Charger le nouvel octet VRAM
    bra     XmYm_Loop_8      ; Continuer la boucle
XmYm_EndLine_8:
    sta     ,u               ; Sauvegarder le dernier octet modifié
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner

;==============================================================================
; ROUTINE OCTANT Y+ X+ (Y DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la droite et le bas
; avec Y dominant (pente entre 45 et 90 degrés)

DrawLine_YpXp_8:
    lda     DY+1             ; A = DY (octet bas, nombre de pixels à tracer)
    inca                     ; A = DY + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
    lda     MASK             ; A = masque de pixel courant
YpXp_Loop_8:
    ora     ,u               ; Allumer le pixel dans l'octet VRAM
    sta     ,u               ; Sauvegarder l'octet modifié

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     YpXp_EndLine_8   ; Si terminé, aller à la fin

    lda     MASK             ; A = masque de pixel courant
    leau    LINE_BYTES,u     ; U += 40 (ligne suivante, vers le bas)
    subb    DX+1             ; ERR -= DX (mise à jour erreur Bresenham)
    bpl     YpXp_Loop_8      ; Si ERR >= 0, pas d'incrémentation X

    addb    DY+1             ; ERR += DY (correction erreur)
    lsra                     ; Décaler le masque vers la droite (pixel suivant)
    sta     MASK             ; Sauvegarder le nouveau masque
    bne     YpXp_Loop_8      ; Si masque != 0, continuer la boucle
    lda     #$80             ; Restaurer le masque au bit 7 ($80)
    sta     MASK
    leau    1,u              ; U += 1 (octet suivant sur la même ligne)
    bra     YpXp_Loop_8      ; Continuer la boucle
YpXp_EndLine_8:
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner

;==============================================================================
; ROUTINE OCTANT Y+ X- (Y DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la gauche et le bas
; avec Y dominant (pente entre 90 et 135 degrés)

DrawLine_YpXm_8:
    lda     DY+1             ; A = DY (octet bas, nombre de pixels à tracer)
    inca                     ; A = DY + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
    lda     MASK             ; A = masque de pixel courant
YpXm_Loop_8:
    ora     ,u               ; Allumer le pixel dans l'octet VRAM
    sta     ,u               ; Sauvegarder l'octet modifié

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     YpXm_EndLine_8   ; Si terminé, aller à la fin

    lda     MASK             ; A = masque de pixel courant
    leau    LINE_BYTES,u     ; U += 40 (ligne suivante, vers le bas)
    subb    DX+1             ; ERR -= DX (mise à jour erreur Bresenham)
    bpl     YpXm_Loop_8      ; Si ERR >= 0, pas d'incrémentation X

    addb    DY+1             ; ERR += DY (correction erreur)
    lsla                     ; Décaler le masque vers la gauche (pixel précédent)
    sta     MASK             ; Sauvegarder le nouveau masque
    bne     YpXm_Loop_8      ; Si masque != 0, continuer la boucle
    lda     #$01             ; Restaurer le masque au bit 0 ($01)
    sta     MASK
    leau    -1,u             ; U -= 1 (octet précédent sur la même ligne)
    bra     YpXm_Loop_8      ; Continuer la boucle
YpXm_EndLine_8:
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner

;==============================================================================
; ROUTINE OCTANT Y- X+ (Y DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la droite et le haut
; avec Y dominant (pente entre 315 et 360 degrés)

DrawLine_YmXp_8:
    lda     DY+1             ; A = DY (octet bas, nombre de pixels à tracer)
    inca                     ; A = DY + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
    lda     MASK             ; A = masque de pixel courant
YmXp_Loop_8:
    ora     ,u               ; Allumer le pixel dans l'octet VRAM
    sta     ,u               ; Sauvegarder l'octet modifié

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     YmXp_EndLine_8   ; Si terminé, aller à la fin

    lda     MASK             ; A = masque de pixel courant
    leau    -LINE_BYTES,u    ; U -= 40 (ligne précédente, vers le haut)
    subb    DX+1             ; ERR -= DX (mise à jour erreur Bresenham)
    bpl     YmXp_Loop_8      ; Si ERR >= 0, pas d'incrémentation X

    addb    DY+1             ; ERR += DY (correction erreur)
    lsra                     ; Décaler le masque vers la droite (pixel suivant)
    sta     MASK             ; Sauvegarder le nouveau masque
    bne     YmXp_Loop_8      ; Si masque != 0, continuer la boucle
    lda     #$80             ; Restaurer le masque au bit 7 ($80)
    sta     MASK
    leau    1,u              ; U += 1 (octet suivant sur la même ligne)
    bra     YmXp_Loop_8      ; Continuer la boucle
YmXp_EndLine_8:
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner

;==============================================================================
; ROUTINE OCTANT Y- X- (Y DOMINANT)
;==============================================================================
; Tracé optimisé pour les lignes se dirigeant vers la gauche et le haut
; avec Y dominant (pente entre 225 et 270 degrés)

DrawLine_YmXm_8:
    lda     DY+1             ; A = DY (octet bas, nombre de pixels à tracer)
    inca                     ; A = DY + 1 (inclut le pixel de fin)
    sta     PIX_CPT          ; PIX_CPT = compteur de pixels
    ldb     ERR+1            ; B = variable d'erreur (octet bas)
    lda     MASK             ; A = masque de pixel courant
YmXm_Loop_8:
    ora     ,u               ; Allumer le pixel dans l'octet VRAM
    sta     ,u               ; Sauvegarder l'octet modifié

    dec     PIX_CPT          ; Décrémenter le compteur de pixels
    beq     YmXm_EndLine_8   ; Si terminé, aller à la fin

    lda     MASK             ; A = masque de pixel courant
    leau    -LINE_BYTES,u    ; U -= 40 (ligne précédente, vers le haut)
    subb    DX+1             ; ERR -= DX (mise à jour erreur Bresenham)
    bpl     YmXm_Loop_8      ; Si ERR >= 0, pas d'incrémentation X

    addb    DY+1             ; ERR += DY (correction erreur)
    lsla                     ; Décaler le masque vers la gauche (pixel précédent)
    sta     MASK             ; Sauvegarder le nouveau masque
    bne     YmXm_Loop_8      ; Si masque != 0, continuer la boucle
    lda     #$01             ; Restaurer le masque au bit 0 ($01)
    sta     MASK
    leau    -1,u             ; U -= 1 (octet précédent sur la même ligne)
    bra     YmXm_Loop_8      ; Continuer la boucle
YmXm_EndLine_8:
    puls    d,x,y,u,pc       ; Restaurer les registres et retourner


;==============================================================================
; DONNÉES ET TABLES
;==============================================================================

;------------------------------------------------------------------------------
; TABLE DES MASQUES DE PIXELS
;------------------------------------------------------------------------------
; Table de conversion position → masque de bit pour l'affichage des pixels
; Index 0..7 correspond à la position du pixel dans l'octet (de gauche à droite)
; Valeurs : 128,64,32,16,8,4,2,1 (bits 7,6,5,4,3,2,1,0)

MASK_TABLE:
        FCB 128,64,32,16,8,4,2,1    ; Masques de bits pour positions 0 à 7

;==============================================================================
; FIN DU FICHIER BRESENHAM.ASM
;==============================================================================
