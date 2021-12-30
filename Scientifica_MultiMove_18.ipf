#pragma rtGlobals=1		// Use modern global access method.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Changed code so that it can communicate using the Heater 2 serial code. It should STILL
//		be compatible with the Heater 1 code, although I cannot verify that now.
//	2021-06-04, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Send string feature can now send a semicolon separated list of strings to manipulators.
//	2017-07-19, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Changed the way default settings are manipulated
// *	Send string feature can now send a semicolon separated list of strings to the heater.
//	2016-08-18, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	IMPORTANT CHANGE: Default settings file MultiMove_Settings is no longer loaded
//	from C: (the root) but from Igor_stuff. The advantage is that Igor_stuff does not require
//	privileges for writing files, but you obviously have to have this folder.
//	2016-08-15, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Made temperature readings compatible with heater firmware v2.10 by using the "?"
//	command instead of the "TEMP" command, and with SCALE set to 10.000000.
//	Previous firmware used was v2.04. I do not know what the compatibility is like for
//	versions after 2.04 and before 2.10.
//	2015-08-19, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Added the ability to inactivate a given manipulator so that it is unaffected by
//	multi-movements such as "Lock to", "Go Oritgin" etc
//	2012-01-17, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Added functionality for communicating with the Scientifica perfusion heater
//	2009-03-12, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Added scaling on all axes to account for UUX setting. This is in the Default Settings file.
// *	Added a Z-axis locking function so that all four Z axes can be controlled from
//	one cube. This is useful for quickly moving manipulators to the bath.
//	2009-01-19, Jesper Sjostrom
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Ported to work with Scientifica manipulators, 2008-01-31, Jesper Sjostrom
//	- This is a major rewrite.
//  	- This port includes changing from VDT to VDT2 and from macros to functions
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Ported to Windows XP and Keyspan USB-to-4-serial-port adapter. J.Sj. 1/29/04
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Added functionality for a fourth manipulator. J.Sj. 6/14/00
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Alteration: Fixed the 'Macros' menu entries to only one entry, 1/5/00, J.Sj.
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// *	Modification of original software made by Chris Hempel and Sooyoung Chung

Menu "Macros"
	"Initiate the MultiMove Controller panel", InitMM()
	"MultiMove Controller panel to front", MM_ToFrontProc("")
	SubMenu "With all manipulators..."
		"...set Origin",MM_AllSetOrigin()
		"...go to Origin",MM_AllGoOrigin()
		"...go to Out position",MM_AllGoOut()
		"...go to In position",MM_AllGoIn()
		"...go to Bath position",MM_AllGoBath()
		"...do Long Retract",MM_AllLongRetract()
		"...do Long Retract, then go Out",MM_AllLongRetractThenOut()
	end
	SubMenu "Settings"
		"Check if heater is on",MM_CheckHeater()
		"Send default settings to heater",MM_TransferHeaterDefaults()
		"Read all heater settings",MM_ReadAllSettings()
		"Edit Defaults Settings",MM_EditSettings()
		"Save Defaults Settings",MM_SaveDefaultSettings()
		"Load Defaults Settings",MM_LoadDefaultSettings()
	end
	"-"
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Send generic string to generic port (i.e. a port not necessarily in the port list)

Function MM_genericSend(CurrPort,theString)
	String	CurrPort
	String	theString
	
	NVAR		MM_TimeOut
	SVAR		MM_TermStr

	String		ReadStr

	VDTOperationsPort2 $CurrPort
	VDTWrite2/O=(MM_TimeOut) theString+"\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadStr
	
	print "Sent: \""+theString+"\" to "+currPort+"."
	print "Returned: \""+ReadStr+"\""

End

Function MM_SaveDefaultSettings()

	//// Figure out path first ////
	PathInfo Igor_stuff
	if (V_flag)
		Print "Using path \"Igor stuff\" to save default settings."
	else
		Print "Fatal error!"
		Print "Tried find path \"Igor stuff\", but path did not exist."
		Abort "Tried find path \"Igor stuff\", but path did not exist."
	endif
	//// Load settings ////
	Save/T/O/P=Igor_stuff MM_SettingsWave as "MultiMove_Settings.itx"

End

Function Make_MM_SettingsWave()			// This makes a template wave for saving into the root of the HD

	Print "Can't find any settings on the HD, so making some default settings to work with..."

	Make/O/T/N=0 MM_SettingsWave
	MM_SettingsWave[0]= {"4","COM55","COM50","COM53","COM54","10","heater:yes","COM51","32.0","DATE;HP 15;HI 0;HD 10;BP 150;BI 0;BD 50;MAX 1600;H"}

End

Function MM_EditSettings()

	if (MM_LoadDefaultSettings())
		Make_MM_SettingsWave()
	endif
	WAVE/T MM_SettingsWave
	DoWindow/K SettingsTable
	Edit/K=1/W=(27,177.5,249,533) MM_SettingsWave as "Settings"
	DoWindow/C SettingsTable
	ModifyTable format(Point)=1,width(MM_SettingsWave)=122

End

Function MM_LoadDefaultSettings()

	//// Figure out path first ////
	PathInfo Igor_stuff
	if (V_flag)
		Print "Using path \"Igor stuff\" to find default settings."
	else
		Print "Fatal error!"
		Print "Tried find path \"Igor stuff\", but path did not exist."
		Abort "Tried find path \"Igor stuff\", but path did not exist."
	endif
	LoadWave/C/Q/T/O/P=Igor_stuff "MultiMove_Settings.itx"
	Print "\tLoaded waves \""+S_waveNames+"\" from file \""+S_fileName+"\" located in this path: "+S_path
	if (V_flag!=1)
		Print "Fatal error!"
		Print "Could not load default settings!"
		Return 1
	endif

	Return 0	

End

Function InitMM()
	
	Variable		i
	
	print "==== Setting up MultiMove Controller panel at time "+Time()+". ===="
	Variable/G	MM_DemoMode = 0	// 1 = demo mode -- don't send anything to serial port
	if (MM_DemoMode)
		Beep
		Print "*** DEMO MODE ***\t*** DEMO MODE ***\t*** DEMO MODE ***\t"
		Print "\tManipulator MultiMove controller running in demo mode..."
		Print "*** DEMO MODE ***\t*** DEMO MODE ***\t*** DEMO MODE ***\t"
	endif
	if (MM_LoadDefaultSettings())
		Print "Can't find Default Settings on HD -- please edit and save defaults settings before proceeding..."
		Abort "Can't find Default Settings on HD -- please edit and save defaults settings before proceeding..."
	endif
	WAVE/T MM_SettingsWave
	//// Continue initialization ////
	VDTGetPortList2
	String		AvailablePortsList = S_VDT
	Print "On this computer, located "+num2str(ItemsInList(AvailablePortsList))+" serial ports:",AvailablePortsList
	Variable/G	MM_nManips = str2num(MM_SettingsWave[0])
	Print "Default settings file states that there are "+num2str(MM_nManips)+" manipulators connected. Here's a dump of the default settings file:"
	String/G		MM_ComPortList = ""//"COM3;COM4;COM8;COM5;"
	i = 0
	do
		print "\tManipulator #"+num2str(i+1)+" is connected to this serial port: "+MM_SettingsWave[i+1]
		MM_ComPortList += MM_SettingsWave[i+1]+";"
		i += 1
	while (i<MM_nManips)
	Variable/G	MM_VerboseMode = 0
	Variable/G	MM_Scaling = Str2Num(MM_SettingsWave[i+1])
	print "\tCoordinate scaling:",MM_Scaling
	Variable/G	MM_HeaterExists = StringMatch(MM_SettingsWave[i+2],"heater:yes")
	String/G		MM_HeaterPort = MM_SettingsWave[i+3]
	Variable/G	MM_TempSet = str2num(MM_SettingsWave[i+4])
	String/G		MM_HeaterDefaults = MM_SettingsWave[MM_FindHeaterSettings()]
	if (MM_HeaterExists)
		print "A heater is hooked up on "+MM_HeaterPort+"."
		print "Default target temperature is "+num2str(MM_TempSet)
		print "Heater default settings are:",MM_HeaterDefaults
	else
		print "No heater is hooked up."
	endif
	Print "Now mapping the manipulators as follows:"
	i = 0
	do
		Print "\tManipulator #"+num2str(i+1)+": "+StringFromList(i,MM_ComPortList)
		if (FindListItem(StringFromList(i,MM_ComPortList),AvailablePortsList)==-1)
			print "Fatal error! "+StringFromList(i,MM_ComPortList)+" does not exist on this computer."
			if (!(MM_DemoMode))
				Abort "Fatal error! "+StringFromList(i,MM_ComPortList)+" does not exist on this computer."
			endif
		endif
		i += 1
	while(i<MM_nManips)
	Variable/G	MM_which = 1				// Which manipulator is currently active?
	Variable/G	MM_Locked = 0				// True when locked
	Variable/G	MM_LockedToWhich = 0		// When locking, indicates to which manipulator the other ones are locked
	Variable/G	MM_LockedCounter = 0		// When locking, this helps format text output
	Variable/G	MM_StoreManipulator = 1		// Variable for storing away currently used manipulator
	Make/O/N=(MM_nManips) MM_whichActive	// Boolean: Is this manipulator active for simultanous move with other ones?
	MM_whichActive = 1						// By default, all manipulators are active
	
	// Coordinates displayed on panel (for currently active device)
	Variable/G	MM_x = 0
	Variable/G	MM_y = 0
	Variable/G	MM_z = 0
	Variable/G	MM_a = 0					// angle of 4th axis
	
	// Stored-away coordinates
	i = 0
	do
		Make/O/N=(4) $("MM_xyza_"+num2str(i+1))			// Present coordinates
