;*****************************************
;
;Created: 	08/01/2018 
;
;
;Authors: 	Dimitrios Raptis				      			
;		Anastasia Pachni-Tsitiridou	
;
;*****************************************


;*****************************************
;		CONSTANT VALUES
;*****************************************
;
;      TEMPERATURE <  10 	==> 	0
;10 <= TEMPERATURE <= 20 	==> 	1
;20 <  TEMPERATURE <  30 	==> 	2
;30 <= TEMPERATURE		==> 	3
;
;    	HUMIDITY >= 50%		==>	0	
;	HUMIDITY <  50%		==>	1	
;
;*****************************************

.include "m16def.inc"

;*****r18-r20 delay

.def TEMPERATURE	= r16
.def HUMIDITY		= r17
.def WATERINGS		= r21
.def INTERVAL		= r22
.def DURATION		= r23
.def current_session	= r24
.def current_sec	= r25
.def buffer		= r26
.def LED		= r27

;===========================================
;Macro that takes an 8-bit register as input 
;and lights up the respective LEDs.
;===========================================
.MACRO 	light
		mov 	buffer, @0
		com 	buffer
		out 	PORTB,	buffer
.ENDMACRO

;************************************
; Initialize the stack
;************************************
InitStackPointer:
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)
	out sph, r16

;===============================
; 	     MAIN
;===============================

init_param:
		;set a random initial value
		ldi TEMPERATURE, 	0
		ldi WATERINGS, 		1
		ldi INTERVAL,		24
		ldi DURATION,		1
		ldi current_session,	1

main:	
		;Configure the pins of PORTD as input pins
		clr buffer
		out DDRD, buffer

		;Configure the pins of PORTB as output pins
		ser buffer
		out DDRB, buffer

		;Initialize input pins with 1's
		ser buffer
		out PIND, buffer

		clr buffer
		light buffer

set_param:
		sbis PIND, 0; when SW0 is pressed, call temp_state_0 
		rjmp temp_state_0
		sbis PIND, 1
		rjmp temp_state_1
		sbis PIND, 2
		rjmp temp_state_2
		sbis PIND, 3
		rjmp temp_state_3
		
		sbis PIND, 4
		rjmp humid

		sbis PIND, 6
		rjmp start

		//check humidity value and set duration
		cpi HUMIDITY, 0
		breq big_humid
		brne small_humid

		rjmp set_param

;*****************************************
;Set WATERINGS, INTERVAL and DURATION
;*****************************************
temp_state_0:
		sbis PIND, 0
		rjmp temp_state_0
	
		;set values
		ldi TEMPERATURE, 0
		ldi WATERINGS, 1
		ldi INTERVAL, 24
		rjmp set_param

temp_state_1:
		sbis PIND, 1
		rjmp temp_state_1
	
		;set values
		ldi TEMPERATURE, 1
		ldi WATERINGS, 1
		ldi INTERVAL, 24
		rjmp set_param

temp_state_2:
		sbis PIND, 2
		rjmp temp_state_2
	
		;set values
		ldi TEMPERATURE, 2
		ldi WATERINGS, 2
		ldi INTERVAL, 12
		rjmp set_param

temp_state_3:
		sbis PIND, 3
		rjmp temp_state_3
	
		;set values
		ldi TEMPERATURE, 3
		ldi WATERINGS, 3
		ldi INTERVAL, 8
		rjmp set_param

humid:
		sbis PIND, 4
		rjmp humid
		ldi HUMIDITY, 1	;set humidity < 50 value
		rjmp set_param

small_humid:
		; temp < 10
		cpi TEMPERATURE, 0
		breq set_duration_1
		; 10 < temp < 20
		cpi TEMPERATURE, 1
		breq set_duration_3
		; 20 < temp < 30
		cpi TEMPERATURE, 2
		breq set_duration_6
		; 30 < temp 
		cpi TEMPERATURE, 3
		breq set_duration_12

		rjmp set_param


big_humid:
		; temp < 10
		cpi TEMPERATURE, 0
		breq set_duration_1
		; 10 < temp < 20
		cpi TEMPERATURE, 1
		breq set_duration_1
		; 20 < temp < 30
		cpi TEMPERATURE, 2
		breq set_duration_4
		; 30 < temp 
		cpi TEMPERATURE, 3
		breq set_duration_10	
		
		rjmp set_param


;***************************
;	Set duration
;***************************
set_duration_1:
		ldi DURATION, 1
		rjmp set_param
