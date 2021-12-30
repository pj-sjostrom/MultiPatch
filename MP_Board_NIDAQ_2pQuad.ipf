#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6

// National Instruments plugin for MultiPatch software
// (c) Jesper Sjostrom, 2004
// * External triggering built in, JSj 2004-04-16
// * Sorting out 6229 and NIDAQ Tools MX compatibility, JSj started 2007-12-07, done 2008-01-30
// * Added NIDAQ debug panel just like I did for ITC18 years ago, with nice progress bar, JSj 2008-01-30
// * Added sealtest feature, JSj 2009-06-03
// * Improved sealtest feature so that user can change parameters and selected channels on the fly, JSj 2009-07-24

function InitBoardVariables()

	// 6229		used for electrophysiology (32 inputs, 4 outputs)			Device 1
	// 6110		used for imaging (4 inputs, 2 outputs)					Device 2

	// OLD NOTES INDENTED BELOW
		// NI6052E	used for data acquisition (8 inputs, 2 outputs)			Device 1
		// NI6713	used for sending waves (zero inputs, 8 outputs)			Device 2
		// NI6110	used for ScanImage, *not* for Igor (4 inputs, 2 outputs)	Device 3
		
		// For NI6052E board, the AcqGainSet variable means:
		//	0.5		clipping at	+/-10	V	-- good for 100x V_m BNC on Dagan (+/-100 mV in current clamp)
		//	1		clipping at	+/-5		V
		//	2		clipping at	+/-2.5	V	-- good for 10x V_m BNC on Dagan (+/-250 mV in current clamp)
		//	5		clipping at	+/-1		V
		//	10		clipping at	+/-0.5	V
		//	20		clipping at	+/-0.25	V
		//	50		clipping at	+/-0.1	V
		//	100		clipping at	+/-0.05	V

	String BoardList =  fDAQmx_DeviceNames()							// Locate the boards
	Variable NumberOfBoards =	ItemsInList(BoardList);				// Number of NI boards installed
	Print "\t\tFound ",NumberOfBoards," boards."
	String/G BoardIdStr =			StringFromList(0,BoardList)			// Assuming ePhys board in slot 1
	String/G	OtherBoardIdStr = 	StringFromList(1,BoardList)			// Assuming imaging board in slot 2
								// Other board is e.g. the imaging board, i.e. whatever board it is that you want to do RTSI triggering with
	Variable/G	BoardId =		str2num(StringFromList(0,BoardList))
	Variable/G	OtherBoardId =	str2num(StringFromList(1,BoardList))
	String/G		BoardName = "PCI-6229"							// Used to identify this Igor Procedure "plug-in" file in main program
	String/G		OtherBoardName = "PCI-6110"						// Used to identify this Igor Procedure "plug-in" file in main program
	Print "\t\tePhys board device ID is \""+BoardIdStr+"\" and its name is "+BoardName+"."
	Print "\t\tImaging board device ID is \""+OtherBoardIdStr+"\" and its name is "+OtherBoardName+"."
	
	Make/O/N=(4)	NI_InputChannels = {0,1,2,3}	// There are 32 input channels to chose 4 from; these 4 are arbitrary and are defined by this wave
												// position 1 in wave is channel 1 as seen in e.g. the MP Switchboard panel, and so on...
												// Example:		{5,1,2,3} means channel 1 in the panel is now channel 5 on the breakout box
												// 				(the other channels are as before)
	Variable	i
	i = 0
	printf "\t\tThe input channels 1, 2, 3, & 4 are taken from the following ADC inputs: "
	do
 		printf "%2.0f",NI_InputChannels[i]
 		i += 1
	while (i<4)
	print ""

	Variable/G	NI_VerboseMode = 0				// 1 = output lots of info, 0 = don't output lot's of info
	Variable/G	NI_TransferDuringAcq = 1			// Boolean: Transfer acquired data during polling or not
	
	//// Output Board channels
	Make/O/N=(4) NI_OutputChannels = {0,1,2,3}	// i.e. {5,0,2,3} means MP output channel #1 is on BNC #5, MP out #2 is on BNC #0, etc
	
	Variable/G	NI_UseExternalTrigger
	Variable/G	NI_UpdateLimit = 0//1/250e3		// Time between samples on different channels (zero makes driver select the default value)
												// DO NOT set NI_UpdateLimit to very small values to achieve near-simultaneous sampling
												// as this may result in smearing and "ghosting" across channels

	Make/O/N=(4) AcqGainSetValues = {10,5,1,0.2}	// Defines the available ranges of input voltage for the NI 622x boards
												// NI 625x boards can cover a wider range with higher resolution, but should be compatible with these values
	Variable/G	AcqGainCurrVal = 10

	Variable/G	NI_PollSpacing = 0.5										// Duration between polls [s]
	Print "\t\tInter-poll interval:",NI_PollSpacing,"s"
	Variable/G	NI_nSamples = 0											// When polling the NIDAQ board, these are the number of samples we expect when done.
	Variable/G	NI_Current_nSamplesVal = 0								// Number of acquired samples
	Variable/G	NI_Current_nSamplesRat = 0								// Ratio of number of samples acquired and total number of samples
	Variable/G	NI_CounterInUse = 0										// Is counter in use?
	
	Variable/G	NI_SealTestFreq = 40				// Seal test frequency [Hz]
	Variable/G	NI_SealTestAmp = -5e-3			// Seal test amplitude [V]

