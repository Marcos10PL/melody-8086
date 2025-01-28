_code segment
	assume  cs:_code, ds:_data, ss:_stack

start:		
	mov	ax,_data
	mov	ds,ax
	mov	ax,_stack
	mov	ss,ax
	mov	sp,offset top

	;liczba znakow w parametrze
	mov	si, 80h

	;spr czy podano parametr
	mov	cl, es:[si]
	cmp	cl, 0
	jz 	blad

	;zamien parametr na nazwe pliku
	mov	di, offset nazwaPliku
	mov	si, 82h ;poczatek nazwy
	mov	ch, 0  

wczytaj_nazwe_pliku:
	mov	al, es:[si]
	mov	byte ptr [di], al
	inc	di
	inc 	si
	loop	wczytaj_nazwe_pliku

	;otwracie pliku
	mov	ah, 3dh
	mov	al, 00h
	mov	dx, offset nazwaPliku
	int 	21h
	jc	blad

	mov	uchwytPliku, ax

czytaj_plik:	
	;uchwyt pliku
	mov	bx, uchwytPliku

	;czytanie - 4 bajty - nuta, oktawa, czas, spcja
	mov 	cx, 4
	mov	ah, 3fh
	mov	dx, offset bufor
	int 	21h
	
	;spr czy koniec pliku
	cmp 	ax, 0
	jz	koniec
	
	call 	odczytaj_nute 		;zapis nuty w bx
	call 	odczytaj_oktawe		;konwersja nuty do odpowiedniej oktawy
	call 	odczytaj_czas_nuty	;czas trwania nuty (nuta, polnuta, itd)
	call    odtworz_nute		;przekanie nuty lub pauzy na glosnik	
	
	jmp czytaj_plik
	
	;obsluga bledu
	blad:
	mov	ah, 09h
	mov	dx, offset error
	int 	21h
koniec:        
   	mov     ah, 4ch
    	int     21h

;-------------NUTA-------------

odczytaj_nute:	
	;przygotowanie
	mov	al, bufor[0] 
	
	;spr czy to pazua (PZ)
	cmp	al, 'P'
	je	pomin_wczytywanie_nuty

	sub	al, 'A'

	;spr czy znak (nuta) w zakresie
	cmp	al, 38
	jg	bladN
	cmp	al,0
	jl	bladN
	
	;nuty 0-6 (A-G)
	cmp	al, 6
	jg	cisdur
	
	;wyszukanie nuty 
	mov	di, offset nuty
	mov	ah, 0
	sal	ax, 1
	add	di, ax
	mov	bx, [di]
	ret
	
cisdur:
	;gama cisdur 0-6 (ais - gis)
	cmp	al, 32
	jl	bladN
	
	sub	al, 32

	;wyszukanie nuty w cisdur
	mov	di, offset cisdurNuty
	mov	ah, 0
	sal	ax, 1
	add	di, ax
	mov	bx, [di]
	ret

pomin_wczytywanie_nuty:
	mov	byte ptr pauza, 1	
	cmp	bufor[1], 'Z'	
	jne	bladP
	ret
	
	;obsluga bledu
	bladN: 
	mov	ah, 09h
	mov	dx, offset errorN
	int 	21h
	jmp 	koniec
	
	bladP: 
	mov	ah, 09h
	mov	dx, offset errorP
	int 	21h
	jmp 	koniec

;-------------OKTAWA-------------

odczytaj_oktawe:
	;spr czy to pauza
	cmp 	byte ptr pauza, 1
	je	pomin_konwersje

	;przygotowanie	
	mov	ah, bufor[1]
	sub	ah, '0'

	;spr czy oktawa w zakresie 1-7
	cmp	ah, 7
	je	pomin_konwersje
	jg	bladO
	cmp	ah, 1
	jl	bladO

	;konwersja nutu do podanej oktawy
	mov	al, 7
	sub	al, ah
	mov	ah, 0
	
	;przesuwaj (/2)
	mov	cx, ax 
