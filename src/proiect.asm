TITLE Proiect ASM - Varianta Finala Explicata
.8086
.MODEL SMALL
.STACK 100h

DATA SEGMENT
    ; --- Zone de mesaje (Interfata utilizator) ---
    msg_intro   DB 13, 10, 'Introduceti 8-16 octeti hex (ex: 1A 2B 3C...): $'
    msg_eroare  DB 13, 10, 'Eroare! Numar incorect de octeti (minim 8, maxim 16).$'
    msg_c_hex   DB 13, 10, '1. Cuvantul C calculat (Hex): $'
    msg_c_bin   DB 13, 10, '   Cuvantul C calculat (Bin): $'
    msg_sortat  DB 13, 10, '2. Sirul sortat (inainte de rotiri): $'
    msg_pozitie DB 13, 10, '3. Pozitia octetului cu max biti 1 (in sir sortat): $'
    msg_final   DB 13, 10, '4. Sirul final (dupa rotiri conform N):', 13, 10, '$'
    pref_b      DB '   B: $'
    pref_h      DB ' H: $'

    ; --- Structuri de date ---
    buffer      DB 60, ?, 60 DUP(?) ; Buffer pentru functia 0Ah (DOS)
    sir         DB 16 DUP(0)        ; Stocam valorile convertite in binar
    nr_el       DB 0                ; Cate valori am extras din text
    c_word      DW 0                ; Cuvantul special C pe 16 biti
    pos_max     DB 0                ; Pozitia elementului cu multi de 1
    val_max     DB 0                ; Numarul maxim de biti de 1 gasiti
DATA ENDS

CODE SEGMENT
    ASSUME CS:CODE, DS:DATA

START:
    ; Initializam segmentul de date
    MOV AX, DATA
    MOV DS, AX

    ; --- PAS 1: CITIREA SI CONVERSIA ---
    MOV AH, 09h             ; Functia DOS de afisare string
    LEA DX, msg_intro
    INT 21h

    MOV AH, 0Ah             ; Citim de la tastatura pana la ENTER
    LEA DX, buffer
    INT 21h

    LEA SI, buffer + 2      ; SI pointeaza la caracterele citite
    LEA DI, sir             ; DI pointeaza la sirul numeric din memorie
    XOR CX, CX
    MOV CL, [buffer + 1]    ; Incarcam nr. de caractere tastate in CX pentru bucla
    MOV nr_el, 0

CONV_LOOP:
    CMP CX, 0               ; Mai avem caractere de procesat?
    JLE VERIFICA
    MOV AL, [SI]
    CMP AL, ' '             ; Daca e spatiu, il ignoram
    JE NEXT_C
    
    ; Transformam prima litera/cifra hex
    CALL CONV_CHAR          ; AL = valoarea binară a caracterului
    SHL AL, 4               ; Muta valoarea pe nibble-ul superior (ex: 3 -> 30h)
    MOV BL, AL
    
    INC SI                  ; Trecem la al doilea caracter al octetului
    DEC CX
    MOV AL, [SI]
    CALL CONV_CHAR          ; Transforma al doilea caracter
    OR AL, BL               ; Combina cele doua cifre (ex: 30h OR 0Fh = 3Fh)
    
    MOV [DI], AL            ; Salveaza octetul rezultat in sir
    INC DI
    INC nr_el               ; Incrementam contorul de numere citite

NEXT_C:
    INC SI
    DEC CX
    JMP CONV_LOOP

VERIFICA:
    ; Validare conform cerintei (8-16 valori)
    CMP nr_el, 8
    JB ERR
    CMP nr_el, 16
    JA ERR
    JMP CALC_C

ERR:
    MOV AH, 09h
    LEA DX, msg_eroare
    INT 21h
    JMP START               ; Reluam citirea in caz de eroare

    ; --- PAS 2: CALCULUL CUVANTULUI C (Pagina 5) ---
