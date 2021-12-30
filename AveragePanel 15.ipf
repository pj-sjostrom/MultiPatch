#pragma rtGlobals=1		// Use modern global access method.

//// By Jesper Sjostrom
//// Adapted to Igor Pro Ver. 4.0 on 01-01-16
//// Adapted to Igor Pro Ver. 5.0 on 04-01-26
//// Not using SNUtilities any longer 04-04-26 (Assuming JS_num2digstr is available in other procdure)
//// 2008-10-17: Now using JespersTools_v03 instead, calling JT_num2digstr instead of JS_num2digstr
//// 2009-01-16: Adapted for use with Pos_Matrix of MultiPatch.
//// 2012-07-19: Made use of Pos_Matrix optional via checkbox.

Menu "Macros"
	"Initiate the Average panel", InitAveragePanel()
	"-"
end

////////////////////////////////////////////////////////////////////////////////////////////////
//// Quickly set all panel values to desired numericals

Function avePset(c1,c2,c3,c4,s1,s2,s3,s4)
	Variable		c1,c2,c3,c4,s1,s2,s3,s4
	
	Make/O		cW = {c1,c2,c3,c4}
	Make/O		sW = {s1,s2,s3,s4}
	
	SVAR		Ch1InName = root:AvePanel:Ch1InName
	SVAR		Ch2InName = root:AvePanel:Ch2InName
	SVAR		Ch3InName = root:AvePanel:Ch3InName
	SVAR		Ch4InName = root:AvePanel:Ch4InName

	SVAR		Ch1OutName = root:AvePanel:Ch1OutName
	SVAR		Ch2OutName = root:AvePanel:Ch2OutName
	SVAR		Ch3OutName = root:AvePanel:Ch3OutName
	SVAR		Ch4OutName = root:AvePanel:Ch4OutName
	
	NVAR		Ch1StartAt = root:AvePanel:Ch1StartAt 
	NVAR		Ch2StartAt = root:AvePanel:Ch2StartAt 
	NVAR		Ch3StartAt = root:AvePanel:Ch3StartAt 
	NVAR		Ch4StartAt = root:AvePanel:Ch4StartAt 
	
	Variable	i
	i = 0
	do
		SVAR		ChInName = $("root:AvePanel:Ch"+num2str(i+1)+"InName")
		SVAR		ChOutName = $("root:AvePanel:Ch"+num2str(i+1)+"OutName")
		NVAR		ChStartAt = $("root:AvePanel:Ch"+num2str(i+1)+"StartAt")
		ChInName = "Cell_"+JT_num2digstr(2,cW[i])+"_"
		ChOutName = "Cell_"+JT_num2digstr(2,cW[i])+"_average"
		ChStartAt = sW[i]
		i += 1
	while(i<4)

End

Macro InitAveragePanel()

	Variable		i
	String		CommandStr
	Variable		YShift
	Variable		Sp = 44
	
	Variable		ScSc = ScreenResolution/75

	Variable		Xpos = 500//592
	Variable		Ypos = 400//398
	Variable		Width = 420
	Variable		Height = 286+18*2

	Make/O/N=(4) ChannelColor_R,ChannelColor_G,ChannelColor_B
	// Yellow, blue, red, green, as on the Tektronix TDS2004B digital oscilloscope
	ChannelColor_R = {59136,	26880,	65280,	00000}
	ChannelColor_G = {54784,	43776,	29952,	65535}
	ChannelColor_B = {01280,	64512,	65280,	00000}

	//// Create folder with variables
	NewDataFolder/O root:AvePanel

	DoWindow Averaging_Control
	if (V_Flag)
		print "Panel already exists -- reading old parameter values."
		DoWindow/K Averaging_Control
	else
		Variable/G		root:AvePanel:NumRepsToAve = 10
		Variable/G		root:AvePanel:nDigs = 4
		
		Variable/G		root:AvePanel:WinStart = 720							// Start of window to be zoomed in on [ms]
		Variable/G		root:AvePanel:WinWidth = 70							// Width of window [ms]
		Variable/G		root:AvePanel:WinSkip = 833							// Skip between windows [ms]
		Variable/G		root:AvePanel:WinNext = 0								// Skip between pulses [ms]
		Variable/G		root:AvePanel:WinBefore = 8								// Skip between pulses [ms]
		
		String/G		root:AvePanel:Ch1InName = "Cell_01_"
		String/G		root:AvePanel:Ch2InName = "Cell_02_"
		String/G		root:AvePanel:Ch3InName = "Cell_03_"
		String/G		root:AvePanel:Ch4InName = "Cell_04_"
		
		String/G		root:AvePanel:Ch1OutName = "Cell_01_average"
		String/G		root:AvePanel:Ch2OutName = "Cell_02_average"
		String/G		root:AvePanel:Ch3OutName = "Cell_03_average"
		String/G		root:AvePanel:Ch4OutName = "Cell_04_average"
		
		Variable/G		root:AvePanel:Ch1StartAt = 1
		Variable/G		root:AvePanel:Ch2StartAt = 1
		Variable/G		root:AvePanel:Ch3StartAt = 1
		Variable/G		root:AvePanel:Ch4StartAt = 1

		Make/O/N=(4) AP_ChannelColor_R,AP_ChannelColor_G,AP_ChannelColor_B
		// Yellow, blue, red, green, as on the Tektronix TDS2004B digital oscilloscope
		AP_ChannelColor_R = {59136,	26880,	65280,	00000}
		AP_ChannelColor_G = {54784,	43776,	29952,	65535}
		AP_ChannelColor_B = {01280,	64512,	65280,	00000}

	endif

	PauseUpdate; Silent 1		// building window...
	NewPanel/K=1/W=(Xpos,Ypos,Xpos+Width,Ypos+Height) as "Control the Averaging of Waves"
	DoWindow/C Averaging_Control
	ModifyPanel/W=Averaging_Control fixedSize=1