przesuwaj:
	sar 	bx, 1
	loop 	przesuwaj
	
pomin_konwersje:	
	ret
	
	;obsluga bledu
	bladO:
	mov	ah, 09h
	mov	dx, offset errorO
	int 	21h
	jmp 	koniec

;-----------RODZAJ NUTY (CZAS)-----------

odczytaj_czas_nuty:
	;odczytanie i konwersja czasu nuty (do CX:DX)
	mov	al, bufor[2]
	sub	al, '0'

	mov	dx, 4240h	;mlodszy bajt 1 000 000
	mov	cx, 000fh	;starszy bajt 1 000 000

;warunek1 - cala nuta (1s)
	cmp	al, 1
	je	zapisz
	
;warunek2 - polnuta (0.5s)
	cmp	al, 2
	jne	warunek3
	mov	cx, 0007h	
	mov	dx, 0a120h	
	jmp 	zapisz
	
warunek3: ; - cwiercnuta (0.25s)
	cmp	al, 3
	jne	warunek4
	mov	cx, 0003h	
	mov	dx, 0d090h
	jmp	zapisz
	
warunek4: ; - osemka (0.125s)
	cmp 	al, 4
	jne	warunek5
	mov	cx, 0001h 	
	mov	dx, 0e848h
	jmp	zapisz
	
warunek5: ; - szesnastka (0.0625s)
	cmp	al, 5
	jne	bladC
	mov	cx, 0000h	
	mov	dx, 0f424h

zapisz:
	mov	dxW, dx ;mlodszy bajt (DX)
	mov	cxW, cx ;starszy bajt (CX)	 
	ret
	
	;obsluga bledu
	bladC:
	mov	ah, 09h
	mov	dx, offset errorC
	int	21h
	
;-------------ODTWORZ NUTE / PAUZE-------------

odtworz_nute:
	;spr czy to nie pauza
	cmp	byte ptr pauza, 1
	je	przerwanie

	;ustawienie kanalu 2 
	mov	al, 182
	out	43h, al

	;odycztanie i konwersja nuty
	mov	dx, 0012h	;starszy bajt 1 193 180 
	mov	ax, 34dch	;mlodszy bajt 1 193 180
	div	bx
	out	42h, al
	mov	al, ah
	out	42h, al
    
	;wlacz glosnik
	in	al, 61h
	or	al, 03h
	out	61h, al

przerwanie:
	;pobierz z pamieci CX:DX
	mov	cx, cxW	 
	mov	dx, dxW

	;opoznij (czas w CX:DX)
	mov	ah, 86h
	mov	al, 0
	int	15h
	
	;spr czy to pauza
	cmp	byte ptr pauza, 1
	je	pomin_wyl_gl

	;wylacz glosnik
	in	al, 61h
	and	al, 0fch
	out	61h, al

pomin_wyl_gl:
	mov	byte ptr pauza, 0
	ret

_code ends

_data segment
	;komunikaty
	error db 'Blad otwarcia pliku!$'
	errorN db 'Bledny zapis nuty!$'
	errorO db 'Bledny zapis oktawy!$'
	errorC db 'Bledny zapis czasu trwania nuty!$'
	errorP db 'Bledny zapis pauzy!$'

	;czestotliwosci nut w 7 oktawie 
	;A, H, C, D, E, F, G
	nuty 		dw 3520, 3951, 2093, 2349, 2637, 2749, 3136
	;Ais, His, Cis, Dis, Fis, Gis 
	cisdurNuty	dw 3729, 4067, 2217, 2489, 2714, 2960, 3322 

	;dane
	nazwaPliku 	db 127 dup(0)
	bufor	   	db 4   dup(0)
	aktualnaNuta	dw 0
	uchwytPliku	dw ?
	pauza		db 0
	dxW			dw 0
	cxW			dw 0

_data ends

_stack segment stack
	top_stack	equ 100h
top	Label word
_stack ends

end start
