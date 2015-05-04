	;*--------------------------------------------------------------
	;*
	;* 24H_clock_v5_1.asm
	;*
	;*
	;* changes to the pin port assignments to make it easier for pcb
	;# fri jan 3, 2014 -tm -changed CONFIG from XT to HS OSC
	;  tue Jan 21, 2014 -v4 replaced 4.000MHz crystal with 4.096MHz 
	;  -set PSA to 1:32  which means  40960000/4 = 10240000 hz fundamental
	;  -  the 1:32 means 10240000/32 = 32000 hz
	;  -  interrupts happen every 256 TMR0 ticks:  32000/256 = 125
	;  - every 125 times through should be one second
	;
	;* Sat Mar 23, 2014
	;*  - need to make RB2, RB4 as the SWITCH inputs
	;*
	;* based upon:	24  hour digital clock
	;*      	www.electronicecircuits.com
	;*
 	;* SW1 =HOURS   SW2=MIN
	;*
	;*    DSP3   1.      18.   DSP4
	;*    DSP1   2.      17.   DSP2
	;*           3.      16.   OSC1
	;*   /MCLR   4.      15.   OSC2  (4.000MHZ crystal)
	;*     GND   5.      14.   VCC   (+5V)
	;*  seconds  6.      13.   d     (  7 segment D)
	;*     : e   7.      12.   f
	;* SW2 : c   8.      11.   b
	;*	 g   9.      10.   a  SW1   
	;*
	;*
	;*  HP 4 digit 7 segment CC display 
	;*       D1=DSP1, D2=DSP2, D3=DSP3, D4=DSP4
	;*
	;*       a    b   D2  f   d   g
	;*      12.  11.  10. 9.  8.  7.
	;*
	;*         
	;*       1.   2.   3. 4.  5.  6.
	;*      D1    e    c  D3  dp  D4
	;*
	;* Tue., Jan. 7 2014 -tm
	;*  --the 4MHz clock drifts and gains too much time, using the Zero-One
	;*    Roman Black (Jose Pino version)
	;*
	;*
	;*------------------------------------------------------------
	 processor	pic16f716
	include		"p16f716.inc"
	radix		hex			; default to base 16.
	
	; 20151211 -tm config for XT crystal on 16F716 
	__CONFIG    _CP_OFF & _VBOR_25 & _BOREN_OFF & _PWRTE_ON & _WDT_OFF & _XT_OSC


	errorlevel	-302			; suppress 'wrong bank' messages

	;*------------------------------------------------------------
	;*  RESET/START VECTOR
	;*------------------------------------------------------------
	org	0x0000
	goto	main

	;*------------------------------------------------------------
	;*  INTERRUPT VECTOR
	;*------------------------------------------------------------
	org	0x0004
	goto	ISR   

	;*------------------------------------------------------------
	;* RAM and DEFINES
	;*------------------------------------------------------------

	cblock	0x20	; for 16F8X, change to 0x20 for most other PIC's
	  s1
	  s10
	  m1
	  m10
	  h1
	  h10
	  del
	  del0
	  del01
	  del02
	  svW			; save W register 
	  svPB			; save Port B register
	  svPA			; save Port A register
	  svSTATUS		; save STATUS register
	  flags			; bit flags: bit#0=1 means 1 second
	  intc			; interrupt counter
	endc

	#define	dp PORTB, W   ; pin no 06  decimal point for 1sec flashing

	;*------------------------------------------------------------
	;* simple cpu-wasting Delay reoutines
	;*------------------------------------------------------------
	
delay01
	decfsz	del, F
	  goto	$-.1
	clrf	PORTB
	return
delay02
	movlw	.2
	movwf	del01
	decfsz	del01, F
	  goto	$-.1
	return

	;*------------------------------------------------------------
	;* 7 Segment Display LOOKUP TABLE
	;*------------------------------------------------------------
table	addwf	PCL, F			
	;         dfbagceX           X=RB0 the 'blinking seconds' indicator
	retlw	b'11110110'		; 0
	retlw	b'00100100'		; 1
	retlw	b'10111010'		; 2
	retlw	b'10111100'		; 3
	retlw	b'01101100'		; 4
	retlw	b'11011100'		; 5
	retlw	b'11011110'		; 6
	retlw	b'00110100'		; 7
	retlw	b'11111110'		; 8
	retlw	b'11111100'		; 9
	

;	Scan displays the multiplexed digits from Right to Left	
scan	
	movlw	b'00000010'  	;  DSP04 -rightmost digit = minutes
	movwf	PORTA
	movf	m1, W
	call	table
	movwf	PORTB
	call	delay01
	movlw	b'00000100'	;  DSP03 -the 10's of minutes
	movwf	PORTA
	movf	m10, W
	call	table
	movwf	PORTB	
	call	delay01	
	movlw	b'00000001'	;  DSP02 -the units digit of the Hours
	movwf	PORTA
	movf	h1, W
	call	table
	movwf	PORTB	
	call	delay01
	movlw	b'00001000'	;  DSP01 -the Tens digits of the Hours
	movwf	PORTA
	movf	h10, W
	call	table
	movwf	PORTB
	call	delay01
	return
		
incr	;	Increment seconds -> Minutes -> Hours	
	;
	bcf	flags, 0	; reset the 'one second' flag
	incf	s1, F	 	
	movf	s1, W
	bcf	STATUS, Z
	xorlw	.10
	btfss	STATUS, Z
	  return
	clrf	s1
	incf	s10, F
	movf	s10, W
	bcf	STATUS, Z
	xorlw	.6
	btfss	STATUS, Z
	 return
	clrf	s10