//		Make/O/N=(4) $("MM_xyza_SO_"+num2str(i+1))		// Surface origin (legacy, no longer used)
		Make/O/N=(4) $("MM_xyza_Lock_"+num2str(i+1))	// Coordinates when locking was initiated
		i += 1
	while(i<MM_nManips)
	
	// Settings and variables
	Variable/G	MM_BathDepth = 3000		// Z distance between plane of fully raised low power objective and the slice surface
	Variable/G	MM_TimeOut = 10			// Time-out in seconds for VDT2 commands.
	String/G		MM_TermStr = "\r"			// The termination character used for communication with Scientifica boxes is CR
	Variable/G	MM_LongRetract = 6000		// Distance of travel that Long Retract button generates
	
	Variable/G	MM_FastVel = 50000
	Variable/G	MM_SlowVel = MM_FastVel/20
	
	String/G		MM_ArbitraryString = "DATE"
	
	Variable/G	MM_CellDepth = 60			// cell depth [microns]
	Variable/G	MM_StopApproach = 20		// stop a little distance from cell [microns]
	
	Variable/G	MM_PollSpacing = 1			// Background polling, spacing in [seconds]
	Variable/G	MM_OpenClosePorts = 1		// Boolean: Open and close ports after each serial port command?
	
	// List of controls to disable when locking manipulators
	String/G		MM_ListOfControls = "bMM_RedrawPanel;bMM1_SwitchManipulator;bMM_SwitchManipulator;bMM2_SwitchManipulator;bMM_ChooseM1;bMM_ChooseM2;bMM_ChooseM3;bMM_ChooseM4;"
	MM_ListOfControls += "UpdatePositionButton;bGoOrigin;bOrigin;bGoBath;LongRetractButton;bMM_SendArbitraryStr;bMM_StartStopPolling;bGoIn;bGoOut;bRevX;bRevY;bRevZ;LockOn;"

	Make/O/N=(4) MM_ChannelColor_R,MM_ChannelColor_G,MM_ChannelColor_B
	// Yellow, blue, red, green, as on the Tektronix TDS2004B digital oscilloscope
	MM_ChannelColor_R = {59136,	26880,	65280,	00000}
	MM_ChannelColor_G = {54784,	43776,	29952,	65535}
	MM_ChannelColor_B = {01280,	64512,	65280,	00000}
	
	Variable/G	MM_HeaterOn = 0				// Boolean: 1 is heater on -- this is a setting
	Variable/G	MM_HeaterOnVerified = 0			// Boolean: 1 is heater on -- this is what is reported from heater controller box
	Variable/G	MM_TempBath = 0
	Variable/G	MM_TempHeater = 0
	Variable/G	MM_TempTarget = 0
	
	// Open all serial ports -- serial port command functions can be called from here onwards!
	if (!MM_OpenClosePorts)
		MM_OpenAllPorts()		// Only open them now if they are not opened & closed for each serial port command
	endif

	if (MM_HeaterExists)
		MM_DetermineHeaterType()
		MM_TransferHeaterDefaults()
		MM_DoSetHeater()
	endif

	// Draw the panel
	MMpanel()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Determine if this is a Heater 1 or a Heater 2 card

Function MM_DetermineHeaterType()

	Print "--- Determining heater type ---"
	Variable/G MM_HeaterType = 0
	String currReply = MM_SendToHeater("V")
	Print "Sent \"V\" and received \""+currReply+"\""
	if (StringMatch(currReply[0],"E"))
		print "\t\tError response -- this is a Heater 1 card..."
		MM_HeaterType = 1
	else
		print "\t\tCorrect response -- this is a Heater 2 card..."
		MM_HeaterType = 2
	endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// In which row are heater settings located?

Function MM_FindHeaterSettings()

	WAVE/T		MM_SettingsWave
	
	Variable	n = numpnts(MM_SettingsWave)
	Variable	row = -1
	Variable	i
	i = 0
	do
		if (StringMatch(MM_SettingsWave[i],"heater:yes"))
			row = i + 3
			i = inf
		endif
		i += 1
	while(i<n)
	
	Return row

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Activate or de-activate a particular manipulator for coordinated movement together with
//// other manipulators.

Function MM_toggleActivationProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	WAVE	MM_whichActive
	String	ctrlName = cba.ctrlName
	Variable	index = str2num(ctrlName[14])-1

	switch( cba.eventCode )
		case 2: // mouse up
			MM_whichActive[index] = cba.checked
			if (cba.checked)
				print "Manipulator #"+num2str(index+1)+" is now active."
			else
				print "Manipulator #"+num2str(index+1)+" is now inactive."
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Switch from one manipulator to the next one, with wrap-around

Function MM_SwitchManipulator(ctrlName) : ButtonControl
	String		ctrlName
	variable		n
	
	NVAR	MM_Which
	NVAR	MM_nManips
	SVAR	MM_ComPortList
	
	NVAR	MM_VerboseMode
	
	WAVE		MM_ChannelColor_R
	WAVE		MM_ChannelColor_G
	WAVE		MM_ChannelColor_B

	String	OtherDirButton = "bMM2_SwitchManipulator"
	String	ChooseButton = "bMM_ChooseM"

	if (StrSearch(ctrlName,ChooseButton,0)!=-1)
		MM_Which = Str2Num(ctrlName[StrLen(ctrlName)-1,StrLen(ctrlName)-1])
		if ((MM_Which<1) %| (MM_Which>MM_nManips))
			Print "Strange error -- Manipulator number out of bounds!"
			Beep
			MM_Which = 1
		endif
	else	
		if (StringMatch(ctrlName,OtherDirButton))
			MM_Which -= 1
			if (MM_Which<1)
				MM_Which = MM_nManips
			endif
		else
			MM_Which += 1
			if (MM_Which>MM_nManips)
				MM_Which = 1
			endif
		endif
	endif
	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)
	Button bMM_SwitchManipulator title="#"+num2str(MM_Which),fColor=(MM_ChannelColor_R[MM_Which-1],MM_ChannelColor_G[MM_Which-1],MM_ChannelColor_B[MM_Which-1])//,fColor=(65535*(5-MM_Which)/4,0,65535*MM_Which/4)

	if (MM_VerboseMode)
		print "{MM_SwitchManipulator} #"+num2str(MM_Which)+" on port "+StringFromList(MM_Which-1,MM_ComPortList)
	endif