//	ShowTools
	SetDrawLayer UserBack
	SetDrawEnv LineThick=1
	SetDrawEnv fillfgc= (65535,65533,32768)
	DrawRect 4,2,Width-4,2+26
	SetDrawEnv fsize= 14,fstyle= 3
	DrawText 160,23,"Average Waves"
	
	YShift = 32
		
	Button GoButton,pos={4,YShift},size={204,18*2-2},proc=StartTheAveraging,title="Go!"

	SetVariable NumRepSetVar,pos={4,YShift+18*2},size={204,17},title="Number of repetitions:"
	SetVariable NumRepSetVar,limits={0,Inf,1},value=root:AvePanel:NumRepsToAve
//	SetVariable NDigSetVar,pos={212,YShift},size={204,17},title="Suffix number of digits:"
//	SetVariable NDigSetVar,limits={1,10,1},value=root:AvePanel:nDigs
	
	Button TakeMPButton,pos={212,YShift+18*0},size={204,17},proc=TakeMPProc,title="Take from Data Acquisition"
	Button TakeDatAnButton,pos={212,YShift+18*1},size={204,17},proc=TakeDatAnProc,title="Take from Data Analysis"
	CheckBox LoadWavesCheck,pos={212,YShift+18*2},size={100,20},title="Data from home",value=1,proc=DataSourceCheckProc
	CheckBox LoadWavesAnalysisFolderCheck,pos={212+100+4,YShift+18*2},size={204,20},title="from data folder",value=0,proc=DataSourceCheckProc
	Button DisplayButton,pos={4,YShift+18*3},size={100,17},proc=DisplayButtonProc,title="(Re)display"
	Button WinCloseButton,pos={4+104,YShift+18*3},size={100,17},proc=WinCloseProc,title="Close"
	CheckBox DispOutput,pos={212,YShift+18*3},size={204,20},title="Display averages",value=1
	Button RiseTimeButton,pos={212+204*2/3,YShift+18*3},size={204/3,17},proc=RiseTimeProc,title="Risetime"

	CheckBox WinCheck,pos={4,YShift+18*4},size={70,20},title="Zoom in",value=1
	SetVariable WinStartSetVar,pos={4+70+4,YShift+18*4+1},size={120,17},title="Start [ms]:"
	SetVariable WinStartSetVar,limits={0,Inf,5},value=root:AvePanel:WinStart
	SetVariable WinWidthSetVar,pos={4+70+4+120+4,YShift+18*4+1},size={110,17},title="Width:"
	SetVariable WinWidthSetVar,limits={0,Inf,10},value=root:AvePanel:WinWidth
	SetVariable WinSkipSetVar,pos={4+70+4+120+4+110+4,YShift+18*4+1},size={100,17},title="Skip:"
	SetVariable WinSkipSetVar,limits={0,Inf,1},value=root:AvePanel:WinSkip
	SetVariable WinNextSetVar,pos={212,YShift+18*5+1},size={104,17},title="Next:"
	SetVariable WinNextSetVar,limits={0,Inf,1},value=root:AvePanel:WinNext
	SetVariable WinBeforeSetVar,pos={4+70+4+120+4+110+4,YShift+18*5+1},size={100,17},title="Before:"
	SetVariable WinBeforeSetVar,limits={-Inf,Inf,1},value=root:AvePanel:WinBefore
	CheckBox MatrixZoomCheck,pos={4,YShift+18*5},size={70,20},title="Use matrix for zooming in",value=1

	YShift = 32+18*4

	variable dd = 1.25
	variable rr = 65535/dd
	variable gg = 65535/dd
	variable bb = 65535/dd
	String	WorkStr

	i = 0
	do
		
		SetDrawEnv LineThick=1,fillfgc=(rr,gg,bb)