End

//////////////////////////////////////////////////////////////////////////////////
//// Make the NIDAQ debug panel

Function NI_MakeNIDAQPanel()

	Variable	PanX = 10
	Variable	PanY = 466+50
	Variable	PanWidth = 320
	Variable	PanHeight = 224
	Variable	RowHeight = 24
	
	NVAR	ScSc = root:MP:ScSc
	NVAR	NI_VerboseMode =			NI_VerboseMode				// Boolean: Verbose output for debugging purposes
	NVAR	NI_TransferDuringAcq
	
	DoWindow/K NIDAQPanel
	NewPanel/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) as "NIDAQ Panel"
	DoWindow/C NIDAQPanel
	
	Variable	YShift = 2
	SetDrawEnv fsize= 16,fstyle= 5,textrgb= (0,0,0),textxjust=1,textyjust=2
	DrawText PanWidth/2,YShift,"NIDAQ Information Panel"

	ValDisplay theBar,pos={4,4+RowHeight*1},size={PanWidth-4-4,rowHeight-4},title="Progress: "
	ValDisplay theBar,frame=2
	ValDisplay theBar,limits={0,1,0},barmisc={0,0},mode= 3,value=#"root:NI_Current_nSamplesRat"

	SetVariable Current_nSamplesSetVar,pos={4,4+RowHeight*2},size={PanWidth-PanWidth*1/3-4-4,rowHeight-4},title="Current number of samples: "
	SetVariable Current_nSamplesSetVar,noEdit=1,limits={0,Inf,0},frame = 0,value=root:NI_Current_nSamplesVal
	
	SetVariable Target_nSamplesSetVar,pos={4+PanWidth*2/3,4+RowHeight*2},size={PanWidth-PanWidth*2/3-4-4,rowHeight-4},title="of: "
	SetVariable Target_nSamplesSetVar,noEdit=1,limits={0,Inf,0},frame = 0,value=root:NI_nSamples

//	Button ToggleVerboseMode,pos={4,RowHeight*3},proc=NI_VerboseForButton,size={PanWidth-4-4,rowHeight},fColor=(65535,65535/2,65535/2),title="Toggle verbose mode on/off" 
	CheckBox ToggleVerboseMode,pos={4,RowHeight*3+4},proc=NI_Verbose,size={PanWidth/2-4-4,rowHeight},title="Verbose mode",value=NI_VerboseMode
	CheckBox TransferDuringAcqCheck,pos={4+PanWidth/2-50,RowHeight*3+4},proc=NI_ToggleTransferDuringAcq,size={PanWidth/2-4-4,rowHeight},title="Data transfer during acquisition",value=NI_TransferDuringAcq

	SetVariable NI_PollSpacingSetVar,pos={4,4+RowHeight*4},size={PanWidth/2-4-4,rowHeight-4},title="Poll spacing [s]: "
	SetVariable NI_PollSpacingSetVar,limits={0.2,Inf,0.1},value=root:NI_PollSpacing
	
	CheckBox AntiGhostingCheck,pos={4+PanWidth/2,RowHeight*4+4},size={PanWidth/2-4-4,rowHeight},title="Employ anti-ghosting",value=0,disable=2

	SetVariable NI_AcqGainCurrValSetVar,pos={4,4+RowHeight*5},size={PanWidth/2-4-4,rowHeight-4},title="Current range [+/- V]: "
	SetVariable NI_AcqGainCurrValSetVar,noEdit=1,frame=0,limits={-Inf,Inf,0},value=root:AcqGainCurrVal
	
	Button StopPollingButton,pos={4+PanWidth/2,RowHeight*5},size={PanWidth/2-4-4,rowHeight},proc=NI_StopPollStation,title="Stop polling"

	Button PanelToBackButton,pos={4,RowHeight*6},proc=NI_PanelToBackProc,size={PanWidth/2-4-4,rowHeight},title="Panel to back" 
	Button ResetBoardsButton,pos={4+PanWidth/2,RowHeight*6},size={PanWidth/2-4-4,rowHeight},proc=ResetBothBoards,title="Reset boards"

	CheckBox SealTestPulseCheck,pos={4,RowHeight*7+4},proc=NI_SealTestPulseProc,size={PanWidth/2-4-4,rowHeight},title="Seal test" 
	SetVariable NI_SealTestFreqSetVar,pos={4+PanWidth*2/5,4+RowHeight*7},size={PanWidth*3/5-4-4,rowHeight-4},title="Seal test freq [Hz]: "
	SetVariable NI_SealTestFreqSetVar,limits={1,Inf,1},value=root:NI_SealTestFreq,proc=NI_ChgSTProc

	Variable	i
	Variable	checkWid = 32
	i = 0
	do
		CheckBox $("Ch"+num2str(i+1)),pos={4+checkWid*i,RowHeight*8+4},proc=NI_ST_CheckProc,size={checkWid-4,rowHeight},title=num2str(i+1) ,value=1
		i += 1
	while(i<4)
	CheckBox Ch3,value=0
	CheckBox Ch4,value=0

	SetVariable NI_SealTestAmpSetVar,pos={4+PanWidth*2/5,4+RowHeight*8},size={PanWidth*3/5-4-4,rowHeight-4},title="Seal test amp [V]: "
	SetVariable NI_SealTestAmpSetVar,limits={-Inf,Inf,0.001},value=root:NI_SealTestAmp,proc=NI_ChgSTProc