End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Update position for current manipulator on panel

Function MM_UpdateCoordinatesOnPanel(ManipNumber)
	Variable	ManipNumber

	NVAR	MM_VerboseMode	
	
	NVAR	MM_x
	NVAR	MM_y
	NVAR	MM_z
	NVAR	MM_a
	
	WAVE	MM_xyza = $("MM_xyza_"+num2str(ManipNumber))
	MM_x = MM_xyza[0]
	MM_y = MM_xyza[1]
	MM_z = MM_xyza[2]
	MM_a = MM_xyza[3]

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get position for all manipulators

Function MM_UpdateCoordinatesForAll()

	NVAR	MM_nManips
	SVAR	MM_ComPortList
	NVAR	MM_TimeOut
	SVAR	MM_TermStr
	
	NVAR	MM_VerboseMode
	
	String	CurrPort,ReadStr
	Variable	ReadVal

	Variable	i
	
	i = 0
	do
		MM_UpdateCoordinatesForOne(i+1)
		i += 1
	while(i<MM_nManips)

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get position for one selected manipulator

Function MM_UpdateCoordinatesForOne(ManipNumber)
	Variable	ManipNumber

	NVAR	MM_nManips
	NVAR	MM_OpenClosePorts
	
	if ((ManipNumber>MM_nManips) %| (ManipNumber<1))
		print "Strange error! -- no such manipulator available: #"+num2str(MM_nManips)
		Abort "Strange error! -- no such manipulator available: #"+num2str(MM_nManips)
	endif
	
	SVAR	MM_ComPortList
	NVAR	MM_TimeOut
	SVAR	MM_TermStr
	NVAR	MM_Scaling
	
	NVAR	MM_VerboseMode
	
	String	CurrPort,ReadStr
	Variable	ReadVal
	
	CurrPort = StringFromList(ManipNumber-1,MM_ComPortList)
	WAVE	w = $("MM_xyza_"+num2str(ManipNumber))
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
//	VDT2 killio
	VDTWrite2/O=(MM_TimeOut) "px\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadVal
	w[0] = ReadVal/MM_Scaling
//	VDT2 killio
	VDTWrite2/O=(MM_TimeOut) "py\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadVal
	w[1] = ReadVal/MM_Scaling
//	VDT2 killio
	VDTWrite2/O=(MM_TimeOut) "pz\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadVal
	w[2] = ReadVal/MM_Scaling
//	VDT2 killio
	VDTWrite2/O=(MM_TimeOut) "angle\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadVal
	w[3] = ReadVal
//	VDT2 killio
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Get position

Function MM_GetPositionProc(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		MM_Which
	NVAR		MM_VerboseMode
	
	if (MM_VerboseMode)
		print "{MM_GetPositionProc} button for #"+num2str(MM_Which)
	endif
	
	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)

	NVAR	MM_HeaterExists
	if (MM_HeaterExists)
		MM_DoReadHeater()
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Set current position to origin

Function MM_SetOriginProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		MM_Which
	NVAR		MM_VerboseMode

	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Applying command for all manipulators."
		DoAlert 1,"Set Origin for all four manipulators.\rAre you sure?"
		if (V_flag==1)
			print "Setting Origin for all four manipulators."
			MM_AllSetOrigin()
		else
			print "Abort."
		endif
	else
		if (MM_VerboseMode)
			Print "Manipulator #"+num2str(MM_Which)+":\tSetting absolute origin"
		endif
		MM_DoSetOrigin(MM_Which)
	endif

End

Function MM_DoSetOrigin(ManipNumber)
	Variable		ManipNumber

	SVAR		MM_ComPortList
	NVAR		MM_TimeOut
	SVAR		MM_TermStr
	
	NVAR		MM_VerboseMode
	
	String		CurrPort,ReadStr
	Variable		ReadVal
	NVAR		MM_OpenClosePorts
	
	CurrPort = StringFromList(ManipNumber-1,MM_ComPortList)
	WAVE	w = $("MM_xyza_"+num2str(ManipNumber))
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
	VDTWrite2/O=(MM_TimeOut) "ZERO\r"
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif
	if (MM_VerboseMode)
		print "{MM_DoSetOrigin} for #"+num2str(ManipNumber)+" using port",CurrPort
	endif

	MM_UpdateCoordinatesForOne(ManipNumber)
	MM_UpdateCoordinatesOnPanel(ManipNumber)

End

Function MM_AllSetOrigin()

	NVAR		MM_nManips
	NVAR		MM_Which
	WAVE		MM_whichActive

	Variable		i

	MM_MemorizeManipulator()	

	i = 0
	do
		if (MM_whichActive[i])
			print "Setting origin: Manipulator #"+num2str(i+1)
			MM_SwitchManipulator("bMM_ChooseM"+num2str(i+1))
			MM_DoSetOrigin(MM_Which)
		else
			print "Manipulator #"+num2str(i+1)+" is not active."
		endif
		i += 1
	while(i<MM_nManips)

	MM_RestoreManipulator()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Remember which manipulator is in use

Function MM_MemorizeManipulator()

	NVAR	 	MM_StoreManipulator
	NVAR		MM_Which
	
	MM_StoreManipulator = MM_Which

End

Function MM_RestoreManipulator()

	NVAR 		MM_StoreManipulator
	NVAR		MM_Which
	
	MM_Which = MM_StoreManipulator
	MM_SwitchManipulator("bMM_ChooseM"+num2str(MM_Which))

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Change TOP velocity

Function MM_ChangeVelocity(whichOne,VelocityValue)
	Variable		whichOne
	Variable		VelocityValue
	
	SVAR		MM_ComPortList
	NVAR		MM_TimeOut
	SVAR		MM_TermStr
	
	NVAR		MM_VerboseMode
	NVAR		MM_OpenClosePorts
	
	String		CurrPort
	
	CurrPort = StringFromList(whichOne-1,MM_ComPortList)
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
	VDTWrite2/O=(MM_TimeOut) "TOP "+num2str(VelocityValue)+"\r"
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif

	if (MM_VerboseMode)
		Print "{MM_ChangeVelocity}",VelocityValue
	endif

End
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Go bath

Function MM_GoBath(ctrlName) : ButtonControl
	String ctrlName
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Applying command for all manipulators."
		MM_AllGoBath()
	else
		MM_DoGoBath()
	endif
	
end

Function MM_DoGoBath()
	String ctrlName
	
	NVAR		MM_Which
	NVAR		MM_BathDepth
	NVAR		MM_FastVel

	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)
	MM_ChangeVelocity(MM_Which,MM_FastVel)
	MM_MoveTo(MM_Which,0,0,MM_BathDepth)

end

Function MM_AllGoBath()

	NVAR		MM_nManips
	WAVE		MM_whichActive

	Variable		i
	
	MM_MemorizeManipulator()
	
	i = 0
	do
		if (MM_whichActive[i])
			print "Going to Bath position: Manipulator #"+num2str(i+1)
			MM_SwitchManipulator("bMM_ChooseM"+num2str(i+1))
			MM_DoGoBath()
		else
			print "Manipulator #"+num2str(i+1)+" is not active."
		endif
		i += 1
	while(i<MM_nManips)

	MM_RestoreManipulator()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Go origin