//		SetDrawEnv	linefgc=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
		DrawRect 4,YShift+Sp*(i+1)-3,Width-4, YShift+Sp*(i+1)+Sp-7
	
		SetDrawEnv LineThick=1,fillfgc=(rr,gg,bb)
		SetDrawEnv	linefgc=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
		DrawRect 4+1,YShift+Sp*(i+1)-3+1,Width-4-1, YShift+Sp*(i+1)+Sp-7-1
	
		CommandStr = "Ch"+num2str(i+1)+"UseCheckBox"
		CheckBox $CommandStr,pos={8,YShift+Sp*(i+1)},labelBack=(rr,gg,bb),size={120,17},title="Channel #"+num2str(i+1),value=1
		
		CommandStr = "Ch"+num2str(i+1)+"OutNameSetVar"
		WorkStr = "Ch"+num2str(i+1)+"OutName"
		SetVariable $CommandStr,pos={132,YShift+Sp*(i+1)},labelBack=(rr,gg,bb),size={280,17},title="Ch"+num2str(i+1)+" average:",value=root:AvePanel:$WorkStr
		
		CommandStr = "Ch"+num2str(i+1)+"InNameSetVar"
		WorkStr = "Ch"+num2str(i+1)+"InName"
		SetVariable $CommandStr,pos={8,YShift+Sp*(i+1)+18},labelBack=(rr,gg,bb),size={250,17},title="Ch"+num2str(i+1)+" in basename:",value=root:AvePanel:$WorkStr

		CommandStr = "Ch"+num2str(i+1)+"StartAtSetVar"
		WorkStr = "Ch"+num2str(i+1)+"StartAt"
		SetVariable $CommandStr,pos={262,YShift+Sp*(i+1)+18},labelBack=(rr,gg,bb),size={150,17},title="Start at:",value=root:AvePanel:$WorkStr

		i += 1
	while (i<4)	

EndMacro

Function DataSourceCheckProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	if (StringMatch(ctrlName,"LoadWavesCheck"))
		CheckBox  LoadWavesAnalysisFolderCheck,win=Averaging_Control,value=0
	endif
	
	if (StringMatch(ctrlName,"LoadWavesAnalysisFolderCheck"))
		CheckBox  LoadWavesCheck,win=Averaging_Control,value=0
	endif

	return 0
End


Function StartTheAveraging(ctrlName) : ButtonControl
	String ctrlName

	Variable i
	Variable j
	Variable k

	String WorkStr

	String CurrentInputWave
	String CurrentOutputWave
	
	NVAR		NumRepsToAve = 		root:AvePanel:NumRepsToAve
	NVAR		nDigs = 				root:AvePanel:nDigs

	SVAR		Ch1InName = 			root:AvePanel:Ch1InName
	SVAR		Ch2InName = 			root:AvePanel:Ch2InName
	SVAR		Ch3InName = 			root:AvePanel:Ch3InName
	SVAR		Ch4InName = 			root:AvePanel:Ch4InName
		
	SVAR		Ch1OutName = 			root:AvePanel:Ch1OutName
	SVAR		Ch2OutName = 			root:AvePanel:Ch2OutName
	SVAR		Ch3OutName = 			root:AvePanel:Ch3OutName
	SVAR		Ch4OutName = 			root:AvePanel:Ch4OutName

	NVAR		Ch1StartAt = 			root:AvePanel:Ch1StartAt
	NVAR		Ch2StartAt = 			root:AvePanel:Ch2StartAt
	NVAR		Ch3StartAt = 			root:AvePanel:Ch3StartAt
	NVAR		Ch4StartAt = 			root:AvePanel:Ch4StartAt
	
	Make/O/T/N=(4) InNames
	InNames = {Ch1InName,Ch2InName,Ch3InName,Ch4InName}
	Make/O/T/N=(4) OutNames
	OutNames = {Ch1OutName,Ch2OutName,Ch3OutName,Ch4OutName}
	Make/O/N=(4) StartAt
	StartAt = {Ch1StartAt,Ch2StartAt,Ch3StartAt,Ch4StartAt}

	Make/O/T/N=(4) waveListWave
	waveListWave = ""
	String	dummyStr

	print Time()+": Starting the averaging."
		
	i = 0
	do

		WorkStr = "Ch"+num2str(i+1)+"UseCheckBox"
		ControlInfo/W=Averaging_Control $WorkStr
		If (V_value)

			CurrentInputWave = InNames[i]+JT_num2digstr(nDigs,StartAt[i])
			MakeSureWaveExists(CurrentInputWave)
			CurrentOutputWave = OutNames[i]
			Duplicate/O $CurrentInputWave $CurrentOutputWave
			WAVE	w1 = $CurrentOutputWave
			w1 = 0
			j = 1
			do
				CurrentInputWave = InNames[i]+JT_num2digstr(nDigs,StartAt[i]+(j-1))
				MakeSureWaveExists(CurrentInputWave)
				print "\t( Cond , Rep ) = (",i,",",j,") -- ", CurrentInputWave," & ", CurrentOutputWave
				WAVE	w1 = $CurrentOutputWave
				WAVE	w2 = $CurrentInputWave
				w1 = w1+w2
				waveListWave[i] += CurrentInputWave+","
				j += 1
			while(j<=NumRepsToAve)
			WAVE	w1 = $CurrentOutputWave
			w1 /= NumRepsToAve
			Note/K w1,Time()+"; "+Date()+";"
