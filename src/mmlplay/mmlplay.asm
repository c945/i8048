;$Id: mmlplay.asm,v 1.13 2004/11/29 05:15:28 runner Exp $

;mmlplayer
;	mmlsyntax
;		'[{<>}]{cdefgabr}[{+}{1248}][.]'
;	<:octave down,continue default 0 octave in 0 1 2
;	>:octave up, continue
;	CDEFGAG:oto data
;	+:#
;	/:Repeat
;	01248:otono nagasa default=4
;	.:futen
;
;	P1[0-7] - LED -GND
;	P25 - CrystalBuzzer - GND
;	clock = 6MHz = 2.5us/MachieCycle

	page	0
	cpu	8048

_P25ON	equ	(1<<5)
_P25OFF	equ	(0ffH ! _P25ON)

	org	0
	mov	a,#0ffh

	mov	R6,#0			;R6:Octave(Default 0)
	mov	R7,#0			;R7:mmldata pointer
loop:
	mov	R5,#'4'			;R5:MML('0'-'9').default 4bu onpu
	mov	a,R7
	inc	R7
	movp3	a,@a			;get mml
	mov	R4,a			;save mml
	xrl	a,#'/'			;check '/' halt
	jz	hlt
	mov	a,R4
	xrl	a,#'<'			;check '<' Octave down.
	jnz	L1
	;MML '<'
	dec	R6
	jmp	loop
L1	mov	a,R4
	xrl	a,#'>'			;check '>' Octave Up.
	jnz	L2
	;MML '>'
	inc	R6
	jmp	loop
L2	mov	a,R4
	call	fixuptone		;convert MML to vector
	mov	R4,a			;R4:fixuped value
	mov	a,R7
	movp3	a,@a
	xrl	a,#'+'			;check '+'
	jnz	L3
	inc	R4
	inc	R7
L3	mov	a,R7
	movp3	a,@a
	add	a,#(256-'0')		;check < '0'
	jnc	L4
	mov	a,R7
	movp3	a,@a
	add	a,#(255-'9')		;check > '9'
	jc	L4
	;MML '0' - '9'
	mov	a,R7
	movp3	a,@a
	mov	R5,a			;R5:MML('0'-'9')
	inc	R7
L4	mov	a,R7
	movp3	a,@a
	xrl	a,#'.'			;check '.'
	jnz	L99
	;MML '.'
	mov	a,R5
	orl	a,#80h
	mov	R5,a
	inc	R7
L99:					;to play
;display led start
	mov	a,R6
	swap	a
	anl	a,#0f0h
	orl	a,R4
	cpl	a
	outl	P1,a			;P1:LED display MML
;display led end
	mov	a,R5
	call	fixuplen
	mov	R1,a			;convert MML(length) to R1
	mov	a,R4			;convert MML(TONE) to value
	call	gettone
	call	play
	jmp	loop

hlt:	mov	a,#'0'			;play "R0" and repeat
	call	fixuplen
	mov	R1,a
	mov	a,#0
	outl	P1,a
	call	play
	jmp	0

	org	($/256+1)*256
play:
	;play sound (R1-1)times play, 1times is mute.
	;@param	a	tone value for tone20ms or 0=mute.
	;@param	R1	repeat N(20ms)
	;@broken	R1
	dec	R1
play_loop
	jz	play_mute
	call	tone20ms
	jmp	play_while
play_mute
	call	mute20ms
play_while
	djnz	R1,play_loop
	call	mute20ms
	retr

fixuplen:
	;convert MML length 
	;@param	a	'0' '1' '2' '4' '8' '9' < 80H < '0' '1' '2' '4' '8' '9'
	;@return=A	160 80  40  20  10  5           240 120  60  30  15   7
	;@broken	R0
	mov	R0,a
	anl	a,#80h
	jnz	fixuplen2
	mov	a,R0
	add	a,#(256-'0')		;sub '0'
	mov	R0,#(fixuplen_data & 0ffh)
	add	a,R0
	movp	a,@a
	retr
fixuplen2
	mov	a,R0
	anl	a,#7fh
	add	a,#(256-'0')		;sub '0'
	mov	R0,#(fixuplen2_data & 0ffh)
	add	a,R0
	movp	a,@a
	retr

	;Normal Onpu
fixuplen_data:
	db	160	;0
	db	80	;1
	db	40	;2
	db	0
	db	20	;4
	db	0	
	db	0
	db	0
	db	10	;8
	db	5	;9(16)

	; Futen Onpu
fixuplen2_data:
	db	240	;0
	db	120	;1
	db	60	;2
	db	0
	db	30	;4
	db	0	
	db	0
	db	0
	db	15	;8
	db	7	;9(16)

fixuptone:
	;MML to vector number
	;@param	a	'c' 'd' 'e' 'f' 'g' 'a' 'b'    'r'
	;@return=A	 0   2   4   5   7   9   11     0
	;@broken	R0
	add	a,#(256-'a')		;sub 'A'
	mov	R0,#(fixuptone_data & 0ffh)
	add	a,R0
	movp	a,@a
	retr
fixuptone_data:
	db	9	;a
	db	11	;b
	db	0	;c
	db	2	;d
	db	4	;e
	db	5	;f
	db	7	;g
	db	255	;h
	db	255	;i
	db	255	;j
	db	255	;k
	db	255	;l
	db	255	;m
	db	255	;n
	db	255	;o
	db	255	;p
	db	255	;q
	db	255	;r