set_duration_3:
		ldi DURATION, 3
		rjmp set_param
set_duration_4:
		ldi DURATION, 4
		rjmp set_param
set_duration_6:
		ldi DURATION, 6
		rjmp set_param
set_duration_10:
		ldi DURATION, 10
		rjmp set_param
set_duration_12:
		ldi DURATION, 12
		rjmp set_param

;***************************




start:
		sbis PIND, 6
		rjmp start

		//run current watering program
		rjmp watering
	
loop:
		;check if SW5 is pressed (low battery state)
		sbis PIND, 5
		rjmp low_battery

		;check if SW7 is pressed (new program state)
		sbis PIND, 7
		rjmp new_program

		ret
		
watering:
		cp current_session, WATERINGS
		breq reset

		;set bits LED6-LED7
		rcall set_LED6_LED7

		rcall set_LED4_LED5_to_0

		;check if SW5 or SW7 is pressed
		rcall loop

		rjmp while_duration

while_duration:
		cp current_sec, DURATION
		breq end_of_watering

		rcall set_LED0_LED3

		light LED	

		rcall delay1
		
		;increase timer
		ldi buffer, 1
		add current_sec, buffer

		;check if SW5 or SW7 is pressed
		rcall loop

		rjmp while_duration

reset:
		;reset the day
		ldi current_session, 0
		rjmp end_of_watering
		
end_of_watering:	
		;clear LEDs
		clr LED
		light LED

		;reset timer
		ldi current_sec, 1

		;TODO: set last 2 bits to current_session value	
		rcall set_LED6_LED7
		rcall set_LED4_LED5_to_1

		light LED

		cpi INTERVAL, 8
		breq break4
		cpi INTERVAL, 12
		breq break6
		cpi INTERVAL, 24
		breq break12
		
end_of_watering2:		
		clr LED
		light LED

		;increase current_session
		ldi buffer, 1
		add current_session, buffer

		;check if SW5 or SW7 is pressed
		rcall loop
		
		rjmp watering

;********************************
;	Intervals delays
;********************************
break4:
		rcall delay4
		rjmp end_of_watering2

break6:
		rcall delay6
		rjmp end_of_watering2

break12:
		rcall delay12
		rjmp end_of_watering2
;********************************


low_battery:
		sbis PIND, 5
		rjmp low_battery

		;light all leds respectively with 1sec delay
		ser buffer
		light buffer
		rcall delay1

		ldi buffer, 0x0
		light buffer
		rcall delay1

		; SW7 to break loop (new program state)
		sbis PIND, 7
		rjmp new_program

		rjmp low_battery

new_program:
		sbis PIND, 7
		rjmp new_program

		rjmp init_param


;*****************************************
;	        LED setters
;*****************************************
set_LED0_LED3:
		;clear bits LED0-LED3 
		ldi buffer, 0b11110000
		and LED, buffer

		mov buffer, current_sec

		;logical OR LED and buffer:	XX000000 OR 0000XXXX ==> XX00XXXX
		or LED, buffer

		ret

set_LED4_LED5_to_0:
		ldi buffer, 0b00000000
		or LED, buffer

		ret

set_LED4_LED5_to_1:
		ldi buffer, 0b00110000
		or LED, buffer

		ret

set_LED6_LED7:
		mov LED, current_session
		;logical left shift value 6 times:	000000XX ==> XX000000
		lsl LED
		lsl LED
		lsl LED
		lsl LED
		lsl LED
		lsl LED

		ret

;*****************************************
;        	  DELAYS
;*****************************************
delay1:
		; Generated by delay loop calculator
		; at http://www.bretmulvey.com/avrdelay.html
		;
		; Delay 4 000 000 cycles
		; 1s at 4.0 MHz

		    ldi  r18, 21
		    ldi  r19, 75
		    ldi  r20, 191
		L1: dec  r20
		    brne L1
		    dec  r19
		    brne L1
		    dec  r18
		    brne L1
		    nop  
			
			ret 

delay3:
	rcall delay1
	rcall delay1
	rcall delay1

	ret

delay4:
	rcall delay1
	rcall delay1
	rcall delay1
	rcall delay1

	ret

delay6:
	rcall delay3
	rcall delay3
	
	ret

delay10:
	rcall delay4
	rcall delay6
	
	ret

delay12:
	rcall delay6
	rcall delay6
	
	ret