//			PathInfo home
//			if (V_flag)
//				Note w1,S_path
//			endif
			dummyStr = waveListWave[i]
			Note w1,dummyStr[0,StrLen(dummyStr)-2]

		endif
		print "\t------------------------"
		
		i += 1
	while (i<4)

	ControlInfo/W=Averaging_Control DispOutput
	if (V_value)
		DoDisplay()
	endif
	
	KillWaves/Z InNames,OutNames,StartAt
	
	print Time()+": Averaging completed."

End



/////////////////////////////////////////////////////////////////////////////////

Function MakeSureWaveExists(Name)
	String		Name
	
	// LoadWavesAnalysisFolderCheck HERE!!!

	if  (!(exists(Name)==1))
		ControlInfo/W=Averaging_Control LoadWavesCheck
		if (V_value)
			Print "\t\tCan't find wave in RAM -- loading from home: \""+Name+"\""
			LoadWave/Q/P=home/O Name
		else
			ControlInfo/W=Averaging_Control LoadWavesAnalysisFolderCheck
			if (V_value)
				Print "\t\tCan't find wave in RAM -- loading from data folder: \""+Name+"\""
				LoadWave/Q/P=SymbPath/O Name
			endif
		endif
	endif

	if (!(exists(Name)==1))
		Print "Cannot find the wave \""+Name+"\"."
		Abort "Cannot find the wave \""+Name+"\"."
	endif

End

/////////////////////////////////////////////////////////////////////////////////

Function DisplayButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	DoDisplay()
	
End

/////////////////////////////////////////////////////////////////////////////////

Function AP_stepleftrightproc(ctrlName) : ButtonControl
	String		ctrlName

	GetAxis/Q bottom
	Variable	x1 = V_min
	Variable	x2 = V_max
	Variable	stepSize = 0.83333
	
	if (StringMatcH(ctrlName,"leftButton"))
		x1 -= stepSize
		x2 -= stepSize
	else
		x1 += stepSize
		x2 += stepSize
	endif
	
	SetAxis Bottom,x1,x2

End

/////////////////////////////////////////////////////////////////////////////////

