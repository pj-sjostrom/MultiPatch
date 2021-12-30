#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Warner Panel
////	(c) Jesper Sjostrom, 14 Dec 2021
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Simple panel for reading temperature from the Warner Inline Heater and
////	enabling communication of this to the MultiPatch software.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	14 Dec 2021. JSj
////	*	Beginning code 
////	*	Made panel plus the key code.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Menu "Macros"
	"Initiate the Warner panel", Warner_init()
	"-"
end

Function Warner_init()

	JT_GlobalVariable("Warner_BoardID",0,"1",1)			// Board ID (this is a string!)

	JT_GlobalVariable("Warner_Offset",0.1,"",0)			// Offset for scaling (degrees) (By trial and error from front panel display)
	JT_GlobalVariable("Warner_Gain",0.1,"",0)				// Gain for scaling (V/degrees) (Manual says: 100mV/*C)
	JT_GlobalVariable("Warner_Channel",4,"",0)				// Channel (numbering starting at zero)
	JT_GlobalVariable("Warner_Temp",32,"",0)				// Temperature (degrees)
	
	Print " "		// JT_GlobalVariable uses printf

	Warner_CreateWarnerPanel()

End

Function Warner_CreateWarnerPanel()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 300
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow WarnerPanel
	if (V_flag)
		GetWindow WarnerPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K WarnerPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Warner Panel"
	DoWindow/C WarnerPanel
	ModifyPanel/W=WarnerPanel fixedSize=1

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	Button GetTempButton,pos={x,y+2},size={xSkip-4,bHeight},proc=Warner_getTempProc,title="Measure",fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable tempSV,pos={x,y+3},size={xSkip-4,bHeight},title="Temperature: ",value=Warner_Temp,limits={1,Inf,0},noEdit=1,fColor=(0,0,65535),valueColor=(0,0,65535),fStyle=1,frame=0,fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable offsetSV,pos={x,y+3},size={xSkip-4,bHeight},title="Offset: ",value=Warner_Offset,limits={-Inf,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable gainSV,pos={x,y+3},size={xSkip-4,bHeight},title="Gain: ",value=Warner_Gain,limits={-Inf,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable BoardIDSV,pos={x,y+3},size={xSkip-4,bHeight},title="Board ID: ",value=Warner_BoardID,fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable channelSV,pos={x,y+3},size={xSkip-4,bHeight},title="Channel: ",value=Warner_Channel,limits={0,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	MoveWindow/W=WarnerPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read the temperature

Function Warner_getTempProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Warner_GetTemp()
			break
	endswitch

	return 0
End

Function Warner_GetTemp()

	SVAR		Warner_BoardID
	NVAR		Warner_Offset
	NVAR		Warner_Gain
	NVAR		Warner_Channel
	NVAR		Warner_Temp

	Variable theVoltage = Warner_ReadChan(Warner_BoardID,Warner_Channel)
	
	Warner_Temp = theVoltage/Warner_Gain + Warner_Offset

End

Function Warner_ReadChan(theDev,theChannel)
	String		theDev
	Variable	theChannel
	
	Variable	sampleRate = 10000			// (Hz)
	Variable	wDur = 3e-3					// Duration of read (s)
	
	Make/O/N=(sampleRate*wDur) Warner_tempWave
	SetScale/P x 0,1/sampleRate,Warner_tempWave
	DAQmx_Scan/DEV=theDev/BKG=0/STRT WAVES="Warner_tempWave,"+num2str(theChannel)+",0,2;"
	
	Return Mean(Warner_tempWave)

End

