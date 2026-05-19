; ============================================================================
; Thomson TO8 - Points d’entrée ROM/moniteur TO8 (adresses fixes ROM)
; Version étendue : adresses, usage détaillé, effets, conventions d’appel
; Strictement conforme : manuel technique, DCMOTO, désassemblage ROM TO8
; Aucune entrée $Axxx (uniquement ROM $Exxx/$Fxxx)
; ============================================================================

; --- Vecteurs d'interruptions ROM ($FFF2-$FFFF) ---
VEC_SWI3        equ $FFF2
VEC_SWI2        equ $FFF4
VEC_FIRQ        equ $FFF6
VEC_IRQ         equ $FFF8
VEC_SWI         equ $FFFA
VEC_NMI         equ $FFFC
VEC_RESET       equ $FFFE

; ============================================================================
; ENTRÉES CONSOLE, TEXTE, CURSEUR
; ============================================================================

; Efface écran courant (texte ou mode graphique)
; Effets : efface, repositionne curseur en haut à gauche, mode inchangé
; Registres modifiés : toutes, pile utilisée
MON_CLS         equ $E403

; Scroll une ligne l’écran texte
; Registres modifiés : toutes, pile utilisée
MON_SCROLL      equ $E429

; Affiche caractère ASCII à la position courante
; Entrée :  A = code ASCII
; Sortie :  curseur avancé, scroll si nécessaire
; Registres modifiés : toutes, pile utilisée
MON_PUTCHAR     equ $E52C

; Affiche chaîne $00-terminée à la position courante
; Entrée :  X = adresse chaîne ($00 final)
; Sortie :  curseur avancé
; Registres modifiés : toutes, pile utilisée
MON_PUTSTR      equ $E5A1

; Attend et lit une touche au clavier
; Sortie :  A = code ASCII (ou 0 si aucune)
; Registres modifiés : toutes, pile utilisée
MON_GETKEY      equ $E40F

; Positionne curseur
; Entrée :  A = colonne (0-39), B = ligne (0-24)
; Registres modifiés : toutes, pile utilisée
MON_LOCATE      equ $E41C

; Allume curseur clignotant
; Registres modifiés : A, flags
MON_CURON       equ $E415

; Éteint curseur
; Registres modifiés : A, flags
MON_CUROFF      equ $E418

; Bip sonore court
; Registres modifiés : A, flags, pile
MON_BELL        equ $E41B

; Change mode graphique
; Entrée :  A = mode (voir doc : 0=texte, 1=320x200 16c…)
; Registres modifiés : toutes, pile utilisée
MON_SETMODE     equ $E419

; Change couleur du bord
; Entrée :  A = couleur (0-15)
; Registres modifiés : A, flags, VIA
MON_SETBORDER   equ $E41F

; Saisie ligne clavier, $00 terminé
; Entrée :  X = adresse tampon, Y = taille max (optionnel)
; Sortie :  tampon rempli, $00 final
; Registres modifiés : toutes, pile utilisée
MON_LINEINPUT   equ $E54D

; Affiche A en décimal (0-255)
; Entrée :  A = valeur
; Registres modifiés : toutes, pile utilisée
MON_PRINTNUM    equ $E5B3

; Affiche A en hexadécimal (00-FF)
; Entrée :  A = valeur
; Registres modifiés : toutes, pile utilisée
MON_PRINTHEX    equ $E5B6

; ============================================================================
; GESTION VIDÉO (pages, palette, modes)
; ============================================================================

; Sélectionne page vidéo affichée (écran)
; Entrée :  A = 0 : page 0 ($C000), 1 : page 1 ($8000)
; Registres modifiés : A, flags, VIA
MON_SET_VPAGE   equ $E540

; Sélectionne page VRAM active pour accès CPU
; Entrée :  A = 0 ou 1
; Registres modifiés : A, flags, VIA
MON_SET_VRAM    equ $E543

; Modifie palette vidéo (EF9369)
; Entrée :  A = index (0-15), B = valeur 12 bits (RRGGBBPPPPPP)
; Registres modifiés : A, B, X, flags
MON_SET_PALETTE equ $E547

; Retourne mode vidéo courant
; Sortie :  A = mode courant (cf. doc)
; Registres modifiés : A, flags
MON_GET_VMODE   equ $E57E

; ============================================================================
; CLAVIER, JOYSTICK, SOURIS
; ============================================================================