Function DoDisplay()

	Variable	i,j,k
	String		WorkStr
	String		CurrentOutputWave
	Variable	First = 1

	String		WinName = "WinZoom_"
	Variable	WinX = 8
	Variable	WinY = 48
	Variable	WinDX = 480	// 270		//480
	Variable	WinDY = 150
	Variable	WinDXSkip = 16
	Variable	WinDYSkip = 32
	Variable	Meaningful												// Flag: Need at least two channels checked for the below plots to be meaningful
	Variable	DMaxMin
	
	SVAR		Ch1OutName = 			root:AvePanel:Ch1OutName
	SVAR		Ch2OutName = 			root:AvePanel:Ch2OutName
	SVAR		Ch3OutName = 			root:AvePanel:Ch3OutName
	SVAR		Ch4OutName = 			root:AvePanel:Ch4OutName

	NVAR		WinStart = 				root:AvePanel:WinStart							// Start of window to be zoomed in on [ms]
	NVAR		WinWidth = 			root:AvePanel:WinWidth							// Width of window [ms]
	NVAR		WinSkip = 				root:AvePanel:WinSkip							// Skip between windows [ms]
	NVAR		WinNext = 				root:AvePanel:WinNext							// Next pulse [ms]
	NVAR		WinBefore =			root:AvePanel:WinBefore						// Start of window before peak of EPSP when using Pos_Matrix

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		AP_ChannelColor_R = AP_ChannelColor_R
	WAVE		AP_ChannelColor_G = AP_ChannelColor_G
	WAVE		AP_ChannelColor_B = AP_ChannelColor_B

	Variable	Pos_Matrix_exists = 0
	if (Exists("root:MP:PM_Data:Pos_Matrix"))
		WAVE/Z		Pos_Matrix =	root:MP:PM_Data:Pos_Matrix			// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]
		Pos_Matrix_exists = 1
	endif

	ControlInfo/W=Averaging_Control MatrixZoomCheck	
	if (V_Value==0)
		Pos_Matrix_exists = 0
	endif


	//// Close all graph windows pertaining to the average panel
	DoWinClose()

	Make/O/T/N=(4) OutNamesTemp
	OutNamesTemp = {Ch1OutName,Ch2OutName,Ch3OutName,Ch4OutName}
	
	
	//// Make the single average graph
	i = 0
	do

		WorkStr = "Ch"+num2str(i+1)+"UseCheckBox"
		ControlInfo/W=Averaging_Control $WorkStr
		If (V_value)

			CurrentOutputWave = OutNamesTemp[i]
			if (!(exists(CurrentOutputWave)==1))
				Abort "The wave \""+CurrentOutputWave+"\" does not appear to exist. You must do the averaging first of all."
			endif
			if (First)
				DoWindow/K TheAverages
				Display/W=(500,66,900,366) $CurrentOutputWave as "Averages"
				DoWindow/C TheAverages
				First = 0
			else
				AppendToGraph	$CurrentOutputWave
//				ModifyGraph rgb($CurrentOutputWave)=(65535*(3-i)/3,0,65535*i/3)
			endif
			ModifyGraph RGB($CurrentOutputWave)=(AP_ChannelColor_R[i],AP_ChannelColor_G[i],AP_ChannelColor_B[i])

		endif
		
		i += 1
	while (i<4)
	ModifyGraph lsize=1
	Legend
	Button WinCloseButton,pos={0,1},size={18,18},proc=WinCloseProc,title="X",fSize=11,font="Arial"
	Button leftButton,pos={22,1},size={18,18},proc=ap_stepleftrightproc,title="<",fSize=10,font="Arial"
	Button rightButton,pos={22+22,1},size={18,18},proc=ap_stepleftrightproc,title=">",fSize=10,font="Arial"
	
	//// Make the zoom-in windows
	Meaningful = 0
	i = 0
	do
		WorkStr = "Ch"+num2str(i+1)+"UseCheckBox"
		ControlInfo/W=Averaging_Control $WorkStr
		if (V_value)
			Meaningful += 1
		endif
		i += 1
	while (i < 4)
	
	Variable	xStart,xEnd
	
	ControlInfo/W=Averaging_Control WinCheck
	if ( (V_value) %& (Meaningful > 1) )

		k = 0
		do
		
			i = 0															// Presyn
			do
				
				WorkStr = "Ch"+num2str(i+1)+"UseCheckBox"
				ControlInfo/W=Averaging_Control $WorkStr
				if (V_value)
				
					if (Pos_Matrix_exists)
						xStart = Pos_Matrix[i][0]+(WinNext*k-WinBefore)/1000
						xEnd = Pos_Matrix[i][0]+(WinNext*k-WinBefore+WinWidth)/1000
					else
						xStart = (WinStart+WinSkip*i+WinNext*k)/1000
						xEnd = (WinStart+WinWidth+WinSkip*i+WinNext*k)/1000
					endif
	
					CurrentOutputWave = OutNamesTemp[i]
					DoWindow/K $(WinName+num2str(i+1)+"_"+num2str(k+1))
					Display/W=(WinX+(WinDX+WinDXSkip)*k,WinY+(WinDY+WinDYSkip)*i,WinX+WinDX+(WinDX+WinDXSkip)*k,WinY+WinDY+(WinDY+WinDYSkip)*i)/L $CurrentOutputWave as "Zoom-in: Channel #"+num2str(i+1)+", Pulse #"+num2str(k+1)
					DoWindow/C $(WinName+num2str(i+1)+"_"+num2str(k+1))
					ModifyGraph RGB($CurrentOutputWave)=(AP_ChannelColor_R[i],AP_ChannelColor_G[i],AP_ChannelColor_B[i])
					DMaxMin = 0
					j = 0													// Postsyn
					do
						WorkStr = "Ch"+num2str(j+1)+"UseCheckBox"
						ControlInfo/W=Averaging_Control $WorkStr
						if ( (V_value) %& (i != j) )
							CurrentOutputWave = OutNamesTemp[j]
							AppendToGraph/R $CurrentOutputWave
							ModifyGraph RGB($CurrentOutputWave)=(AP_ChannelColor_R[j],AP_ChannelColor_G[j],AP_ChannelColor_B[j])
							WaveStats/Q/R=(xStart,xEnd) $CurrentOutputWave
							if ( (V_max-V_min) > DMaxMin )
								DMaxMin = V_max-V_min
							endif
						endif
						j += 1
					while (j < 4)
					SetAxis bottom,xStart,xEnd
					SetAxis right,0,0+DMaxMin
					j = 0													// Shift postsyn waves to same y position
					do
						WorkStr = "Ch"+num2str(j+1)+"UseCheckBox"
						ControlInfo/W=Averaging_Control $WorkStr
						if ( (V_value) %& (i != j) )
							CurrentOutputWave = OutNamesTemp[j]
							WaveStats/Q/R=(xStart,xEnd) $CurrentOutputWave
							ModifyGraph offset($CurrentOutputWave)={0,0-V_min}
						endif
						j += 1
					while (j < 4)
					ModifyGraph lsize=2
					//Legend
					Button WinCloseButton,pos={0,1},size={18,18},proc=WinCloseProc,title="X",fSize=11,font="Arial"
	
				endif // Presyn wave is in use?
	
				i += 1
			while (i < 4)

			k += inf
		while (k < 2)

	endif

	// Special case when using the Averaging Panel to analyze data off line