Function MM_GoOrigin(ctrlName) : ButtonControl
	String ctrlName
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Applying command for all manipulators."
		MM_AllGoOrigin()
	else
		MM_DoGoOrigin()
	endif

end

Function MM_DoGoOrigin()
	NVAR		MM_Which
	NVAR		MM_FastVel

	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)
	MM_ChangeVelocity(MM_Which,MM_FastVel)
	MM_MoveTo(MM_Which,0,0,0)

End

Function MM_AllGoOrigin()

	NVAR		MM_nManips
	WAVE		MM_whichActive

	Variable		i
	
	MM_MemorizeManipulator()
	
	i = 0
	do
		if (MM_whichActive[i])
			print "Going to Origin: Manipulator #"+num2str(i+1)
			MM_SwitchManipulator("bMM_ChooseM"+num2str(i+1))
			MM_DoGoOrigin()
		else
			print "Manipulator #"+num2str(i+1)+" is not active."
		endif
		i += 1
	while(i<MM_nManips)
	
	MM_RestoreManipulator()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move all manipulators along diagonal and then go to Out position

Function MM_AllLongRetractThenOut()

	NVAR		MM_nManips

	MM_AllLongRetract()
	MM_AllGoOut()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move indicated manipulator to desired position

Function MM_MoveTo(ManipNumber,x,y,z)
	Variable		ManipNumber
	Variable		x
	Variable		y
	Variable		z

	SVAR		MM_ComPortList
	NVAR		MM_TimeOut
	SVAR		MM_TermStr
	
	NVAR		MM_VerboseMode
	NVAR		MM_OpenClosePorts
	
	NVAR		MM_Scaling

	String		CurrPort,ReadStr
	Variable		ReadVal
	
	CurrPort = StringFromList(ManipNumber-1,MM_ComPortList)
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
	VDTWrite2/O=(MM_TimeOut) "ABS "+num2str(Round(x*MM_Scaling))+" "+num2str(Round(y*MM_Scaling))+" "+num2str(Round(z*MM_Scaling))+"\r"
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif
	if (MM_VerboseMode)
		print "{MM_MoveTo} for #"+num2str(ManipNumber)+" using port",CurrPort,"and [x,y,z]=",Round(x),Round(y),Round(z)," with scaling",MM_Scaling
	endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Open serial ports

Function MM_OpenAllPorts()

	SVAR		MM_ComPortList
	NVAR		MM_VerboseMode
	NVAR		MM_nManips

	String		CurrPort
	Variable		i
	
	if (MM_VerboseMode)
		print "{MM_OpenAllPorts} Opening all serial ports"
	endif
	i = 0
	do
		CurrPort = StringFromList(i,MM_ComPortList)
		VDTOpenPort2 $CurrPort
		if (MM_VerboseMode)
			print "\t{MM_OpenAllPorts} Opened: "+CurrPort
		endif
		i += 1
	while(i<MM_nManips)

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Close serial ports

Function MM_CloseAllPorts()

	SVAR		MM_ComPortList
	NVAR		MM_VerboseMode
	NVAR		MM_nManips

	String		CurrPort
	Variable		i
	
	if (MM_VerboseMode)
		print "{MM_CloseAllPorts} Opening all serial ports"
	endif
	i = 0
	do
		CurrPort = StringFromList(i,MM_ComPortList)
		VDTClosePort2 $CurrPort
		if (MM_VerboseMode)
			print "\t{MM_CloseAllPorts} Closed: "+CurrPort
		endif
		i += 1
	while(i<MM_nManips)

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Wait until move is completed

Function MM_WaitUntilMoveDone(ManipNumber)
	Variable		ManipNumber

	SVAR		MM_ComPortList
	NVAR		MM_TimeOut
	SVAR		MM_TermStr
	
	NVAR		MM_VerboseMode
	NVAR		MM_OpenClosePorts
	
	String		CurrPort
	Variable		ReadVal
	Variable		i
	
	CurrPort = StringFromList(ManipNumber-1,MM_ComPortList)
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
	do
		VDTWrite2/O=(MM_TimeOut) "S\r"
		VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadVal
		if (MM_VerboseMode)
			print "\t{MM_WaitUntilMoveDone} got ReadVal=",ReadVal," --- WAITING ---"
		endif
	while(ReadVal!=0)
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif
	if (MM_VerboseMode)
		print "{MM_WaitUntilMoveDone} for #"+num2str(ManipNumber)+" using port",CurrPort
		print "\tGot ReadVal=",ReadVal
	endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Long retract along diagonal, to avoid bumping into objective when moving home

Function MM_LongRetractProc(ctrlName) : ButtonControl
	String ctrlName
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Applying command for all manipulators."
		MM_AllLongRetract()
	else
		MM_DoLongRetract()
	endif
	
End
	
Function MM_AllLongRetract()

	NVAR		MM_nManips
	WAVE		MM_whichActive

	Variable		i
	
	MM_MemorizeManipulator()
	
	i = 0
	do
		if (MM_whichActive[i])
			print "Doing Long Retract: Manipulator #"+num2str(i+1)
			MM_SwitchManipulator("bMM_ChooseM"+num2str(i+1))
			MM_DoLongRetract()
		else
			print "Manipulator #"+num2str(i+1)+" is not active."
		endif
		i += 1
	while(i<MM_nManips)

	MM_RestoreManipulator()

End

Function MM_DoLongRetract()
	
	NVAR		MM_Which
	NVAR		MM_LongRetract
	NVAR		MM_FastVel
	NVAR		MM_SlowVel

	NVAR		MM_VerboseMode
	
	Variable		toX
	Variable		toY
	Variable		toZ
	Variable		Angle
	Variable		i
	
	Print "Manipulator #"+num2str(MM_Which)+":\tRetracting along diagonal..."

	// Re-read coordinates to be on the safe side
	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)
	WAVE	w = $("MM_xyza_"+num2str(MM_Which))
	toX = w[0]
	toY = w[1]
	toZ = w[2]
	Angle = w[3]

	// Step #2: Slow move
	Print "\tFirst slowly..."
	MM_ChangeVelocity(MM_Which,MM_SlowVel)
	toX = Round(w[0]-cos(Angle*pi/180)*100)						// NB! Axes are differently labelled as compared to the Sutter MP285s
	toZ = Round(w[2]-sin(Angle*pi/180)*100)
	MM_MoveTo(MM_Which,toX,toY,toZ)
	MM_WaitUntilMoveDone(MM_Which)
	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)

	// Step #3: Fast move
	Print "\tThen fast..."
	MM_ChangeVelocity(MM_Which,MM_FastVel)
	toX = Round(w[0]-cos(Angle*pi/180)*(MM_LongRetract-100))		// NB! w[1] and w[2] updated since they were used last time
	toZ = Round(w[2]-sin(Angle*pi/180)*(MM_LongRetract-100))
	MM_MoveTo(MM_Which,toX,toY,toZ)
	CtrlNamedBackground MM_Poll,status
	if (!(NumberByKey("RUN",S_info)))
		MM_WaitUntilMoveDone(MM_Which)
		MM_UpdateCoordinatesForOne(MM_Which)
		MM_UpdateCoordinatesOnPanel(MM_Which)
	endif

	if (MM_VerboseMode)
		print "{MM_LongRetractProc} for #"+num2str(MM_Which)
		print "MM_FastVel",MM_FastVel
		print "MM_SlowVel",MM_SlowVel
		print "Angle",Angle
		print "sin(Angle)",sin(Angle*pi/180)
		print "cos(Angle)",cos(Angle*pi/180)
	endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Send arbitrary string to controller box

Function bMM_SendArbitraryStrProc(ctrlName) : ButtonControl
	String ctrlName
	
	MM_SendArbitraryStrList()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Send a list of arbitrary strings to a manipulator