incr_sm	incf	m1, F
	movf	m1, W
	bcf	STATUS, Z
	xorlw	.10
	btfss	STATUS, Z
	 return
	clrf	m1
	incf	m10, F
	movf	m10, W
	bcf	STATUS, Z
	xorlw	.6
	btfss	STATUS, Z
	 return
	clrf	m10
	;

incr_sh	incf	h1, F
	swapf	h10, W
	addwf	h1, W
	bcf	STATUS, Z
	xorlw	24h
	btfss	STATUS, Z
	 goto	$+4		; style note, should use a label
	clrf	h1
	clrf	h10
	return
	movf	h1, W
	bcf	STATUS, Z
	xorlw	.10
	btfss	STATUS, Z
	 return
	clrf	h1
	incf	h10, F
	return

	;*------------------------------------------------------------
	;* INTERRUPT SERVICE ROUTINE
	;*
	;* an interrupt occurs on TMR0  every 256 ticks
	;*
	;*------------------------------------------------------------
ISR	;
	movwf	svW			; preserve W
	swapf	STATUS, W		; preserve STATUS
	movwf	svSTATUS
	;
	;  we get here ever 0.008 seconds with a 4.096MHz crystal
	;  and a 1:32 Prescaler on TMR0, TMR0 freely increments
	;
	decfsz	intc, F			; when we have 125 counts we should
          goto	ISR_9			; don't do anything while intc > 0
	; 125 passes so one second
	call	incr			; do the 1 second Time Keeping routines
	movlw	.125			; now reset the interrupts count 125 * 0.008 = 1 sec  
	movwf	intc			; and reset the interrupt
	;
ISR_9
	swapf	svSTATUS, W
	movwf	STATUS
	swapf	svW, F
	swapf	svW, W
	bcf	INTCON, T0IF		; clear the TMR0 for the next time
	;
	retfie

;----------------------------------------------------------------------
; 	pushbutton tests: RB2=Minutes  RB4=Hours
;----------------------------------------------------------------------
key	
	; since the RB2 and RB4 pins are mostly outputs, we have to
	; save the PORTB values
	;
	movf	PORTB, W
	movwf	svPB  		; save PORTB current latch 
	nop
	bsf	STATUS, RP0	; work in Bank1 to set PORT directions
	bcf	OPTION_REG, 7	; Enable the Weak Pullups on PORTB
	movlw	b'00010100'	; make RB2, RB4 as Inputs, rest Outputs
	movwf	TRISB
	bcf	STATUS, RP0	; make sure we're back in Bank0
	call	delay02

sm1	btfsc	PORTB, 2  ; set minutes : SW2=LOW means button pushed
	 goto	sh1
	call	incr_sm
	goto	keyx

sh1	call	delay02  
	btfsc	PORTB, 4  ;   set hour : SW1=LOW means button pushed
	 goto	keyx
	call	incr_sh

keyx	bsf	STATUS, RP0		; work in Bank1
	bsf	OPTION_REG, 7		; disable PortB weak pullups
	clrf	TRISB			; make PORTB all Outputs
	bcf	STATUS, RP0		; work in Bank0
	movf	svPB, W			
	movwf	PORTB			; restore PORTB
	movlw	.100
	movwf	del02
	call	scan
	decfsz	del02, F
	  goto	$-.2
	;;bcf 	OPTION_REG, 7
	return
		
				
main	;  -Initialize all variables 
	;  -setup the Interrupts to trigger on TMR0 overflow
	;  -assign Prescaler to the WatchDog Timer
	;
	bcf	STATUS, RP0	; work in Bank0
	;     set the start time:  1234
	;
	movlw	1
	movwf	h10
	movlw	2
	movwf	h1
	movlw	3
	movwf	m10
	movlw	4
	movwf	m1
	clrf	s1		; Seconds Units
	clrf	s10		; Seconds Tens
	;
	clrf	del		; Delay loop variables
	clrf	del0
	clrf	del01
	clrf	del02
	;
	clrf	flags		; all bit flags are cleared
	clrf	svW		; W register Save on Interrupt
	clrf	svSTATUS 	; STATUS register Save on Interrupt
	movlw	.125		; initialize the interrupt counter
	movwf	intc
	;
	bsf	STATUS, RP0	; get into Bank1 and set the I/O direction
	;
	clrf	TRISB		; both PORTA/B are all OUTPUTS
	clrf	TRISA
	;
	;
	; OPTION_REG
	;Bit#    7.	6.	5.	4.	3.	2.	1.	0.
	;Access	R/W 	R/W 	R/W 	R/W 	R/W 	R/W 	R/W 	R/W
	;Initial 1 	1 	1 	1 	1 	1 	1 	1
	;Name 	-RBPU 	INTEDG 	TOCS 	TOSE 	PSA 	PS2 	PS1 	PS0
	;
	movlw	b'10000100'		;  PSA -> TMR0; disable WPU on Inputs
					;  PSA=100 is 1:32
	movwf	OPTION_REG		;  no prescaler and Enable weak pullups 
	bcf	STATUS, RP0		; switch back to Bank0  
        ;
	bcf   	INTCON, T0IF		; clear any possible TMR0 overflow interrupt flag 	
	bsf	INTCON, T0IE		; ENABLE the TMR0 interrupt
	bsf	INTCON, GIE		; ENABLE Global Interrupts
	;
TimeKeeper
	;
	call	scan
	call	key
	goto	TimeKeeper
	;				
	org		2007h
	;;data	3ff1h
	end