//	ControlInfo/W=Averaging_Control LoadWavesAnalysisFolderCheck
//	if (V_value)
//		DoWindow/K WinZoom_2_1
//		MoveWindow/W=WinZoom_1_1 8,66,480,366
//	endif

end

/////////////////////////////////////////////////////////////////////////////////

Function WinCloseProc(ctrlName) : ButtonControl
	String ctrlName

	DoWinClose()

end
	
Function DoWinClose()

	String		WinName = "WinZoom_"
	Variable	i,j
	
	DoWindow/K TheAverages
	i = 0
	do
		j = 0
		do
			DoWindow/K $(WinName+num2str(i+1)+"_"+num2str(j+1))
			j += 1
		while (j < 2)
		i += 1
	while (i < 4)

end

/////////////////////////////////////////////////////////////////////////////////
// Figure out rise time based on top graph

Function RiseTimeProc(ctrlName) : ButtonControl
	String ctrlName
	
	String		ListOfWaves = WaveList("*",";","WIN:")
	String		currWave

	if(FindListItem("RiseTimeY",ListOfWaves,";")>-1)
		RemoveFromGraph RiseTimeY
		DoUpdate
		ListOfWaves = WaveList("*",";","WIN:")
	endif	

	Variable	nItems = ItemsInList(ListOfWaves,";")
	
	Variable	i
	
	GetAxis/Q bottom
	Variable	xmin = V_min
	Variable	xmax = V_max

	Variable	baseLine
	Variable	bWidth = 0.007
	Variable	peak,peakloc
	Variable	x80,x20,theMin
	
	Make/O/N=(4*nItems) RiseTimeY,RiseTimeX
	RiseTimeY = NaN
	RiseTimeX = NaN
	AppendToGraph/R RiseTimeY vs RiseTimeX
	ModifyGraph mode(RiseTimeY)=3,marker(RiseTimeY)=8,RGB(RiseTimeY)=(0,0,0)
	
	Print "------------- Analyzing graph for risetimes."
	Print "\tFound the following traces: ",ListOfWaves
	
	i = 0
	do
		currWave = StringFromList(i,ListOfWaves,";")
		WAVE	w = $currWave
		WaveStats/Q/R=(xmin,xmax) w
		if (V_max>0)
			print "\t\t(Skipping wave ",currWave," as it appears to be the presynaptic wave.)"
		else
			theMin = V_min
			print "Analyzing wave ",currWave
			baseLine = Mean(w,xmin,xmin+bWidth)
			RiseTimeY[i*4+0] = baseLine-theMin
			RiseTimeX[i*4+0] = xmin+bWidth
			peak = V_max-baseLine
			peakloc = V_maxloc
			RiseTimeY[i*4+1] = V_max-theMin
			RiseTimeX[i*4+1] = V_maxloc
		 	FindLevel/Q/R=(peakloc,xmin) w,0.8*peak+baseLine
		 	if (!V_flag)
		 		x80 = V_LevelX
				RiseTimeY[i*4+2] = 0.8*peak+baseLine-theMin
				RiseTimeX[i*4+2] = x80
			 	FindLevel/Q/R=(peakloc,xmin) w,0.2*peak+baseLine
			 	if (!V_flag)
			 		x20 = V_LevelX
					RiseTimeY[i*4+3] = 0.2*peak+baseLine-theMin
					RiseTimeX[i*4+3] = x20
			 		print "\t20%-80% risetime: ",(x80-x20)*1000," ms, with a peak of ",peak*1000," mV"
			 	else
			 		print "\tFail -- Could not find 20% crossing point."
			 	endif
		 	else
		 		print "\tFail -- Could not find 80% crossing point."
		 	endif
		endif
		i += 1
	while (i<nItems)