CALC_C:
    ; Bitii 0-3: XOR intre primii 4 biti din octetul 1 si ultimii 4 din ultimul octet
    MOV AL, [sir]           ; Primul octet
    SHR AL, 4               ; Izolam primii 4 biti
    XOR BX, BX
    MOV BL, nr_el
    DEC BX
    MOV AH, [sir + BX]      ; Ultimul octet
    AND AH, 0Fh             ; Izolam ultimii 4 biti
    XOR AL, AH              ; Operatia XOR ceruta
    AND AL, 0Fh             ; Pastram doar 4 biti
    MOV BYTE PTR [c_word], AL

    ; Bitii 4-7: OR intre bitii 2,3,4,5 ai tuturor octetilor
    XOR SI, SI
    XOR DX, DX
    MOV CL, nr_el
B_OR:
    MOV AL, [sir + SI]
    SHR AL, 2               ; Mutam bitii 2-5 pe pozitiile 0-3
    AND AL, 0Fh             ; Izolam acesti 4 biti
    OR DL, AL               ; Cumulam prin operatia OR
    INC SI
    LOOP B_OR
    SHL DL, 4               ; Punem rezultatul pe pozitiile 4-7
    OR BYTE PTR [c_word], DL

    ; Bitii 8-15: Suma tuturor octetilor (modulo 256)
    XOR SI, SI
    XOR AL, AL
    MOV CL, nr_el
B_SUM:
    ADD AL, [sir + SI]      ; Adunarea pe 8 biti face automat modulo 256
    INC SI
    LOOP B_SUM
    MOV BYTE PTR [c_word + 1], AL ; Salvam in octetul superior al lui C

    ; --- AFISARE REZULTAT C ---
    MOV AH, 09h
    LEA DX, msg_c_hex
    INT 21h
    MOV AX, c_word
    MOV AL, AH              ; Afisam octetul high
    CALL PRNT_HEX
    MOV AL, BYTE PTR [c_word] ; Afisam octetul low
    CALL PRNT_HEX

    MOV AH, 09h
    LEA DX, msg_c_bin
    INT 21h
    MOV AX, c_word
    MOV AL, AH
    CALL PRNT_BIN
    MOV AL, BYTE PTR [c_word]
    CALL PRNT_BIN

    ; --- PAS 3: SORTARE BUBBLE SORT (Descrescator) ---
SORT:
    XOR CX, CX
    MOV CL, nr_el
    DEC CL                  ; N-1 treceri
EXT_L:
    PUSH CX
    LEA SI, sir
INT_L:
    MOV AL, [SI]
    MOV BL, [SI+1]
    CMP AL, BL
    JAE NO_SWP              ; Daca AL >= BL, sunt deja sortate descrescator
    MOV [SI], BL            ; Inversam valorile (Swap)
    MOV [SI+1], AL
NO_SWP:
    INC SI
    LOOP INT_L              ; Bucla interna
    POP CX
    LOOP EXT_L              ; Bucla externa

    ; --- AFISARE SIR SORTAT (Pagina 10) ---
    MOV AH, 09h
    LEA DX, msg_sortat
    INT 21h
    XOR SI, SI
    XOR CX, CX
    MOV CL, nr_el
PRNT_S:
    PUSH CX                 ; Protejam CX pentru a evita loop infinit
    MOV AL, [sir + SI]
    CALL PRNT_HEX           ; Afisam in format Hex
    MOV DL, ' '             ; Afisam spatiu intre numere
    MOV AH, 02h
    INT 21h
    INC SI
    POP CX
    LOOP PRNT_S

    ; --- CAUTARE MAXIM BITI DE 1 ---
    XOR SI, SI
    XOR CX, CX
    MOV CL, nr_el
    MOV val_max, 0
F_MAX:
    PUSH CX
    MOV AL, [sir + SI]
    XOR BL, BL              ; BL va numara bitii de 1
    MOV CX, 8
C_B: SHL AL, 1              ; Impingem bitul in Carry
    ADC BL, 0               ; Adunam Carry la BL (0 sau 1)
    LOOP C_B
    
    CMP BL, 4               ; Cerinta: minim 4 biti de 1
    JB N_M
    CMP BL, val_max         ; Verificam daca e noul maxim
    JBE N_M
    MOV val_max, BL
    MOV AX, SI
    INC AX                  ; Pozitia umana incepe de la 1
    MOV pos_max, AL