Function MM_SendArbitraryStrList()
	SVAR		MM_ArbitraryString

	String		replyStr
	Variable	n = ItemsInList(MM_ArbitraryString)
	print "Found "+num2str(n)+" string items to send."
	String	currStr
	Variable	i
	i = 0
	do
		currStr = StringFromList(i,MM_ArbitraryString)
		Print "\t"+num2str(i+1)+".\tSending this to manipulator: \""+currStr+"\""
		replyStr = MM_DoSendArbitraryStr(currStr)
		Print "\t"+num2str(i+1)+".\tReceived this as a reply: \""+replyStr+"\"."
		i += 1
	while(i<n)
	
End
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Send one arbitrary string to a manipulator

Function/S MM_DoSendArbitraryStr(theString)
	String		theString

	NVAR		MM_Which
	SVAR		MM_ComPortList
	NVAR		MM_TimeOut
	SVAR		MM_TermStr
	
	NVAR		MM_VerboseMode
	NVAR		MM_OpenClosePorts
	
	String		CurrPort
	String		ReadStr
	
	CurrPort = StringFromList(MM_Which-1,MM_ComPortList)
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
	VDTWrite2/O=(MM_TimeOut) theString+"\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadStr
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif

	if (MM_VerboseMode)
		print "{MM_DoSendArbitraryStr} for #"+num2str(MM_Which)+" using port",CurrPort
	endif	
	
	Return ReadStr

End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Redraw panel

Function bMM_RedrawPanelProc(ctrlName) : ButtonControl
	String ctrlName
	
	MMpanel()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Toggle verbose mode

Function bMM_ToggleVerboseProc(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		MM_VerboseMode
	
	if (MM_VerboseMode)
		MM_VerboseMode = 0
		Button bMM_ToggleVerbose,win=MM_Panel,fColor=(65535,65535/2,65535/2)
		if (!(StringMatch("",ctrlName)))
			Print Date(),Time(),"Scientifica MultiMove Verbose Mode is OFF..."
		endif
	else
		MM_VerboseMode = 1
		Button bMM_ToggleVerbose,win=MM_Panel,fColor=(65535/2,65535,65535/2)
		if (!(StringMatch("",ctrlName)))
			Print Date(),Time(),"Scientifica MultiMove Verbose Mode is ON..."
		endif
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Draw the panel

Function MMpanel() : Panel

	Variable		xPos = 10
	Variable		yPos = 100
	Variable		Width = 984-631+30
	Variable		Height = 736-255+20+20+48+45+16		// Note to self: Panel height NOT automatically adjusted with number of rows of buttons
	Variable		ScSc = ScreenResolution/PanelResolution("")
	
	NVAR		MM_Which
	NVAR		MM_nManips
	
	WAVE		MM_ChannelColor_R
	WAVE		MM_ChannelColor_G
	WAVE		MM_ChannelColor_B
	
	WAVE		MM_whichActive
	
	DoWindow	MM_Panel
	if (V_flag)
		GetWindow MM_Panel wsize
		xPos = V_left
		yPos = V_top
	endif
	DoWindow/K MM_Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width,yPos*ScSc+Height)
	DoWindow/C MM_Panel
	ModifyPanel cbRGB=(65535*4/6,65535*4/6,65535*4/6)
	SetDrawLayer ProgBack
	SetDrawEnv fillfgc= (52428,52425,1)
	SetDrawEnv save
	SetDrawLayer UserBack
	SetDrawEnv fillfgc= (32792,65535,1),fstyle= 1,textrgb= (52428,52428,52428)
	SetDrawEnv save

	SetDrawEnv textxjust= 1,textyjust= 2,fstyle= 1,fsize= 24,textrgb= (0,0,0)
	DrawText Width/2,2,"Scientifica MultiMove"
	
	Variable YShift = 45
	Variable fontSize = 12
	Variable	bHeight = 36
	Variable	hSkip = 4
	Variable	bWidth = 180
	Variable	wSkip = 14
	Variable	xStart = 4
	Variable i
	
	Button bMM1_SwitchManipulator,pos={xStart,YShift},size={bWidth/4-2,bHeight},fsize=32,proc=MM_SwitchManipulator
	Button bMM1_SwitchManipulator title="<"
	
	Button bMM_SwitchManipulator,pos={xStart+bWidth/4,YShift},size={bWidth/2-2,bHeight},fsize=32,fColor=(0,0,65280),proc=MM_SwitchManipulator
	Button bMM_SwitchManipulator title="#"+num2str(MM_Which),fColor=(MM_ChannelColor_R[MM_Which-1],MM_ChannelColor_G[MM_Which-1],MM_ChannelColor_B[MM_Which-1])
	
	Button bMM2_SwitchManipulator,pos={xStart+bWidth/4+bWidth/2,YShift},size={bWidth/4-2,bHeight},fsize=32,proc=MM_SwitchManipulator
	Button bMM2_SwitchManipulator title=">"

	YShift -= 10
	SetVariable xPosSetVar,pos={xStart+bWidth+wSkip-10,YShift+0*16},fsize=fontSize,size={80,17},title="x:"
	SetVariable xPosSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_x
	SetVariable yPosSetVar,pos={xStart+bWidth+wSkip-10,YShift+1*16},fsize=fontSize,size={80,17},title="y:"
	SetVariable yPosSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_y
	SetVariable zPosSetVar,pos={xStart+bWidth+wSkip-10,YShift+2*16},fsize=fontSize,size={80,17},title="z:"
	SetVariable zPosSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_z
	SetVariable aPosSetVar,pos={xStart+bWidth+wSkip+50+wSkip,YShift+0*16},fsize=fontSize,size={80,17},title="angle:"
	SetVariable aPosSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_a
	YShift += 10
	
	YShift += bHeight+hSkip

	Variable	totWid = bWidth*2+wSkip
	Variable	chooseWid = totWid/MM_nManips
	i = 0
	do
		Button $("bMM_ChooseM"+num2str(i+1)),pos={xStart+chooseWid*(MM_nManips-(i+1)),YShift},size={chooseWid-2,bHeight},fsize=24,proc=MM_SwitchManipulator
		Button $("bMM_ChooseM"+num2str(i+1)) title="#"+num2str(i+1),fColor=(MM_ChannelColor_R[i],MM_ChannelColor_G[i],MM_ChannelColor_B[i])// fColor=(65535*(5-(i+1))/4,0,65535*(i+1)/4)
		CheckBox $("MM_ActiveCheck"+num2str(i+1)),pos={xStart+chooseWid*(MM_nManips-(i+1))+4,YShift+bHeight+hSkip},size={chooseWid-2,bHeight/2}
		CheckBox $("MM_ActiveCheck"+num2str(i+1)),proc=MM_toggleActivationProc,title="Activated",value=(MM_whichActive[i])
		i += 1
	while(i<MM_nManips)
	
	YShift += bHeight+hSkip+bHeight/2+hSkip

	Button ToBackButton,pos={xStart,YShift},size={bWidth,bHeight},proc=MM_ToBackProc,title="Move panel\rto back"
	Button UpdatePositionButton,pos={xStart+bWidth+wSkip,YShift},size={bWidth,bHeight},proc=MM_GetPositionProc,title="Update\rposition"

	YShift += bHeight+hSkip

	Button bGoOrigin,pos={xStart,YShift} ,size={bWidth,bHeight},proc=MM_GoOrigin,title="^^^   Go Origin   ^^^"
	Button bOrigin,pos={xStart+bWidth+wSkip,YShift},size={bWidth,bHeight},proc=MM_SetOriginProc,title="***   Set Origin   ***"

	YShift += bHeight+hSkip

	Button bGoBath,pos={xStart,YShift},size={bWidth,bHeight},proc=MM_GoBath,title="vvv   Go Bath   vvv"
	SetVariable SetBathDepth,pos={xStart+bWidth+wSkip,YShift},fsize=fontSize,size={160,17},title="BathDepth: "
	SetVariable SetBathDepth,limits={0,inf,100},value=MM_BathDepth

	YShift += bHeight+hSkip

	Button LongRetractButton,pos={xStart,YShift},size={bWidth,bHeight},proc=MM_LongRetractProc,title="Long retract"
	SetVariable LongRetractSetVar,pos={xStart+bWidth+wSkip,YShift},fsize=fontSize,size={160,17},title="Distance: "
	SetVariable LongRetractSetVar,limits={110,Inf,1000},value=MM_LongRetract

	YShift += bHeight+hSkip

	Button bMM_ToggleVerbose,pos={xStart,YShift},size={bWidth,bHeight},proc=bMM_ToggleVerboseProc,title="Verbose\rred - off; green - on"
	bMM_ToggleVerboseProc("")	// Just to update color of button
	bMM_ToggleVerboseProc("")
	Button bMM_RedrawPanel,pos={xStart+bWidth+wSkip,YShift},size={bWidth,bHeight},proc=bMM_RedrawPanelProc,title="Redraw panel"
	Button bMM_RedrawPanel,win=MM_Panel,fColor=(65535/2,65535/2,65535/2)
	
	YShift += bHeight+hSkip

	Button bMM_SendArbitraryStr,pos={xStart,YShift},size={bWidth,bHeight},proc=bMM_SendArbitraryStrProc,title="Send string"
	SetVariable MM_ArbitraryStrSetVar,pos={xStart+bWidth+wSkip,YShift},fsize=fontSize,size={160,17},title="String:"
	SetVariable MM_ArbitraryStrSetVar,limits={0,0,0},frame=1,value= MM_ArbitraryString

	YShift += bHeight+hSkip

	Button bMM_StartStopPolling,pos={xStart,YShift},size={bWidth,bHeight},proc=bMM_StartStopPollingProc,title="Start/Stop Polling\rred - off; green - on"
	Button bMM_StartStopPolling,win=MM_Panel,fColor=(65535,65535/2,65535/2)
	SetVariable MM_PollFreqSetVar,pos={xStart+bWidth+wSkip,YShift},fsize=fontSize,size={160,17},title="Poll spacing [s]: ",proc=MM_ChgPollSpacing
	SetVariable MM_PollFreqSetVar,limits={0.1,Inf,.1},value=MM_PollSpacing

	YShift += bHeight+hSkip

	Button bGoIn,pos={xStart,YShift} ,size={bWidth,bHeight},proc=MM_GoInProc,title="IN"
	Button bGoOut,pos={xStart+bWidth+wSkip,YShift},size={bWidth,bHeight},proc=MM_GoOutProc,title="OUT"

	YShift += bHeight+hSkip
	
	chooseWid = totWid/3
	Button bRevX,pos={xStart+chooseWid*0,YShift} ,size={chooseWid-2,bHeight},proc=MM_RevProc,title="Reverse X"
	Button bRevY,pos={xStart+chooseWid*1,YShift} ,size={chooseWid-2,bHeight},proc=MM_RevProc,title="Reverse Y"
	Button bRevZ,pos={xStart+chooseWid*2,YShift} ,size={chooseWid-2,bHeight},proc=MM_RevProc,title="Reverse Z"

	YShift += bHeight+hSkip

	Button LockOn,pos={xStart,YShift} ,size={bWidth,bHeight},proc=MM_LockOnProc,title="Lock all Z axes to\rthis manipulator"
	Button Unlock,pos={xStart+bWidth+wSkip,YShift},size={bWidth,bHeight},proc=MM_UnlockProc,title="Unlock"
	
	YShift += bHeight+hSkip