End

/////////////////////////////////////////////////////////////////////////////////

Function TakeDatAnProc(ctrlName) : ButtonControl
	String ctrlName

	// From DatAn
	NVAR		NumRepsToAve = 		root:AvePanel:NumRepsToAve

	SVAR		Ch1InName = 			root:AvePanel:Ch1InName
	SVAR		Ch2InName = 			root:AvePanel:Ch2InName
	SVAR		Ch3InName = 			root:AvePanel:Ch3InName
	SVAR		Ch4InName = 			root:AvePanel:Ch4InName
		
	SVAR		Ch1OutName = 			root:AvePanel:Ch1OutName
	SVAR		Ch2OutName = 			root:AvePanel:Ch2OutName
	SVAR		Ch3OutName = 			root:AvePanel:Ch3OutName
	SVAR		Ch4OutName = 			root:AvePanel:Ch4OutName

	NVAR		Ch1StartAt = 			root:AvePanel:Ch1StartAt
	NVAR		Ch2StartAt = 			root:AvePanel:Ch2StartAt
	NVAR		Ch3StartAt = 			root:AvePanel:Ch3StartAt
	NVAR		Ch4StartAt = 			root:AvePanel:Ch4StartAt

	NVAR		WinStart = 				root:AvePanel:WinStart							// Start of window to be zoomed in on [ms]
	NVAR		ExtraBaseLinePulseDispl =		root:DatAn:ExtraBaseLinePulseDispl

	// From DatAn
	SVAR		PreBase =		 		root:DatAn:PreBase
	SVAR		PostBase = 				root:DatAn:PostBase

	NVAR		PreStart = root:DatAn:PreStart								// Where presynaptic waves start
	NVAR		PostStart = root:DatAn:PostStart								// Where postsynaptic waves start
	NVAR		ExtraBaseline = root:DatAn:ExtraBaseline					// Number of waves in the additional baseline
	
	NVAR		ExtraBaseLineSkipPre = root:DatAn:ExtraBaseLineSkipPre	// Also take into account the gap between extra baseline and baseline 1, if there is one
	NVAR		ExtraBaseLineSkipPost = root:DatAn:ExtraBaseLineSkipPost

	NVAR		PulseDispl =			root:DatAn:PulseDispl
	
	NVAR		SealTestDur = root:DatAn:SealTestDur						// Duration of sealtest
	NVAR		SealTestPad1 = root:DatAn:SealTestPad1						// Padding of sealtest -- before
	NVAR		SealTestPad2 = root:DatAn:SealTestPad2						// Padding of sealtest -- after

	Variable 	AddTime = SealTestPad1+SealTestDur+SealTestPad2						// Time the sealtest requires in total

	Variable	ExtraBaselineCheck = 0
	
	DoWindow MultiPatch_DatAn
	if (V_Flag)

		ControlInfo/W=MultiPatch_DatAn UseExtraBaselineCheck
		ExtraBaselineCheck = V_value

		Ch1InName = PreBase
		Ch1OutName = PreBase+"average"

		Ch2InName = PostBase
		Ch2OutName = PostBase+"average"
		
		if (ExtraBaselineCheck)
			if (WinStart==PulseDispl+AddTime)
				WinStart = ExtraBaseLinePulseDispl+AddTime
				Ch1StartAt = PreStart
				Ch2StartAt = PostStart
				Print "Starting at Extra baseline. Click again to toggle."
			else
				WinStart = PulseDispl+AddTime
				Ch1StartAt = PreStart+(ExtraBaseline+ExtraBaseLineSkipPre)
				Ch2StartAt = PostStart+(ExtraBaseline+ExtraBaseLineSkipPost)
				Print "Starting at Baseline 1. Click again to toggle."
			endif
		else
			WinStart = PulseDispl+AddTime
			Ch1StartAt = PreStart
			Ch2StartAt = PostStart
			Print "Starting at Baseline 1. Click again to toggle."
		endif

		CheckBox LoadWavesCheck,value=0
		CheckBox LoadWavesAnalysisFolderCheck,value=1

		CheckBox Ch1UseCheckBox,value=1
		CheckBox Ch2UseCheckBox,value=1
		CheckBox Ch3UseCheckBox,value=0
		CheckBox Ch4UseCheckBox,value=0
	else
		Abort "Cannot find MP Data Analysis panel!"
	endif