N_M: POP CX
    INC SI
    LOOP F_MAX

    ; Afisare pozitie gasita
    MOV AH, 09h
    LEA DX, msg_pozitie
    INT 21h
    MOV AL, pos_max
    ADD AL, 30h             ; Convertim cifra in caracter ASCII
    MOV DL, AL
    MOV AH, 02h
    INT 21h

    ; --- PAS 4: ROTIRI SI TABEL FINAL (Pagina 6 & 10) ---
    MOV AH, 09h
    LEA DX, msg_final
    INT 21h
    XOR SI, SI
    XOR CX, CX
    MOV CL, nr_el
FIN_L:
    PUSH CX
    MOV AL, [sir + SI]
    ; Calcul N = suma primilor doi biti (bit 7 si bit 6)
    MOV BL, AL
    XOR DL, DL
    ROL BL, 1               ; Bit 7 -> Carry
    ADC DL, 0
    ROL BL, 1               ; Bit 6 -> Carry
    ADC DL, 0
    
    ; Rotire circulara la stanga cu N pozitii
    MOV CL, DL
    CMP CL, 0
    JE PR_LINE              ; Daca N=0, sarim rotirea
    ROL AL, CL

PR_LINE:
    MOV BL, AL              ; Salvam valoarea rotita pentru afisari multiple
    ; Afisare Binar cu prefix B:
    MOV AH, 09h
    LEA DX, pref_b
    INT 21h
    MOV AL, BL
    CALL PRNT_BIN
    
    ; Afisare Hex cu prefix H:
    MOV AH, 09h
    LEA DX, pref_h
    INT 21h
    MOV AL, BL
    CALL PRNT_HEX
    
    ; Rand nou (CR + LF)
    MOV DL, 13
    MOV AH, 02h
    INT 21h
    MOV DL, 10
    INT 21h
    
    INC SI
    POP CX
    LOOP FIN_L

    ; Inchidere program (Return to DOS)
    MOV AH, 4Ch
    INT 21h

; --- SUBRUTINE REUTILIZABILE ---

CONV_CHAR PROC
    ; Converteste un caracter ASCII ('0'-'F') in valoare numerica (0-15)
    CMP AL, '9'
    JBE IS_D
    CMP AL, 'F'
    JBE IS_U
    SUB AL, 20h             ; Convertim literele mici in mari daca e cazul
IS_U: SUB AL, 37h           ; Pentru litere ('A' -> 10)
    RET
IS_D: SUB AL, 30h           ; Pentru cifre ('0' -> 0)
    RET
CONV_CHAR ENDP

PRNT_BIN PROC
    ; Afiseaza valoarea din AL in format binar (8 biti)
    PUSH CX
    MOV CX, 8
B_LP: ROL AL, 1             ; Rotim pentru a extrage bitul cel mai semnificativ
    MOV DL, '0'
    ADC DL, 0               ; Daca Carry=1, DL devine '1'
    PUSH AX
    MOV AH, 02h             ; Afisare caracter in DOS
    INT 21h
    POP AX
    LOOP B_LP
    POP CX
    RET
PRNT_BIN ENDP

PRNT_HEX PROC
    ; Afiseaza valoarea din AL in format Hexazecimal (2 cifre)
    PUSH AX
    MOV CH, AL
    SHR AL, 4               ; Izolam prima cifra (nibble superior)
    CALL PR_NIB
    MOV AL, CH
    AND AL, 0Fh             ; Izolam a doua cifra (nibble inferior)
    CALL PR_NIB
    POP AX
    RET
PRNT_HEX ENDP

PR_NIB PROC
    ; Transformă o valoare 0-15 în caracter ASCII și o afișează
    CMP AL, 9
    JBE IS_N
    ADD AL, 7               ; Ajustare pentru literele A-F
IS_N: ADD AL, 30h           ; Ajustare pentru cifrele 0-9
    MOV DL, AL
    MOV AH, 02h
    INT 21h
    RET
PR_NIB ENDP

CODE ENDS
END START