End

//////////////////////////////////////////////////////////////////////////////////
//// Change sealtest amplitude or frequency

Function NI_ChgSTProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			ControlInfo/W=NIDAQPanel SealTestPulseCheck
			if (V_Value)						// If sealtest pulse is on...
				NI_SealTestPulseProc("",0)	// ... turn sealtest pulse off...
				NI_SealTestPulseProc("",1)	// ... then turn it on again.
			endif
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle sealtest on individual channels on/off

Function NI_ST_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			ControlInfo/W=NIDAQPanel SealTestPulseCheck
			if (V_Value)						// If sealtest pulse is on...
				NI_SealTestPulseProc("",0)	// ... turn sealtest pulse off...
				NI_SealTestPulseProc("",1)	// ... then turn it on again.
			endif
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle sealtest on/off

Function NI_SealTestPulseProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR		AcqInProgress = 			root:MP:AcqInProgress
	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning		// Boolean: Is a pattern running?
	NVAR		NI_SealTestFreq =		root:NI_SealTestFreq
	NVAR		NI_SealTestAmp =		root:NI_SealTestAmp

	SVAR		BoardIdStr = 				root:BoardIdStr
	Variable		i
	String		outStr = ""
	String		currWave
	WAVE		NI_OutputChannels =		root:NI_OutputChannels	// The mapping of the output channels
	NVAR		SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]
	Variable		waveDur = 1/NI_SealTestFreq*1e3					// Wave length [ms]
	Variable		pulseDur = waveDur/2
	Variable		pulseStart = waveDur/4

	NVAR		NI_VerboseMode =		root:NI_VerboseMode
	
	Variable		errorState

	if (AcqInProgress %| PatternRunning)
		CheckBox SealTestPulseCheck,win=NIDAQPanel,value=0
		print "Acquisition in progress already. Cannot start sealtest pulse right now."
		print "\tIf you did Single Send, wait until wave has been acquired and try again."
		print "\tIf pattern is running, wait until it is done or stop it before you try again."
	else
		if (checked)
			print "---  NIDAQ Panel: turning seal test pulse on ---"
			print Time()
			errorState = fDAQmx_WaveformStop(BoardIdStr)			// Stop wave generation if it is running
			if (errorState!=0)
				if (NI_VerboseMode)
					print "fDAQmx_WaveformStop threw up an error for trying to stop a waveform that is already stopped:",errorState
				endif
				NI_FlushErrorStack(NI_VerboseMode)
			endif
			// Create waves
			i = 0
			outStr = ""
			do
				ControlInfo/W=NIDAQPanel $("Ch"+num2str(i+1))
				if (V_Value)
					if (NI_VerboseMode)
						print "\t\tChannel #"+num2str(i+1)+" is ON."
					endif
					currWave = "NI_tempW"+num2str(i+1)
					ProduceWave(currWave,SampleFreq,waveDur)
					ProducePulses(currWave,pulseStart,1,pulseDur,1,NI_SealTestAmp,0,0,0,0)
					ProduceScaledWave(currWave,i+1,3)
					outStr += currWave + "," + num2str(NI_OutputChannels[i]) + ";"
				else
					if (NI_VerboseMode)
						print "\t\tChannel #"+num2str(i+1)+" is OFF."
					endif
				endif
				i += 1
			while(i<4)
			if (StrLen(outStr)==0)
				CheckBox SealTestPulseCheck,win=NIDAQPanel,value=0
				print "No output channels selected."
				Abort "No output channels selected."
			endif
			DAQmx_WaveformGen /DEV=BoardIdStr/NPRD=0/STRT=1 outStr
		else
			print "---  NIDAQ Panel: turning seal test pulse off ---"
			print Time()
			fDAQmx_WaveformStop(BoardIdStr)
			i = 0			// Once waveform has been stopped, make sure that outputs are set to zero and not to NI_SealTestAmp
			outStr = ""
			do
				if (NI_VerboseMode)
					print "\t\tSetting channel #"+num2str(i+1)+" output to zero."
				endif
				outStr += "0," + num2str(NI_OutputChannels[i]) + ";"
				i += 1
			while(i<4)		// Note to self: This affects all four channels whether they are selected or not!!!
			DAQmx_AO_SetOutputs/DEV=BoardIdStr outStr
		endif
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle NI verbose mode