//	MM_HeaterExists

	DrawLine Width*0.25,YShift,Width*0.75,YShift
	YShift += hSkip

	Variable	tSpacing = 18
	Variable	disableState = 0
	NVAR	MM_HeaterExists
	if (!(MM_HeaterExists))
		disableState = 2
	endif
	fontSize = 12
	Variable	DotSize = 20
	Button HeaterOn,pos={xStart+DotSize+4,YShift},size={bWidth-DotSize-4,bHeight},proc=MM_ToggleHeaterProc,title="Toggle heater\ron/off",disable=disableState
	ValDisplay HeaterDot,pos={xStart,YShift+bHeight/2-DotSize/2},size={DotSize,DotSize},frame=2,limits={0,1,0.1},barmisc={0,0},bodyWidth= DotSize,mode=1,value=#"MM_HeaterOnVerified",disable=disableState
	MM_CheckHeater()

	SetVariable TempBathSetVar,pos={xStart+bWidth+wSkip,YShift+0*tSpacing},fsize=fontSize,size={bWidth/2,17},title="Bath:"
	SetVariable TempBathSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_TempBath,disable=disableState
	SetVariable TempHeaterSetVar,pos={xStart+bWidth+wSkip,YShift+1*tSpacing},fsize=fontSize,size={bWidth/2,17},title="Heater:"
	SetVariable TempHeaterSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_TempHeater,disable=disableState
	SetVariable TempTargetSetVar,pos={xStart+bWidth+wSkip+bWidth/2,YShift+0*tSpacing},fsize=fontSize,size={bWidth/2,17},title="Target:"
	SetVariable TempTargetSetVar,noedit=1,limits={-Inf,Inf,0},frame=0,value= MM_TempTarget,disable=disableState
	SetVariable TempSetSetVar,pos={xStart+bWidth+wSkip+bWidth/2,YShift+1*tSpacing},fsize=fontSize,size={bWidth/2,17},title="Set:"
	SetVariable TempSetSetVar,limits={0,Inf,0.5},value= MM_TempSet,disable=disableState,proc=TempSetSetVarProc
	MM_DoReadHeater()
	
	YShift += bHeight+hSkip

	Button ReadHeater,pos={xStart,YShift},size={bWidth,bHeight},proc=MM_ReadHeaterProc,title="Read heater\rtemperature",disable=disableState
	Button SendStringToHeaterButton,pos={xStart+bWidth+wSkip,YShift},size={bWidth,bHeight},proc=MM_SendStringToHeaterProc,title="Send string\rto heater",disable=disableState

	print "This is version 18."

End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Transfer heater default settings to heater controller box

Function MM_TransferHeaterDefaults()


	SVAR		MM_HeaterDefaults
	WAVE/T		MM_SettingsWave
	MM_HeaterDefaults = MM_SettingsWave[MM_FindHeaterSettings()]	// Make sure defaults are up to date WRT to the text wave source
	if (MM_FindHeaterSettings()==-1)
		print "Fatal error! Cannot locate default settings in default settings."
		Abort "Fatal error! Cannot locate default settings in default settings."
	endif

	Variable		nEntries = ItemsInList(MM_HeaterDefaults)
	Variable		i
	String		currEntry,currReply

	Print "--- Applying default settings to heater controller ---"
	Print Time()
	i = 0
	do
		currEntry = StringFromList(i,MM_HeaterDefaults)
		currReply = MM_SendToHeater(currEntry)
		Print "Sent \""+currEntry+"\" and received \""+currReply+"\""
		i += 1
	while(i<nEntries)

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Update set temperature on heater controller when setvar is altered

Function TempSetSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			MM_DoSetHeater()
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read all heater settings