gettone:
	;get tone value for tone20ms
	;param	a	0=C(do) 1=C#(do#) 2=D(re) 3=D#(re#) 4=E(mi) ...255=mute
	;param	R6	octave 0 or 1 or 2
	;return	a	TONE VALLUE(mute=0)
	;broken	R0
	inc	a
	jz	gettone_end
	dec	a
	xch	a,R6
	mov	R0,a
	xch	a,R6	;R0=Octave
	inc	a
	inc	a
	inc	a	;skip from beepvalue.dat A,A#,B
	inc	R0
	jmp	$+4
	add	a,#12
	djnz	R0,$-2
	mov	R0,#(gettone_value & 0ffh);
	add	a,R0
	movp	a,@a
gettone_end
	retr
gettone_value:
	db 225	;A  440.00Hz t=2272.73us val=224.77 
	db 212	;A# 466.16Hz t=2145.17us val=212.02 
	db 200	;B  493.88Hz t=2024.77us val=199.98 
	db 189	;C  523.25Hz t=1911.13us val=188.61 
	db 178	;C# 554.37Hz t=1803.86us val=177.89 
	db 168	;D  587.33Hz t=1702.62us val=167.76 
	db 158	;D# 622.25Hz t=1607.06us val=158.21 
	db 149	;E  659.26Hz t=1516.86us val=149.19 
	db 141	;F  698.46Hz t=1431.73us val=140.67 
	db 133	;F# 739.99Hz t=1351.37us val=132.64 
	db 125	;G  783.99Hz t=1275.53us val=125.05 
	db 118	;G# 830.61Hz t=1203.94us val=117.89 
	db 111	;A  880.00Hz t=1136.36us val=111.14 
	db 105	;A# 932.33Hz t=1072.58us val=104.76 
	db 99	;B  987.77Hz t=1012.38us val=98.74 
	db 93	;C  1046.50Hz t=955.56us val=93.06 
	db 88	;C# 1108.73Hz t=901.93us val=87.69 
	db 83	;D  1174.66Hz t=851.31us val=82.63 
	db 78	;D# 1244.51Hz t=803.53us val=77.85 
	db 73	;E  1318.51Hz t=758.43us val=73.34 
	db 69	;F  1396.91Hz t=715.86us val=69.09 
	db 65	;F# 1479.98Hz t=675.69us val=65.07 
	db 61	;G  1567.98Hz t=637.76us val=61.28 
	db 58	;G# 1661.22Hz t=601.97us val=57.70 
	db 54	;A  1760.00Hz t=568.18us val=54.32 
	db 51	;A# 1864.66Hz t=536.29us val=51.13 
	db 48	;B  1975.53Hz t=506.19us val=48.12 
	db 45	;C  2093.00Hz t=477.78us val=45.28 
	db 43	;C# 2217.46Hz t=450.97us val=42.60 
	db 40	;D  2349.32Hz t=425.66us val=40.07 
	db 38	;D# 2489.02Hz t=401.77us val=37.68 
	db 35	;E  2637.02Hz t=379.22us val=35.42 
	db 33	;F  2793.83Hz t=357.93us val=33.29 
	db 31	;F# 2959.96Hz t=337.84us val=31.28 
	db 29	;G  3135.96Hz t=318.88us val=29.39 
	db 28	;G# 3322.44Hz t=300.98us val=27.60 

mute20ms:
	;mute 20ms
	;@param		none
	;@broken	R0,TIMER
	xch	a,R0
	clr	a
	mov	T,a
	strt	t
mute20ms_loop
	jtf	mute20ms_end
	jmp	mute20ms_loop
mute20ms_end
	stop	tcnt
	retr
	
tone20ms:
	;BEEP to P25 while 20ms
	;@param		a:tone control 25+10N (us)
	;@broken	R0,TIMER
	xch	a,R0
	clr	a
	mov	T,a
	strt	t
	xch	a,R0
tone20ms_loop:			;5+2*(N-1)+5+2*(N-1)+4 Machine Cycle.
	orl	P2,#_P25ON	;=14+4*(N-1) = 10+4N = 25+10N(us)
	mov	R0,a		;Ex. 440Hz = 2273us = (2273-25)/10N ... N=225
	djnz	R0,$
	anl	P2,#_P25OFF
	mov	R0,a
	djnz	R0,$
	jtf	tone20ms_end
	jmp	tone20ms_loop
tone20ms_end
	stop	tcnt
	retr

	org	0300h		;8048 Page 3
mmldata:

	;Jeux interdits
	db "aaaagffeddfa>ddddc<a+a+aggaa+aa+a>c+<a+aagffedeeeefed1"
	db "aaaagffeddfa>ddddc<a+a+aggaa+aa+a>c+<a+aagffedeeeefed1"
	db "f+f+f+f+eddc+c+c+cc+bbbb>c+<bbaaab>c+ddddc+c<bbbbagf+f+f+f+ged1"
	db "aaaagffeddfa>ddddc<a+a+aggaa+aa+a>c+<a+aagffedeeeefed0"
	db "r0"
	db "/"

	end