; Scanne clavier, retourne code touche (brut)
; Sortie :  A = code touche ou 0
MON_KEYBOARD_SCAN  equ $E434

; Retourne état touche
; Entrée :  A = code à tester
; Sortie :  B = état (0: relâchée, 1: appuyée)
MON_KEYBOARD_STATE equ $E437

; Lit joystick
; Entrée :  A = n° port (0 ou 1)
; Sortie :  B = état boutons/directions
MON_JOYSTICK_READ  equ $E4A3

; Lit souris
; Entrée :  X = adresse buffer struct souris
; Modifie : buffer struct (déplacement, boutons)
MON_MOUSE_READ     equ $E4B2

; ============================================================================
; GESTION GRAPHIQUE (pixel, ligne, zone…)
; ============================================================================

; Place un pixel (mode graphique)
; Entrée :  X = adresse VRAM (calculée), A = couleur
; Registres modifiés : toutes, flags, VRAM
MON_PLOTPIXEL      equ $E601

; Lit couleur d’un pixel
; Entrée :  X = adresse VRAM (calculée)
; Sortie :  A = couleur
MON_GETPIXEL       equ $E604

; Trace segment graphique (ligne)
; Entrée :  X0, Y0, X1, Y1 sur pile (voir doc)
; Registres modifiés : toutes, pile utilisée, VRAM
MON_GRAFLINE       equ $E7F4

; Remplissage zone (flood fill)
; Entrée :  X, Y, couleur sur pile (voir doc)
; Registres modifiés : toutes, pile utilisée, VRAM
MON_GRAFFILL       equ $E7F1

; Trace cercle
; Entrée :  X0, Y0, rayon sur pile (voir doc)
MON_GRAFCIRCLE     equ $E7F7

; Trace rectangle
; Entrée :  X0, Y0, X1, Y1 sur pile (voir doc)
MON_GRAFRECT       equ $E7FA

; Place caractère graphique
; Entrée :  X, Y, A=caractère sur pile (voir doc)
MON_GRAFCHAR       equ $E7FD

; ============================================================================
; MÉMOIRE, COPIE, REMPLISSAGE
; ============================================================================

; Copie mémoire
; Entrée :  X = src, Y = dst, B = longueur
; Registres modifiés : toutes, flags, pile
MON_COPYMEM        equ $E5C6

; Remplit mémoire
; Entrée :  X = dst, B = valeur, Y = longueur
MON_FILLMEM        equ $E5CB

; ============================================================================
; TEMPORISATION, SYNCHRO VBL
; ============================================================================

; Attente temporisée (nombre de VBL)
; Entrée :  A = durée (en VBL, 1/50s)
; Registres modifiés : A, flags
MON_VBL_WAIT       equ $E4F2

; ============================================================================
; DISQUETTE (FDC), CASSETTE
; ============================================================================

; Commande FDC (contrôleur disquette)
; Entrée :  A = code commande, X/Y/stack selon commande
; Registres modifiés : toutes, flags, pile
MON_FDC_CMD        equ $E6A0

; Lecture secteur disquette
; Entrée :  paramètres secteur sur pile (cf. doc)
; Sortie :  données lues
; Registres modifiés : toutes, flags, pile
MON_FDC_READSEC    equ $E6B0

; Écriture secteur disquette
MON_FDC_WRITESEC   equ $E6C0

; Lecture cassette
; Entrée :  X = adresse, Y = taille
; Sortie :  données lues
MON_TAPE_READ      equ $E6D0

; Écriture cassette
; Entrée :  X = adresse, Y = taille
MON_TAPE_WRITE     equ $E6E0

; ============================================================================
; IMPRIMANTE CENTRONICS
; ============================================================================

; Initialisation imprimante
MON_PRINT_INIT     equ $E700

; Envoi caractère à l’imprimante
; Entrée :  A = caractère à envoyer
MON_PRINT_CHAR     equ $E703

; ============================================================================
; ENTRÉES BASIC, EXTRAMONITEUR
; ============================================================================

; Entrée BASIC 512
BASIC_ENTRY        equ $E000

; Entrée EXTRAMONITEUR (optionnel)
EXTRAMON_ENTRY     equ $E800

; ============================================================================
; TOUS LES POINTS D’ENTRÉE SONT EN ROM ($Exxx/$Fxxx), JAMAIS $Axxx.
; Les registres modifiés sont précisées pour chaque routine ; toujours vérifier
; conventions d’appel et pile avant utilisation en assembleur.
; ============================================================================