Function MM_ReadAllSettings()

	NVAR	MM_HeaterType

	SVAR		MM_ArbitraryString
	String		storeStr = MM_ArbitraryString			// Store panel string
	if (MM_HeaterType==1)
		MM_ArbitraryString = "HP;HI;HD;BP;BI;BD;MAX;HEATMAX;TARGET;"
	else
		MM_ArbitraryString = "MAXH;MAXDIF;PIDGAINS;TARGET;"
	endif
	MM_DoSendStringToHeater()
	MM_ArbitraryString = storeStr						// Restore panel string

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Send arbitrary string to heater

Function MM_SendStringToHeaterProc(ctrlName) : ButtonControl
	String		ctrlName
	
	MM_DoSendStringToHeater()
	
End

Function MM_DoSendStringToHeater()
	SVAR		MM_ArbitraryString

	String		replyStr
	Variable	n = ItemsInList(MM_ArbitraryString)
	print "Found "+num2str(n)+" string items to send."
	String	currStr
	Variable	i
	i = 0
	do
		currStr = StringFromList(i,MM_ArbitraryString)
		Print "\t"+num2str(i+1)+".\tSending this to heater: \""+currStr+"\""
		replyStr = MM_SendToHeater(currStr)
		Print "\t"+num2str(i+1)+".\tReceived this as a reply: \""+replyStr+"\"."
		i += 1
	while(i<n)
	
End
	
Function/S MM_SendToHeater(theString)
	String		theString

	SVAR		MM_HeaterPort

	NVAR		MM_TimeOut
	SVAR		MM_TermStr
	
	NVAR		MM_VerboseMode
	NVAR		MM_OpenClosePorts
	
	String		CurrPort
	String		ReadStr
	
	CurrPort = MM_HeaterPort
	if (MM_OpenClosePorts)
		VDTOpenPort2 $CurrPort
	endif
	VDTOperationsPort2 $CurrPort
	VDTWrite2/O=(MM_TimeOut) theString+"\r"
	VDTRead2/O=(MM_TimeOut)/Q/T=(MM_TermStr) ReadStr
	if (MM_OpenClosePorts)
		VDTClosePort2 $CurrPort
	endif

	if (MM_VerboseMode)
		print "{MM_SendToHeater} using port",CurrPort
	endif	

	Return ReadStr

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set heater target temperature

Function MM_SetHeaterProc(ctrlName) : ButtonControl
	String		ctrlName
	
	MM_DoSetHeater()
	
End

Function	MM_DoSetHeater()

	NVAR	MM_TempSet
	NVAR	MM_HeaterType

	Variable	Scaling = 100
	if (MM_HeaterType==1)
		Scaling = 100
	else
		Scaling = 1
	endif

	Print Time(),"Setting heater temperature to ",MM_TempSet
	String	replyStr = MM_SendToHeater("TARGET "+num2str(MM_TempSet*Scaling))
	MM_DoReadHeater()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read heater

Function MM_ReadHeaterProc(ctrlName) : ButtonControl
	String		ctrlName
	
	MM_DoReadHeater()
	
End

Function	MM_DoReadHeater()

	NVAR MM_TempBath
	NVAR MM_TempHeater
	NVAR MM_TempTarget

	NVAR	MM_HeaterType

	String/G MM_tempStr			// Make global for debug purposes

	if (MM_HeaterType==1)
		//// Heater 1 card new code
		// ? - bath, state, heater
		// HT - target
		MM_tempStr = MM_SendToHeater("?")
		MM_TempBath = Str2Num(StringFromList(0,MM_tempStr,"\t"))/100
		MM_TempHeater = Str2Num(StringFromList(2,MM_tempStr,"\t"))/100
		String tempStr = MM_SendToHeater("HT")
		MM_TempTarget = Str2Num(tempStr)/100
		MM_tempStr += "\t"+tempStr
	else
		//// Heater 2 card firmware 2016 code
		//	Returns: <b> Bath temperature
		//		<h> Heater temperature
		//		<ac> Actual heater output current
		//		<tc> Target heater output current
		//		<v> Valve state
		//		<u> Units
		//		<t> Target temperature
		//		<e> Heater enabled (0 = disabled, 1 = enabled)
		//		<r> Raw debug output
		//		<ps> Proportional debug output
		//		<is> Integral debug output
		//		<ds> Dierential debug output
		//		<s> Stable (0 = Unstable, 1 = stable)
		//		<d> Dry (0 = Normal, 1 = dry)
		MM_tempStr = MM_SendToHeater("V")
		MM_TempBath = Str2Num(StringFromList(0,MM_tempStr,"\t"))
		MM_TempHeater = Str2Num(StringFromList(1,MM_tempStr,"\t"))
		MM_TempTarget = Str2Num(StringFromList(6,MM_tempStr,"\t"))
	endif

End

//// Heater 1 card old code -- OBSOLETE (I hope)

Function	MM_DoReadHeater_OLD()

	NVAR MM_TempBath
	NVAR MM_TempHeater
	NVAR MM_TempTarget

	String	tempStr = MM_SendToHeater("TEMP")
	MM_TempTarget = Str2Num(StringFromList(0,tempStr,"\t"))/100
	MM_TempBath = Str2Num(StringFromList(1,tempStr,"\t"))/100
	MM_TempHeater = Str2Num(StringFromList(2,tempStr,"\t"))/100

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Toggle heater

Function MM_ToggleHeaterProc(ctrlName) : ButtonControl
	String		ctrlName
	
	NVAR		MM_HeaterOn

	if (MM_HeaterOn)
		Print Time(),"Turning heater off"
		MM_HeaterOn = 0
	else
		Print Time(),"Turning heater on"
		MM_HeaterOn = 1
	endif
	
	String dummyStr = MM_SendToHeater("ENABLE "+num2str(MM_HeaterOn))
	MM_CheckHeater()
	
End

Function MM_CheckHeater()

	NVAR	MM_HeaterOnVerified

	if (Str2Num(MM_SendToHeater("ENABLE")))
		print "Heater is on"
		MM_HeaterOnVerified = 1
	else
		print "Heater is off"
		MM_HeaterOnVerified = 0
	endif

End
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Reverse axis

Function MM_RevProc(ctrlName) : ButtonControl
	String		ctrlName
	
	String		SendStr = "JD"+ctrlName[4,4]
	String		ReadStr
	ReadStr = MM_DoSendArbitraryStr(SendStr)
	print "Reversing knob rotation on "+ctrlName[4,4]+" axis by sending "+SendStr

End
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Go IN

Function MM_GoInProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Applying command for all manipulators."
		MM_AllGoIn()
	else
		MM_DoGoIn()
	endif

End
	
Function MM_DoGoIn()

	String		ReadStr
	ReadStr = MM_DoSendArbitraryStr("IN")

End

Function MM_AllGoIn()

	NVAR		MM_nManips
	WAVE		MM_whichActive

	Variable		i
	
	MM_MemorizeManipulator()
	
	i = 0
	do
		if (MM_whichActive[i])
			print "Going to 'IN' position: Manipulator #"+num2str(i+1)
			MM_SwitchManipulator("bMM_ChooseM"+num2str(i+1))
			MM_DoGoIn()
		else
			print "Manipulator #"+num2str(i+1)+" is not active."
		endif
		i += 1
	while(i<MM_nManips)

	MM_RestoreManipulator()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Go OUT

Function MM_GoOutProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Applying command for all manipulators."
		MM_AllGoOut()
	else
		MM_DoGoOut()
	endif

End
	
Function MM_DoGoOut()

	String		ReadStr
	ReadStr = MM_DoSendArbitraryStr("OUT")

End

Function MM_AllGoOut()

	NVAR		MM_nManips
	WAVE		MM_whichActive

	Variable		i
	
	MM_MemorizeManipulator()
	
	i = 0
	do
		if (MM_whichActive[i])
			print "Going to 'OUT' position: Manipulator #"+num2str(i+1)
			MM_SwitchManipulator("bMM_ChooseM"+num2str(i+1))
			MM_DoGoOut()
		else
			print "Manipulator #"+num2str(i+1)+" is not active."
		endif
		i += 1
	while(i<MM_nManips)

	MM_RestoreManipulator()

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Button: Toggle background polling of coordinates