Function NI_StopPollStation(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		NI_VerboseMode =			NI_VerboseMode				// Boolean: Verbose output for debugging purposes

	NVAR		NI_CounterInUse
	
	if (NI_VerboseMode)
		Print "{NI_StopPollStation} called at "+Time()
	endif

	CtrlNamedBackground NI_PollTask,stop
	
	if (NI_CounterInUse)
		NI_ReleaseCounter()
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle data transfer during acquisition on and off

Function NI_ToggleTransferDuringAcq(ctrlName,Checked) : CheckBoxControl
	String		ctrlName
	Variable		Checked

	NVAR		NI_TransferDuringAcq =			NI_TransferDuringAcq				// Boolean: Verbose output for debugging purposes

	NI_TransferDuringAcq = Checked

	if (NI_TransferDuringAcq)
		print Time()+":\tData transfer during acquisition mode on"
	else
		print Time()+":\tData transfer during acquisition mode off"
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle NI verbose mode

Function NI_Verbose(ctrlName,Checked) : CheckBoxControl
	String		ctrlName
	Variable		Checked

	NVAR		NI_VerboseMode =			NI_VerboseMode				// Boolean: Verbose output for debugging purposes

	NI_VerboseMode = Checked

	if (NI_VerboseMode)
		print Time()+":\tVerbose mode on"
	else
		print Time()+":\tVerbose mode off"
	endif

End

//////////////////////////////////////////////////////////////////////////////////

Function SetUpBoards()

	Variable	err
	
	NVAR		BoardId = 				root:BoardId
	SVAR		BoardIdStr =				root:BoardIdStr
	SVAR		BoardName =			root:BoardName
	NVAR		DemoMode = 			root:MP:DemoMode

	NVAR		NI_VerboseMode =		root:NI_VerboseMode
	
	NVAR		NI_UseExternalTrigger =	root:NI_UseExternalTrigger
	
	print "\t\tSetting up board: "+BoardName
	if (NI_VerboseMode)
		print "\t\t\tBoard number is ",BoardId
	endif
	
	//// Hardware reset of ephys board
	fDAQmx_ResetDevice(BoardIDStr)

	if  (!DemoMode)					//// Don't attempt to set up triggering if working in demo mode (i.e. a computer without a board)
		//// Set up triggering correctly
		NI_WhatTrigger()		
	else
		print "\t\t*** Working in demo mode ***"
		NI_UseExternalTrigger = 0
	endif

//	//// Reset all waveform generation
//	print "\t\t\tStopping all DA conversion..."
//	fDAQmx_WaveformStop(BoardIDStr)			// Shouldn't be necessary, but you never know...
//
//	//// Reset all scanning
//	print "\t\t\tStopping all AD conversion..."
//	fDAQmx_ScanStop(BoardIDStr)

	//// Flush error stack
	NI_FlushErrorStack(NI_VerboseMode)
	
	//// Stop the background polling
	NI_StopPollStation("")

	Print "\t\tBuilding the NIDAQ Information Panel"
	NI_MakeNIDAQPanel()
//	NI_PanelToBackProc("")

End

//////////////////////////////////////////////////////////////////////////////////
//// Move NIDAQ Information Panel to back

Function NI_PanelToBackProc(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/B NIDAQPanel
	
End

//////////////////////////////////////////////////////////////////////////////////
//// The wavenames passed to this function will be sent to the board as soon as the data acquisition
//// is begun.
//// Pass empty strings to not send a wave on that channel.

Function PrepareToSend(w1,w2,w3,w4)

	String		w1
	String		w2
	String		w3
	String		w4
	
	Variable		n1,n2,n3,n4				// number of datapoints in wave
	Variable		i
	
	String		WaveListStr = ""
	String		CommandStr = ""
	
//	SVAR		ErrStr =					root:Packages:NIDAQTools:NIDAQ_ERROR_STRING
	NVAR		AcqInProgress = 			root:MP:AcqInProgress
	NVAR		DemoMode = 			root:MP:DemoMode	

	NVAR		BoardId = 				root:BoardId
	SVAR		BoardIdStr = 				root:BoardIdStr
	SVAR		BoardName =			root:BoardName
	
	NVAR		OtherBoardId = 			root:OtherBoardId
	SVAR		OtherBoardIdStr = 		root:OtherBoardIdStr
	SVAR		OtherBoardName =		root:OtherBoardName
	
	WAVE		NI_OutputChannels =		root:NI_OutputChannels	// The mapping of the output channels
	
	NVAR		NI_VerboseMode =		root:NI_VerboseMode

	NVAR		NI_UseExternalTrigger =	root:NI_UseExternalTrigger	

	print "\t"+Time()+":\tSending\t\t"+w1+"\t"+w2+"\t"+w3+"\t"+w4

	if (!StringMatch(w1,""))
		WAVE	ww1 = $w1
		n1 = numpnts(ww1)
		w1 += ","+num2str(NI_OutputChannels[0])+";"					// ",0;"
	else
		n1 = 0
	endif

	if (!StringMatch(w2,""))
		WAVE	ww2 = $w2
		n2 = numpnts(ww2)
		w2 += ","+num2str(NI_OutputChannels[1])+";"
	else
		n2 = 0
	endif

	if (!StringMatch(w3,""))
		WAVE	ww3 = $w3
		n3 = numpnts(ww3)
		w3 += ","+num2str(NI_OutputChannels[2])+";"
	else
		n3 = 0
	endif

	if (!StringMatch(w4,""))
		WAVE	ww4 = $w4
		n4 = numpnts(ww4)
		w4 += ","+num2str(NI_OutputChannels[3])+";"
	else
		n4 = 0
	endif

	WaveListStr = w1+w2+w3+w4

	if (NI_VerboseMode)
		print "Output waves:",WaveListStr
	endif
	
	//// Set up triggering correctly
	NI_WhatTrigger()

	//// Weird thing about PCI-6713: The total number of samples (i.e. all waves to be sent taken together)
	//// cannot be an odd number. Checking this here:
	if (mod(n1+n2+n3+n4,2))
		// Add a single zero sample at the end of the waves that are used, just to make them an even number of samples
		if (!StringMatch(w1,""))
			ww1[n1] = {0}
		endif
		if (!StringMatch(w2,""))
			ww2[n2] = {0}
		endif
		if (!StringMatch(w3,""))
			ww3[n3] = {0}
		endif
		if (!StringMatch(w4,""))
			ww4[n4] = {0}
		endif
//		if (NI_VerboseMode)
		Beep;print "Total number of samples was odd (",n1+n2+n3+n4,"), so this was fixed by adding single zero samples at end of used waves."
//		endif
	else
		if (NI_VerboseMode)
			print "Total number of samples was even (",n1+n2+n3+n4,") -- no fix required."
		endif
	endif
	
	String	errStr = ""
	
	if (!(StringMatch(WaveListStr,"")))
		if(NI_UseExternalTrigger)
			DAQmx_WaveformGen/DEV=BoardIdStr/NPRD=1/TRIG={"/"+BoardIdStr+"/pfi0",1,0}/STRT WaveListStr
			if (NI_VerboseMode)
				print "trig parameter /"+BoardIdStr+"/pfi0"
			endif
		else
			DAQmx_WaveformGen/DEV=BoardIdStr/NPRD=1/TRIG={"/"+BoardIdStr+"/ai/starttrigger"}/STRT WaveListStr
		endif
		errStr = fDAQmx_ErrorString()
		if (NI_VerboseMode)
			print "Error string dump: \""+errStr,"(#chars in errStr: "+num2str(StrLen(errStr))+")\t\tWaveListStr = ",WaveListStr+"\r"
		endif
		if ((StrLen(errStr)>1) %& (!DemoMode))
			print "{PrepareToSend} Failed to send waves on Output Board."
			print "\tError on board ",BoardIdStr," was \""+errStr+"\"."
			print "\tName of this board is ",BoardName
			Abort "Could not send waves. ("+BoardName+") \rNIDAQ: "+errStr
		endif
	endif

	AcqInProgress = 1														// Flag that acquisition is now in progress

End

//////////////////////////////////////////////////////////////////////////////////
//// External trigger?

Function NI_WhatTrigger()

	NVAR		NI_UseExternalTrigger =	root:NI_UseExternalTrigger	
	SVAR		BoardIdStr = 				root:BoardIdStr

	DoWindow MultiPatch_Switchboard
	if (!(V_flag))
		Beep
		Print "Strange error! SwitchBoard panel not found."
		Print "\tAssuming triggering is internally generated..."
		NI_UseExternalTrigger = 0
	else
		ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck
		NI_UseExternalTrigger = V_value
	endif
	
	Variable trigOutFlag = fDAQmx_ConnectTerminals("/"+BoardIdStr+"/ai/StartTrigger", "/"+BoardIdStr+"/PFI6", 0)
	if (trigOutFlag)
		print "WARNING! Could not hook up output trigger properly!"
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// If you only want to send one wave, use this function.

Function SendOneWave(WaveName,Channel)

	String		WaveName
	Variable	Channel
	
	String		w1 = ""
	String		w2 = ""
	String		w3 = ""
	String		w4 = ""
	
	if (Channel==1)
		w1 = WaveName
		PrepareToSend(w1,w2,w3,w4)
	else
		if (Channel==2)
			w2 = WaveName
			PrepareToSend(w1,w2,w3,w4)
		else
			if (Channel==3)
				w3 = WaveName
				PrepareToSend(w1,w2,w3,w4)
			else
				if (Channel==4)
					w4 = WaveName
					PrepareToSend(w1,w2,w3,w4)
				endif
			endif
		endif
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Set up background task

Function PM_SetBackground()

	NVAR		NI_VerboseMode =		root:NI_VerboseMode

	if (NI_VerboseMode)
		print "Setting background task to PM_PatternHandler()..."
	endif

	SetBackground PM_PatternHandler()		// Set PatternHandler procedure

End

//////////////////////////////////////////////////////////////////////////////////
//// This function begins the data acquisition, which also triggers the waveform generation that
//// was specified in one of the above functions.

Function BeginAcquisition(WaveListStr)
	String		WaveListStr

	NVAR		DemoMode = 			root:MP:DemoMode

	NVAR		BoardId = 				root:BoardId
	SVAR		BoardIdStr = 				root:BoardIdStr
	SVAR		BoardName =			root:BoardName

	NVAR		NI_VerboseMode =		root:NI_VerboseMode

	NVAR		NI_UseExternalTrigger =	root:NI_UseExternalTrigger	
	NVAR		NI_UpdateLimit =			root:NI_UpdateLimit
	
	WAVE		NI_InputChannels =		root:NI_InputChannels

	NVAR		AcqGainCurrVal =		root:AcqGainCurrVal

	NVAR		NI_CounterInUse = 		root:NI_CounterInUse
	NVAR		NI_nSamples =			root:NI_nSamples
	
	ControlInfo/W=NIDAQPanel	AntiGhostingCheck
	Variable		AcqDummyWave = V_Value	// Boolean: Acquire dummy waves interleaved with actual waves to get rid of cross-channel ghosting
	Variable		AcqDummyChannel = 7		// Dummy waves are acquired from AcqDummyChannel+ChannelNumber

	printf "\t\t\t\tAcquiring\t"
	printf StringFromList(0,StringFromList(0,WaveListStr),",")+"\t"
	printf StringFromList(0,StringFromList(1,WaveListStr),",")+"\t"
	printf StringFromList(0,StringFromList(2,WaveListStr),",")+"\t"
	printf StringFromList(0,StringFromList(3,WaveListStr),",")+"\t"
	print " "

	//// Set up triggering correctly
	NI_WhatTrigger()

	//// Data acquisition on Input Board

	if ( (StringMatch(WaveListStr,"")) %& (!(NI_UseExternalTrigger)) )
		Print "BeginAcquisition: Empty wavelist passed.\r{When not using external trigger, you need to have at least\rone input channel selected to get output to work.}"
		Abort "BeginAcquisition: Empty wavelist passed.\r{When not using external trigger, you need to have at least\rone input channel selected to get output to work.}"
	endif
	if (NI_VerboseMode)
		print "{WaveListStr}:",WaveListStr
		if (NI_UseExternalTrigger)
			print "Triggering externally"
		else
			print "Triggering internally"
		endif
	endif
	
	// Parse wavelist string so that it works with NIDAQ Tools MX
	// This mainly accounts for communication the per-channel gain to the NIDAQmx driver
	// Also rearrange input channels according to NI_InputChannels
	Variable	i
	String	localWaveListStr = ""
	String	entryStr
	String	waveNameStr
	Variable	tempChannel
	NI_nSamples = 1
	do
		entryStr = StringFromList(i,WaveListStr,";")
		waveNameStr = StringFromList(0,entryStr,",")
		if ((!(StringMatch(waveNameStr,""))) %& (NI_nSamples==1))
			NI_nSamples = numpnts($waveNameStr)
		endif
		if (AcqDummyWave)
			Duplicate/O $waveNameStr,$("qqq_wDummy_"+num2str(i+1))
		endif
		tempChannel = str2num(StringFromList(1,entryStr,","))
		localWaveListStr += waveNameStr+","+num2str(NI_InputChannels[tempChannel])
		localWaveListStr += ","+num2str(-AcqGainCurrVal)+","+num2str(AcqGainCurrVal)
		localWaveListStr += ";"
		if (AcqDummyWave)		// Add dummy channel interleaved with actual data
			Duplicate/O $waveNameStr,$("qqq_wDummy_"+num2str(i+1))
			if (NI_VerboseMode)
				print "\tAdding interleaved dummy wave "+"qqq_wDummy_"+num2str(i+1)+" to acquisition."
			endif
			localWaveListStr += "qqq_wDummy_"+num2str(i+1)+","+num2str(AcqDummyChannel+i)
			localWaveListStr += ","+num2str(-AcqGainCurrVal)+","+num2str(AcqGainCurrVal)
			localWaveListStr += ";"
		endif
		if (NI_VerboseMode)
			print i,waveNameStr,tempChannel,"-->",NI_InputChannels[tempChannel]
		endif
		i += 1
	while(i<ItemsInList(WaveListStr,";"))
	if (NI_VerboseMode)
		print "{BoardIdStr}",BoardIdStr,"{localWaveListStr}",localWaveListStr
	endif
	
	String	errStr
	//// Set up counter to monitor progress (used in NIDAQ Panel)
	if (NI_CounterInUse)
		if (NI_VerboseMode)
			print "Whoopsie! Counter already in use -- did MultiPatch exit acquisition improperly just a second ago? If so, no worries..."
		endif
		NI_ReleaseCounter()
	endif
	DAQmx_CTR_CountEdges/DEV=BoardIdStr/STRT=1/TRIG={"/"+BoardIdStr+"/ai/StartTrigger"}/SRC="/"+BoardIdStr+"/ai/SampleClock" 0
	NI_CounterInUse = 1
	if(NI_UseExternalTrigger)
		DAQmx_Scan/DEV=BoardIdStr/TRIG={"/"+BoardIdStr+"/pfi0",1,0}/BKG/EOSH="DA_EndOfScanHook()"/ERRH="DA_ErrorHook()"/SINT=(NI_UpdateLimit)/STRT WAVES=localWaveListStr
		if (NI_VerboseMode)
			print "trig parameter /"+BoardIdStr+"/pfi0"
		endif
	else
		DAQmx_Scan/DEV=BoardIdStr/BKG/EOSH="DA_EndOfScanHook()"/ERRH="DA_ErrorHook()"/SINT=(NI_UpdateLimit)/STRT WAVES=localWaveListStr
	endif
	errStr = fDAQmx_ErrorString()
	if (NI_VerboseMode)
		print "Error string dump:\""+errStr+"\"(#chars in errStr: "+num2str(StrLen(errStr))+")\tParameters: ",BoardIdStr,WaveListStr,"DA_EndOfScanHook()","DA_ErrorHook()", "\r"
	endif
	if ((StrLen(errStr)>1) %& (!DemoMode))
		print "Failed to set up data acquisition on Input Board."
		print "\tError on board "+BoardIdStr+" was "+errStr
		print "\tName of this board is ",BoardName
		Abort "Could not acquire waves. ("+BoardIdStr+") during BeginAcquisition:\r"+errStr
	endif
	NI_StartPolling()

End

//////////////////////////////////////////////////////////////////////////////////
//// Starts the polling of the progress of the NI data acquisition

Function NI_StartPolling()

	NVAR		NI_VerboseMode
	NVAR		NI_PollSpacing

	if (NI_VerboseMode)
		print "\t\t{NI_StartPolling} was called"
	endif

	CtrlNamedBackground NI_PollTask,period=(NI_PollSpacing*60.15)
	CtrlNamedBackground NI_PollTask,proc=NI_PollStation
	CtrlNamedBackground NI_PollTask,start

End



//////////////////////////////////////////////////////////////////////////////////
//// Polls the progress of the NI data acquisition and shows this in the NIDAQ information panel

Function NI_PollStation(infoOnBackground)

	STRUCT		WMBackgroundStruct &infoOnBackground
	
	NVAR		NI_VerboseMode
	NVAR		NI_TransferDuringAcq

	SVAR		BoardIdStr = 				root:BoardIdStr
	NVAR		AcqInProgress =			root:MP:AcqInProgress				// Boolean: Is acquisition in progess?

	NVAR		NI_nSamples 							// When polling the NIDAQ board, these are the number of samples we expect when done.
	NVAR		NI_Current_nSamplesVal
	NVAR		NI_Current_nSamplesRat

	Variable		StopSignal = 0							// 1 means stop, 0 means keep going

	NI_Current_nSamplesVal = fDAQmx_CTR_ReadCounter(BoardIdStr,0)	// Read sample counter
	NI_Current_nSamplesRat = NI_Current_nSamplesVal/NI_nSamples		// Update progress bar
	
	if (NI_VerboseMode)
		Print "\t{NI_PollStation} invoked at "+Time()+" -- current number of samples "+num2str(NI_Current_nSamplesVal)+" -- target "+num2str(NI_nSamples)
	endif
	
	if (NI_TransferDuringAcq)
		NI_CopyWavesToTemp()
	endif
	
	if (!(AcqInProgress))
		StopSignal = 1
		if (NI_VerboseMode)
			Print "\t{NI_PollStation} says: Clean exit on end of acquisition..."
		endif
		NI_ReleaseCounter()
	endif
		
	return		StopSignal
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Update temp waves

Function NI_CopyWavesToTemp()

	Variable	i
	
	String		ToWaveName
	String		SafeKeepWaveName
	NVAR		RpipGenerated =			root:MP:RpipGenerated

	WAVE		WaveWasAcq =				root:MP:FixAfterAcq:WaveWasAcq
	WAVE/T		WaveNames =				root:MP:FixAfterAcq:WaveNames

	NVAR		NI_nSamples 							// When polling the NIDAQ board, these are the number of samples we expect when done.

	NVAR		NI_VerboseMode
	
	NVAR		NI_nSamples 							// When polling the NIDAQ board, these are the number of samples we expect when done.
	NVAR		NI_Current_nSamplesVal

	if (NI_VerboseMode)
		print "{NI_CopyWavesToTemp} called with WaveWasAcq as follows:",WaveWasAcq
	endif

	DelayUpdate
	i = 0
	do
		if (WaveWasAcq[i])																		// If wave was acquired...
			ToWaveName = "Temp"+num2str(i+1)
			SafeKeepWaveName = "Temp2_"+num2str(i+1)
			Duplicate/O $ToWaveName,$SafeKeepWaveName
			Duplicate/O $(WaveNames[i]),$ToWaveName			// Copy the entire wave to the template wave shown in the input wave plot...
		endif
		i += 1
	while (i<4)
	DA_FixTempWavesDuringAcq()
	if (NI_Current_nSamplesVal<NI_nSamples)						// This is horrendous code, but it gives that appearance of graded transfer of data on the screen
		i = 0
		do
			if (WaveWasAcq[i])																		// If wave was acquired...
				ToWaveName = "Temp"+num2str(i+1)
				SafeKeepWaveName = "Temp2_"+num2str(i+1)
				WAVE source = $SafeKeepWaveName
				WAVE dest = $ToWaveName
				dest[NI_Current_nSamplesVal-1,NI_nSamples-1] = source[p]
			endif
			i += 1
		while (i<4)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Release counter

Function NI_ReleaseCounter()

	NVAR		NI_VerboseMode
	NVAR		NI_CounterInUse = 		root:NI_CounterInUse
	SVAR		BoardIdStr = 				root:BoardIdStr

	Variable		catchCounterError
	catchCounterError = fDAQmx_CTR_Finished(BoardIdStr,0)
	NI_CounterInUse = 0
	if (NI_VerboseMode)
		Print "\t{NI_ReleaseCounter} reports value:",catchCounterError
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Trap for NIDAQ error during data acquisition.

Function DA_ErrorHook()

	NVAR	AcqInProgress =					root:MP:AcqInProgress
	SVAR	MasterName =					root:MP:MasterName
	
	SVAR		BoardName =				root:BoardName

	NVAR		BoardId_Input = 				root:BoardId_Input
	NVAR		BoardId_Output = 			root:BoardId_Output
	SVAR		BoardName_Input =			root:BoardName_Input
	SVAR		BoardName_Output =			root:BoardName_Output

	AcqInProgress = 0;						// Flag that data acquisition is no longer in progress

	Beep
	print "DA_ErrorHook: NIDAQ board data acquisition failed"
	String		errStr = fDAQmx_ErrorString()
	print "\tError was:",errStr
	Abort "Error during data acquisition. ("+MasterName+" DA_EndOfScanHook)"

End


//////////////////////////////////////////////////////////////////////////////////
//// Flush NIDAQ Tools MX error stack

Function NI_FlushErrorStack(Verbose)
	Variable		Verbose

	String		dummyStr
	if (Verbose)
		Print "Flushing error stack... these errors may be irrelevant."
	endif
	Variable		i
	i = 0
	do
		dummyStr = fDAQmx_ErrorString()
		if (Verbose)
			print	"\t\t\t",i+1,dummyStr
		endif
		i +=  1
	while(i<5)

End