End

/////////////////////////////////////////////////////////////////////////////////

Function TakeMPProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		NumRepsToAve = 		root:AvePanel:NumRepsToAve

	SVAR		Ch1InName = 			root:AvePanel:Ch1InName
	SVAR		Ch2InName = 			root:AvePanel:Ch2InName
	SVAR		Ch3InName = 			root:AvePanel:Ch3InName
	SVAR		Ch4InName = 			root:AvePanel:Ch4InName
		
	SVAR		Ch1OutName = 			root:AvePanel:Ch1OutName
	SVAR		Ch2OutName = 			root:AvePanel:Ch2OutName
	SVAR		Ch3OutName = 			root:AvePanel:Ch3OutName
	SVAR		Ch4OutName = 			root:AvePanel:Ch4OutName

	NVAR		Ch1StartAt = 			root:AvePanel:Ch1StartAt
	NVAR		Ch2StartAt = 			root:AvePanel:Ch2StartAt
	NVAR		Ch3StartAt = 			root:AvePanel:Ch3StartAt
	NVAR		Ch4StartAt = 			root:AvePanel:Ch4StartAt

	SVAR		WaveNamesIn1 = 		root:MP:IO_Data:WaveNamesIn1
	SVAR		WaveNamesIn2 = 		root:MP:IO_Data:WaveNamesIn2
	SVAR		WaveNamesIn3 = 		root:MP:IO_Data:WaveNamesIn3
	SVAR		WaveNamesIn4 = 		root:MP:IO_Data:WaveNamesIn4

	NVAR		StartAt1 = 				root:MP:IO_Data:StartAt1
	NVAR		StartAt2 = 				root:MP:IO_Data:StartAt2
	NVAR		StartAt3 = 				root:MP:IO_Data:StartAt3
	NVAR		StartAt4 = 				root:MP:IO_Data:StartAt4
	
	NVAR		WinSkip = 				root:AvePanel:WinSkip							// Skip between windows [ms]

	//// BASELINE -- this is data from MultiPatch
	NVAR	Base_Spacing =	 	root:MP:ST_Data:Base_Spacing		// The spacing between the pulses in the baseline [ms]
	NVAR	Base_Freq = 		root:MP:ST_Data:Base_Freq			// The frequency of the pulses [Hz]
	NVAR	Base_NPulses = 	root:MP:ST_Data:Base_NPulses		// The number of pulses for each channel during the baseline
	NVAR	Base_Recovery =	root:MP:ST_Data:Base_Recovery		// Boolean: Recovery pulse?
	NVAR	Base_RecoveryPos =root:MP:ST_Data:Base_RecoveryPos	// Position of recovery pulse relative to end of train [ms]
	
	Variable	i

	DoWindow MultiPatch_Switchboard
	if (V_Flag)

		Ch1InName = WaveNamesIn1
		Ch1OutName = WaveNamesIn1+"average"
		Ch1StartAt = StartAt1-NumRepsToAve
		if (Ch1StartAt<1)
			Ch1StartAt = 1
		endif

		Ch2InName = WaveNamesIn2
		Ch2OutName = WaveNamesIn2+"average"
		Ch2StartAt = StartAt2-NumRepsToAve
		if (Ch2StartAt<1)
			Ch2StartAt = 1
		endif

		Ch3InName = WaveNamesIn3
		Ch3OutName = WaveNamesIn3+"average"
		Ch3StartAt = StartAt3-NumRepsToAve
		if (Ch3StartAt<1)
			Ch3StartAt = 1
		endif

		Ch4InName = WaveNamesIn4
		Ch4OutName = WaveNamesIn4+"average"
		Ch4StartAt = StartAt4-NumRepsToAve
		if (Ch4StartAt<1)
			Ch4StartAt = 1
		endif
		
		WinSkip = Base_Spacing+1/Base_Freq*1000*(Base_NPulses-1)
		if (Base_Recovery)
			WinSkip += Base_RecoveryPos
		endif
		
		if (Exists("root:MP:ST_Data:ST_ChannelsChosen"))
			WAVE 		ST_ChannelsChosen = 	root:MP:ST_Data:ST_ChannelsChosen
			i = 0
			do
				CheckBox $("Ch"+num2str(i+1)+"UseCheckBox") value=ST_ChannelsChosen[i],win=Averaging_Control
				i += 1
			while (i<4)
		endif

	else
		Abort "Cannot find MultiPatch!"
	endif

End