Function bMM_StartStopPollingProc(ctrlName) : ButtonControl
	String		ctrlName
	
	NVAR		MM_VerboseMode
	NVAR		MM_PollSpacing
	
	Variable		PollingInProcess = 0
	
	CtrlNamedBackground MM_Poll,status
	if (MM_VerboseMode)
		print "{bMM_StartStopPollingProc} S_info=",S_info
	endif
	if (NumberByKey("RUN",S_info))
		PollingInProcess = 1
	else
		PollingInProcess = 0
	endif
	
	if (PollingInProcess)
		Button bMM_StartStopPolling,win=MM_Panel,fColor=(65535,65535/2,65535/2)
		CtrlNamedBackground MM_Poll,kill
	else
		Button bMM_StartStopPolling,win=MM_Panel,fColor=(65535/2,65535,65535/2)
		CtrlNamedBackground MM_Poll,period=(MM_PollSpacing*60.15)
		CtrlNamedBackground MM_Poll,proc=MM_PollStation
		CtrlNamedBackground MM_Poll,start
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Background procedure that polls the manipulator controller box for coordinates
//// and angle

Function MM_PollStation(infoOnBackground)

	STRUCT		WMBackgroundStruct &infoOnBackground
	
	NVAR		MM_Which
	NVAR		MM_VerboseMode
	
	Variable		StopSignal = 0							// 1 means stop, 0 means keep going

	MM_UpdateCoordinatesForOne(MM_Which)
	MM_UpdateCoordinatesOnPanel(MM_Which)

	NVAR	MM_HeaterExists
	if (MM_HeaterExists)
		MM_DoReadHeater()
	endif

	WAVE	w = $("MM_xyza_"+num2str(MM_Which))

	if (MM_VerboseMode)
		print "{MM_PollStation} just executed... ["+num2str(w[0])+","+num2str(w[1])+","+num2str(w[2])+"], angle="+num2str(w[3])
	endif

	return		StopSignal
	
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Change poll spacing on the fly

Function MM_ChgPollSpacing(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	NVAR		MM_PollSpacing
	CtrlNamedBackground MM_Poll,period=(MM_PollSpacing*60.15)
	CtrlNamedBackground MM_LockPoll,period=(MM_PollSpacing*60.15)

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Lock all other manipulators' Z axes to that of the selected manipulator

Function MM_LockOnProc(ctrlName) : ButtonControl
	String		ctrlName

	NVAR		MM_Which
	NVAR		MM_Locked
	NVAR		MM_LockedToWhich
	NVAR		MM_nManips
	NVAR		MM_FastVel
	NVAR		MM_LockedCounter
	
	if (Exists("root:MP:PM_Data:PatternRunning")==2)
		NVAR		PatternRunning = 				root:MP:PM_Data:PatternRunning		// Boolean: Is a pattern currently running?
		NVAR		AcqInProgress =					root:MP:AcqInProgress				// Boolean: Is acquisition in progess?
		if ((PatternRunning) %| (AcqInProgress))
			Print "=== It is a bad idea to press this button while acquiring data!!! ==="
			Abort
		endif
	endif

	Variable		i

	MM_LockedCounter = 0

	MM_Locked = 1
	MM_LockedToWhich = MM_Which
	print "Locking to Manipulator #"+num2str(MM_LockedToWhich)
	MM_UpdateCoordinatesForAll()
	i = 0
	do
		MM_ChangeVelocity(i+1,MM_FastVel)
		WAVE	wSource = $("MM_xyza_"+num2str(i+1))
		WAVE	wDest = $("MM_xyza_Lock_"+num2str(i+1))
		wDest = wSource
		i += 1
	while(i<MM_nManips)
	MM_DisableControls(1)
	MM_LockZaxis()

End	

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Unlock manipulators' Z axes

Function MM_UnlockProc(ctrlName) : ButtonControl
	String		ctrlName
	
	NVAR		MM_Locked
	NVAR		MM_LockedToWhich

	print "Unlocking manipulators."
	CtrlNamedBackground MM_LockPoll,kill
	MM_DisableControls(0)
	MM_Locked = 0

End	

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Start background task for locking manipulators

Function MM_LockZaxis()

	NVAR		MM_Locked
	NVAR		MM_LockedToWhich
	NVAR		MM_PollSpacing

	CtrlNamedBackground MM_LockPoll,period=(MM_PollSpacing*60.15)
	CtrlNamedBackground MM_LockPoll,proc=MM_LockZaxisPollStation
	CtrlNamedBackground MM_LockPoll,start
	
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pollstation for locking manipulators together

Function MM_LockZaxisPollStation(infoOnBackground)

	STRUCT		WMBackgroundStruct &infoOnBackground
	
	NVAR		MM_LongRetract
	NVAR		MM_FastVel
	NVAR		MM_SlowVel

	NVAR		MM_VerboseMode
	
	NVAR		MM_nManips
	SVAR		MM_ComPortList
	
	WAVE		MM_ChannelColor_R
	WAVE		MM_ChannelColor_G
	WAVE		MM_ChannelColor_B

	NVAR		MM_Locked
	NVAR		MM_LockedToWhich
	NVAR		MM_LockedCounter

	WAVE		MM_whichActive
	
	Variable		StopSignal = 0							// 1 means stop, 0 means keep going

	Variable		i,j
	
	MM_LockedCounter += 1

	MM_UpdateCoordinatesForAll()
	MM_UpdateCoordinatesOnPanel(MM_LockedToWhich)

	WAVE	wCurr = $("MM_xyza_"+num2str(MM_LockedToWhich))
	if (MM_VerboseMode)
		print "{MM_LockZaxisPollStation} just executed... ["+num2str(wCurr[0])+","+num2str(wCurr[1])+","+num2str(wCurr[2])+"], angle="+num2str(wCurr[3])
	endif
	WAVE	wLock = $("MM_xyza_Lock_"+num2str(MM_LockedToWhich))
	Variable	zDelta = wCurr[2]-wLock[2]
	i = 0
	do
		if (i+1!=MM_LockedToWhich)
			if (MM_whichActive[i])							// Only move active manipulators
				WAVE	wCurr = $("MM_xyza_"+num2str(i+1))
				WAVE	wLock = $("MM_xyza_Lock_"+num2str(i+1))
				MM_MoveTo(i+1,wCurr[0],wCurr[1],wLock[2]+zDelta)
				if (MM_VerboseMode)
					print "Just moved Manipulator #"+num2str(i+1)+" relative to Manipulator #"+num2str(MM_LockedToWhich)
				endif
			else
				if (MM_VerboseMode)
					print "Manipulator #"+num2str(i+1)+" is not active, so was not moved."
				endif
			endif
		endif
		i += 1
	while(i<MM_nManips)

	if (MM_Locked)
		printf "Locked! "
		if (MOD(MM_LockedCounter,20)==0)
			printf "\r"
		endif
	else
		print "Unlocked!"
		StopSignal = 1
		j = Inf
	endif

	return		StopSignal

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Disable controls (or "able" them) when toggling manipulator locking on/off

Function MM_DisableControls(disable)
	Variable		disable

	SVAR		MM_ListOfControls
	Variable		n = ItemsInList(MM_ListOfControls)
	Variable		i
	String		currControl
	
	NVAR		MM_VerboseMode

	if (MM_VerboseMode)
		print "{MM_DisableControls} called"
	endif

	i = 0
	do
		currControl = StringFromList(i,MM_ListOfControls)
		Button $currControl,win=MM_Panel,disable=(2*disable)
		i += 1
	while(i<n)

End