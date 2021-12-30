#pragma rtGlobals=1				// Use modern global access method.
#pragma IgorVersion=6
#if (Exists("fDAQmx_DeviceNames")%&(1))		// 1 to allow NIDAQmx driver, 0 to force DEMO mode. 
													// NOTE! With NIDAQToolsMXStubs.xop installed, procs will compile, but patterns won't execute right due to lack of EndOfScanHook in Stubs
													// Change to zero to force DEMO mode in that scenario.
#include "MP_Board_NIDAQ_2pQuad"	// Routines specific for the National Instrument boards. Based on my Rockefeller 2p quadruple setup.
#else
#include "MP_Board_DEMO"				// Routines simulating a board when there is none connected & when there are no drivers that can simulate a board
#endif

//#include "MP_Board_NIDAQ_2PLSM"		// Routines specific for the National Instrument boards. Assuming the 2-photon setup...
//#include "MP_Board_NIDAQ"		// Routines specific for the National Instrument boards
//#include "MP_Board_ITC18"		// Routines specific for the Instrutech ITC18 board
//#include "MP_Board_ITC18_xTrig"		// Routines specific for the Instrutech ITC18 board, *with* external triggering...
//#include "MP_Board_ITC"		// Routines specific for any of the Instrutech boards (ITC16, ITC18, ITC1600)

//////////////////////////////////////////////////////////////////////////////////
// MultiPatch
//////////////////////////////////////////////////////////////////////////////////
// Copyright Jesper Sjostrom, 9/2/99
//////////////////////////////////////////////////////////////////////////////////
// This is the backbone program for handling current injections and recordings of up to four cells
// at the same time. Any channel can be used for extracellular stimulation in the stead of a
// whole-cell recording. Or dendritic recording. Or laser uncaging. 
//////////////////////////////////////////////////////////////////////////////////

//		BUGS TO FIX, FEATURES TO ADD, ETC.
//		--------------------------
// Which waves are listed in the popup menus should be possible to chose
// Potential bug: loading a pattern as a wavedescriptor TWICE, or vice versa --> uncaptured error

// ADD: ST_Creator, when making waves that includes "dendrites," then the sealtest should be appended to the end of the ST trace
// FIX: MultiMake should produce a text wave for cycling through waves and not rely on repeating patterns.
// BUG: R_pip procedure assumes current clamp!!!
// FIX: ITC-18 driver file "MP_Board_ITC18" assumes there is an input channel selected for each output channel selected -- fix this!
// FIX: lock mode checkbox --> synch v clamp/i clamp in WaveCreator and SwitchBoard
// FIX: Remove pre-scaling of waves and instead work with unscaled output waves.

// --- MultiMake list:
//	MultiMake -- used for the making of multiple waves for the studying of AP-EPSP coincidence along with 2-photon imaging
//	MultiMake 2 -- used for dendritic depolarizations on action potential back-propagation using the 2-photon.
//	MultiMake 3 -- intended for Alanna's original PurkPurk paper
//	MultiMake 4 -- combine uncaging with electrophys signals, for Kate's preNMDAR paper and for Alex' ACh study

//////////////////////////////////////////////////////////////////////////////////
// CHANGES AND IMPROVEMENTS DESCRIBED BELOW:
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed button color bug associated with Igor 9.
//	*	Added support for the Warner Inline Heater TC-324C. To use this feature,
//		need to also load and init the Warner Panel (WarnerPanel.ipf).
//  J.Sj. 2021-12-14
//////////////////////////////////////////////////////////////////////////////////
//	*	Decided to deprecate the MultiPatch Load Recently Acquired data panel and 
//		instead use the response detector in Jesper's Tools Load Waves panel. The 
//		two panels were too similar, so I went with the more flexible one.
//  J.Sj. 2021-03-26
//////////////////////////////////////////////////////////////////////////////////
//	*	In WaveCreator, made a "Repeat across slots" button, which copies settings
//		in Slot 1 to the other 9 slots on the selected channel, while also ramping
//		"2. Pulse amplitude" according to the range Start and Step settings, with
//		a "t-step" timestep.
//  J.Sj. 2021-03-08
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a plot-prior-runs to the PatternMaker for input resistance and
//		V_m / i_hold plots too. I did not do this for temperature though, since
//		I cannot code for that in demo mode.
//  J.Sj. 2021-03-07
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a plot-prior-runs to the PatternMaker, so that synaptic responses
//		from previous runs of the pattern can be shown _before_ the current pattern.
//		This feature does not apply to the V_m, R_input, or temperature plots.
//  J.Sj. 2021-03-03
//////////////////////////////////////////////////////////////////////////////////
//	*	The Load Waves panel now has "Zoom-in" windows, useful for identifying
//		multiple responses from different sources in the same sweep. This is suitable
//		for visualizing responses evoked by 2p Zap optogenetics or uncaging.
//  J.Sj. 2020-10-17
//////////////////////////////////////////////////////////////////////////////////
//	*	ST Creator's "SpTm2Wv" function is now sensitive to the "Extrac stim"
//		checkbox. 
//  J.Sj. 2020-02-25
//////////////////////////////////////////////////////////////////////////////////
//	*	ST Creator now accepts duration in samples for the extrac stim pulses, to
//		account for the possibility of changing the sample rate.
//  J.Sj. 2020-01-11
//////////////////////////////////////////////////////////////////////////////////
//	*	Sample frequency is now saved in default settings file.
//  J.Sj. 2019-12-19
//////////////////////////////////////////////////////////////////////////////////
//	*	Settings are henceforth located in the Igor Stuff folder, no longer in the
//		main HD root path.
//	*	Added filtering option to the Temp traces shown in the Acquired Waves window.
//		The data saved on the HD is _not_ filtered; this is cosmetic and online only.
//	*	The default sampling frequency was changed from 10 kHz to 40 kHz.
//	*	All legacy code referring to the slave computer was finally removed.
//	*	Fixed pesky bug in ChgNStepsProc in PatternMaker AGAIN! s.eventcode == 8,
//		not 2 like I had before.
//  J.Sj. 2019-12-17
//////////////////////////////////////////////////////////////////////////////////
//	*	Below pesky bug also affected WaveCreator, so I fixed this problem.
//  J.Sj. 2018-10-12
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed pesky bug in ChgNStepsProc in PatternMaker related to how Igor 8 
//		handles hook functions.
//  J.Sj. 2018-08-29
//////////////////////////////////////////////////////////////////////////////////
//	*	SpTm2Wv now takes Induction Freq and # pulses as arguments for creating
//		the output wave (for Christina Chou's RPM experiments with jScan).
//  J.Sj. 2018-05-02
//////////////////////////////////////////////////////////////////////////////////
//	*	Every time default settings are loaded, they are dumped into the Parameter
//		Log (previously only into the Igor history window).
//  J.Sj. 2017-03-28
//////////////////////////////////////////////////////////////////////////////////
//	*	Added feature to SpikeTiming Creator for creating a range of spike timings
//		to be used with the jScan grid uncaging feature.
//  J.Sj. 2016-12-19
//////////////////////////////////////////////////////////////////////////////////
//	*	SpTm2Waves bugfix: gain-scaling of output waves applied (forgot this!)
//  J.Sj. 2016-02-09
//////////////////////////////////////////////////////////////////////////////////
//	*	SpTm2Waves was modified to output to _ST waves, so that we may in the future use them
//		as induction waves in STDP experiments.
//	*	Fixed some bugs and made sure notes are dumped to Parameter_Log in the right way.
//  J.Sj. 2016-02-08
//////////////////////////////////////////////////////////////////////////////////
//	*	Added new feature in ST_Creator to create waves with any spiking pattern at all given a set
//		of four waves containing spike times. This was created for a collaboration with Simon Schultz
//		at Imperial College London. Feature is called SpTm2Waves.
//  J.Sj. 2016-02-06
//////////////////////////////////////////////////////////////////////////////////
//	*	Minor bug fixes.
//	*	Added ramps to the WaveCreator
//	*	Made it possible to put the test pulse at the end of the trace with the WaveCreator (previously
//		only possible with the ST_Creator)
//	*	Note that MP_Board_DEMO also was updated with this version.
//  J.Sj. 2013-02-01
//////////////////////////////////////////////////////////////////////////////////
//	*	Reorganized windows a tad for computers with screens in portrait mode.
//	*	Fixed that pesky suffix naming bug with Cycle-through-waves Make button.
//  J.Sj. 2012-06-19
//////////////////////////////////////////////////////////////////////////////////
//	*	Restructured the organization of the MultiMake panel buttons in the ST Creator panel
//	*	Added a new MultiMake 4 panel, to look for supralinear summation between light-induced
//		signal and electrophysiologically evoked action potentials.
//  J.Sj. 2010-08-25
//////////////////////////////////////////////////////////////////////////////////
//	*	Output checkboxes are no longer linked 1-to-1 with the Input checkboxes in the
//		SwitchBoard if you use the Natl Instruments boards. (still linked with ITC18)
//	*	Added more/less button in SpikeTiming Creator for hiding the tweaks and making the panel
//		smaller.
//	*	Relatively major rewrite: Added a feature for light stimulation of cells, e.g. for glutamate
//		uncaging with 405 nm solid-state laser, or for diode wide-field activation of ChR2, or
//		in principle also for gating of a Pockels cell (requires further tweaks for power calibration
//		though).
//  J.Sj. 2010-08-23
//////////////////////////////////////////////////////////////////////////////////
//	*	Added AutoY button to RT_PM graphs.
//	*	Fixed various boring bugs
//	*	Added autosave experiment feature
//  J.Sj. 2009-03-12
//////////////////////////////////////////////////////////////////////////////////
//	*	Mark feature for RT PM graphs now provides time and pattern details stamp in
//		Parameter Log.
//	*	Fixed bug in add-to-log entries so that picture data is converted to PNG format. Before, 
//		graphics from Windows machines would not show up on a PC, and vice versa.
//  J.Sj. 2009-02-23
//////////////////////////////////////////////////////////////////////////////////
//	*	Added Mark feature to RT PM graphs, so that user can easily mark when during
//		an experiment they e.g. wash in a drug. Note that this marker is erased if the window is
//		and reopened.
//  J.Sj. 2009-02-11
//////////////////////////////////////////////////////////////////////////////////
//	*	Added functionality in Manipulate Pattern panel for converting a repeating pattern into
//		a wavelist, thus circumventing the pesky restart-of-pattern glitch.
//	*	Added functionality in Manipulate Pattern panel for copying output wave in first step
//		to all subsequent steps, but only on one selected channel.
//	*	Added Tektronix color coding to to R_pip panel.
//  J.Sj. 2009-02-10
//////////////////////////////////////////////////////////////////////////////////
//	*	"S" (spread) and Baseline Stabillity functionality did not work with Con_Matrix. Fixed this.
//  J.Sj. 2009-01-23
//////////////////////////////////////////////////////////////////////////////////
//	*	Made PatternManipulator panel with which the user can quickly copy the settings from the
//		first step of a pattern to all subsequent steps at the click of a button. You can currently
//			1.	copy the output waves from the first step
//			2.	copy the checkbox settings from the first step
//			3.	copy the number of repeats from the first step
//			4.	copy the ISI from the first step
//			5.	shift the entire pattern up one step (thus erasing the first step) [this part is not
//				a new addition]
//	*	Some cosmetic changes in PatternMaker, e.g. added Tektronix channel coloring
//	*	Hold Shift key while pressing "Reposition Notebook" will now bring Notebook to front
//		without resizing it.
//  J.Sj. 2009-01-16
//////////////////////////////////////////////////////////////////////////////////
//	*	To account for data analysis bug, default basename is Cell_91_ through Cell_94_ for the four
//		channels.
//  J.Sj. 2009-01-10
//////////////////////////////////////////////////////////////////////////////////
//	*	Making sure massive re-write works in Igor under Windows XP too
//	*	Fixed various cosmetic bugs
//  J.Sj. 2009-01-07
//////////////////////////////////////////////////////////////////////////////////
//	*	Massive re-write: Added a ConnectivityPanel to PatternMaker, so that multiple EPSPs onto
//		one channel can be monitored with the RealTime analysis.
//	*	I still kept the old RT_EPSP analysis bit, since the new way of monitoring EPSPs only 
//		integrates with St_Creator, but not with WaveCreator. One should thus use the old
//		RT_EPSP "grab" mode with WaveCreator, whereas the new ConnectivityPanel works
//		best with ST_Creator.
//	*	The positions of both the new and the old forms of EPSP amplitude tracking can be visualized
//		using the "EPSP pos?" button in the MultiPatch_ShowInputs graph. Hold down shift while
//		pressing the same button to clear the lines.
//	*	Rewrote the DEMO mode driver, so that it simulates spikes and EPSPs according to
//		connectivity set up in the ConnectivityPanel of PatternMaker.
//  J.Sj. 2009-01-06
//////////////////////////////////////////////////////////////////////////////////
//	*	Added conditional compilation for driver procedure vs demo mode. This will include NIDAQmx
//		driver if XOP is installed, elsewhere defaults for demo mode.
//	*	Made Tektronix-style channel color coding more consistent across panels.
//	*	Made WaveCreator defaults useful for IO curve creation with MultiRange (see note below).
//  J.Sj. 2008-12-17
//////////////////////////////////////////////////////////////////////////////////
//	*	Upon Kate Buchanan's request, added a button in WaveCreator that repeats the CreateRange 
//		for each channel selected in the Switchboard and then finally calls Range2Pattern. This is
//		useful for when repeating the same IO curves for each channel.
//	*	Locked the Output and Input checkboxes in Switchboard to each other.
//	*	Added channel coloring to Switchboard and ST_Creator panels.
//  J.Sj. 2008-12-16
//////////////////////////////////////////////////////////////////////////////////
//	*	Save ParameterLog_BACKUP.ifn after each Single Send and after each Pattern.
//  J.Sj. 2008-10-10
//////////////////////////////////////////////////////////////////////////////////
//	*	Fix suggested by Kate Buchanan: Change trace colors on each channel to match those of the
//		four-channel digital oscilloscope Tektronix 2004B.
//  J.Sj. 2008-10-09
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a MultiMake 3 (MM3) panel that simplifies the making of waves for Alanna's PurkPurk
//		paper. This panel operates on the WaveCreator panel. These routines require Jesper's Tools
//		v.03.
//  J.Sj. 2006-11-07
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed the LoadData panel so that it can load waves with different steps between them.
//  J.Sj. 2006-11-06
//////////////////////////////////////////////////////////////////////////////////
//	*	In WaveCreator, added a way of making EPSP-like responses using a biexponential function.
//		The parameters are stored in the wave descriptor file as for pulse trains.
//	*	Note that the taus that describe the time course for the biexponentials are accessed by clicking
//		the "Biexp" checkbox while holding down the shift button.
//  J.Sj. 2006-07-12
//////////////////////////////////////////////////////////////////////////////////
//	*	Added an are-you-sure dialog box when trying to restart MultiPatch, in case this Macros menu item was
//		chosen by mistake.
//	*	Added a LoadData panel that can be accessed from the Macros menu. This panel loads the most recently
//		acquired data and displays it in up to four graphs, one for each channel. In this panel, the "grab" button
//		takes the waves suffix numbers in the SwitchBoard panel and subtracts the number of repetitions chosen
//		and stores these values in the LoadData panel. The load data button does exactly that, while the close
//		button closes.
//  J.Sj. 2006-04-08
//////////////////////////////////////////////////////////////////////////////////
//	*	Changed the 'Auto X' button to also do 'Auto Y' if user holds the shift key. Similarly, if holding the shift key
//		while pressing one of the 'ApX' buttons, the Y axis is autoscaled.
//  J.Sj. 2006-03-17
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a global string variable "root:MP:PM_Data:CustomProc" which -- if it is not empty -- will be executed
//		in the EndOfScanHook. Use this to make custom adjustments to acquired waves. Example:
//			root:MP:PM_Data:CustomProc	="print pi"
//		Change "print pi" to your procedure of choice.
//  J.Sj. 2005-08-02
//////////////////////////////////////////////////////////////////////////////////
//	*	Modified DoSpreadTracesInGraph so that the rare case when all waves are exactly zero is handled correctly
//	*	Added a Percent Reduction setting in MultiMake 2, to account for the fact that somatic spikes require less
//		current when there is a dendritic depolarization. Set the Percent Reduction to e.g. 80% to reduce to this
//		number the amount of current that is injected in the soma during the "Both" condition.
//	*	Added PassiveCheck check boxes to the MultiMake 2 panel, in case there are two dendritic recordings, 
//		and one is meant to be passive (i.e. only monitoring spikes, not actually injecting any current).
//  J.Sj. 2005-05-19
//////////////////////////////////////////////////////////////////////////////////
//	*	Modfied the Averager so that averaged traces are aligned at zero on the y axis -- good for continuous
//		monitoring EPSPs, for example.
//  J.Sj. 2005-03-18
//////////////////////////////////////////////////////////////////////////////////
//	*	Added checkbox so that voltage clamp pulses can be added during the baseline in the ST_Creator.
//  J.Sj. 2004-11-24
//////////////////////////////////////////////////////////////////////////////////
//	*	Made an adapt for cycling button in the WC_RangeGraph that simply renames all the waves
//		in this window to end in _ST_1, _ST_2, etc to enable use with the cycling button in ST_Creator
//	*	Added Go to ROI and Grab ROI buttons in the MultiPatch_ShowInputs window.
//  J.Sj. 2004-10-25
//////////////////////////////////////////////////////////////////////////////////
//	*	Made a new panel -- MultiMake 2 -- that can be brought up from the ST_Creator panel. This
//		panel is used for the making of multiple waves for studying the effect of dendritic depolarizations on
//		action potential back-propagation using the 2-photon. Very specialized panel -- not likely to be
//		useful for other purposes.
//  J.Sj. 2004-10-25
//////////////////////////////////////////////////////////////////////////////////
//	*	Removed GoToLineScanAnalysisButton and made a GoToMP285Button instead.
//  J.Sj. 2004-10-18
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed the freezing problem when using external triggering with the ITC18. Solved this by using
//		a background task which polls the ITC18 board for the number of desired samples. The new solution
//		should also solve the potential problem of the stack building up, as the recursion is eliminated.
//  J.Sj. 2004-09-30
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixing external triggering when using the ITC-18 board. Problem that remains: Computer will freeze up
//		completely when using the external trigger in a pattern. I should fix this by setting up a separate
//		background task for the ITC-18. One other potential problem is that the stack may build up
//		since the whole thing is massively recursive.
//  J.Sj. 2004-09-15
//////////////////////////////////////////////////////////////////////////////////
//	*	Adapting MultiPatch for use with ITC-18 on a Windows XP machine.
//	*	IMPORTANT: Moved the settings from "root:Users:Jesper:" to "root:". (User folders are managed
//		differently, especially here at Wolfson Institute, since there is a central server to which data is
//		automatically backed up.)
//  J.Sj. 2004-09-15
//////////////////////////////////////////////////////////////////////////////////
//	*	In ST_Creator, added checkboxes for dendritic recordings. When checked, the 
//		sealtest pulse is removed from both induction and baseline traces. Also, current pulses
//		(meant to produce spikes) during the baseline are replaced by the sealtest pulse. The
//		corresponding replacement of baseline pulses by the sealtest pulse is performed for
//		channels in voltage clamp as well as when checking the MM Poo V Clamp checkbox.
//  J.Sj. 8/4/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Loading settings file now dumps loaded info to command window.
//  J.Sj. 7/6/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a Averager panel, that will average waves in real time at a given position. This could
//		be used for loose-patch searching of connected pairs while recording from the postsynaptic
//		cell in whole-cell configuration.
//  J.Sj. 6/25/04
//////////////////////////////////////////////////////////////////////////////////
//	*	WC_MakeRange now displays the waves that are created in a single window. Also, graph
//		from the WC_DisplayOutputWaveGraph routine is suppressed to reduce clutter.
//  J.Sj. 6/24/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed bug associated with RealTimeAnalysis when extracting input resistance from
//		traces with the sealtest at the *end* of the wave.
//  J.Sj. 4/22/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a checkbox to ST_Creator so that the sealtest can be put at the end of the waves instead
//		of at the beginning.
//	*	Tried to fix the realtime analysis of input resistance in the PatternMaker so that it can at
//		least *sort of* handle the analysis of waves that have the sealtest at the end of the wave.
//		This little fix assumes that waves were created using the ST_Creator, and *not* using the
//		WaveCreator.
//	*	Made a new panel -- MultiMake -- that can be brought up from the ST_Creator panel. This
//		panel is used for the making of multiple waves for the studying of AP-EPSP coincidence
//		along with 2-photon imaging. This panel is very specialized and probably not very useful for
//		other applications.
//	*	Fixed the external triggering in the PatternMaker. Added a feature so that patterns are free-
//		running (no background task or timing of waves involved) when external trigger is selected.
//  J.Sj. 4/21/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed bug: R_pip procedure does not work with external triggering. Catch this using an
//		abort dialog box.
//  J.Sj. 4/20/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added button for Kazuo Kitamura's LineScanAnalysis panel.
//  J.Sj. 4/16/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added external triggering feature. This mostly involved changes in the National Instruments
//		plug-in procedure "MP_Board_NIDAQ_2PLSM." The external triggering needs to be refined a bit.
//	*	Seems to be working sufficiently well with Svoboda's ScanImage software.
//  J.Sj. 4/8/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added auto-scale button in AcquiredWaves window.
//  J.Sj. 3/12/04
//////////////////////////////////////////////////////////////////////////////////
//	*	<Concatenate waves> no longer needed?
//	*	Modified MultiPatch to work in Demo mode without the NIDAQ driver. (small stupid bug)
//  J.Sj. 3/08/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added function in SpikeTimingCreator to export waves as .txt files to VClamp.
//		Creates the directory "MP_WaveExport" in the root of the HD, where the .txt
//		files are saved.
//  J.Sj. 2/27/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Added multiple ROIs
//	*	Added "quick zoom-in on spike" function
//	*	AcqGainSet is now included in the Settings file and is loaded automatically on start-up
//	*	Added progress bar during start-up.
//  J.Sj. 2/17/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Panels (not graphs or any other kinds of windows in Igor) are positioned based on pixels on a Mac,
//		but based on ScreenResolution on a Windows machine. Fixed bugs due to this difference.
//  J.Sj. 2/6/04
//////////////////////////////////////////////////////////////////////////////////
//	*	ST_Creator: Output windows had weird sizes.
//	*	WFM generation did not work with the NI6713 board unless the total number of samples
//		were even. I added a clumsy check for this in PrepareToSend(), and I also made a quick
//		fix in ProduceWave(). These fixes were based on adding a trailing zero sample to make the
//		output wave(s) contain an even number of samples. These fixes may come back to haunt
//		me in the future. *** CAREFUL ***
//	*	Data acquisition would not work unless I set the update limit to something lower than the
//		default value of 100 microsec (a strangely high default value!). I set it 1 microsec, although
//		I must keep in mind that ***IT MAY PRODUCE PROBLEMS IN THE FUTURE***
//	*	Adapted the NIDAQ routines to work with two boards on the Hausser in vitro 2-photon rig. This
//		assumes there is one MIO board for input and one 8-channel output board for output (currently
//		using PCI-6052E for input and PCI-6713 for output).
//	*	Fixed problem with the Parameter Log positioning
//  J.Sj. 1/27/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Started adapting MultiPatch to Igor 5.0 and to Windows XP
//  J.Sj. 1/26/04
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed bug in PatternMaker that made the interpattern-ISI become IPI+last ISI
//	*	Fixed the AppearanceMode in the RealTime Analysis graphs -- it is now remembered
//		correctly
//	*	SingleSend routines now check that it is not trying to send a text wave.
//	*	RpipProc now works with ITC18
//	*	Fixed bug in notebook: Notes always end up at end of file now.
//  J.Sj. 7/16/03
//////////////////////////////////////////////////////////////////////////////////
//	*	Added time stamping of waves using the wave note.
//	*	The wave note now includes information on the date, time, the Igor DateTime, the channel
//		gain, and the units ascribed to this channel (which also tells you whether voltage or current
//		clamp was used).
//	*	Fixed various bugs associated with adapting the software to the ITC18 board. Tested that
//		cycling of waves and that repeating of patterns work. Tested that timings when switching
//		ISI from one step to the next step is correct.  Timings of the background task is less accurate
//		than with the NI boards (because the end-of-scan hook has to be simulated, which results in
//		some slop in the timings), and most often leads to a <5% systematic increase in the ISIs.
//  J.Sj. 7/15/03
//////////////////////////////////////////////////////////////////////////////////
//	*	Software now functions with the ITC18 board.
//	*	Fixed bug in PatternMaker that made the interpattern-ISI rubs off on the first step of the
//		second (and ensuing) pattern runs.
//	*	Fixed bug in Wave Creator that made Command Level propagate from current channel to all
//		other channels.
//  J.Sj. 7/14/03
//////////////////////////////////////////////////////////////////////////////////
//	*	Beginning work to adapt the program for use with either National Instruments or Instrutech
//		boards.
//  J.Sj. 6/17/03
//////////////////////////////////////////////////////////////////////////////////
//	*	ST_Creator spikes during baseline can now be reversed in order, in case LTD window is
//		_very_ wide for 30 Hz baseline.
//  J.Sj. 12/13/02
//////////////////////////////////////////////////////////////////////////////////
//	*	ST_Creator and the PatternHandler can now handle cycling through waves, more specifically
//		intended for alternating induction waves.
//  J.Sj. 2/27/02
//////////////////////////////////////////////////////////////////////////////////
//	*	ST_Creator can now concatenate induction waves with previously exisiting induction waves,
//		thus considerably increasing the flexibility of these waves. For example, one can produce
//		induction waves which will induce LTD in both directions in a bidirectionally connected
//		pair even at 0.1 Hz.
//	*	PatternHandler appearance mode switch button was added.
//	*	PatternHandler size switch button was improved.
//  J.Sj. 2/18/02
//////////////////////////////////////////////////////////////////////////////////
//	*	ST_Creator takes RelDispl into account when calculating length of induction waves. This is
//		good for creating induction waves to be used during the baseline.
//  J.Sj. 1/17/02
//////////////////////////////////////////////////////////////////////////////////
//	*	Popup menus in SwitchBoard and PatternMaker only list waves whose names start with
//		"Out", to avoid clutter in the popup menus.
//  J.Sj. 12/12/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a percentage wave scaling for the ST_Creator panel. The occasional cell may need much
//		more or much less current than the others for spiking, which may produce double-spiking
//		and complicate the analysis of redistribution of synaptic efficacy. There is one percentage
//		per channel, which scales all current injections on that particular channel accordingly,
//		EXCEPT the sealtest current injection. Voltages for extracellular stimulation are also scaled.
//		Voltage clamp voltage injections are also scaled, again excepting the sealtest step.
//	*	The dumping of stats to the notebook was updated accordingly.
//  J.Sj. 10/10/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Note that the pattern information dumped to the notebook by the PatternHandler does not
//		include any information whatsoever about the presence of random firing. This is completely
//		defined by whether a wave at a certain step is a text wave or a numerical wave. May want
//		to fix this in the future.
//	*	The slave computer was completely by-passed in that it doesn't "know" about random firing
//		or text waves. The master computer adapts the pattern if it encounters text waves and creates
//		a pattern for the slave computer with the corresponding number of steps with only one
//		iteration each. BE AWARE OF THIS WHEN UPDATING THE SLAVE COMPUTER SOFTWARE IN
//		THE FUTURE!!!
//	*	PatternMaker was updated to handle random firing, as described by text waves containing
//		lists of the numerical waves to be sent.
//	*	RandomSpiker produces a text wave with a list of all the random spike waves. This wave will
//		be used by the PatternMaker for the generation of random spike train patterns.
//	*	RandomSpiker can now produce extracellular waves.
//	*	RandomSpiker dumps stats to notebook.
//  J.Sj. 7/9/01
//////////////////////////////////////////////////////////////////////////////////
//	*	RandomSpiker was fixed so that uniform spiking can be generated in certain circumstances.
//	*	Interface was improved.
//	*	PatternMaker still needs to be updated to quickly handle random spike waves.
//  J.Sj. 7/8/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Adding a random spiking generating feature to the ST Panel. Did not finish, although core
//		code was written. Want uniform spiking, but got gaussian, due to the summation of two
//		uniform distributions.
//  J.Sj. 7/5/01
//////////////////////////////////////////////////////////////////////////////////
//	*	The long depolarizing current injection in the ST_Creator is now centered around the
//		entire spike train, and not just the first spike of the spike train. Long depolarizing current
//		injections can now be used with high-frequency protocols as well.
//  J.Sj. 6/21/01
//////////////////////////////////////////////////////////////////////////////////
//	*	"Range feature" in WaveCreator: The user can now create a set of waves for one channel based
//		on a range of values. The range of values must be in the wave "MP_Values" localized in the
//		root directory. The range of values will affect one of six parameters, these parameters being:
//			1. Number of pulses
//			2. Pulse amplitude
//			3. Pulse duration
//			4. Pulse frequency
//			5. Displaced relative origin
//			6. Command level
//		The parameter is chosen by selecting the correspondingly numbered checkbox. Only the
//		parameter in the currently selected slot will be be affected. Waves will only be made for the
//		currently selected channel. Notes will be taken as if the user had pressed the "Create this
//		wave" button several times. The range feature can be used for, e.g.:
//			- I-f curves
//			- V-I curves
//			- measurements of inactivation time constants in voltage clamp
//		etc.
//	*	Added a button to simplify the editing of the MP_Values wave.
//	*	Added another button that automatically updates the PatternMaker panel with the waves
//		created using the above-mentioned range feature. Input and output checkboxes in the
//		PatternMaker that correspond to the currently selected channel will be set. Input and output
//		checkboxes corresponding to the other three (and not currently selected channels) will
//		be set or unset according to the "Wave in use" checkbox for those channels.
//  J.Sj. 4/29/01
//////////////////////////////////////////////////////////////////////////////////
//	*	WaveCreator: Extensive recoding to allow for more flexible wave creation. Each wave
//		descriptor now has ten slots, each of which corresponds to one of the "old-format" wave
//		descriptors. Each slot can be used (or not used -- see checkbox) to add more complex wave
//		forms. Furthermore, each slot can be additive or absolute (again, see corresponding
//		checkbox). The only thing not allowed for thus far are ramps. WaveCreator is still
//		compatible with old-format wave descriptors that were previously saved, and will load these
//		into the currently selected slot (at the same time activating that slot).
//  J.Sj. 4/25/01
//////////////////////////////////////////////////////////////////////////////////
//	*	ST Creator: Current injection and current duration in I clamp can now be different during
//		the induction as compared to during the baseline.
//  J.Sj. 4/13/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Added features to ST_Creator panel:
//		-	Added recovery pulse to baseline spike trains. Wave lengths etc adapt to check box value.
//	*	Fixed minor bug causing extracellular pulses to be two samples wide, instead of one sample.
//  J.Sj. 4/10/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Added features to ST_Creator panel:
//		-	All spikes during the induction on any one channel can be removed.
//		-	A negative current injection between the spikes during the induction can be added.
//	*	Fixed bug: Elapsed time is not reset in between the repeats of a repeating pattern.
//  J.Sj. 1/17/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Adapted the panels for use with Igor Pro 4.0.
//	*	Added time-measuring feature into PatternHandler, so that the elapsed minutes and seconds
//		are displayed automatically.
//	*	Added a red dot that marks the current step in the PatternMaker panel.
//  J.Sj. 1/16/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Added feature to SpikeTiming panel so that in a spike train delivered during the induction,
//		either only the first or the last spike can be kept for a particular channel. This way, it is
//		possible to have pre- or postsynaptic bursting coincident with only a single pre- or post-
//		synaptic spike.
//	*	Changed the layout of the SpikeTiming panel. Parameters were better grouped, to clarify
//		things.
//	*	Fixed bug in SpikeTiming panel. When changing the padding-at-end parameter, the wave-
//		lengths (for the induction and for the basline) were not updated automatically.
//  J.Sj. 1/4/01
//////////////////////////////////////////////////////////////////////////////////
//	*	Added feature to SpikeTiming panel so that a short hyperpolarizing current injection can be
//		added right after the long depolarizing current. This is to test the hypothesis that the de-
//		polarizing current step is inactivating I_A, which leads to failure of action potential back
//		propagation. The hyperpolarizing current step after the depolarizing current step is needed
//		to bring V_m back to at least normal hyperpolarization level, so that any LTP that is pro-
//		duced is sure to have nothing to do with the depolarization per se, but only with the in-
//		activation of I_A.
//  J.Sj. 12/19/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Added feature to SpikeTiming panel so that a long depolarizing current injection can be added
//		to the post-synaptic wave during the induction. The idea is that this will substitute for the
//		need for large EPSPs, or for high K+-induced depolarization of the cell.
//  J.Sj. 11/18/00
//////////////////////////////////////////////////////////////////////////////////
//	*	The video acquisition routines were bugged. Fixed this.
//  J.Sj. 10/3/00
//////////////////////////////////////////////////////////////////////////////////
//  Fixed some bugs related to having right-side axis for voltage clamp.  Added variables for ROI.
//  These changes are labelled KM 9/25/00.
//   Procs affected:  InitMultiPatch; MultiPatchPatternMaker; DA_DoShowInputs; PM_TakeROIProc;
//  PM_ToggleROIOnOffProc.
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed minor bug related to the re-sizing of the RT Analysis graphs.
//	*	The updating of the window showing the acquired waves is now smoother.
//  J.Sj. 9/24/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Zoom-in of the graph showing the acquired waves now happens automatically if the Zoom
//		checkbox in the SwitchBoard is checked. This is good for monitoring EPSPs, EPSPs, sealtest
//		steps etc. In effect, this renders the Region-Of-Interest function in the PatternMaker
//		obsolete, but it was kept it for the moment; it may be removed in a future version.
//	*	The acquired waves are now scaled to either [pA] or [A] in voltage clamp, and either [V] or
//		[mV] in current clamp by checking the appropriate checkboxes in the SwitchBoard panel.
//	*	Added the possibility to save the most important settings of the SwitchBoard panel to file:
//		-	Input and output gains in both voltage and current clamp.
//		-	The channel notes that names the amplifiers in the SwitchBoard panel.
//		-	The units of the acquired waves (pA/A, mV/V), as described in the above bullet.
//	*	The program looks for the file "Default_Settings" in the "MultiPatch Parameters" folder
//		upon startup. The user should save a settings file under this name to avoid having to click
//		cancel every time the program starts up and cannot find this file.
//	*	The WaveCreator panel can now be closed without causing problems. This avoids screen
//		clutter.
//	*	The boolean global flag "ShowPanelsOnStartup" decides whether the WaveCreator and
//		PatternMaker panels will be displayed on startup.
//	*	The RpipProc is blocked when a pattern is running, to avoid accidentally injecting
//		cells with a huge current.
//	*	Added a button to the PatternMaker panel for quick re-sizing of the RT_Analysis plots.
//	*	Speed up and optimized the start-up of the panel.
//  J.Sj. 9/21/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Added Inter-Pattern-Interval SetVar for the amount of time in between the repetitions of
//		a pattern.
//	*	Fixed bug in PatternMaker, reported by Chaelon and by Kate. Computer would interrupt
//		itself when repeating a pattern, so that the last iteration of the last step would be truncated
//		by the next repetition of the pattern. This fix was related to the above bullet.
//  J.Sj. 9/17/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed bug in R_pip procedure. Wrong gains were used occasionally.
//  J.Sj. 9/4/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed the real time sealtest analysis to work in v clamp.
//	*	Bug in WaveCreator reported by Chaelon was fixed. Units on y axis are now fine.
//	*	Fixed bug in PatternMaker, where inappropriate handling of axes would produce an error
//		message dialog box at the start of a pattern under some circumstances. Chaelon found the
//		error.
//	*	Fixed the SpikeTiming panel for Alanna so that it can produce waves for the Bi&Poo type of
//		protocol (Bi&Poo, 1998, J.Neurosci.) -- Bi & Poo did the baseline in V clamp and the 
//		induction in I clamp.
//	*	Fixed bug that produced inaccurately scaled output waves in SpikeTiming Creator. Gains
//		were specified by the wrong source.
//  J.Sj. 8/29/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Finished adding voltage clamp. This is a major revision.
//	*	Did some final touches on the WaveCreator panel.
//	*	There are now separate input and output gains for voltage and current clamp. These are used
//		automatically, as the voltage clamp switchbox is toggled.
//	*	Adapted the SpikeTiming panel so that it can handle voltage clamp.
//	*	Adapted the PatternMaker panel, so that one can use it in voltage clamp mode. RealTime
//		analysis procedure should now work in voltage clamp and in current clamp at the same time.
//		I expect bugs here, but these should be possible to fix quickly.
//	*	Added features for Chaelon's purposes: Patterns can now be repeated any number of times. It
//		is thus possible to "cycle" through a pattern.
//	*	Added a simple button to the PatternMaker panel so that one can quickly shift a pattern up
//		one step. The idea is to speed things up when the user makes a mistake in the second, or third,
//		etc., step -- one can simply stop the pattern, fix the waves, shift the pattern up one step,
//		and restart it. Should only take seconds.
//  J.Sj. 8/27/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Continued work on adding voltage clamp features.
//	*	Considerably restructured the way the WaveCreator panel works, to prepare for future
//		improvements.
//	*	Cleaned up routines, sped things up, restructured naming and ordering of functions.
//  J.Sj. 8/24/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed bug associated with the updating of gains.
//	*	SpikeTiming Creator can now handle extracellular channels.
//	*	Added a button for the making of only the extracellular wave(s), to speed things up and save
//		space in the notebook. Usage: Create all wave using "Make the waves" button _first_. Then
//		you can change the amplitude of the extracellular waves quickly by using the "Make extra-
//		cellular wave" button.
//  J.Sj. 8/7/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed a bug: PatternHandler would record waves of the length of the first wave sent on the
//		first step only. Now input waves are of the same length as the output waves in the current
//		step of the pattern.
//  J.Sj. 7/11/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Fixed a few bugs associated with the changes made on 6/26/00:
//		-	Wave amplitude in ST_Creator was set too low.
//		-	Baseline 1 stability check bug which gave rise to repeated display of the same value was
//			fixed.
//		-	The "Send Once" button did not work as expected with ST_Creator, because it would make
//			input waves whose length would match that of the 'TotalDur' variable in the
//			WaveCreator.
//  J.Sj. 6/29/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Added the SpikeTiming Creator panel, which is to be used to _quickly_ generate waves once
//		you have one or several pairs that are connected. The panel should be rather idiot-proof, and
//		scales the length of waves according to the number of pulses that are contained, the number
//		of channels that are used, etc. The SpikeTiming Creator panel can also modify a typical
//		spike induction pattern that must be already loaded into the PattterMaker panel. The
//		ST Creator changes the checkboxes for the inputs and the outputs in the three first steps,
//		according to what the user selected in the upper row of checkboxes in the ST Creator panel.
//		The idea is to speed up everything and reduce the risk of LTP washout.
//	*	The realtime analysis of EPSP amplitude was changed once again. Now four EPSP positions
//		can be picked using the 'Pick EPSP' button. The trace on which the round cursor is positioned
//		decides which channel the EPSP position belongs to.
//	*	A short routine was included in the realtime analysis procedures that tells the user if the
//		baseline in a typical spike-timing induction pattern is stable. The stability criterion is
//		that of Markram et al. (Science, 1997), i.e. the first and the second half of the baseline must
//		not change more than 10%.
//  J.Sj. 6/26/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Added extra manipulator for AxoClamp 2B ME2. Changed the gains accordingly.
//  J.Sj. 6/14/00
//////////////////////////////////////////////////////////////////////////////////
//   *	I did extensive modifications to the PatternManager routines. Now the pattern and the waves
//		are first transferred to the slave computer, which then loads them and prepares to run its
//		"own pattern". The only synchronization is provided through the trig signal from the start
//		of the data acquisition on the board of the master computer. A dummy wave with 100 samples
//		is acquired on the slave computer. The reason for this is to obtain access to the End-of-scan
//		hook of the fNIDAQ_ScanAsynchStart instruction. This hook is then used on the slave
//		computer to initiate another iteration of the pattern, as specified by the pattern originally
//		passed over from the master computer. Most of the real changes were in the AppleScripting
//		routines on the slave computer. The end result is a _considerably_ improved efficiency
//		with the patterns. Interstimulus intervals can now easily be as low as 4 seconds for waves
//		of around 2 second duration, without problem. This should be sufficient for most applications.
//	*	The PatternHandler routines on the master computer were sped up, mainly by avoiding
//		redrawing the graph displaying the newly acquired waves, but also by generally speeding
//		up the code. Again, this should help keeping the collisions of individual scans occuring too
//		often. This latter problem is now minimal, but even if it does happen, it seems to be less
//		likely to cause a crash. The crashing must have been due to the frequent AppleScript calls
//		that were previously employed. N.B.! Most of these improvements only apply if the waves
//		are killed directly after acquisition.
//	*	The function "for realtime analysis of EPSP amplitudes" that was added on 4/8/00 was
//		altered so that the user only has to define the beginning of the EPSP peak using the left
//		(top) cursor. This speeds the handling up, and makes the procedure less cumbersome.
//	*	A bug causing the MSTimers to be used up was fixed. The 'dt_vector's are now no longer
//		full of zeros towards the end of an experiment!
//  J.Sj. 6/6/00
//////////////////////////////////////////////////////////////////////////////////
//   *	Added small & silly routine to measure access resistance from the seal test in the top plot.
//  J.Sj. 5/27/00
//////////////////////////////////////////////////////////////////////////////////
//   *	In an attempt to reduce the 60 Hz noise in averaged waves obtained from patterns, a uniform-
//		noise variable was added to the ISI in the PatternHandler. Before, the waves were acquired
//		at virtually exactly the same time with respect to the phase of the 60 Hz noise, so this noise
//		became additive. The uniform noise should alleviate this problem.
//  J.Sj. 5/22/00
//////////////////////////////////////////////////////////////////////////////////
//   *	Fixed a bug related to changing the input and the output gains. Gain waves are now updated.
//  J.Sj. 5/13/00
//////////////////////////////////////////////////////////////////////////////////
//   *	60Hz-like noise in recordings may be due to aliased high-frequency noise on the board. This
//		might be alleviated by changing the sampling frequency to an uneven number. Tried changing
//		the default sample frequency to 10001.1 Hz.
//  J.Sj. 4/15/00
//////////////////////////////////////////////////////////////////////////////////
//   *	Added function for realtime analysis of EPSP amplitudes. The baseline in the trace before
//		the EPSP and the peak of the EPSP itself are defined by the positions of the cursors in the
//		plot containing the acquired waves. To use: (1) acquire a wave (2) select the desired baseline
//		before the EPSP using the cursors (3) press 'grab baseline position' button (4) repeat for
//		the EPSP peak and press 'grab EPSP position' button. Cursors can be in any order. EPSPs
//		are searched for in any input wave acquired during a pattern.
//	*	Added a 'close the plots' button in the PatternMaker. This button closes the sealtest plot, the
//		membrane potential plot, and the above-mentioned EPSP amplitude graph.
//	*	All the waves used to generate the above plots -- sealtest, membrane potential, EPSP
//		amplitude -- are now copied to the root and timestamped when a pattern is either termi-
//		nated or reaches its end.
//  J.Sj. 4/8/00
//////////////////////////////////////////////////////////////////////////////////
//   *	Added function for automatic measurement of pipette resistances.
//  J.Sj. 4/1/00
//////////////////////////////////////////////////////////////////////////////////
//   *	Can now opt to have a constant current offset parameter in output waves.  "CommandLevel" is 
//     	the new variable, found on WaveCreater Panel.  Adds a constant current to the waves, default 
//  		is zero.  Saves and Loads as Descriptor Params;  Loads older descriptors (which don't contain
//		a commandlevel param)just fine.
//	*	Potential bug that i think i've fixed:  the offset current would remain after the output wave
//		is over;  now the output wave is designed to make the last point always return to zero. 
//  KM 3/30/00
//////////////////////////////////////////////////////////////////////////////////
//	*	The user can now opt to have acquired waves killed right after acquisition. The idea is to save
//		memory and to prevent Igor from crashing, due to Igor's apparent inability to properly
//		free up previously allocated memory.
//	*	As a side-effect, input waves used with patterns are no longer created before the pattern
//		starts to run. This means that each acquisition step in a pattern will be slightly slower, since
//		the input waves have to be created at run-time. N.B.! Make sure that patterns do not have too
//		short ISIs! Although the difference in processing time as compared to before should be ever
//		so slight.
//	J.Sj. 3/13/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Plots of sealtest and resting membrane potential are generated in realtime during the run of
//		a pattern.
//	*	A ROI (Region Of Interest) function was added to the PatternMaker. The 'GrabROI' button
//		takes the axes from the current 'MP_ShowInputs' graph and stores them. If the 'ROI' check-
//		box is checked as a pattern is running, the 'MP_ShowInputs' graph will automatically be
//		zoomed-in to the previously selected axes.
//	*	A button was added to call the 'MP_DatAn' data analysis panel to the front, if it exists.
//	J.Sj. 3/11/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Default wave parameters were changed, to separate the spike trains more.
//	*	Default sealtest length was increased.
//	*	There are now two sealtest padding parameters in the WaveCreator -- one before and one
//		after the sealtest pulse.
//	J.Sj. 3/8/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Added a checkbox to the WaveCreator called "ST". When this is checked, the suffix string to
//		the right of the checkbox is added to the end of _all_ four wave names as they are being
//		created. The idea is that this would be a fast way of generating waves with different names,
//		using the actual wave name as a base name.
//	*	Fixed a bug associated with the PatternMaker. Patterns that were loaded would not behave
//		correctly because the OldNSteps variable was not updated.
//	*	Notes are added to the notebook at end of each step of a pattern, to simplify data analysis.
//	J.Sj. 3/6/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Made the default waves 2500 ms and extended the default sealtest padding to 300 ms.
//	*	Additional bug in PatternMaker was fixed. Patterns should now switch correctly from one
//		step to another. Previously, the switch was incomplete.
//	J.Sj. 3/4/00
//////////////////////////////////////////////////////////////////////////////////
//	*	All SetDataFolder instructions were removed from the code. Only direct addressing of
//		variables and waves is now used. This was done to avoid a possible bug.
//	*	Descriptions of patterns and wave descriptors are now dumped to the notebook as soon as they
//		are loaded.
//	*	Minor bug in PatternMaker was fixed.
//	J.Sj. 2/28/00
//////////////////////////////////////////////////////////////////////////////////
//	*	The waves at which a pattern is started and ended (or terminated) are described in the 
//		notebook.
//	*	Changes to parameters done in the WaveCreator will not affect the wave in question
//		_until_ the user presses a button to create the wave. The temporary wave is created under
//		the wavename 'MP_ShowWave'. DO NOT SEND THIS WAVE TO THE BOARD, since it is _not_
//		scaled appropriately for outputting.
//	*	Wave descriptors can now be saved and loaded in the WaveCreator. This means that the same
//		wave shape can be loaded into the four different channel slots, to quickly produce the same
//		wave on all four channels. One can also prepare waves for a "standardized" experiment, which 
//		is good when one is doing the same stuff over and over and over and over.
//	*	Delay between spike trains in the deafult values for the WaveCreator were increased. This
//		was done to accommodate better for recordings at room temperature.
//	J.Sj. 2/23/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Bug in PatternHandler fixed. No unwanted waves are sent now!
//	*	PatternHandler kills unused waves if pattern is terminated.
//	J.Sj. 2/22/00
//////////////////////////////////////////////////////////////////////////////////
//	*	Waves are automatically stored as soon as they are acquired. (Stored in the experiment
//		folder, or in the same folder as the experiment, if the experiment is packed.)
//	*	PatternMaker now describes the pattern in the notebook before it is being run.
//	*	Seal test default values were changed to smaller value and shorter duration. (Appropriate
//		for experiments at room temperature.)
//	J.Sj. 2/19/00
//////////////////////////////////////////////////////////////////////////////////
// Changing amplifier on the second channel to AxoPatch 1-B
// 		Ch.2 headstage 1x
//        -------------
//	1)	Variable output gain, but preferrably set to alpha = 10x
//	2)	Input gain is either 20 mV/V or 1 mV/V in voltage clamp
//	3)	Input gain is 10 pA/mV in current clamp = 10 nA/V
//	4)	Hence, in current clamp, you get 20*10 = 200 pA/V = 0.2 nA/V for the 20 mV/V setting
//	5)	In this program, a wave of ones corresponds to a wave of 1 nA
//	6)	So the scaling factor for the external command (the output gain) is 0.2x
//	JSj, 2/16/2000
//////////////////////////////////////////////////////////////////////////////////
// BEWARE! Input wave names are no longer tagged with the channel number. JSj, 2/16/2000
//////////////////////////////////////////////////////////////////////////////////
//    In OnceProc changed WaveStr to include an additional board gain in the data acquisition parameter
//  string (to '45) in order to reduce quantization problems (default gain of 1 resulted in quantization
//  on the order of 2/10s of millivolt, given an 10x amplified signal).  Change to 5, and quantization is
//  below noise threshold at 1/25 of millivolt.  good for small (even <1mV) PSP signals.  no rescaling
//  necessary.   
// KM 20100
//  ...but problem with saturation at -100mV;  Changed to be a global variable in root:MP:AcqGainSet
//  Change to smaller value if saturation is a problem. 	22000 KM
//////////////////////////////////////////////////////////////////////////////////
//  Current amplifier setup:
//    Output from computer to Amps:
//  		Ch1 - Axoclamp 2B ME1/ headstage H=0.1
//				External Command gains:  10*H nA/V	= 1 nA/V
//		Ch2 - Axoclamp  2B ME2/ headstage H=1
//				External Command gains:  10*H nA/V	=  10 nA/V
//		Ch3 - Axopatch 200B
//				External Command (front switched(beta=1))  2/beta nA/V =  2 nA/V  
//		Ch4 - Not currently in use.
//
//	 Input to computer from Amps:
//  		Ch1 - Axoclamp 2B ME1
//				Amp Output gain:  10mV/mV
//		Ch2 - Axoclamp 2B ME2
//				Amp Output gain:  1mV/mV
//		Ch3 - Axopatch 200B
//				Amp Output gain:  alpha mV/mV   = 10mV/mV
//					(**alpha is variable, usually 10; front panel control-> must check it; could use telegraph)
//		Ch4 - Not currently in use.
//
//  KM 11/30/99
//////////////////////////////////////////////////////////////////////////////////

Menu "Macros"
	"Initiate the MultiPatch panel", AreYouSure_Restart()
	"Load recently acquired data", JT_MakeLoadWavesPanel() // MakeLoadWavesPanel() has been deprecated as of 26 Mar 2021, JSj
	"Add custom procedure after acq",HowToAddCustomProc()
	"-"
end

Function HowToAddCustomProc()

	Print "To add a custom procedure that is executed after each acquired wave, alter the below"
	Print "string variable to contain the executable statement of choice:"
	Print "\troot:MP:PM_Data:CustomProc	=\"print pi\""
	Print "To stop execution, just set string to the empty string, \"\"."
	
End

Macro AreYouSure_Restart()

	PauseUpdate; Silent 1

	DoWindow MultiPatch_Switchboard
	if (V_flag)
		DoAlert 1,"Do you want to reastart MultiPatch?\r(Cannot be undone.)"
		if (V_flag==1)
			Print "Restarting MultiPatch."
			InitMultiPatch()
		else
			Print "Did not restart MultiPatch."
		endif
	else
		Print "Starting up MultiPatch."
		InitMultiPatch()
	endif
	
End

Macro InitMultiPatch();

	PauseUpdate; Silent 1
	
	Print "============= Setting up ============="

	NewDataFolder/O root:MP						// Create dedicated RAM data folder for MultiPatch
	SetDataFolder root:MP
	killwaves /a/z									// Clear everything & start from scratch
	killstrings /a/z
	killvariables /a/z
	Variable/G	Progress_Val
	Variable/G	Progress_TickSave = Ticks
	Variable/G	Progress_Counter = 0
	Variable/G	Progress_Max = 58
	String/G		Progress_MessageStr
	MakeProgressBar()
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up basic variables...")
	root:MP:Progress_Counter += 1
	
	String/G	MasterName
	PathInfo Igor
	MasterName = StringFromList(0,S_path,":")
		Print "Using path \"Igor\" to find out name of HD."
		Print "\tName of HD is: \""+MasterName+"\""
	Variable/G	DemoMode = 0						// Boolean: NIDAQ board set to demo mode...
	Variable/G	ShowPanelsOnStartup = 0			// Boolean: Show panels on startup?
	
	SetDataFolder root:								// ROOT!
	
	PathInfo Igor_Stuff
	if (V_flag)
		print "Settings are located in the Igor Stuff folder."
	else
		Print "Fatal error during start-up: Igor Stuff path not found (this is where the settings live, so this path is kind of important)"
		Abort "Fatal error during start-up: Igor Stuff path not found (this is where the settings live, so this path is kind of important)"
	endif
	String		BasePath = S_path

	NewPath/O Settings BasePath+"MultiPatch Parameters:"									// Default path for storing settings
	NewPath/O Patterns BasePath+"MultiPatch Parameters:MP_Patterns:"						// Default path for storing patterns
	NewPath/O WaveDescriptors BasePath+"MultiPatch Parameters:MP_WaveDescriptors:"		// Default path for storing patterns
	
	String/G	PatternsPath = BasePath+"MultiPatch Parameters:MP_Patterns:"					// Same as above, but as strings
	String/G	WaveDescriptorsPath = BasePath+"MultiPatch Parameters:MP_WaveDescriptors:"	//
	
	//// Set up variables, constants, etc
	
	Variable	i = 0
	Variable	j = 0
	String		CommandStr						// Used for Execute commands
	
	InitBoardVariables()							// Board-specific: Setting up variables depending on the included file   ---------BOARD HERE -----------

	NewDataFolder/O root:MP						// Create dedicated RAM data folder for MultiPatch
	SetDataFolder root:MP
	
	print "\tBasic parameters"
	
	Variable/G CellNumber = 0						// The current cell number -- for notes only

	Variable/G SampleFreq = 40000				// Sampling frequency [Hz]
	Variable/G CreateAppendsFlag = 0				// Boolean: All wave creation appends to previously existing wave
	Variable/G TotalDur = 5500					// Total wave duration [ms]
	
	Variable/G ScSc = ScreenResolution/72			// The screen scale tells Igor where to position Panels (only really applies in Windows, not on Macs)

	Variable/G SealTestFlag = 1						// Seal test at begninning of waves on or off
	Variable/G SealTestDur = 250					// Seal test duration [ms]
	Variable/G SealTestPad1 = 50					// Seal test padding -- addition of time before seal test [ms]
	Variable/G SealTestPad2= 400					// Seal test padding -- addition of time after seal test [ms]
	Variable/G SealTestAmp_I = -0.025				// Seal test amplitude in current clamp [nA]
	Variable/G SealTestAmp_V = -0.005			// Seal test amplitude in voltage clamp [V]

	Variable/G ChannelNumber = 1					// Channel number
	Variable/G SlotNumber = 1						// Slot number
	Variable/G PreviousChannel = ChannelNumber	// Remember previous channel
	Variable/G PreviousSlot = SlotNumber			// Remember previous slot
	Variable/G ChannelType = 1						// Channel type, 1 = intra i clamp, 2 = extra, 3 = intra v clamp
	Variable/G BiphasicFlag = 1						// Biphasic stimulus wave, only applicable to extracellular type
	Variable/G ShowFlag = 1						// Show the wave as the user creates it
	Variable/G UseSlotFlag = 1						// Use the current slot?
	Variable/G AddSlotFlag = 0						// Is the current slot additive? (otherwise absolute)
	Variable/G RampFlag = 0						// Is the current slot a ramp? (otherwise a pulse)
	Variable/G SynapseSlotFlag = 0					// Is the current slot a biexponential current? (otherwise a pulse)
	Variable/G SynapseTau1 = 0.3					// Rising phase tau of synapse-like biexponential [ms]
	Variable/G SynapseTau2 = 3						// Falling phase tau of synapse-like biexponential [ms]
	Variable/G NPulses = 1							// Number of pulses
	Variable/G PulseAmp = 0.7						// Pulse amplitude [nA]
	Variable/G PulseDur = 500						// Pulse duration, [ms] for intracellular, [samples] for extracellular
	Variable/G PulseFreq = 20						// Pulse frequency [Hz]
	Variable/G PulseDispl = 0						// Displacement of pulse relative to time origin
	Variable/G CommandLevel=0					//  Adds Command Current(/voltage for future Voltage Clamp) offset to whole wave (nA)  3/30/00 KM
	
	Variable/G ResetAllValue = 1					// When resetting suffixes, set them to this value

	Variable/G InputOffset = 0						// When offsetting the acquired waves, use this value
	
	Variable/G InfoBoxHandle = 0					// When producing info box messages, this keeps track of the handle
	
	String/G	GraphBaseName = "Channel_"		// Basename for graphs containing created waves
	
	Variable/G	STFlag = 0							// Flags if a SpikeTiming wave is to be created (changes the wave name on all channels by adding '_ST' at the end)
	
	Variable/G	WC_RangeStart = -0.3				// When editing range of values, start at this value
	Variable/G	WC_RangeStep = 0.2					// When editing range of values, use this step size value
	Variable/G	WC_tStep = 1000					// When editing range of values across slots, use this time step size value [ms]
	
	//// Parameters for loading data after acquisition
	Make/O/N=(4) LoadDataFromThisChannel = {1,1,1,1}	// Boolean: Load data from this channel or not?
	Variable/G	nRepsToLoad = 10							// Number of repetitions to load
	Variable/G	MP_AtLeastOneLoad = 1						// At least one channel checked
	Variable/G	LoadData_Suff1Start = 1					// Start loading at this suffix, Ch1
	Variable/G	LoadData_Suff2Start = 1					// Start loading at this suffix, Ch2
	Variable/G	LoadData_Suff3Start = 1					// Start loading at this suffix, Ch3
	Variable/G	LoadData_Suff4Start = 1					// Start loading at this suffix, Ch4
	Variable/G	LoadData_Step = 1							// Use this step size between waves
	
	//// Loading data after acquisition, but displaying as several small windows
	Variable/G	LD_xStart = 50								// Start of first response (ms)
	Variable/G	LD_xSpacing = 500							// Separation of responses (ms)
	Variable/G	LD_nResponses = 25						// Number of responses to display
	Variable/G	LD_winWidth = 75							// Window width (ms)
	Variable/G	LD_xPad = 5									// Padding before response (ms)
	Variable/G	LD_RespWin = 4								// Response window (ms)
	Variable/G	LD_latency = 10							// Latency to peak (ms)
	Variable/G	LD_pulseFreq = 30							// Pulse frequency (Hz)
	Variable/G	LD_nPulses = 2								// Number of pulse

	//// Build the data folder for the four inputs and outputs
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up I/O variables...")
	root:MP:Progress_Counter += 1
	NewDataFolder/O root:MP:IO_Data				// Create dedicated RAM data folder for MultiPatch IO data stuff
	SetDataFolder root:MP:IO_Data
	print "\tIO parameters"
	
	killwaves /a/z									// Clear everything & start from scratch
	killstrings /a/z
	killvariables /a/z
	
	Variable/G	NSlots = 10							// The WaveCreator has this many slots -- use to create more complex waves

	String/G	WaveNamesOut1 = "Out_1"			// The default output wave names
	String/G	WaveNamesOut2 = "Out_2"
	String/G	WaveNamesOut3 = "Out_3"
	String/G	WaveNamesOut4 = "Out_4"
	Make/O/T/N=(4) WaveNamesOutWave = {WaveNamesOut1,WaveNamesOut2,WaveNamesOut3,WaveNamesOut4}			// Need the above as a wave
	Make/O/T/N=(4) WaveOutVarNames = {"WaveNamesOut1","WaveNamesOut2","WaveNamesOut3","WaveNamesOut4"}		// Names of the above variables
	String/G	WaveNamesIn1 = "Cell_91_"			// The default input wave names
	String/G	WaveNamesIn2 = "Cell_92_"
	String/G	WaveNamesIn3 = "Cell_93_"
	String/G	WaveNamesIn4 = "Cell_94_"
	Make/O/T/N=(4) WaveInVarNames = {"WaveNamesIn1","WaveNamesIn2","WaveNamesIn3","WaveNamesIn4"}			// Names of the above variables
	String/G	STSuffix = "_ST"					// To be added to the end of wave names when used for SpikeTiming
	
	make/O :::$WaveNamesOut1						// Create spaceholder waves
	make/O :::$WaveNamesOut2
	make/O :::$WaveNamesOut3
	make/O :::$WaveNamesOut4

	KillWaves/Z :::$(WaveNamesOut1+STSuffix)
	KillWaves/Z :::$(WaveNamesOut2+STSuffix)
	KillWaves/Z :::$(WaveNamesOut3+STSuffix)
	KillWaves/Z :::$(WaveNamesOut4+STSuffix)

	make/O :::$(WaveNamesOut1+STSuffix)			// Create spaceholder waves for the SpikeTiming as well
	make/O :::$(WaveNamesOut2+STSuffix)
	make/O :::$(WaveNamesOut3+STSuffix)
	make/O :::$(WaveNamesOut4+STSuffix)

	String/G WaveDescriptor1 = "Params_1"		// The name of the data file that describes the output wave
	String/G WaveDescriptor2 = "Params_2"
	String/G WaveDescriptor3 = "Params_3"
	String/G WaveDescriptor4 = "Params_4"
	
	Variable/G	Cell_1 = 0							// When a new cell is registered, the cell number is placed in the right variable
	Variable/G	Cell_2 = 0
	Variable/G	Cell_3 = 0
	Variable/G	Cell_4 = 0

	SetDataFolder root:MP

	print "\tBasic parameters"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up basic variables...")
	root:MP:Progress_Counter += 1
	
	String/G	DummyStr							// Used for work-arounds in functions
	String/G	WaveListStr						// Used for the wavelist sent to the board for data acquisition
	CommandStr= "String/G CurrWaveNameOut = :IO_Data:" +:IO_Data:WaveOutVarNames[ChannelNumber-1]
	Execute CommandStr
	CommandStr = "String/G CurrWaveDescriptor = :IO_Data:WaveDescriptor"+num2str(ChannelNumber)
	Execute CommandStr							// The currently chosen channel's wave descriptor name
	Variable/G	SingleSendFlag = 0;					// Tells you that data acquisition was initiated with the 'Single Send' button, and not from a pattern
	Variable/G	AcqInProgress = 0;					// Tells you if data acquisition is in progress
	Variable/G	RpipGenerated = 0;					// Tells you if data acquisition was triggered from the Rpip procedure
	Variable/G  AcqGainSet = 1						//  used in OnceProc;  PM_PatternProc.  22000 KM

	SetDataFolder root:MP:IO_Data

	print "\tIO parameters"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up I/O variables...")
	root:MP:Progress_Counter += 1
	
	Variable/G StartAt1 = 1							// Channel#1 input waves will be numbered starting at...
	Variable/G StartAt2 = 1
	Variable/G StartAt3 = 1
	Variable/G StartAt4 = 1
	Variable/G root:MP:TempStartAt = 1
	String/G ChannelNote1 = "AxoClamp ME1"		// #### Note for channels -- for the purpose of specifying which amplifier is in use with the channel in question
	String/G ChannelNote2 = "AxoClamp ME2"
	String/G ChannelNote3 = "AxoPatch-1B"
	String/G ChannelNote4 = "AxoPatch 200B"
	Variable/G OutGain1 = 1						// Output gain in current clamp (Output refers to the output from the computer and not from the amplifier)
	Variable/G OutGain2 = 1
	Variable/G OutGain3 = 0.2
	Variable/G OutGain4 = 2
	Make/O/N=(4) OutGainIClampWave				// Corresnponding wave in current clamp
	OutGainIClampWave = {OutGain1,OutGain2,OutGain3,OutGain4}
	Make/O/N=(4) OutGainVClampWave				// Corresponding wave in voltage clamp
	OutGainVClampWave = {1,1,0.02,0.02}
	Variable/G InGain1 = 10						// Input gain  in current clamp (Input refers to the input to the computer and not to the amplifier)
	Variable/G InGain2 = 10
	Variable/G InGain3 = 10
	Variable/G InGain4 = 10
	Make/O/N=(4) InGainIClampWave				// Corresponding wave in current clamp
	InGainIClampWave = {InGain1,InGain2,InGain3,InGain4}
	Make/O/N=(4) InGainVClampWave				// Corresponding wave in voltage clamp
	InGainVClampWave = {1,1,20,20}

	Variable/G	ZoomFlag = 1				// Boolean: True --> keep the zoom-in in the graph showing the acquired waves when showing the next waves
	Variable/G	pAUnits						// Boolean: Convert to [pA] in v clamp (otherwise [A])
	Variable/G	mVUnits					// Boolean: Convert to [mV] in i clamp (otherwise [V])
	
	Make/O/N=(4) ChannelColor_R,ChannelColor_G,ChannelColor_B
	// Yellow, blue, red, green, as on the Tektronix TDS2004B digital oscilloscope
	ChannelColor_R = {59136,	26880,	65280,	00000}
	ChannelColor_G = {54784,	43776,	29952,	65535}
	ChannelColor_B = {01280,	64512,	65280,	00000}

	Make/O/N=(4) VClampWave			// Boolean: voltage clamp = true for channel in question
	Make/O/N=(4) ChannelType			// Intra- or extracellular, 1/2 *** MODIFIED 2000-08-25 J.Sj. ***		Intra (I clamp) =	1
											//																			Extra =				2
											//																			Intra (V clamp) =	3
	Make/O/N=(4,NSlots) NPulses			// Number of pulses per output wave							[channel#][slot#]
	Make/O/N=(4,NSlots) PulseAmp		// Output wave pulse amplitude [nA] or [V]						[channel#][slot#]
	Make/O/N=(4,NSlots) PulseDur		// Output wave pulse duration [ms] or [samples]				[channel#][slot#]
	Make/O/N=(4,NSlots) PulseFreq		// Output wave pulse frequency [Hz]								[channel#][slot#]
	Make/O/N=(4,NSlots) PulseDispl		// Output wave pulse displacement relative to time origin [ms]	[channel#][slot#]
	Make/O/N=(4,NSlots) BiphasicFlag		// Output wave pulse biphasic flag								[channel#][slot#]
	Make/O/N=(4) OutputOnOff				// Output wave, on/off
	Make/O/N=(4) InputOnOff				// Input wave, on/off
	Make/O/N=(4)	CommandLevel			//  Constant current offset [pA] 3/30/00 KM
	Make/O/N=(4,NSlots)	AddSlotWave	// Boolean: is pulse train in this slot additive or absolute?		[channel#][slot#]
	AddSlotWave = 0						// 0 = absolute, 1 = additive
	Make/O/N=(4,NSlots)	RampWave		// Boolean: ramps or pulses?		[channel#][slot#]
	RampWave = 0							// 0 = ramp, 1 = pulse
	Make/O/N=(4,NSlots)	SynapseSlotWave	// Boolean: Is this a biexponential or a current pulse?		[channel#][slot#]
	SynapseSlotWave = 0						// 0 = pulse, 1 = biexp
	Make/O/N=(4,NSlots)	UseSlotWave	// Boolean: Is this slot to be used?								[channel#][slot#]
	UseSlotWave = 0
	i = 0									// The first slot should default to 1 (meaning it is being used)
	do
		UseSlotWave[i][0] = 1
		i += 1
	while (i<4)
	String/G	SlotPopUpItems = ""		// Items to be displayed in the slot popup menu
	i = 0									// Make the popup string with the items
	do
		if (!(i==0))
			SlotPopUpItems += ";"
		endif
		SlotPopUpItems += JS_num2digstr(2,i+1)
		i += 1
	while (i<NSlots)
	//// Set up for all channels
	PulseAmp = 0.7
	NPulses = 0
	PulseFreq = 20
	PulseDur = 500
	BiphasicFlag = 	1
	//// Set up that is specific for certain channels, or certain slots of certain channels
	// Channel 1 -- for channel #1, need to change above as well to obtain desired change...
		ChannelType[0] = 		1
		NPulses[0][0] = 		1
		PulseDispl[0] =	 	0				// N.B.! Affects all slots on this channel
		InputOnOff[0] = 		1
		OutputOnOff[0] = 		1
		CommandLevel[0]=		0	//  3/30/00 KM
	// Channel 2
		ChannelType[1] = 		1
		NPulses[1][0] = 		1
		PulseDispl[1] = 		1200			// N.B.! Affects all slots on this channel
		InputOnOff[1] = 		1
		OutputOnOff[1] = 		1
		CommandLevel[1]=		0	// 3/30/00 KM
	// Channel 3
		ChannelType[2] = 		1
		NPulses[2][0] = 		1
		PulseDispl[2] = 		2400			// N.B.! Affects all slots on this channel
		InputOnOff[2] = 		1
		OutputOnOff[2] = 		1
		CommandLevel[2]=		0	 // 3/30/00 KM
	// Channel 4
		ChannelType[3] = 		1
		NPulses[3][0] = 		1
		PulseDispl[3] = 		3600				// N.B.! Affects all slots on this channel
		InputOnOff[3] = 		1
		OutputOnOff[3] = 		1
		CommandLevel[3]=		0	// 3/30/00 KM
	
	//// Build the data folder for the PatternMaker
	NewDataFolder/O root:MP:PM_Data				// Create dedicated RAM data folder for MultiPatch PatternMaker stuff
	SetDataFolder root:MP:PM_Data

	print "\tPatternHandler parameters"
	print "\tGoal:\t\t***************"
	printf "\tProgress:\t"

	killwaves /a/z									// Clear everything & start from scratch
	killstrings /a/z
	killvariables /a/z

	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	Variable/G	AppearanceMode = 1					// Appearance of RT waves has 3 modes
													// 0 - B&W, useful for printouts
													// 1 - New default -- easier to see
													// 2 - Used to be default
	Variable/G	SizeMode = 1						// Size of RT wave window has 2 modes
	Variable/G	SizeModeNB = 1						// Size of notebook has 2 modes
	Variable/G	PatternRunning = 0					// Boolean telling you if a pattern is running in the background
	Variable/G	PatternReachedItsEnd = 0			// Boolean telling you if a pattern running in the background just reached its end (not being terminated!)
	Variable/G	CurrentStep = 1					// The current step at which the PatternHandler is executing
	Variable/G	IterCounter = 0						// The iteration counter for the step currently being executed
	Variable/G	DummyIterCounter = 0				// Same, but counts up instead, for displaying
	Variable/G	TimerRef							// Handle for MSTimer
	Variable/G	NewStepBegun						// Boolean: Flags true when a new step in the PatternHandler was begun
	
	Variable/G	StartTicks							// The ticks counter when the pattern was started
	Variable/G	ElapsedMins						// Number of minutes elapsed since the start of the recording
	Variable/G	ElapsedSecs							// Number of seconds (minus the above minutes) elapsed since the start of the recording

	Variable/G	NSteps = 3							// Chosen number of steps for the pattern generator
	Variable/G	OldNSteps = NSteps				// When changing the number of steps, the computer needs to remember the old value...
	Variable/G	MaxSteps = 30						// Maximum number of steps
	String/G	PatternName = "Pattern #1"			// Set the default pattern name
	String/G		CustomProc	=""					// This string -- if not empty -- will be executed in DA_EndOfScanHook
	
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	Variable/G	ISINoise = 10/60					// Uniform noise in the ISI for patterns --> reduce the 60 Hz noise [s]

	Variable/G	RT_RepeatPattern = 0				// Boolean: Want to repeat the entire pattern a number of times?
	Variable/G	RT_RepeatFirst = 1					// Boolean: First time around?
	Variable/G	RT_RepeatNTimes = 10				// Number of times that the user wants to repeat the pattern
	Variable/G	RT_DoRestartPattern = 0			// Boolean: Restart the pattern? --> Used to restart pattern from EndOfScanHook
	Variable/G	RT_IPI = 10							// Inter-Pattern-Interval [s] -- used when repeating patterns
	Variable/G	CurrISI								// Store away the ISI [s] for the current step in the pattern
	Variable/G	RT_nPlotRepeats = 0				// Show this many repeats
	Make/O/D/N=(0) root:RT_PatternSuffixWave		// Keep track of all prior pattern runs
	
	Variable/G	RT_SealTestWidth = 50				// Width of window (at peak sealtest voltage = pad1+duration) used to measure input resistance [ms]
	Variable/G	RT_VmWidth = 50					// Width of window (at beginning of trace) used to measure membrane potential [ms]
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1

	make/O root:RT_SealTestWave1					// Placeholders for the corresponding waves
	make/O root:RT_SealTestWave2
	make/O root:RT_SealTestWave3
	make/O root:RT_SealTestWave4
	make/O root:RT_VmImWave1
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1

	make/O root:RT_VmImWave2
	make/O root:RT_VmImWave3
	make/O root:RT_VmImWave4
	make/O root:RT_EPSPWave1
	make/O root:RT_EPSPWave2
	make/O root:RT_EPSPWave3
	make/O root:RT_EPSPWave4
	i = 0
	do
		j = i +1
		if (j<4)
			do
				make/O $("root:RT_EPSPMatrix"+num2str(i+1)+num2str(j+1))
				make/O $("root:RT_EPSPMatrix"+num2str(j+1)+num2str(i+1))
				j += 1
			while (j<4)
		endif
		i += 1
	while (i<4)
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1

	Variable/G	RT_SealTestOnOff = 1				// Boolean: RealTime Sealtest graph on or off?
	Variable/G	RT_VmOnOff = 1						// Boolean: RealTime membrane voltage graph on or off?
	Variable/G	RT_ROIOnOff = 0						// Boolean: RealTime membrane voltage graph on or off?
	Variable/G	RT_ROI_Slot = 0						// Current slot (1 through 4)
	Make/O/N=(4)	RT_ROI_x1 = 0					// Region of interest in the input wave plot [s]
	Make/O/N=(4)	RT_ROI_x2 = root:MP:TotalDur		// [s]
	Make/O/N=(4)	RT_ROI_y1 = -0.06				// [V]
	Make/O/N=(4)	RT_ROI_y2 = 0.08				// [V]
	Make/O/N=(4)	RT_ROI_yy1 = -0.5				// for right-hand axis  KM 9/25/00
	Make/O/N=(4)	RT_ROI_yy2 = 0.5				// 
	Variable/G	RT_EPSPOnOff = 1					// Boolean: RealTime EPSP measurements on or off?
	Variable/G	RT_EPSPUseGrab = 0					// Boolean: RealTime EPSP measurements based on manually grabbed position?
	Variable/G	RT_EPSPUseMatrix = 1				// Boolean: RealTime EPSP measurements based on manually grabbed position?
	Make/O/N=(4,4) Conn_Matrix					// Booelan: Connectivity matrix for a connection from channel r to channel k
	Conn_Matrix = NaN
	Make/O/N=(4,4) Pos_Matrix					// Position of EPSP [s], notation as for Conn_Matrix above
	Pos_Matrix = NaN
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1

	Variable/G	RT_EPSPLatency = 0.007			// Latency of EPSP peak measurement in trace [s]
	Variable/G	RT_EPSPWidth = 0.002				// Width of EPSP measurement in trace [s]
	Variable/G	RT_EPSPBaseStart = -0.008		// _Relative_ start of baseline for EPSP measurement in trace [s]
	Variable/G	RT_EPSPBaseWidth = 0.006			// Width of baseline for EPSP measurement in trace [s]
	Make/O/N=(4) EPSPPosWave
	EPSPPosWave = {0,0,0,0}						// Start of EPSP measurement in trace [s]
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	
	Variable/G	RT_StableBaseline = 1				// Boolean: Test for baseline stability?
	Make/O/N=(4) RT_FirstHalfMean				// The first and the second half of the baseline... if means are more than 10% different, then discard experiment
	Make/O/N=(4) RT_SecondHalfMean
	RT_FirstHalfMean = 0
	RT_SecondHalfMean = 0
	Make/O/N=(4,4) RT_FirstHalfMeanMatrix				// The first and the second half of the baseline... if means are more than 10% different, then discard experiment
	Make/O/N=(4,4) RT_SecondHalfMeanMatrix
	RT_FirstHalfMeanMatrix = 0
	RT_SecondHalfMeanMatrix = 0
	Variable/G	RT_FirstHalfEnds = 0				// The iteration at which the first half of the first baseline ends (the second half ends when the baseline ends)
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	
	make/O root:Temp1								// These are placeholder waves for the dummy display waves used when killing the actual acquired waves
	make/O root:Temp2
	make/O root:Temp3
	make/O root:Temp4

	Variable/G	PM_RT_NotchFilterFlag = 0				// Boolean: Notch filter on?
	Variable/G	PM_RT_LowPassFilterFlag = 0			// Boolean: Low-pass filter on?
	Variable/G	PM_RT_BoxFilterFlag = 0					// Boolean: Box filter on?
	Variable/G	PM_RT_NotchFilter1 = 58					// Notch filter, start frequency
	Variable/G	PM_RT_NotchFilter2 = 62					// Notch filter, end frequency
	Variable/G	PM_RT_LowPassFilter = 1000				// Low-pass filter, cut-off frequency (Butterworth)
	Variable/G	PM_RT_LowPass_nPoles = 2				// Low-pass filter, number of poles
	Variable/G	PM_RT_BoxSize = 5							// Smooth input data on postsynaptic side with this size box, before analyzing

	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	Variable	NRepeatsDefault = 1					// Set default values
	Variable	ISIDefault = 10
	Variable	MaxTotalIterations = 5000
	
	Make/O/N=(MaxTotalIterations) dt_vector		// Save the _resulting_ ISIs for future reference
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	Make/T/O/N=(MaxTotalIterations) t_vector		// Save the stimulus times for future reference
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	Clear_tVectors()
	make/O/N=(MaxSteps) PMWaveDuration		// The duration of all waves in a particular step

	Variable/G	NoWavesOnSlave					// Boolean: During the pattern, are any waves to be sent to the slave computer?
	Variable/G	TotalIterCounter = 0				// The total number of iterations (will eventually be the sum of all NRepeats for a given pattern)
	
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	Variable/G	WorkVar							// Dummy variable used to communicate data to functions
	Variable/G	WorkVar2							// Dummy variable used to communicate data to functions
	Variable/G	WorkVar3							// Dummy variable used to communicate data to functions
	Variable/G	WorkVar4							// Dummy variable used to communicate data to functions
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	String/G	WorkStr							// As above, except for string variables
	make/N=4	SuffixCounter						// Temporary suffix counter when creating the input waves in PatternMaker
	String/G	w1									// Temporary wavename strings
	String/G	w2
	String/G	w3
	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	String/G	w4
	make/N=4	UseInputFlags						// Boolean: Flags if the input channel is at all to be used during a particular pattern
	
	Variable/G	AddThisChannel						// Boolean dummy variable needed for fix in 'DA_DoShowInputs' procedure

	printf "*"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternHandler variables...")
	root:MP:Progress_Counter += 1
	print "\r"
	print "\t\tSetting up variables used for PatternMaker panel."
	print "\t\tGoal:\t\t******************************"
	printf "\t\tWorking:\t"

	i = 0
	do												// Create variables for every potential step
	
		printf "*"
		UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up PatternMaker Panel Variables...")
		root:MP:Progress_Counter += 1

		j = 0										// ... and for every channel
		do
			
			CommandStr = "Variable/G OutputCheck"+num2str(i+1)+"_"+num2str(j+1)+" = 1"			// Is output checked or not?
			Execute CommandStr
	
			CommandStr = "String/G OutputWave"+num2str(i+1)+"_"+num2str(j+1)+" = root:MP:IO_Data:WaveNamesOut"+num2str(j+1)	// Provide a default output name
			Execute CommandStr
	
			CommandStr = "Variable/G InputCheck"+num2str(i+1)+"_"+num2str(j+1)+" = 1"			// Is input checked or not?
			Execute CommandStr
	
			j += 1
		while(j<4)

		CommandStr = "Variable/G NRepeats"+num2str(i+1)+" = "+num2str(NRepeatsDefault)				// Number of repeats
		Execute CommandStr

		CommandStr = "Variable/G ISI"+num2str(i+1)+" = "+num2str(ISIDefault)							// Inter-stimulus interval
		Execute CommandStr
		
		i += 1
	while (i<MaxSteps)
	print "\r"
	
	// Stuff for the online Averager
	Make/O/N=(4)	WantAverageOnThisChannel = {0,0,0,0}		// Boolean: Want average on this channel or not?
	Variable/G	PM_RT_AtLeastOneAve = 0					// Boolean: Is there any checkbox selected in the Averager?
	Variable/G	PM_RT_nAverages = 15						// Number of averages
	Variable/G	PM_RT_AverageDuration = 300					// Duration of average [ms]
	Variable/G	PM_RT_AveragePosition = 5					// Duration of average [ms]
	Variable/G	PM_RT_AveragerSlotCounter = 0				// Counter that keeps track of the current slot to update in the stored waves
	Variable/G	PM_RT_AveBaseStart = 0						// Baseline start [ms] -- used for aligning the averaged waves at zero in graph
	Variable/G	PM_RT_AveBaseWidth = 4					// Baseline width [ms]
	Variable/G	PM_RT_AveAlignBase = 1						// Boolean: Align baseline or not?
	SetDataFolder root:
	UpdateAverageWavesProc("",NaN,"","")																	// Create the averaging waves
	SetDataFolder root:MP:PM_Data
	
	//// Build the data folder for the FixAfterAcq routines
	print "\tData acquisition parameters"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up data acquisition variables...")
	root:MP:Progress_Counter += 1

	NewDataFolder/O root:MP:FixAfterAcq
	SetDataFolder root:MP:FixAfterAcq

	Make/O/N=(4) WaveWasAcq																			// Boolean: True if wave was acquired
	WaveWasAcq = 0
	Make/O/T/N=(4) WaveNames																			// Text wave with the wave names, one name for each channel

	StopAllMSTimers()

	//// Build the data folder for the SpikeTiming Creator routines
	print "\tSpike timing parameters"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up spike timing variables...")
	root:MP:Progress_Counter += 1

	NewDataFolder/O root:MP:ST_Data
	SetDataFolder root:MP:ST_Data
	
	Variable/G	Ind_Origin = 75									// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	Variable/G	Ind_Freq = 50									// The frequency of the spike timing during the induction [Hz]
	Variable/G	Ind_NPulses = 5									// The number of pulses for the same waves
	Variable/G	Ind_WaveLength = 1400							// The length of the waves for the ST_Creator [ms]
	Variable/G	Ind_RelDispl_1 = 10								// The relative displacement for the four channels [ms]
	Variable/G	Ind_RelDispl_2 = 0
	Variable/G	Ind_RelDispl_3 = 0
	Variable/G	Ind_RelDispl_4 = 0
	Variable/G	Ind_Sealtest = 1									// Boolean: Sealtest during induction?
	Variable/G	Ind_ConcatFlag = 0								// Boolean: Concatenate induction wave with already exisiting induction wave?
	Variable/G	Ind_AmplitudeIClamp = 1.3						// The pulse amplitude for induction intracellular current clamp pulses [nA]
	Variable/G	Ind_DurationIClamp = 5							// The pulse duration for induction current clamp pulses [ms]
	
	Variable/G	Ind_rangeStart = 25								// When making a range of spiketimings (for jScan), start at this time [ms] relative to laser pulse
	Variable/G	Ind_rangeEnd = -100								// When making a range of spiketimings (for jScan), end at this time [ms]
	
	Variable/G	Base_Spacing = 700								// The spacing between the pulses in the baseline [ms]
	Variable/G	Base_Freq = 30									// The frequency of the pulses [Hz]
	Variable/G	Base_NPulses = 5									// The number of pulses for each channel during the baseline
	Variable/G	Base_WaveLength = 1400							// The length of the waves for the ST_Creator [ms]
	Variable/G	Base_Sealtest = 1								// Boolean: Sealtest during baseline?
	Variable/G	Base_RevOrder = 0								// Boolean: Reverse the ordering of the spikes in the different cells?
	Variable/G	Base_vClampPulse = 0							// Boolean: Produce pulses when in voltage clamp too?
	Variable/G	Base_Recovery = 0								// Boolean: Recovery test pulse during baseline?
	Variable/G	Base_RecoveryPos = 500							// Recovery test pulse position relative to end of train [ms]
	Variable/G	Base_AmplitudeIClamp = Ind_AmplitudeIClamp		// The pulse amplitude for baseline intracellular current clamp pulses [nA]
	Variable/G	Base_DurationIClamp = Ind_DurationIClamp		// The pulse duration for baseline current clamp pulses [ms]
	
	Variable/G	ST_SealTestAtEnd = 0								// Put the seal test at the end of the wave, rather than at the beginning
	
	Variable/G	ST_RedPerc1 = 100								// Reduce current injection (or increase it) by this percentage, channel 1
	Variable/G	ST_RedPerc2 = 100								// Reduce current injection (or increase it) by this percentage, channel 2
	Variable/G	ST_RedPerc3 = 100								// Reduce current injection (or increase it) by this percentage, channel 3
	Variable/G	ST_RedPerc4 = 100								// Reduce current injection (or increase it) by this percentage, channel 4

	Variable/G	ST_AmplitudeVClamp = 0.07						// The pulse amplitude for _all_ intracellular voltage clamp pulses [V]
	Variable/G	ST_DurationVClamp = 200							// The pulse duration for _all_ voltage clamp pulses [ms]
	Variable/G	ST_StartPad = 25									// The padding before the first pulse -- applies to both induction and baseline [ms]
	Variable/G	ST_EndPad = 300									// The padding after the last pulse -- applies to both induction and baseline [ms]
	Variable/G	MMPooStyle = 0									// Boolean: True if MM Poo-style voltage clamp spike timing experiment, from J.Neurosci., Bi & Poo, 1998
	
	String/G	ST_BaseName = "Out_"								// The base name for all waves
	String/G	ST_Suffix = "_ST"									// The suffix to be added to the spiketiming waves
	
	Make/O/N=(4) ST_ChannelsChosen								// Used to store away the checkbox values -- which channels are chosen?
	ST_ChannelsChosen = {1,1,1,1}									// N.B.! Only used for drawing the panel -- check directly on panel to know values! (Comment is obsolete? 8/14/00 J.Sj.)
	
	Make/O/N=(4) ST_LightStim									// Used to store away the checkbox values -- which channels are used for LEDs, lasers, pockel cells?
	ST_LightStim = {0,0,0,0}
	Variable/G	ST_LightVoltage = 5									// The voltage amplitude for _all_ light pulses [V]
	Variable/G	ST_LightDur = 2									// The duration of _all_ light pulses [ms]

	Make/O/N=(4) ST_Extracellular								// Used to store away the checkbox values -- which channels are extracellular?
	ST_Extracellular = {0,0,0,0}

	Make/O/N=(4) ST_DendriticRec								// Used to store away the checkbox values -- which channels are dendritic recordings?
	ST_DendriticRec = {0,0,0,0}

	Variable/G	ST_Voltage = 1										// The voltage amplitude for _all_ extracellular pulses [V]
	Variable/G	ST_StimDur = 4										// The stim pulse duration for _all_ extracellular pulses [samples]
	Variable/G	ST_Biphasic = 1									// Biphasic voltage pulse for extracellular?

	Make/O/N=(4) ST_LongInj										// Used to store away the checkbox values -- which channels are have a long current injection? (providing a voltage plateau in current clamp)
	ST_LongInj = {0,0,0,0}
	Variable/G	ST_LongAmpI = 0.10								// The current injection amplitude for _all_ long injection pulses [nA]
	Variable/G	ST_LongWidth = 200									// Width of the long current injection pulse [ms] (is centered around the spike, unless short current injection is also clicked for specific channel)

	Make/O/N=(4) ST_ShortInj									// Used to store away the checkbox values -- which channels are have a short current injection? (quick repolarization after plateau)
	ST_ShortInj = {0,0,0,0}
	Variable/G	ST_ShortAmpI = -0.6								// The current injection amplitude for _all_ short injection pulses [nA]
	Variable/G	ST_ShortWidth = 3									// Width of the short current injection pulse [ms] (occurs just before spike, and just after long current injection)

	Make/O/N=(4) ST_KeepLast									// Used to store away the checkbox values -- keep only last spike in a spike train?
	ST_KeepLast = {0,0,0,0}
	Make/O/N=(4) ST_KeepFirst									// Used to store away the checkbox values -- keep only first spike in a spike train?
	ST_KeepFirst = {0,0,0,0}

	Make/O/N=(4) ST_NegPulse									// Used to store away the checkbox values -- Add negative pulses between spikes?
	ST_NegPulse = {0,0,0,0}
	Variable/G	ST_NegPulseAmpI = -0.3							// The size of the negative pulse
	
	Make/O/N=(4) ST_NoSpikes									// Used to store away the checkbox values -- No spikes at all on checked channel
	ST_NoSpikes = {0,0,0,0}
	
	// Parameters for the RandomSpiker
	Variable/G	ST_nWaves	 = 75									// Number of waves to be generated
	Variable/G	ST_RandWidTrain = 10								// Width of uniform distribution in [ms] for the whole spike train
	Variable/G	ST_nGrainsTrain = 0								// Granularity or graininess of the above width, e.g. a granularity of 2 means only two values within the range are possible
																	// Use a granularity of 0 to disable granularity, i.e. get "smooth" distribution
	Variable/G	ST_RandWidSpikes = 10							// Width of uniform distribution in [ms] for the individual spikes of a spike train
	Variable/G	ST_nGrainsSpikes = 0								// Granularity for the above width, as described for the spike train above
	Variable/G	ST_CorrWid = 20									// Width of correlograms
	Variable/G	ST_CorrNBins = 8									// Number of bins for the correlograms

	Variable/G	RandTrainsOff = 0									// Boolean: Use randomizer to change position of _train_ of spikes
	Variable/G	RandSpikesOff = 1									// Boolean: Use ranodmizer to change position of individual _spikes_ within a train

	// Parameters for the CycleGenerator
	Variable/G	ST_Cycle_TotIter = 18								// Total number of iterations, i.e. total number of steps in induction, or total number of waves listed in textwave
	Variable/G	ST_Cycle_nCycle = 3								// Number of waves per cycle
	String/G	ST_Cycle_Suffix = "_ST"							// The suffix to be added to the cycle text wave
	
	// Parameters for the MultiMake panel #1
	Variable/G	ST_MM_Voltage1 = 1								// Voltage for small EPSPs [V]
	Variable/G	ST_MM_Voltage2 = 3.5								// Voltage for large EPSPs [V]
	String/G	ST_MM_Name1 = "_ST_4"								// Suffix name for coincidence (small EPSPs)
	String/G	ST_MM_Name2 = "_ST_3"								// Suffix name for coincidence (large EPSPs)
	String/G	ST_MM_Name3 = "_ST_2"								// Suffix name for no EPSPs, only APs
	String/G	ST_MM_Name4 = "_ST_5"								// Suffix name for no APs, only (small) EPSPs
	String/G	ST_MM_Name5 = "_ST_1"								// Suffix name for no APs, only (large) APs
																// Note! This numbering of the suffices ensures that running a cycling pattern of three waves (not five)
																// selects the right waves.

	// Parameters for the MultiMake panel #2
	Variable/G	ST_MM_LongIstep = 0.3							// Current for long I-step [nA]
	Variable/G	ST_MM_PercReduc = 100							// Percent reduction of current injection for the depolarized condition [%]
	String/G	ST_MM2_Name1 = "_ST_1"							// Suffix name for APs plus depol
	String/G	ST_MM2_Name2 = "_ST_2"							// Suffix name for depol only (no APs)
	String/G	ST_MM2_Name3 = "_ST_3"							// Suffix name for APs only (no depol)

	// Parameters for the MultiMake panel #4
	String/G	ST_MM4_Name1 = "_ST_1"							// Suffix name for APs plus Light
	String/G	ST_MM4_Name2 = "_ST_2"							// Suffix name for Light only (no APs)
	String/G	ST_MM4_Name3 = "_ST_3"							// Suffix name for APs only (no Light)

	SetDataFolder root:MP

	//// Set up the notebook
	print "\tNotebook"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up Parameter Log...")
	root:MP:Progress_Counter += 1

	DoWindow/K Parameter_Log
	NewNotebook/N=Parameter_Log/F=1/V=1/W=(675,130,1022,358) as "Parameter Log for MultiPatch"
	Notebook Parameter_Log defaultTab=36, statusWidth=238, pageMargins={72,72,72,72}
	Notebook Parameter_Log showRuler=0, rulerUnits=1, updating={1, 216000}
	Notebook Parameter_Log newRuler=Normal, justification=0, margins={0,0,468}, spacing={0,0,0}, tabs={16,32,400+3*8192,450+8192*2}, rulerDefaults={"Geneva",10,0,(0,0,0)}
	Notebook Parameter_Log newRuler=TabRow, justification=0, margins={0,0,468}, spacing={0,0,0}, tabs={16,32,80,100,148}, rulerDefaults={"Geneva",10,0,(0,0,0)}
	RepositionNotebookProc("")
	RepositionNotebookProc("")
	String WorkStr = ""
	i = 0
	do
		WorkStr += num2str(80+floor((400-80)/(root:MP:IO_Data:NSlots-1)*i)+8192*3)
		if (i!=root:MP:IO_Data:NSlots-1)
			WorkStr += ","
		endif
		i += 1
	while (i<root:MP:IO_Data:NSlots)
	CommandStr = "Notebook Parameter_Log newRuler=SlotTabRow,textRGB=(0,0,0), justification=0, margins={0,0,468}, spacing={0,0,0}, tabs={16,"+WorkStr+"}, rulerDefaults={\"Geneva\",10,0,(0,0,0)}"
	Execute CommandStr
	Notebook Parameter_Log newRuler=TextRow, justification=0, margins={0,0,468}, spacing={0,0,0}, tabs={16,32,450+8192*2}, rulerDefaults={"Geneva",10,0,(0,0,0)}
	Notebook Parameter_Log newRuler=TextRow2, justification=0, margins={0,0,468}, spacing={0,0,0}, tabs={16,32,128,450+8192*2}, rulerDefaults={"Geneva",10,0,(0,0,0)}
	Notebook Parameter_Log newRuler=ImageRow, justification=1, margins={0,0,468}, spacing={0,0,0}, tabs={16,32,450+8192*2}, rulerDefaults={"Geneva",10,0,(0,0,0)}
	Notebook Parameter_Log newRuler=Title, justification=0, margins={0,0,538}, spacing={0,0,0}, tabs={}, rulerDefaults={"Helvetica",18,0,(0,0,0)}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Starting up the MultiPatch software\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\tDate: "+Date()+"\r"
	Notebook Parameter_Log text="\tTime: "+Time()+"\r"
	Notebook Parameter_Log text="\tBoard: "+root:BoardName+"\r"
	if (StringMatch(root:BoardName,"NI_2PLSM"))
		Notebook Parameter_Log ruler=TextRow2,text="\t\tInput:\t"+root:BoardName_Input+"\r"
		Notebook Parameter_Log ruler=TextRow2,text="\t\tOutput:\t"+root:BoardName_Output+"\r"
	endif
	Notebook Parameter_Log text="\tHD: "+root:MP:MasterName+"\r\r"

	print "\tBuilding panels"
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Building panels...")
	root:MP:Progress_Counter += 1

	//// Kill previous ST_Creator panel, if it exists
	DoWindow/K MultiPatch_ST_Creator
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Building panels...")
	root:MP:Progress_Counter += 1

	//// Build the Switchboard panel
	MultiPatch_Switchboard()
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Building panels...")
	root:MP:Progress_Counter += 1

	if (ShowPanelsOnStartup)

		//// Build the WaveCreator panel
		MultiPatch_WaveCreator()
	
		//// Build the PatternMaker panel
		MakeMultiPatch_PatternMaker()
	
		if (root:MP:ShowFlag)
			WC_ShowWave(root:MP:ChannelNumber)
		endif

	else
	
		DoWindow/K MultiPatch_PatternMaker
		DoWindow/K MultiPatch_WaveCreator
		DoWindow/K ConnectivityPanel

	endif
	//// Want the Switchboard panel in front at first
	DoWindow/F MultiPatch_Switchboard
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Building panels...")
	root:MP:Progress_Counter += 1

	SetDataFolder root:

	//// Load settings from file
	Print "\tAuto-loading default settings from file."
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Loading settings...")
	root:MP:Progress_Counter += 1
	DoLoadSettings(0)

	//// Reset board, set up gain...
	UpdateProgressBar(root:MP:Progress_Counter/root:MP:Progress_Max,"Setting up boards...")
	root:MP:Progress_Counter += 1
	print "\tSetting up board(s)"
	SetUpBoards()

	Print "============= Finished setting up ============="
	KillProgressBar()

EndMacro

//////////////////////////////////////////////////////////////////////////////////

Function ExternalTriggerCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	if (checked)
		print Time()+"\tExternal trigger is checked!"
		DoAlert 0,"FYI: You just selected external triggering!"
	else
		print Time()+"\tExternal trigger is unchecked!"
	endif

End
		
//////////////////////////////////////////////////////////////////////////////////

Window MultiPatch_Switchboard() : Panel
	String CommandStr
	Variable i
	
	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	String WorkStr1,WorkStr2
	
	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
//	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
//	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
//	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	PauseUpdate; Silent 1

	DoWindow/K MultiPatch_Switchboard
	NewPanel/K=2/W=(9*root:MP:ScSc,45*root:MP:ScSc,9*root:MP:ScSc+378-9,45*root:MP:ScSc+587+19-45+19) as "MultiPatch Switchboard"
	DoWindow/C MultiPatch_Switchboard
	ModifyPanel/W=MultiPatch_Switchboard fixedSize=1
//	ShowTools
	SetDrawLayer UserBack
	SetDrawEnv linethick= 2,fillfgc= (3,52428,1),fillbgc= (3,52428,1)
	DrawRect 54,2,315,36
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
	DrawText 73,29,"MultiPatch Switchboard"
	
	if ( StringMatch(BoardName,"NI_2PLSM") %| StringMatch(BoardName,"PCI-6363") )
			SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
			DrawText 4,29-10,"4 output"
			SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
			DrawText 4,29,"channels"
			SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
			DrawText 329-12,29-10,BoardName // "NI Multi"
	endif
	if (StringMatch(BoardName,"ITC18"))
			SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
			DrawText 4,29-10,"4 output"
			SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
			DrawText 4,29,"channels"
			SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
			DrawText 329-12,29-10,"ITC18"
	endif
	if ( (root:MP:DemoMode) %| (StringMatch(BoardName,"DEMO")) )
		SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
		DrawText 329-12,29-10,"DEMO"
		SetDrawEnv fsize= 10,fstyle= 0,textrgb= (0,0,0)
		DrawText 329-12,29+2,"No board"
	endif

	Button PatternButton,pos={4,339},size={86,35},proc=PM_PatternProc,title="Run pattern"
	Button OnceButton,pos={94,339},size={80,35},proc=OnceProc,title="Send once"

	Button ResetBoardsButton,pos={178,338},size={100,16},proc=ResetBothBoards,title="Reset boards"
	CheckBox ExternalTrigCheck pos={178,338+19},size={100,19},title="External trigger",proc=ExternalTriggerCheckProc,value=0	//,labelBack=(rr,gg,bb)

	SetDrawEnv linethick = 1,fillfgc=(rr,gg,bb)
	DrawRRect 4,377,111,462
	Button RpipButton,pos={8,381},size={99,16},proc=RpipProc,title="R_pip",labelBack=(rr,gg,bb),fColor=(65535,0,0)
	Variable SpChX = 53
	Variable SpChY = 19
	CheckBox Rpip1Check pos={8+SpChX*0,400+SpChY*0},labelBack=(rr,gg,bb),size={SpChX-4,19},title="Ch 1",value=1
	CheckBox Rpip2Check pos={8+SpChX*1,400+SpChY*0},labelBack=(rr,gg,bb),size={SpChX-4,19},title="Ch 2",value=1
	CheckBox Rpip3Check pos={8+SpChX*0,400+SpChY*1},labelBack=(rr,gg,bb),size={SpChX-4,19},title="Ch 3",value=1
	CheckBox Rpip4Check pos={8+SpChX*1,400+SpChY*1},labelBack=(rr,gg,bb),size={SpChX-4,19},title="Ch 4",value=1
	CheckBox RpipGraphCheck pos={8,438},labelBack=(rr,gg,bb),size={99,19},fsize=12,title="Show graph",value=1
	
	Button RepositionNotebookButton,pos={4,465},size={178,16},proc=RepositionNotebookProc,title="Reposition Notebook"
	Button CalcR_AccessButton,pos={4,484},size={178,16},proc=CalcR_Access,title="Calculate R_access"

	Button GoToWaveCreatorButton,pos={186,465},size={178,16},fColor=(65535,65535/2,65535/2),proc=GoToWaveCreator,title="WaveCreator"
//	Button GoToPatternMakerButton,pos={186,484},size={178,16},fColor=(29524,1,58982),proc=GoToPatternMaker,title="Go to PatternMaker"
	Button GoToPatternMakerButton,pos={186,484},size={178,16},fColor=(65535/2,65535/10,65535),proc=GoToPatternMaker,title="PatternMaker"

	Button GoToDatAnButton,pos={186,503},size={178,16},proc=GoToDatAn,title="DataAnalysis"

	Button GoToAveragePanelButton,pos={186,522},size={178,16},fColor= (65535*0.95,65533*0.95,32768*0.95),proc=GoToAveragePanelProc,title="Average Panel"

	Button ST_GoToSpikeTimingCreatorButton,pos={186,522+19},size={178,16},fColor=(65535/2,65535/2,65535),proc=ST_GoToSpikeTimingCreator,title="Spike-Timing Creator"

	Button GoToLineScanAnalysisPanelButton,pos={186,522+19+19},size={178,16},proc=GoToMP285PanelProc,title="MultiMove Panel"

	SetVariable AcqGainSetSetVar,pos={4,503},size={178,20}
 	if ( (StringMatch(BoardName,"NI")) %| (StringMatch(BoardName,"NI_2PLSM")) %| (StringMatch(BoardName,"PCI-6363")) )
		SetVariable AcqGainSetSetVar,proc=NIAcqGainSetProc,title="The per-channel gain: "
//		SetVariable AcqGainSetSetVar,title="The per-channel gain: ",limits={0.5,Inf,10}
	else
	 	if (StringMatch(BoardName,"ITC18"))
			SetVariable AcqGainSetSetVar,proc=AcqGainSetProc,title="Board resolution: "
		endif
	endif
	SetVariable AcqGainSetSetVar,value=root:MP:AcqGainSet,limits={0,Inf,1}

	SetDrawEnv fsize= 13,fstyle= 5,textrgb= (0,0,0)
	DrawText 4,522+16,"Settings:"
	Button SaveSettingsButton,pos={4+64+10,522},size={50,16},proc=SaveSettingsProc,title="Save"
	Button LoadSettingsButton,pos={4+64+60+4,522},size={50,16},proc=LoadSettingsProc,title="Load"

	SetDrawEnv fsize= 12,fstyle=0,textrgb= (0,0,0)
	DrawText 4,522+16+19,"Input units:"
	RedrawUnitsCheckboxes()

	SetDrawEnv linethick = 1,fillfgc=(rr,gg,bb)
	DrawRRect 115,418,278,462
	Button NewCellButton,pos={115+4,423},size={62,16},proc=NewCellProc,title="New cell",labelBack=(rr,gg,bb)
	SetVariable CellNumberSetVar,pos={183,423},fsize=12,labelBack=(rr,gg,bb),size={91,20},title="Cell #: "
	SetVariable CellNumberSetVar,limits={0,Inf,1},value=root:MP:CellNumber
	SetDrawEnv fsize=11
	SetDrawEnv fname= "Helvetica",fstyle=0
	DrawText 117,459,"...on channel: "
	i = 0
	CommandStr = ""
	do
		Button $("LabelChannelButton"+num2str(i+1)),pos={115+70+i*23,443},size={20,16},proc=LabelChannelProc,title=num2str(i+1),labelBack=(rr,gg,bb),fcolor=(root:MP:IO_Data:ChannelColor_R[i],root:MP:IO_Data:ChannelColor_G[i],root:MP:IO_Data:ChannelColor_B[i])
		i += 1
	while (i<4)

	SetDrawEnv linethick = 1,fillfgc=(rr,gg,bb)
	DrawRRect 282,402,364,462
	Button SaveExperimentButton,pos={286,405},size={74,19+19},proc=DA_SaveExperiment,title="Save\rexperiment",labelBack=(rr,gg,bb),fSize=11
	CheckBox AutoSaveOnOff,pos={286,421+22},labelBack=(rr,gg,bb),size={74,16},proc=ToggleAutoSaveExpProc,value=1,title="Autosave"

//	CheckBox VideoOnOff,pos={286,404},labelBack=(rr,gg,bb),size={74,16},disable=2,proc=ToggleVideoProc,value=0,title="Video"
//	Button GrabFrameButton,pos={286,423},size={74,16},disable=2,proc=GrabFrameProc,title="Grab",labelBack=(rr,gg,bb)
//	Button FrameToLogButton,pos={286,442},size={74,16},disable=2,proc=FrameToLogProc,title="Add to log",labelBack=(rr,gg,bb)

	SetDrawEnv linethick = 1,fillfgc=(rr,gg,bb)
	DrawRRect 115,377,278,414
	SetDrawEnv fsize=12,fstyle=4,textrgb= (0,0,0)
	DrawText 119,377+18,"Acquired waves:"
	CheckBox ShowInputs pos={119+155-55+2,396},size={53,20},fsize=12,labelBack=(rr,gg,bb),proc=DA_ToggleShowInputs,title="Show",value=1
//	CheckBox ZoomInputGraph pos={119+155-55+2,396},size={53,20},fsize=12,labelBack=(rr,gg,bb),proc=DA_ToggleZoomProc,title="Zoom",value=root:MP:IO_Data:ZoomFlag,disable=2
	CheckBox StoreCheck pos={119,396},size={54,19},fsize=12,labelBack=(rr,gg,bb),Proc=NoStoreButKillProc,title="Store",value=1
	CheckBox KillCheck pos={119+54+4,396},size={42,19},fsize=12,labelBack=(rr,gg,bb),Proc=NoStoreButKillProc,title="Kill",value=1
	SetVariable OffsetSetVar,pos={4,522+19+19},size={178,20},title="Acquired waves offset:",limits={-Inf,Inf,0.01},value=root:MP:InputOffset

	SetDrawEnv linethick = 1,fillfgc=(rr,gg,bb)
	DrawRRect 282,339,364,399
	Button ResetAllButton,pos={286,342},size={74,16},proc=ResetAll,title="Reset all",labelBack=(rr,gg,bb)
	SetVariable ResetValueSetVar,pos={286,362},labelBack=(rr,gg,bb),size={74,17},title="to",limits={1,Inf,1},value=root:MP:ResetAllValue
	CheckBox CountUp pos={286,380},labelBack=(rr,gg,bb),size={72,20},title="Count up",value=1

	i = 0;
	do

		SetDrawEnv linethick = 1,fillfgc=(rr,gg,bb)
		DrawRect 364+2,(40+i*75)-2,4-2,109+i*75+2
		
		SetDrawEnv linethick = 2,fillfgc=(rr,gg,bb)
		SetDrawEnv linefgc=(root:MP:IO_Data:ChannelColor_R[i],root:MP:IO_Data:ChannelColor_G[i],root:MP:IO_Data:ChannelColor_B[i])
		DrawRect 364,(40+i*75),4,109+i*75
		
		SetDrawEnv fsize=16, fstyle=7
		SetDrawEnv fname= "Helvetica",fstyle= 7
		DrawText 10,62+i*75,"Channel "+num2str(i+1)
		
		CommandStr = "Out"+num2str(i+1)
		WorkStr1 = "WC_ToggleOutputOnOff"
		CheckBox $CommandStr,pos={100,44+i*75},size={16+60,20},labelBack=(rr,gg,bb),fsize=14,proc=$WorkStr1,title="Output:",value=root:MP:IO_Data:OutputOnOff[i]
	
		CommandStr =  "Out"+num2str(i+1)+"Popup"
		WorkStr1 = "WaveNamesOut"+num2str(i+1)
		PopupMenu $CommandStr,pos={116+60,44+i*75},size={149-60,19},labelBack=(rr,gg,bb),title="",mode=1,popvalue=root:MP:IO_Data:$WorkStr1,value=#"WaveList(\"Out*\", \";\", \"\")",win=MultiPatch_Switchboard

		CommandStr = "VClamp"+num2str(i+1)
		CheckBox $CommandStr,pos={8,64+i*75},size={88,20},labelBack=(rr,gg,bb),fsize=14,proc=ToggleVClampProc,title="V clamp",value=0
	
		CommandStr = "In"+num2str(i+1)
		WorkStr1 = "WC_ToggleInputOnOff"
		CheckBox $CommandStr,pos={100,64+i*75},size={16+60,20},labelBack=(rr,gg,bb),fsize=14,proc=$WorkStr1,title="Input:",value=root:MP:IO_Data:OutputOnOff[i]
		//// Jesper, 2008-12-16: Hardwiring the ITC18 behavior for all board types, since it makes most sense usually anyhow
		//// Jesper, 2010-08-23: Taking out hardwiring for non-ITC18 boards at Alex Moreau's request
		if (StringMatch(BoardName,"ITC18"))
			CheckBox $CommandStr,disable=2			// In the case of ITC-18, disable user input, as the output checkbox will affect the input checkbox as well...
		endif
	
		CommandStr = "BaseNameInSetVar"+num2str(i+1)
		WorkStr1 = "WaveNamesIn"+num2str(i+1)
		SetVariable $CommandStr,pos={26+92+60-1,66+i*75},size={250-92-60,19},labelBack=(rr,gg,bb),title=" ",value=root:MP:IO_Data:$WorkStr1

		CommandStr = "StartAtSetVar"+num2str(i+1)
		WorkStr1 = "StartAt"+num2str(i+1)
		SetVariable $CommandStr,limits={1,Inf,1},labelBack=(rr,gg,bb),fsize=10,value=root:MP:IO_Data:$WorkStr1,pos={280,66+i*75},size={78,19},title="@"

		CommandStr = "ChannelNoteSetVar"+num2str(i+1)
		WorkStr1 = "ChannelNote"+num2str(i+1)
		SetVariable $CommandStr,value=root:MP:IO_Data:$WorkStr1,frame=0,labelBack=(rr,gg,bb),pos={10,88+i*75},size={106,19},title=" "

		CommandStr = "OutGainSetVar"+num2str(i+1)
		WorkStr1 = "OutGain"+num2str(i+1)
		SetVariable $CommandStr,limits={-inf,inf,0},labelBack=(rr,gg,bb),pos={116,88+i*75},title=" Out gain:",size={120,19},proc=OutGainSetProc,value=root:MP:IO_Data:$WorkStr1

		CommandStr = "InGainSetVar"+num2str(i+1)
		WorkStr1 = "InGain"+num2str(i+1)
		SetVariable $CommandStr,pos={238,88+i*75},labelBack=(rr,gg,bb),size={120,19},title=" In gain:",limits={-inf,inf,0},proc=InGainSetProc,value=root:MP:IO_Data:$WorkStr1

		i += 1
	while (i<4)

EndMacro

//////////////////////////////////////////////////////////////////////////////////
//// For NI: Set the per-channel gain

Function NIAcqGainSetProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName
	
	NVAR		AcqGainSet =			root:MP:AcqGainSet

	// Ensure valid range by wrap-around
	if (AcqGainSet>4)
		AcqGainSet = 1
	endif
	if (AcqGainSet<1)
		AcqGainSet = 4
	endif

	// Note to self: Does this work with "MP_Board_NIDAQ_2PLSM" include file?
	// May need to include the below variables in InitBoardVariables() of that include file.
	// Alternatively, NaNs will gracefully fall through acquisition procedures.
	WAVE/Z		AcqGainSetValues =		AcqGainSetValues	// This wave is defined by 2pQuad include file
	NVAR/Z		AcqGainCurrVal = root:AcqGainCurrVal
	
	Print "\t\tGain is "+num2str(AcqGainSet)+"; setting range to ±"+num2str(AcqGainSetValues[AcqGainSet-1])+" V for all channels"
	AcqGainCurrVal = AcqGainSetValues[AcqGainSet-1]
	
End

//////////////////////////////////////////////////////////////////////////////////
//// For ITC18: Change the range

Function AcqGainSetProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName
	
	NVAR		AcqGainSet =			root:MP:AcqGainSet

	// Ensure valid range by wrap-around
	if (AcqGainSet>4)
		AcqGainSet = 1
	endif
	if (AcqGainSet<1)
		AcqGainSet = 4
	endif
	
	// Interpret value
	InterpretAcqGainSet(AcqGainSet)

End

//////////////////////////////////////////////////////////////////////////////////
//// Only pertains to ITC18

Function InterpretAcqGainSet(AcqGainSet)
	variable	AcqGainSet
	
	WAVE		InChannelsDefault =		InChannelsDefault
	WAVE		AcqGainSetValues =		AcqGainSetValues	// This wave is defined by ITC18 include file
	
	NVAR		AcqGainCurrVal = root:AcqGainCurrVal

	variable	i
	
	Print "\t\tGain is "+num2str(AcqGainSet)+"; setting ITC18 range to ±"+num2str(AcqGainSetValues[AcqGainSet-1])+" V for all channels"
	AcqGainCurrVal = AcqGainSetValues[AcqGainSet-1]

	i = 0
	do
		Execute "ITC18SetADCRange "+num2str(InChannelsDefault[i])+", "+num2str(AcqGainSetValues[AcqGainSet-1])
		i += 1
	while (i<4)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Reset all suffix counter values to the ResetAllValue value.

Function ResetAll(ctrlName) : ButtonControl
	String ctrlName

	NVAR ResetAllValue = root:MP:ResetAllValue
	NVAR StartAt1 = root:MP:IO_Data:StartAt1
	NVAR StartAt2 = root:MP:IO_Data:StartAt2
	NVAR StartAt3 = root:MP:IO_Data:StartAt3
	NVAR StartAt4 = root:MP:IO_Data:StartAt4

	StartAt1 = ResetAllValue
	StartAt2 = ResetAllValue
	StartAt3 = ResetAllValue
	StartAt4 = ResetAllValue

End

//////////////////////////////////////////////////////////////////////////////////

Window MultiPatch_WaveCreator() : Panel

	String CommandStr

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	String WorkStr1,WorkStr2
	
	DoWindow/K MultiPatch_WaveCreator
	NewPanel/K=2/W=(392*root:MP:ScSc, 45*root:MP:ScSc, 392*root:MP:ScSc+660-392, 45*root:MP:ScSc+488+9+19*6-42) as "MultiPatch WaveCreator"
	DoWindow/C MultiPatch_WaveCreator
	ModifyPanel/W=MultiPatch_WaveCreator fixedSize=1
	SetDrawLayer UserBack
	SetDrawEnv linethick= 2,fillfgc= (52428,1,1),fillbgc= (52428,1,1)
	DrawRect 4,2,264,36
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
	DrawText 18,29,"MultiPatch WaveCreator"
	SetDrawEnv linethick= 2,fillfgc=(rr,gg,bb)
	DrawRect 4,77,264,154
	SetDrawEnv linethick= 2,fillfgc=(rr,gg,bb)
	DrawRect 4,158,264,350

	Button GoToSwitchboardButton,pos={132,393},size={132,16},fColor=(65535/2,65535,65535/2),proc=GoToSwitchboard,title="Switchboard"
	Button GoToPatternMakerButton,pos={132,413},size={132,16},fColor=(65535/2,65535/10,65535),proc=GoToPatternMaker,title="PatternMaker"
	Button ST_GoToSpikeTimingCreatorButton,pos={132,413+19},fColor=(65535/2,65535/2,65535),size={132,16},proc=ST_GoToSpikeTimingCreator,title="SpikeTiming Creator",fSize=11

	Button CreateOneWaveButton,pos={4,393},size={125,16},proc=WC_CreateOneWave,title="Create this wave"
	Button CreateOutputWavesButton,pos={4,413},size={125,16},proc=WC_CreateOutputWaves,title="Create all waves"
	Button KillWCButton,pos={4,413+19},size={125,16},proc=WC_KillWCPanel,title="Close panel"

	SetVariable SampleFreqSetVar,pos={4,39},size={150,17},proc=WC_UpdateAfterSetVarChange,title="Sample freq [Hz]: "
	SetVariable SampleFreqSetVar,limits={1000,60000,1000},value= root:MP:SampleFreq

	CheckBox CreateAppendsCheckBox,pos={4+150+4,39},size={100,17},Proc=WC_ToggleCreateAppendsProc,title="Create appends",value=root:MP:CreateAppendsFlag
	
	SetVariable DurationSetVar,pos={4,57},size={260,17},proc=WC_UpdateAfterSetVarChange,title="Total wave duration [ms]: "
	SetVariable DurationSetVar,limits={0,Inf,100},value= root:MP:TotalDur

	CheckBox SealTestCheck,pos={8,80},size={86,20},labelBack=(rr,gg,bb),title="Test pulse",value=root:MP:SealTestFlag,proc=WC_ToggleSealTest
	CheckBox WC_SealTestAtEndCheck,pos={8+86,80},size={86,20},Proc=WCST_ToggleSealTestAtEndProc,title="Test pulse at end",value=root:MP:ST_Data:ST_SealTestAtEnd
	// Potential bug alert: The above checkbox causes interaction between ST_Creator and WaveCreator
	WC_SealTestParamsUpdate()

	PopupMenu DestSelectPopup,pos={8,161},fsize=10,size={101,19},title="Channel",proc=WC_ToggleDest
	PopupMenu DestSelectPopup,mode=root:MP:ChannelNumber,value= #"\" #1; #2; #3; #4;\""

	PopupMenu SlotNumberPopup,pos={8+101-8,161},fsize=10,size={101,19},title="Slot",proc=WC_ToggleSlot
	PopupMenu SlotNumberPopup,mode=root:MP:SlotNumber,value=root:MP:IO_Data:SlotPopUpItems
	WC_ToggleSlotOnDisplay()

	SetVariable NPulsesSetVar,pos={8,201},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="1. Number of pulses: "
	SetVariable NPulsesSetVar,limits={0,Inf,1},value=root:MP:NPulses

	WC_RefreshTypePopup(root:MP:ChannelType)
	WC_DoToggleTypeOnDisplay(root:MP:ChannelType)

	CheckBox ShowWaveCheck,pos={176+40,160},size={56,20},title="Show",labelBack=(rr,gg,bb),proc=WC_ToggleShow,value=root:MP:ShowFlag
	CheckBox BiphasicCheck,pos={176+40,186},labelBack=(rr,gg,bb),size={75,20},title="Bipol",proc=WC_ToggleBiphasic,value=root:MP:BiphasicFlag
	SetVariable PulseFreqSetVar,pos={8,255},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="4. Pulse frequency [Hz]: "
	SetVariable PulseFreqSetVar,limits={0,Inf,1},value= root:MP:PulseFreq
	SetVariable DisplacedSetVar,pos={8,273},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="5. Displaced relative origin [ms]: "
	SetVariable DisplacedSetVar,limits={-Inf,Inf,5},value=root:MP:PulseDispl

	SetVariable WaveNameOutSetVar,pos={8,291+18},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="Output wave: "
	SetVariable WaveNameOutSetVar,value=root:MP:CurrWaveNameOut
	
	CommandStr = "Out"+num2str(root:MP:ChannelNumber)
	WorkStr1 = "WC_ToggleOutputOnOff"
	CheckBox $CommandStr,pos={8,329},size={124,17},labelBack=(rr,gg,bb),proc=$WorkStr1,title="Use this channel",value=root:MP:IO_Data:OutputOnOff[root:MP:ChannelNumber-1]

	Button SaveWaveDescriptorButton,pos={4,353},size={36,17},proc=SaveWaveDescriptorProc,title="Save",fSize=11
	Button LoadWaveDescriptorButton,pos={44,353},size={36,17},proc=LoadWaveDescriptorProc,title="Load",fSize=11
	SetVariable WaveDescriptorSetVar,pos={84,353},fsize=12,size={180,17},title="Name:"
	SetVariable WaveDescriptorSetVar,value=root:MP:CurrWaveDescriptor

	Button AddToLog_OneOutput,pos={138,329},size={122,17},proc=AddToLogProc,title="This graph to log"

	Button AddToLog_AllOutputs,pos={4,372},size={125,17},proc=AddToLogProc,title="All graphs to log"

	CheckBox STCheck,pos={133,371+2},size={56,20},fsize=12,title="Suffix:",value=root:MP:STFlag
	SetVariable STSuffixSetVar,pos={170+24,372},fsize=12,size={94-24,17},title=" "
	SetVariable STSuffixSetVar,value=root:MP:IO_Data:STSuffix

	SetDrawEnv linethick= 2,fillfgc=(rr,gg,bb)
	DrawRect 4,413+19+19,264,413+19*8-2
	Button MakeRangeButton,pos={8,413+19+19+4},size={125-4,16},proc=WC_MakeRange,title="Create range"
	Button EditRangeButton,pos={132,413+19+19+4},size={132-4,16},proc=WC_EditRange,title="Edit range"
	SetVariable WC_RangeStartSetVar,pos={8,413+19*3+2},size={123,17},labelBack=(rr,gg,bb),proc=WC_EditRangeAfterSetVarChange,title="Start:"
	SetVariable WC_RangeStartSetVar,limits={-Inf,Inf,0.1},value= root:MP:WC_RangeStart
	SetVariable WC_RangeStepSetVar,pos={135,413+19*3+2},size={123,17},labelBack=(rr,gg,bb),proc=WC_EditRangeAfterSetVarChange,title="Step:"
	SetVariable WC_RangeStepSetVar,limits={-Inf,Inf,0.1},value= root:MP:WC_RangeStep
	SetDrawEnv fsize= 12
	DrawText 8,413+19*4-3+19,"Parameter"
	WC_DoFlipParamProc(2)
	Button Range2PatternButton,pos={8,413+19*5-2},size={260-8,16},proc=WC_Range2Pattern,title="Use range to update PatternMaker"
	Button MultiRangeButton,pos={8,413+19*6-2},size={260-8,16},proc=WC_MultiRange,title="Repeat across channels"
	Button MultiSlotRangeButton,pos={8,413+19*7-2},size={160,16},proc=WC_MultiSlotRange,title="Repeat 2. across slots"
	SetVariable WC_RangeTimeStepSV,pos={8+160+4,413+19*7-2},size={260-8-4-160,17},labelBack=(rr,gg,bb),title="t-step:"
	SetVariable WC_RangeTimeStepSV,limits={-Inf,Inf,100},value= root:MP:WC_tStep

End

//////////////////////////////////////////////////////////////////////////////////
//// Repeat across all slots for the selected channel

Function WC_MultiSlotRange(ctrlName) : ButtonControl
	String ctrlName
	
	WC_repeatAcrossSlots()
	
End

Function WC_repeatAcrossSlots()

	NVAR ChannelNumber =		root:MP:ChannelNumber		// Wave number
	NVAR SlotNumber =			root:MP:SlotNumber			// Slot number
	NVAR PreviousSlot =		root:MP:PreviousSlot			// Previous slot number
	NVAR ChannelType = 		root:MP:ChannelType			// Wave type
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 		root:MP:PulseDispl			// Pulse displacement
	NVAR BiphasicFlag = 		root:MP:BiphasicFlag			// Biphasic flag
	NVAR CommandLevel=		root:MP:CommandLevel			// holding current/volt command level   3/30/00 KM

	WAVE PulseAmpWave = 		root:MP:IO_Data:PulseAmp		// Stored dittos
	WAVE ChannelTypeWave = 	root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 		root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 		root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 	root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 	root:MP:IO_Data:PulseDispl
	WAVE BiphasicFlagWave =	root:MP:IO_Data:BiphasicFlag	

	NVAR	UseSlotFlag = 		root:MP:UseSlotFlag				// Use this slot?
	WAVE	UseSlotWave = 		root:MP:IO_Data:UseSlotWave	// Same, store away
	NVAR	AddSlotFlag = 		root:MP:AddSlotFlag				// Slot is additive?
	WAVE	AddSlotWave = 		root:MP:IO_Data:AddSlotWave	// Same, store away
	NVAR	SynapseSlotFlag = root:MP:SynapseSlotFlag			// Slot is a biexponential?
	WAVE	SynapseSlotWave = root:MP:IO_Data:SynapseSlotWave	// Same, store away
	NVAR	RampFlag = 			root:MP:RampFlag					// Ramp?
	WAVE	RampWave = 			root:MP:IO_Data:RampWave		// Same, store away
	
	NVAR	WC_RangeStart =	root:MP:WC_RangeStart
	NVAR	WC_RangeStep =		root:MP:WC_RangeStep
	NVAR	WC_tStep = 			root:MP:WC_tStep

	Variable	n = 10
	Variable	i
	
	Print "--- Copying from slot 1 to the other slots ---"
	print "Using range values "+num2str(WC_RangeStart)+" and "+num2str(WC_RangeStep)+" and time step "+num2str(WC_tStep)+" and applying this to \"2. Pulse amplitude\"."

	//// Make sure we are in Slot 1
	WC_ToggleSlot("",1,"")

	// Define first slot according to range values
	PulseAmp = WC_RangeStart
	PulseAmpWave[ChannelNumber-1][i] = PulseAmp

	// All slots will be used
	UseSlotWave[ChannelNumber-1][0] = 1

	// Copy from first slot to all other slots
	i = 1
	do
		// These two parameters are ramped
		PulseAmpWave[ChannelNumber-1][i] = WC_RangeStart + WC_RangeStep*i
		PulseDisplWave[ChannelNumber-1][i] = PulseDisplWave[ChannelNumber-1][0]+WC_tStep*i

		// These parameters are copied from Slot 1
		NPulsesWave[ChannelNumber-1][i] = NPulsesWave[ChannelNumber-1][0]
		PulseDurWave[ChannelNumber-1][i] = PulseDurWave[ChannelNumber-1][0]
		PulseFreqWave[ChannelNumber-1][i] = PulseFreqWave[ChannelNumber-1][0]
		BiphasicFlagWave[ChannelNumber-1][i] = BiphasicFlagWave[ChannelNumber-1][0]
		UseSlotWave[ChannelNumber-1][i] = UseSlotWave[ChannelNumber-1][0]
		AddSlotWave[ChannelNumber-1][i] = AddSlotWave[ChannelNumber-1][0]
		SynapseSlotWave[ChannelNumber-1][i] = SynapseSlotWave[ChannelNumber-1][0]
		RampWave[ChannelNumber-1][i] = RampWave[ChannelNumber-1][0]
		i += 1
	while(i<n)

	//// Refresh the slot check box
	WC_ToggleSlotOnDisplay()
	
	//// Show the wave?
	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
	//// Redefine previous slot to be present slot
	PreviousSlot = SlotNumber
	PopupMenu SlotNumberPopup,mode=SlotNumber,win=MultiPatch_WaveCreator		// Only necessary if called by other routine rather than through popup
	
	ControlUpdate/A/W=MultiPatch_WaveCreator

end

//////////////////////////////////////////////////////////////////////////////////
//// Edit Range of Values after SetVar was changed

Function WC_EditRangeAfterSetVarChange(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	if (Exists("MP_Values")!=1)
		Print "MP_Values wave does not exist! Creating it..."
		WC_EditRange("")
	endif
	
	WAVE		MP_Values
	NVAR		WC_RangeStart = root:MP:WC_RangeStart
	NVAR		WC_RangeStep = root:MP:WC_RangeStep

	MP_Values = WC_RangeStep*x+WC_RangeStart

End	

//////////////////////////////////////////////////////////////////////////////////
//// Little window for managing EPSP-tracking parameters

Function PM_EPSPParamsWindow()

	Variable	PanX = 240
	Variable	PanY = 200
	Variable	PanWidth = 320
	Variable	PanHeight = 200

	NVAR		ScSc = root:MP:ScSc
	
	Variable	xPos = 8
	Variable	yShift = 4+28
	Variable	controlHeight = 20
	Variable	fontSize = 14
	Variable	rowSpacing = 24

	DoWindow/K EPSP_ParametersWin
	NewPanel/K=1/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) as "EPSP parameters"
	DoWindow/C EPSP_ParametersWin
	
	SetDrawLayer UserBack
	SetDrawEnv fsize=(fontSize+4),fstyle=5,textxjust=1,textyjust= 2
	DrawText PanWidth/2,4,"EPSP-tracking parameters"

	SetVariable RT_EPSPLatencySetVar,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},title="EPSP peak latency [s]:"
	SetVariable RT_EPSPLatencySetVar,limits={0,Inf,0.001},value=root:MP:PM_Data:RT_EPSPLatency,fsize=(fontSize)
	yShift += rowSpacing
	
	SetVariable RT_EPSPWidthSetVar,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},title="EPSP window width [s]:"
	SetVariable RT_EPSPWidthSetVar,limits={0,Inf,0.001},value=root:MP:PM_Data:RT_EPSPWidth,fsize=(fontSize)
	yShift += rowSpacing
	
	SetVariable RT_EPSPBaseStartSetVar,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},title="Baseline start [s]:"
	SetVariable RT_EPSPBaseStartSetVar,limits={-Inf,Inf,0.001},value=root:MP:PM_Data:RT_EPSPBaseStart,fsize=(fontSize)
	yShift += rowSpacing
	
	SetVariable RT_EPSPBaseWidthSetVar,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},title="Baseline window width [s]:"
	SetVariable RT_EPSPBaseWidthSetVar,limits={0,Inf,0.001},value=root:MP:PM_Data:RT_EPSPBaseWidth,fsize=(fontSize)
	yShift += rowSpacing
	
	Button CloseThisPanelButton,pos={xPos+16,yShift},size={panWidth-xPos*2-32,controlHeight},title="Close this panel"
	Button CloseThisPanelButton,proc=PM_EPW_CloseThisPanelProc,fsize=(fontSize),fColor=(65535,0,0)
	yShift += rowSpacing
	PanHeight = yShift

	MoveWindow/W=EPSP_ParametersWin PanX,PanY,PanX+PanWidth/ScSc,PanY+PanHeight/ScSc
	ModifyPanel/W=EPSP_ParametersWin fixedSize=1

End

Function PM_EPW_CloseThisPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/K EPSP_ParametersWin
			break
	endswitch

	return 0
End

Function PM_RT_EPSPParamsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			PM_EPSPParamsWindow()
			break
	endswitch

	return 0
End


//////////////////////////////////////////////////////////////////////////////////
//// Add connectivity graph to Log

Function Conn_ConnGraph2LogProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	WAVE	Conn_Matrix = root:MP:PM_Data:Conn_Matrix
	
	WAVE/T	WaveInVarNames = 			root:MP:IO_Data:WaveInVarNames

	Variable	i,j
	
	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow ConnectivityGraph
			if (!(V_Flag))
				Conn_DoMakeConnGraph()
				DoUpdate
			endif
			Notebook Parameter_Log selection={endOfFile, endOfFile}
			Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Connectivity graph\r",textRGB=(0,0,0)
			Notebook Parameter_Log ruler=Normal, text="\tProduced at time "+Time()+".\r"
			Notebook Parameter_Log ruler=Normal, text="\r"
			Notebook Parameter_Log ruler=ImageRow, picture={ConnectivityGraph,-1,1},selection={startOfParagraph, endOfParagraph}, convertToPNG=1, selection={endOfFile, endOfFile},text="\r"
			Notebook Parameter_Log ruler=Normal, text="\r"
			Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Connectivity matrix\r",textRGB=(0,0,0)
			i = 0
			do
				Notebook Parameter_Log ruler=Normal, text="\t"
				j = 0
				do
					Notebook Parameter_Log ruler=Normal, text=num2str(Conn_Matrix[j][i])
					if (j<3)
						Notebook Parameter_Log ruler=Normal, text=","
					endif
					j += 1
				while(j<4)
				Notebook Parameter_Log ruler=Normal, text="\r"
				i += 1
			while(i<4)
			i = 0
			do
				SVAR	baseName = $("root:MP:IO_Data:"+WaveInVarNames[i])
				Notebook Parameter_Log ruler=Normal, text="\tChannel #"+num2str(i+1)+": "+baseName[0,strlen(baseName)-2]+"\r"
				i += 1
			while(i<4)
			Notebook Parameter_Log ruler=Normal, text="\r"
			break
	endswitch

	return 0
End


//////////////////////////////////////////////////////////////////////////////////
//// Make connectivity graph
//// This shows -- based on the connectivity panel -- how cells in a quadruple recording are
//// interconnected to each other

Function Conn_MakeConnGraphProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Conn_DoMakeConnGraph()
			break
	endswitch

	return 0
End

Function Conn_DoMakeConnGraph()

	WAVE/T	WaveInVarNames = 			root:MP:IO_Data:WaveInVarNames

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	Variable	RRect_Width = 100
	Variable	RRect_Height = 50//RRect_Width
	Variable	RRect_x = 4
	Variable	RRect_y = 10+18+10
	Variable	RRect_x_sp = RRect_Width+100
	Variable	RRect_y_sp = RRect_Height+100
	
	Variable	txt_ln_sp = 20
	Variable	txt_size = 16
	
	Variable	conn_x_sp = RRect_Width/2+15
	Variable	conn_y_sp = RRect_Height/2+15//conn_x_sp
	
	Variable	chk_x_sp = conn_x_sp-10
	Variable	chk_y_sp = conn_y_sp-10//chk_x_sp
	Variable	chk_xAdj = -7
	Variable	chk_yAdj = -6
	
	Variable	PanX = 320
	Variable	PanY = 180
	Variable	PanWidth = RRect_x+RRect_Width+RRect_x_sp+RRect_x
	Variable	PanHeight = RRect_y+RRect_Height+RRect_y_sp+RRect_x+12
	PanX += 60
	PanY += 60
	Variable	i,j,k

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	Variable		ScSc = 1

	Make/O/N=(2) dummyData1,dummyData2
	dummyData2 = {0,PanWidth}
	dummyData1 = {0,PanHeight}

	DoWindow/K ConnectivityGraph
	Display/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) dummyData1 vs dummyData2 as "Connectivity Graph" //K=2
	DoWindow/C ConnectivityGraph

	// Coordinates specifying the physical relative location of the manipulators for each channel, origin is top left corner
	WAVE	Manip_xPos
	WAVE	Manip_yPos
	// Coordinates specifying the physical relative location of the manipulators for each channel, origin is top left corner

	Make/O/N=(4) RRect_xCenter,RRect_yCenter
	
	SetDrawLayer UserFront
	
	SetDrawEnv xcoord= bottom,ycoord= left
	SetDrawEnv textxjust= 1,textyjust= 2
	SetDrawEnv fstyle=5,fSize=txt_size*1.2
	DrawText PanWidth/2,0,"Connectivity Graph"

	Variable	xShift = 4
	Variable	bY = 8
	Variable	bSpacing = 8

	Variable	grayBack = 65535*0.6

	// Make cells
	i = 0
	do
		SetDrawEnv xcoord= bottom,ycoord= left
		SetDrawEnv linethick = 2
		SetDrawEnv fillfgc=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
//		SetDrawEnv fillfgc=(0,0,0)
		DrawRRect RRect_x+Manip_xPos[i]*RRect_x_sp,RRect_y+RRect_Height+Manip_yPos[i]*RRect_y_sp,RRect_x+RRect_Width+Manip_xPos[i]*RRect_x_sp,RRect_y+Manip_yPos[i]*RRect_y_sp
		RRect_xCenter[i] = RRect_x+Manip_xPos[i]*RRect_x_sp+RRect_Width/2
		RRect_yCenter[i] = RRect_y+Manip_yPos[i]*RRect_y_sp+RRect_Height/2
		SetDrawEnv xcoord= bottom,ycoord= left
		SetDrawEnv textxjust= 1,textyjust= 1
		SetDrawEnv fstyle=0,fSize=txt_size
		DrawText RRect_xCenter[i],RRect_yCenter[i]-txt_ln_sp/2,"Ch#"+num2str(i+1)
		SVAR	baseName = $("root:MP:IO_Data:"+WaveInVarNames[i])
		SetDrawEnv xcoord= bottom,ycoord= left
		SetDrawEnv textxjust= 1,textyjust= 1
		SetDrawEnv fstyle=0,fSize=txt_size
		DrawText RRect_xCenter[i],RRect_yCenter[i]+txt_ln_sp/2,baseName[0,strlen(baseName)-2]
		i += 1
	while(i<4)
	
	// Connect cells
	WAVE	Conn_Matrix = root:MP:PM_Data:Conn_Matrix
	Variable	xD,yD
	String		checkName
	i = 0
	do
		j = i+1
		if (j<4)
			do
				xD = Round(Manip_xPos[j]-Manip_xPos[i])
				yD = Round(Manip_yPos[j]-Manip_yPos[i])
				if ((Conn_Matrix[j][i]) %| (Conn_Matrix[i][j]))
					SetDrawEnv xcoord= bottom,ycoord= left
					SetDrawEnv linethick= 2,arrowfat= 1
					if ((Conn_Matrix[j][i]) %& (Conn_Matrix[i][j]))
						SetDrawEnv arrow= 3
					else
						if (Conn_Matrix[j][i])
							SetDrawEnv arrow= 2
						else
							SetDrawEnv arrow= 1
						endif
					endif
					DrawLine RRect_xCenter[i]+xD*conn_x_sp,RRect_yCenter[i]+yD*conn_y_sp,RRect_xCenter[j]-xD*conn_x_sp,RRect_yCenter[j]-yD*conn_y_sp
				endif
				checkName = "conn_"+num2str(j+1)+"_"+num2str(i+1)
				checkName = "conn_"+num2str(i+1)+"_"+num2str(j+1)
				j += 1
			while(j<4)
		endif
		i += 1
	while(i<4)
	
	ModifyGraph noLabel=2,axThick=0
	ModifyGraph mode=2
	ModifyGraph margin = 2
	ModifyGraph rgb=(65535,65535,65535)
	SetAxis/A/R left

	Button CopyConnGraph,pos={1,1},size={36,18},title="Copy",proc=Conn_CopyConnGraphProc,fSize=11,font='Arial'
	Button CloseConnGraph,pos={1,1+18+1},size={36,18},proc=Conn_CloseConnGraphProc,title="Kill",fSize=11,font='Arial'

End

Function Conn_CopyConnGraphProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String		nameStr

	switch( ba.eventCode )
		case 2: // mouse up
			if (Exists("Var_Graph_name"))
				SVAR	Var_Graph_name
			else
				String/G	Var_Graph_name
			endif
			Var_Graph_name = "enter name here"
			JT_MakeQueryPanel("Enter new graph name","Graph name","Conn_NameConnGraphCopyProc()")
			break
	endswitch

	return 0
End

Function Conn_CloseConnGraphProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String		nameStr

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/K ConnectivityGraph
			break
	endswitch

	return 0
End

Function Conn_NameConnGraphCopyProc()

//	WAVE/T	JT_QueryWave
	SVAR	Var_Graph_name

	Variable	PanX = 64
	Variable	PanY = 64
	Variable	PanWidth = 240
	Variable	PanHeight = 200

	NVAR		ScSc = root:MP:ScSc

	DoWindow/F ConnectivityGraph
	JT_DuplicateGraph()
	String	windowName = Var_Graph_name
	kw(windowName)
	nw(windowName)
	KillControl/W=$(windowName) CopyConnGraph
	KillControl/W=$(windowName) CloseConnGraph
	MoveWindow /W=$(windowName) PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight

End


//////////////////////////////////////////////////////////////////////////////////
//// Make connectivity matrix
//// This describes how cells in a quadruple recording are interconnected to each other

Function Conn_MakeConnectivityPanel()
	
	WAVE/T	WaveInVarNames = 			root:MP:IO_Data:WaveInVarNames

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	Variable	RRect_Width = 100
	Variable	RRect_Height = 50//RRect_Width
	Variable	RRect_x = 4
	Variable	RRect_y = 10+18+10+24+2
	Variable	RRect_x_sp = RRect_Width+100
	Variable	RRect_y_sp = RRect_Height+100
	
	Variable	txt_ln_sp = 20
	Variable	txt_size = 16
	
	Variable	conn_x_sp = RRect_Width/2+25
	Variable	conn_y_sp = RRect_Height/2+25//conn_x_sp
	
	Variable	chk_x_sp = conn_x_sp-10
	Variable	chk_y_sp = conn_y_sp-10//chk_x_sp
	Variable	chk_xAdj = -7
	Variable	chk_yAdj = -6
	
	Variable	PanX = 320
	Variable	PanY = 180
	Variable	PanWidth = RRect_x+RRect_Width+RRect_x_sp+RRect_x
	Variable	PanHeight = RRect_y+RRect_Height+RRect_y_sp+RRect_x+12

	Variable	i,j,k
	
	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	NVAR		ScSc = root:MP:ScSc

	DoWindow/F ConnectivityPanel
	if (V_flag)
		GetWindow ConnectivityPanel, wsize
		PanX = V_left
		PanY = V_top
	endif

	DoWindow/K ConnectivityPanel
	NewPanel/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight)/K=2 as "Connectivity Panel" //K=2
//	NewPanel/W=(PanX,PanY,PanX+PanWidth,PanY+PanHeight) as "Connectivity Panel" //K=2
	DoWindow/C ConnectivityPanel
	ModifyPanel/W=ConnectivityPanel fixedSize=1
	
	// Coordinates specifying the physical relative location of the manipulators for each channel, origin is top left corner
	Make/O/N=(4) Manip_xPos = {1,1,0,0}
	Make/O/N=(4) Manip_yPos = {0,1,1,0}

	Make/O/N=(4) RRect_xCenter,RRect_yCenter
	
	SetDrawLayer UserBack
	
	// Add buttons
	Variable	xShift = 12
	Variable	bY = 8
	Variable	bSpacing = 8
	Button CloseButton,pos={xShift,bY},size={56,20},title="Close",proc=Conn_CloseProc,fColor=(65535,0,0)
	xShift += 56+bSpacing
	Button RedrawButton,pos={xShift,bY},size={64,20},title="Redraw",proc=Conn_RedrawProc
	xShift += 64+bSpacing
	Button ReadValuesButton,pos={xShift,bY},size={90,20},title="Read values",proc=Conn_ReadValuesProc
	xShift += 90+bSpacing
	Button ClearValuesButton,pos={xShift,bY},size={50,20},title="Clear",proc=Conn_ClearValuesProc
	xShift += 50+bSpacing
	
	bY += 24
	xShift = 12
	Button MakeConnGraphButton,pos={xShift,bY},size={140,20},title="Connectivity graph",proc=Conn_MakeConnGraphProc
	xShift += 140+bSpacing
	Button ConnGraph2LogButton,pos={xShift,bY},size={136,20},title="Graph to log",proc=Conn_ConnGraph2LogProc
	xShift += 136+bSpacing

	Variable	grayBack = 65535*0.6
	SetDrawEnv linethick= 0,fillfgc=(grayBack,grayBack,grayBack)
//	DrawLine 0,27,PanWidth,27
	DrawRRect 4,4,PanWidth-4,32+24+2

	// Make cells
	i = 0
	do
		SetDrawEnv linethick = 2
		SetDrawEnv fillfgc=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
//		SetDrawEnv fillfgc=(0,0,0)
		DrawRRect RRect_x+Manip_xPos[i]*RRect_x_sp,RRect_y+Manip_yPos[i]*RRect_y_sp,RRect_x+RRect_Width+Manip_xPos[i]*RRect_x_sp,RRect_y+RRect_Height+Manip_yPos[i]*RRect_y_sp
		RRect_xCenter[i] = RRect_x+Manip_xPos[i]*RRect_x_sp+RRect_Width/2
		RRect_yCenter[i] = RRect_y+Manip_yPos[i]*RRect_y_sp+RRect_Height/2
		SetDrawEnv textxjust= 1,textyjust= 1
		SetDrawEnv fstyle=0,fSize=txt_size
		DrawText RRect_xCenter[i],RRect_yCenter[i]-txt_ln_sp/2,"Ch#"+num2str(i+1)
		SVAR	baseName = $("root:MP:IO_Data:"+WaveInVarNames[i])
		SetDrawEnv textxjust= 1,textyjust= 1
		SetDrawEnv fstyle=0,fSize=txt_size
		DrawText RRect_xCenter[i],RRect_yCenter[i]+txt_ln_sp/2,baseName[0,strlen(baseName)-2]
		i += 1
	while(i<4)
	
	// Connect cells
	WAVE	Conn_Matrix = root:MP:PM_Data:Conn_Matrix
	Variable	xD,yD
	String		checkName
	i = 0
	do
		j = i+1
		if (j<4)
			do
				xD = Round(Manip_xPos[j]-Manip_xPos[i])
				yD = Round(Manip_yPos[j]-Manip_yPos[i])
				SetDrawEnv linethick= 2,arrow= 3,arrowfat= 1
				DrawLine RRect_xCenter[i]+xD*conn_x_sp,RRect_yCenter[i]+yD*conn_y_sp,RRect_xCenter[j]-xD*conn_x_sp,RRect_yCenter[j]-yD*conn_y_sp
				checkName = "conn_"+num2str(j+1)+"_"+num2str(i+1)
				CheckBox $(checkName),pos={chk_xAdj+RRect_xCenter[i]+xD*chk_x_sp,chk_yAdj+RRect_yCenter[i]+yD*chk_y_sp},size={16,14},title="",value=Conn_Matrix[j][i],proc=Conn_CheckReadValuesProc
				checkName = "conn_"+num2str(i+1)+"_"+num2str(j+1)
				CheckBox $(checkName),pos={chk_xAdj+RRect_xCenter[j]-xD*chk_x_sp,chk_yAdj+RRect_yCenter[j]-yD*chk_y_sp},size={16,14},title="",value=Conn_Matrix[i][j],proc=Conn_CheckReadValuesProc
				j += 1
			while(j<4)
		endif
		i += 1
	while(i<4)

End

Function Conn_CloseProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Conn_DoReadValues()
			DoWindow/K ConnectivityPanel
			break
	endswitch

	return 0
End

Function Conn_RedrawProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Conn_DoReadValues()
			Conn_MakeConnectivityPanel()
			break
	endswitch

	return 0
End

Function Conn_ReadValuesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	WAVE	Conn_Matrix = root:MP:PM_Data:Conn_Matrix

	switch( ba.eventCode )
		case 2: // mouse up
			Conn_DoReadValues()
			Print "=== Reading connectivity matrix ==="
			Print "\t",Date(),Time()
			print Conn_Matrix
			break
	endswitch

	return 0
End

Function Conn_CheckReadValuesProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			Conn_DoReadValues()
			break
	endswitch

	return 0
End

Function Conn_ClearValuesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	WAVE	Conn_Matrix = root:MP:PM_Data:Conn_Matrix

	Variable	setValue = 0
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
//		Print "\tYou pressed the Shift key."
		setValue = 1
	endif

	switch( ba.eventCode )
		case 2: // mouse up
			Conn_Matrix = setValue
			if (setValue)
			endif
			Conn_MakeConnectivityPanel()
			break
		case 5: // mouse enter
			if (setValue)
				Button ClearValuesButton,title="Set",win=ConnectivityPanel//,fColor=(0,65535,0)
			else
				Button ClearValuesButton,title="Clear",win=ConnectivityPanel//,fColor=(65535,65535,65535)
			endif
			break
		case 6: // mouse leave
			Button ClearValuesButton,title="Clear",win=ConnectivityPanel//,fColor=(65535,65535,65535)
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////////
//// Read connectivity matrix from connectivity panel

Function Conn_DoReadValues()

	Variable	i,j,k
	
	DoWindow ConnectivityPanel
	if (V_flag)
		
		WAVE	Conn_Matrix = root:MP:PM_Data:Conn_Matrix
		Conn_Matrix = NaN
		
		String		checkName
		i = 0
		do
			j = i+1
			if (j<4)
				do
					checkName = "conn_"+num2str(j+1)+"_"+num2str(i+1)
					ControlInfo/W=ConnectivityPanel $(checkName)
					if (V_flag==2)
						Conn_Matrix[j][i] = V_Value
					else
						Print "Strange error for conn_"+num2str(j+1)+"_"+num2str(i+1)+" -- it does not exist."
						Abort "Strange error for conn_"+num2str(j+1)+"_"+num2str(i+1)+" -- it does not exist."
					endif
					checkName = "conn_"+num2str(i+1)+"_"+num2str(j+1)
					ControlInfo/W=ConnectivityPanel $(checkName)
					if (V_flag==2)
						Conn_Matrix[i][j] = V_Value
					else
						Print "Strange error for conn_"+num2str(i+1)+"_"+num2str(j+1)+" -- it does not exist."
						Abort "Strange error for conn_"+num2str(i+1)+"_"+num2str(j+1)+" -- it does not exist."
					endif
					j += 1
				while(j<4)
			endif
			i += 1
		while(i<4)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////

Function MakeMultiPatch_PatternMaker()

	String		CommandStr

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	NVAR	ScSc = root:MP:ScSc
	NVAR	NSteps = root:MP:PM_Data:NSteps
	NVAR	MaxSteps = root:MP:PM_Data:MaxSteps
	NVAR	RT_SealTestOnOff = root:MP:PM_Data:RT_SealTestOnOff
	NVAR	RT_VmOnOff = root:MP:PM_Data:RT_VmOnOff
	NVAR	RT_EPSPOnOff = root:MP:PM_Data:RT_EPSPOnOff
	NVAR	RT_EPSPUseGrab = root:MP:PM_Data:RT_EPSPUseGrab
	NVAR	RT_EPSPUseMatrix = root:MP:PM_Data:RT_EPSPUseMatrix
	NVAR	RT_StableBaseline = root:MP:PM_Data:RT_StableBaseline
	NVAR	RT_RepeatPattern = root:MP:PM_Data:RT_RepeatPattern
	
	WAVE	ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE	ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE	ChannelColor_B = root:MP:IO_Data:ChannelColor_B
	
	String WorkStr1,WorkStr2
	
	Variable	i = 0
	Variable	j = 0

	Variable	WinX = 144						// Panel x position
	Variable	WinY = 50							// Panel y position

	Variable	OriX = 4							// Reference point in x direction
	Variable	OriY = 117+29						// Reference point in y direction ***** UPDATE IN PM_DrawDot as well *****
	Variable	SpNo = 24							// Spacing for the numbering column
	Variable	SpOutputs = 160					// Spacing for output columns
	Variable	SpInputs = 20						// Spacing for input columns
	Variable	SpRepeats = 60						// Spacing for the repeat column
	Variable	SpISI = 60							// Spacing for the inter-stimulus interval column
	Variable	SpRMargin = OriX					// Leave a small margin at the right hand of the window
	Variable	SpLines	= 22						// Spacing of lines ***** UPDATE IN PM_DrawDot as well *****
	Variable	SpBMargin = 4						// Leave a small margin at the bottom of the window
	Variable	TextAdj = 16						// Adjustment for text to keep it on the same line
	Variable	CheckAdj = -2						// Ditto for checkboxes
	
	Variable	WinWidth = OriX+SpNo+SpOutputs*4+SpInputs*4+SpRepeats+SpISI+SpRMargin	// Panel width
	Variable	WinHeight = OriY+SpLines*(NSteps+1)+SpBMargin				// Panel height

	DoWindow MultiPatch_PatternMaker
	if (V_Flag)										// Panel already exists --> don't move it when recreating it!
		GetWindow MultiPatch_PatternMaker, wsize
		WinX = V_left
		WinY = V_top
	endif
	DoWindow/K MultiPatch_PatternMaker
	NewPanel/K=2/W=(WinX*ScSc,WinY*ScSc,WinX*ScSc+WinWidth,WinY*ScSc+WinHeight) as "MultiPatch PatternMaker"
	DoWindow/C MultiPatch_PatternMaker
	ModifyPanel/W=MultiPatch_PatternMaker fixedSize=1
	DoUpdate
	SetDrawLayer UserBack

	SetDrawEnv linethick= 2,fillfgc= (29524,1,58982),fillbgc= (29524,1,58982)
	DrawRect 4,4,266,38
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
	DrawText 18,31,"MultiPatch PatternMaker"

	SetVariable PatternNameSetVar,pos={270,4},size={180,17},title="Pattern: "
	SetVariable PatternNameSetVar,value=root:MP:PM_Data:PatternName

	SetVariable NStepsSetVar,pos={270,24},size={180,17},title="Number of steps: "
	SetVariable NStepsSetVar,limits={1,MaxSteps,1},proc=ChgNStepsProc,value=root:MP:PM_Data:NSteps

	Button SavePatternButton,pos={456,4},size={100,17},proc=SavePatternProc,title="Save pattern"
	Button LoadPatternButton,pos={456,24},size={100,17},proc=LoadPatternProc,title="Load pattern"

	Button GoToSwitchboardButton,pos={560,4},size={134,17},fColor=(65535/2,65535,65535/2),proc=GoToSwitchboard,title="Switchboard"
	Button GoToSpikeTimingCreatorButton,pos={560,24},size={134,17},fColor=(65535/2,65535/2,65535),proc=ST_GoToSpikeTimingCreator,title="SpikeTiming Creator",fSize=11

	Button HidePatternMakerButton,pos={698,4},size={168,17},proc=HidePatternMakerProc,title="Hide PatternMaker"
	Button PatternButton,pos={698,24},size={168,17},proc=PM_PatternProc,title="Run pattern"

	Variable YShift = 2
	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 4,42+YShift,206,67+YShift
	CheckBox RT_SealTestCheck, pos={8,45+YShift},size={100,20},labelBack=(rr,gg,bb),fsize=12,title="R_input plot",value=RT_SealTestOnOff,proc=StorePatternMakerCheckValues
	SetVariable RT_SealTestWidthSetVar,pos={112,46+YShift},labelBack=(rr,gg,bb),size={90,17},title="Width:"
	SetVariable RT_SealTestWidthSetVar,limits={0,Inf,5},value=root:MP:PM_Data:RT_SealTestWidth

	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 210,42+YShift,384,67+YShift
	CheckBox RT_VmCheck,pos={212,45+YShift},size={80,20},labelBack=(rr,gg,bb),fsize=12,title="V_m plot",value=RT_VmOnOff,proc=StorePatternMakerCheckValues
	SetVariable RT_VmWidthSetVar,pos={290,46+YShift},labelBack=(rr,gg,bb),size={90,17},title="Width:"
	SetVariable RT_VmWidthSetVar,limits={0,Inf,5},value=root:MP:PM_Data:RT_VmWidth

	SetDrawLayer UserBack
	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 448-60,42+YShift,866,67+YShift
	Button ROI0Go,pos={448-60+4,45+YShift},size={40,20},proc=PM_RT_GotoROIProc,title="Auto",labelBack=(rr,gg,bb)

	Variable	ROI_x = 720-36*4-70
	Variable	ROI_w = 36
	SetDrawLayer UserFront
	SetDrawEnv fstyle=0,textxjust=0,fsize=14
	DrawText ROI_x-70,46+YShift+17,"Goto ROI: "
	Button ROI1Go,pos={ROI_x+ROI_w*0,45+YShift},size={ROI_w-6,20},proc=PM_RT_GotoROIProc,title=" 1 ",labelBack=(rr,gg,bb)
	Button ROI2Go,pos={ROI_x+ROI_w*1,45+YShift},size={ROI_w-6,20},proc=PM_RT_GotoROIProc,title=" 2 ",labelBack=(rr,gg,bb)
	Button ROI3Go,pos={ROI_x+ROI_w*2,45+YShift},size={ROI_w-6,20},proc=PM_RT_GotoROIProc,title=" 3 ",labelBack=(rr,gg,bb)
	Button ROI4Go,pos={ROI_x+ROI_w*3,45+YShift},size={ROI_w-6,20},proc=PM_RT_GotoROIProc,title=" 4 ",labelBack=(rr,gg,bb)

	ROI_x = 720
	ROI_w = 36
	SetDrawLayer UserFront
	SetDrawEnv fstyle=0,textxjust=0,fsize=14
	DrawText ROI_x-70,46+YShift+17,"Grab ROI: "
	Button ROI1Grab,pos={ROI_x+ROI_w*0,45+YShift},size={ROI_w-6,20},proc=PM_RT_TakeROIProc,title=" 1 ",labelBack=(rr,gg,bb)
	Button ROI2Grab,pos={ROI_x+ROI_w*1,45+YShift},size={ROI_w-6,20},proc=PM_RT_TakeROIProc,title=" 2 ",labelBack=(rr,gg,bb)
	Button ROI3Grab,pos={ROI_x+ROI_w*2,45+YShift},size={ROI_w-6,20},proc=PM_RT_TakeROIProc,title=" 3 ",labelBack=(rr,gg,bb)
	Button ROI4Grab,pos={ROI_x+ROI_w*3,45+YShift},size={ROI_w-6,20},proc=PM_RT_TakeROIProc,title=" 4 ",labelBack=(rr,gg,bb)

	YShift = 2+29
	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 4,42+YShift,8+145+78+8+78+4+98+7,67+19+YShift
	CheckBox RT_EPSPCheck, pos={8,45+YShift},size={145,20},labelBack=(rr,gg,bb),fsize=12,title="EPSP amplitude plot",value=RT_EPSPOnOff,proc=StorePatternMakerCheckValues
	Button TakeEPSPRangeButton,pos={157,45+YShift},size={58,20+20},proc=PM_RT_GrabEPSPProc,title="Grab\rEPSP",labelBack=(rr,gg,bb)
	Button EPSPParamsButton,pos={8,45+19+YShift},size={143,20},proc=PM_RT_EPSPParamsProc,title="EPSP parameters",labelBack=(rr,gg,bb)
	Button ConnectivityPanelButton,pos={157+58+4,45+YShift},size={98,20+20},proc=Conn_RedrawProc,title="Connectivity\rMatrix",labelBack=(rr,gg,bb)

	CheckBox RT_UseGrabCheck, pos={157+58+4+98+4,45+YShift},size={145,20},labelBack=(rr,gg,bb),fsize=12,title="Use grab",value=RT_EPSPUseGrab,proc=StorePatternMakerCheckValues
	CheckBox RT_UseMatrixCheck, pos={157+58+4+98+4,45+19+YShift},size={145,20},labelBack=(rr,gg,bb),fsize=12,title="Use matrix",value=RT_EPSPUseMatrix,proc=StorePatternMakerCheckValues

	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 484-54,42+YShift,696-54+4+70,67+19+YShift
	Button BringThePlotsToFrontButton,pos={436,45+YShift},size={60,20+20},proc=PM_RT_BringThePlotsToFrontProc,title="Plots\rto front",labelBack=(rr,gg,bb)
	Button CloseThePlotsButton,pos={436+64,45+YShift},size={50,20},proc=PM_RT_CloseThePlotsProc,title="Close",labelBack=(rr,gg,bb)
	Button ResizeThePlotsButton,pos={436+54+64,45+YShift},size={60,20},proc=PM_RT_ResizeThePlotsProc,title="Resize",labelBack=(rr,gg,bb)
	Button AppearanceModeButton,pos={436+54+64+64,45+YShift},size={90,20},proc=PM_RT_AppearanceModeProc,title="Appearance",labelBack=(rr,gg,bb)
	PopupMenu PlotPreviousPopUp,pos={436+64,45+YShift+20},size={50+60+90+4+4,19},proc=PlotPreviousProc,mode=1,title="Show this many prior runs:",value="0;1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;",font="Arial",fSize=11

	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 696-54+4+70+4,42+YShift,696-54+4+70+158-8,67+19+YShift
	SetDrawEnv fsize=14,fstyle=2
	SetVariable TotalElapsedCountSetVar,pos={704+20,46+YShift},size={70,17},labelBack=(rr,gg,bb),limits={-inf,inf,0},noEdit=1,frame=0,title="Total:",value=root:MP:PM_Data:TotalIterCounter
	SetVariable ElapsedCountSetVar,pos={704+20+10+60+4,46+YShift},size={60,17},labelBack=(rr,gg,bb),limits={-inf,inf,0},noEdit=1,frame=0,title="Rep:",value=root:MP:PM_Data:DummyIterCounter
	SetVariable ElapsedMinsSetVar,pos={704+20,46+19+YShift},size={70,17},labelBack=(rr,gg,bb),limits={-inf,inf,0},noEdit=1,frame=0,title="min:",value=root:MP:PM_Data:ElapsedMins
	SetVariable ElapsedSecsSetVar,pos={704+20+10+60+4,46+19+YShift},size={60,17},labelBack=(rr,gg,bb),limits={-inf,inf,0},noEdit=1,frame=0,title="sec:",value=root:MP:PM_Data:ElapsedSecs

	SetVariable ISINoiseSetVar,pos={704+20,46+19*2+YShift+4},size={158-20,17},title="1/f noise [s]:"
	SetVariable ISINoiseSetVar,limits={0,Inf,0.001},value=root:MP:PM_Data:ISINoise
	CheckBox RT_StableBaselineCheck, pos={704+20,46+19*3+YShift},size={158-20,20},title="Baseline stability",value=RT_StableBaseline,proc=StorePatternMakerCheckValues

	YShift = 2+29+29+19
	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 4,42+YShift,480-54-78-4+100+4,67+YShift
	CheckBox RT_RepeatPatternCheck, pos={8,45+YShift},size={145,20},labelBack=(rr,gg,bb),fsize=12,proc=PM_RT_RepeatPatternToggleProc,title="Repeat the pattern",value=RT_RepeatPattern,proc=StorePatternMakerCheckValues
	SetVariable RT_RepeatNTimesSetVar,pos={157,46+YShift},labelBack=(rr,gg,bb),size={90+90,17},title="Number of repeats:"
	SetVariable RT_RepeatNTimesSetVar,limits={0,Inf,1},value=root:MP:PM_Data:RT_RepeatNTimes
	SetVariable RT_IPISetVar,pos={157+90+90+4,46+YShift},labelBack=(rr,gg,bb),size={100,17},title="IPI [s]:"
	SetVariable RT_IPISetVar,limits={0,Inf,1},value=root:MP:PM_Data:RT_IPI

	YShift = 2+29+29+19
	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 480-54-78+100+4,42+YShift,480-54-78+180+8+100+4,67+YShift
	Button ManipulatePatternButton,pos={480-54-78+4+100+4,45+YShift},size={180,20},proc=PM_PatternManipulatorProc,title="Manipulate pattern",labelBack=(rr,gg,bb)

	SetDrawEnv fillfgc=(rr,gg,bb)
	DrawRect 480-54-78+4+100+4+180+4+4,42+YShift,480-54-78+4+100+4+180+4+4+72,67+YShift
	Button AveragerSettingsButton,pos={480-54-78+4+100+4+180+4+4+4,45+YShift},size={64,20},proc=PM_RT_AveragerSettingsProc,title="Averager",labelBack=(rr,gg,bb)

	//// Make headers
	i = 0
	SetDrawEnv fstyle=1,textxjust=2
	DrawText OriX+SpNo,OriY+TextAdj+2,"# "
	do
		SetDrawEnv linethick = 2
		SetDrawEnv linefgc=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
		DrawLine OriX-2+SpNo+i*SpOutputs,OriY+TextAdj+2,OriX+SpNo+i*SpOutputs+SpOutputs-6,OriY+TextAdj+2
		SetDrawEnv fstyle=1,textxjust=0
		DrawText OriX+SpNo+i*SpOutputs,OriY+TextAdj+2,"Output channel "+num2str(i+1)
		SetDrawEnv linethick = 2
		SetDrawEnv linefgc=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
		DrawLine OriX-2+SpNo+SpOutputs*4+SpInputs*i,OriY+TextAdj+2,OriX-2+SpNo+SpOutputs*4+SpInputs*i+SpInputs-4,OriY+TextAdj+2
		i += 1
	while (i<4)
	SetDrawEnv fstyle=1,textxjust=0
	DrawText OriX+SpNo+4*SpOutputs,OriY+TextAdj+2,"Inputs 1-4"
	SetDrawEnv fstyle=1,textxjust=0
	DrawText OriX+SpNo+4*SpOutputs+4*SpInputs,OriY+TextAdj+2,"Repeats"
	SetDrawEnv fstyle=1,textxjust=0
	DrawText OriX+SpNo+4*SpOutputs+4*SpInputs+SpRepeats,OriY+TextAdj+2,"1/f [s]"

	//// Make program layout
	OriY += SpLines							// Account for the header line
	i = 0											// Line/pattern counter
	do
		j = 0										// Column/channel counter
		do

			SetDrawEnv fstyle=1,textxjust=2
			DrawText OriX+SpNo,OriY+SpLines*i+TextAdj,num2str(i+1)+"."

			NVAR	theValue = $("root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1))
			CheckBox $("OutputOnOff_"+num2str(i+1)+"_"+num2str(j+1)),pos={OriX+SpNo+SpOutputs*j,OriY+SpLines*i+CheckAdj+4},size={17,20},title="",value=theValue

			SVAR	theStrValue = $("root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1))
			PopupMenu $("OutputWave_"+num2str(i+1)+"_"+num2str(j+1)),pos={OriX+SpNo+SpOutputs*j+18,OriY+SpLines*i},size={SpOutputs-17-4,19},mode=1,popvalue=theStrValue,value=#"WaveList(\"Out*\", \";\", \"\")"	// NB! popvalue CANNOT break the line, must be on this line!

			NVAR	theValue = $("root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1))
			CheckBox $("InputOnOff_"+num2str(i+1)+"_"+num2str(j+1)), pos={OriX+SpNo+SpOutputs*4+SpInputs*j,OriY+SpLines*i+CheckAdj+4},size={17,20},title="",value=theValue

			j += 1
		while (j<4)

		NVAR	theValue = $("root:MP:PM_Data:NRepeats"+num2str(i+1))
		SetVariable $("NRepeats_"+num2str(i+1)),pos={OriX+SpNo+SpOutputs*4+SpInputs*4,OriY+SpLines*i},size={SpRepeats-4,20},limits={1,Inf,1},title=" ",value=theValue

		NVAR	theValue = $("root:MP:PM_Data:ISI"+num2str(i+1))
		SetVariable $("ISI_"+num2str(i+1)),pos={OriX+SpNo+SpOutputs*4+SpInputs*4+SpRepeats,OriY+SpLines*i},size={SpISI-4,20},limits={1,Inf,1},title=" ",value=theValue

		i += 1
	while (i<NSteps)

End

//////////////////////////////////////////////////////////////////////////////////
//// Plot this many previous runs in the PatternMaker windows

Function PlotPreviousProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	NVAR		RT_nPlotRepeats = root:MP:PM_Data:RT_nPlotRepeats
	WAVE		RT_PatternSuffixWave													// Keep track of all old pattern runs by remembering the timestamp

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			RT_nPlotRepeats = popNum-1
			print "Will try to plot this many prior runs:",RT_nPlotRepeats
			if (RT_nPlotRepeats>numpnts(RT_PatternSuffixWave))
				print "\t\tHowever, only "+num2str(numpnts(RT_PatternSuffixWave))+" available for plotting."
			endif
			PM_RT_CloseThePlotsProc("")
			PM_RT_Prepare_Waves_n_Graphs(0)
			PM_SortOutXAxes(1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////////
//// This procedure saves all the parameters that are needed to describe a wave.

Macro SaveWaveDescriptorProc(ctrlName) : ButtonControl
	String		ctrlName

	make/O/N=(10) W_Params										// First create a wave that can be saved
	W_Params[0] = root:MP:ChannelType								// Intracellular or extracellular
	W_Params[1] = root:MP:CommandLevel								// Constant current/voltage command level   3/30/00 KM
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_PulseAmp
	W_PulseAmp[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:PulseAmp[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_NPulses
	W_NPulses[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:NPulses[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_PulseDur
	W_PulseDur[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:PulseDur[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_PulseFreq
	W_PulseFreq[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:PulseFreq[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_PulseDispl
	W_PulseDispl[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:PulseDispl[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_BiphasicFlag
	W_BiphasicFlag[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:BiphasicFlag[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_AddSlot
	W_AddSlot[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:AddSlotWave[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_SynapseSlot
	W_SynapseSlot[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:SynapseSlotWave[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_UseSlot
	W_UseSlot[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:UseSlotWave[root:MP:ChannelNumber-1][p]
	
	Make/O/N=(root:MP:IO_Data:NSlots) W_RampSlot
	W_RampSlot[0,root:MP:IO_Data:NSlots-1] = root:MP:IO_Data:RampWave[root:MP:ChannelNumber-1][p]
	
	Make/O/T/N=(1) W_WaveDescriptorName							// Create a text wave, coz strings cannot be saved
	W_WaveDescriptorName[0] = root:MP:CurrWaveDescriptor

	Save/O/T/I/P=WaveDescriptors W_Params,W_PulseAmp,W_NPulses,W_PulseDur,W_PulseFreq,W_PulseDispl,W_BiphasicFlag,W_AddSlot,W_SynapseSlot,W_UseSlot,W_RampSlot,W_WaveDescriptorName as root:MP:CurrWaveDescriptor

	print "Saving wave descriptor \""+root:MP:CurrWaveDescriptor+"\" at "+time()

	killwaves/Z W_Params					// Discard the parameter waves once they have been used
	killwaves/Z W_PulseAmp
	killwaves/Z W_NPulses
	killwaves/Z W_PulseDur
	killwaves/Z W_PulseFreq
	killwaves/Z W_PulseDispl
	killwaves/Z W_BiphasicFlag
	killwaves/Z W_AddSlot
	killwaves/Z W_SynapseSlot
	killwaves/Z W_UseSlot
	killwaves/Z W_RampSlot
	killwaves/Z W_WaveDescriptorName
	
End

//////////////////////////////////////////////////////////////////////////////////
//// This procedure saves all the parameters that are needed to describe a wave.

Macro LoadWaveDescriptorProc(ctrlName) : ButtonControl
	String		ctrlName

	String		CommandStr

	Loadwave/Q/O/T/P=WaveDescriptors/A=base

	if (exists("root:W_Params")==0)
		Abort "That's not a wave descriptor file!"
	endif

	Variable	OldFormat

	if (exists("root:W_PulseAmp")==0)
		Beep;Beep;
		Print "You are trying to load an old and mildly incompatible wave descriptor!"
		Print "Old format will be converted and loaded into the current slot of the current channel."
		OldFormat = 1
	else
		OldFormat = 0
	endif

	if (exists("root:W_SynapseSlot")==0)
		Beep;Beep;
		Print "You are trying to load an old and mildly incompatible wave descriptor! (Old format will be converted.)"
		Print "You should immediately resave the wave descriptor data using the same name. Doing this"
		Print "will prevent this error message from being displayed next time you load the wave descriptor."
		DoAlert 0,"There is a minor problem. Please read text in command history window."	
		Duplicate/O W_AddSlot,W_SynapseSlot
		W_SynapseSlot = 0
	endif

	if (exists("root:W_RampSlot")==0)
		Beep;Beep;
		Print "You are trying to load an old and mildly incompatible wave descriptor! (Old format will be converted.)"
		Print "You should immediately resave the wave descriptor data using the same name. Doing this"
		Print "will prevent this error message from being displayed next time you load the wave descriptor."
		DoAlert 0,"There is a minor problem. Please read text in command history window."	
		Duplicate/O W_AddSlot,W_RampSlot
		W_RampSlot = 0
	endif

	root:MP:CurrWaveDescriptor = root:W_WaveDescriptorName[0]	// The name of the current wave descriptor

	print "Loading wave descriptor \""+root:MP:CurrWaveDescriptor+"\" at "+time()

	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Loading a wave descriptor\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\tLoading the wave descriptor \""+root:MP:CurrWaveDescriptor+"\" to channel #"+num2str(root:MP:ChannelNumber)+"\r"
	Notebook Parameter_Log ruler=Normal, text="\tat time "+Time()+".\r"
	if (OldFormat)
		Notebook Parameter_Log ruler=Normal, text="\tWave is of old format -- only current slot is affected.\r"
	endif
	Notebook Parameter_Log ruler=Normal, text="\r"

	if (OldFormat)
		root:MP:PulseAmp = root:W_Params[1]								// Pulse amplitude
		root:MP:ChannelType = root:W_Params[2]							// Intracellular or extracellular
		root:MP:NPulses = root:W_Params[3]								// Number of pulses in train
		root:MP:PulseDur = root:W_Params[4]								// Duration of these pulses
		root:MP:PulseFreq = root:W_Params[5]								// The frequency of these pulses
		root:MP:PulseDispl = root:W_Params[6]							// Displacement in time of wave relative to the origin
		root:MP:BiphasicFlag = root:W_Params[7]							// If extracellular wave, is the wave biphasic?
		root:MP:CommandLevel = root:W_Params[8]						// Constant current/voltage command level (if exists)  3/30/00 KM
		root:MP:UseSlotFlag = 1												// Use this slot! (Why load it otherwise?)
	else
		root:MP:PulseAmp = root:W_PulseAmp[root:MP:SlotNumber-1]		// Pulse amplitude
		root:MP:ChannelType = root:W_Params[0]							// Intracellular or extracellular
		root:MP:NPulses = root:W_NPulses[root:MP:SlotNumber-1]			// Number of pulses in train
		root:MP:PulseDur = root:W_PulseDur[root:MP:SlotNumber-1]		// Duration of these pulses
		root:MP:PulseFreq = root:W_PulseFreq[root:MP:SlotNumber-1]		// The frequency of these pulses
		root:MP:PulseDispl = root:W_PulseDispl[root:MP:SlotNumber-1]	// Displacement in time of wave relative to the origin
		root:MP:BiphasicFlag = root:W_BiphasicFlag[root:MP:SlotNumber-1]// If extracellular wave, is the slot biphasic?
		root:MP:CommandLevel = root:W_Params[1]						// Constant current/voltage command level (if exists)  3/30/00 KM
		root:MP:AddSlotFlag = root:W_AddSlot[root:MP:SlotNumber-1]		// Additive slot?
		root:MP:SynapseSlotFlag = root:W_SynapseSlot[root:MP:SlotNumber-1]		// Biexponential slot?
		root:MP:RampFlag = root:W_RampSlot[root:MP:SlotNumber-1]		// Ramp?
		root:MP:UseSlotFlag = root:W_UseSlot[root:MP:SlotNumber-1]		// Use this slot?
	endif

	CommandStr = "root:MP:IO_Data:WaveDescriptor"+num2str(root:MP:ChannelNumber)+" = root:MP:CurrWaveDescriptor"
	Execute CommandStr												// The name of wave descriptor should be stored away

	killwaves/Z W_Params												// Discard the parameter wave once it has been used
	killwaves/Z W_WaveDescriptorName
	
	if (OldFormat)
		//// Change the stored data as well
		root:MP:IO_Data:NPulses[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] = root:MP:NPulses					// number of pulses
		root:MP:IO_Data:ChannelType[root:MP:ChannelNumber-1] = root:MP:ChannelType									// wave type
		root:MP:IO_Data:PulseAmp[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] = root:MP:PulseAmp				// pulse amplitude
		root:MP:IO_Data:PulseDur[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] = root:MP:PulseDur					// pulse duration
		root:MP:IO_Data:PulseFreq[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] =root:MP:PulseFreq				// pulse frequency
		root:MP:IO_Data:PulseDispl[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] = root:MP:PulseDispl				// pulse displacement
		root:MP:IO_Data:BiphasicFlag[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] = root:MP:BiphasicFlag			// biphasic?
		root:MP:IO_Data:CommandLevel[root:MP:ChannelNumber-1] = root:MP:CommandLevel								// command level 3/3/00 KM
		root:MP:IO_Data:UseSlotWave[root:MP:ChannelNumber-1][root:MP:SlotNumber-1] = 1								// Use this slot! (Why load it otherwise?)
	else
		root:MP:IO_Data:PulseAmp[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_PulseAmp[q]			// pulse amplitude
		root:MP:IO_Data:NPulses[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_NPulses[q]			// number of pulses
		root:MP:IO_Data:ChannelType[root:MP:ChannelNumber-1] = root:MP:ChannelType									// wave type
		root:MP:IO_Data:PulseDur[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_PulseDur[q]			// pulse duration
		root:MP:IO_Data:PulseFreq[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] =root:W_PulseFreq[q]			// pulse frequency
		root:MP:IO_Data:PulseDispl[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_PulseDispl[q]		// pulse displacement
		root:MP:IO_Data:BiphasicFlag[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_BiphasicFlag[q]	// biphasic?
		root:MP:IO_Data:CommandLevel[root:MP:ChannelNumber-1] = root:MP:CommandLevel								// command level 3/3/00 KM
		root:MP:IO_Data:AddSlotWave[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_AddSlot[q]			// additive slot?
		root:MP:IO_Data:SynapseSlotWave[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_SynapseSlot[q]	// Biexponential slot?
		root:MP:IO_Data:RampWave[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_RampSlot[q]		// Ramp?
		root:MP:IO_Data:UseSlotWave[root:MP:ChannelNumber-1][0,root:MP:IO_Data:NSlots-1] = root:W_UseSlot[q]		// use this slot?
		killwaves/Z W_PulseAmp
		killwaves/Z W_NPulses
		killwaves/Z W_PulseDur
		killwaves/Z W_PulseFreq
		killwaves/Z W_PulseDispl
		killwaves/Z W_BiphasicFlag
		killwaves/Z W_AddSlot
		killwaves/Z W_SynapseSlot
		killwaves/Z W_RampSlot
		killwaves/Z W_UseSlot
		WC_ToggleSlotOnDisplay()
	endif

	//// Redraw WaveCreator panel according to chosen channel
	WC_RefreshTypePopup(root:MP:ChannelType)
	WC_DoToggleTypeOnDisplay(root:MP:ChannelType)

	//// Show the wave?
	if (root:MP:ShowFlag)
		WC_ShowWave(root:MP:ChannelNumber)
	endif
	
	//// Take automatic notes
	if (OldFormat)
		Notebook Parameter_Log ruler=Normal, text="\tWave description -- loaded into slot "+JS_num2digstr(2,root:MP:SlotNumber)+":\r"
		if (root:MP:IO_Data:ChannelType[root:MP:ChannelNumber-1]==1)
			Notebook Parameter_Log ruler=TextRow, text="\t\tType:\tIntracellular\r"
		else
			Notebook Parameter_Log ruler=TextRow, text="\t\tType:\tExtracellular\r"
		endif
		Notebook Parameter_Log ruler=Normal, text="\t\tNumber of pulses:\t"+num2str(root:MP:IO_Data:NPulses[root:MP:ChannelNumber-1])+"\r"
		if (root:MP:IO_Data:ChannelType[j]==1)
			Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude:\t"+num2str(root:MP:IO_Data:PulseAmp[root:MP:ChannelNumber-1])+"\tnA\r"
			Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration:\t"+num2str(root:MP:IO_Data:PulseDur[root:MP:ChannelNumber-1])+"\tms\r"
		else
			Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude:\t"+num2str(root:MP:IO_Data:PulseAmp[root:MP:ChannelNumber-1])+"\tV\r"
			Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration:\t"+num2str(root:MP:IO_Data:PulseDur[root:MP:ChannelNumber-1])+"\tsamples\r"
		endif
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse frequency:\t"+num2str(root:MP:IO_Data:PulseFreq[root:MP:ChannelNumber-1])+"\tHz\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tDisplaced rel. origin:\t"+num2str(root:MP:IO_Data:PulseDispl[root:MP:ChannelNumber-1])+"\tms\r"
		
		if (root:MP:IO_Data:ChannelType[j]==1)
			Notebook Parameter_Log ruler=Normal, text="\t\tCommand level:\t"+num2str(root:MP:IO_Data:CommandLevel[root:MP:ChannelNumber-1])+"\tnA\r\r"
		else
			Notebook Parameter_Log ruler=Normal, text="\t\tCommand level:\t"+num2str(root:MP:IO_Data:CommandLevel[root:MP:ChannelNumber-1])+"\tV\r\r"
		endif
	else
		WC_DetailedNotesForWaveCreation(root:MP:CurrWaveDescriptor,root:MP:ChannelNumber)
	endif

End

//////////////////////////////////////////////////////////////////////////////////

Macro SavePatternProc(ctrlName) : ButtonControl
	String		ctrlName

	String		CommandStr

	Variable	i
	Variable	j
	Variable	Handle
	
	Handle = ShowInfoBox("Updating parameters!")								// Make sure the data in the panel has been stored
	StorePatternMakerValues()
	RemoveInfoBox(Handle)

	Handle = ShowInfoBox("Preparing to save!")	

	make/O/N=(root:MP:PM_Data:NSteps,4)		W_OutputCheck				// First create waves that can be saved
	make/T/O/N=(root:MP:PM_Data:NSteps,4)		W_OutputWaveNames		// (Global variables can't be saved)
	make/O/N=(root:MP:PM_Data:NSteps,4)		W_InputCheck
	make/O/N=(root:MP:PM_Data:NSteps)			W_NRepeats
	make/O/N=(root:MP:PM_Data:NSteps)			W_ISI
	make/O/N=(1)									W_NSteps
	make/T/O/N=(1)								W_PatternName

	i = 0
	do

		j = 0
		do
			
			CommandStr = "root:W_OutputCheck["+num2str(i)+"]["+num2str(j)+"]="				// Output checkbox values
			CommandStr += "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr

			CommandStr = "root:W_OutputWaveNames["+num2str(i)+"]["+num2str(j)+"]="			// Output wave names
			CommandStr += "root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr

			CommandStr = "root:W_InputCheck["+num2str(i)+"]["+num2str(j)+"]="					// Input checkbox values
			CommandStr += "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr

			j += 1
		while (j<4)

		CommandStr = "root:W_NRepeats["+num2str(i)+"]="											// Number of repeats
		CommandStr += "root:MP:PM_Data:NRepeats"+num2str(i+1)
		Execute CommandStr

		CommandStr = "root:W_ISI["+num2str(i)+"]="												// Inter-stimulus interval
		CommandStr += "root:MP:PM_Data:ISI"+num2str(i+1)
		Execute CommandStr

		i += 1
	while (i<root:MP:PM_Data:NSteps)
	
	W_NSteps = root:MP:PM_Data:NSteps
	W_PatternName = root:MP:PM_Data:PatternName
		
	RemoveInfoBox(Handle)
	
	save/O/T/I/P=Patterns W_OutputCheck,W_OutputWaveNames,W_InputCheck,W_NRepeats,W_ISI,W_NSteps,W_PatternName as root:MP:PM_Data:PatternName

	print "Saving pattern \""+root:MP:PM_Data:PatternName+"\" at "+time()

	killwaves/Z W_OutputCheck								// Discard the waves once they have been used
	killwaves/Z W_OutputWaveNames
	killwaves/Z W_InputCheck
	killwaves/Z W_NRepeats
	killwaves/Z W_ISI
	killwaves/Z W_NSteps
	killwaves/Z W_PatternName

End

//////////////////////////////////////////////////////////////////////////////////

Macro LoadPatternProc(ctrlName) : ButtonControl
	String		ctrlName
	
	String		CommandStr

	Variable	i
	Variable	j
	Variable	Handle
	
	loadwave/Q/O/T/P=Patterns/A=base

	if (exists("root:W_PatternName")==0)
		Abort "That's not a pattern file!"
	endif
	
	Handle = ShowInfoBox("Reshuffling the loaded data!")

	root:MP:PM_Data:NSteps = root:W_NSteps[0]																	// The number of steps in the pattern
	root:MP:PM_Data:OldNSteps = root:MP:PM_Data:NSteps															// Update the "old" number of steps
	root:MP:PM_Data:PatternName = root:W_PatternName[0]														// Name of the pattern

	i = 0
	do																												// Step counter

		j = 0
		do																											// Channel counter
			
			CommandStr = "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)+"="				// Output checkbox values
			CommandStr += "root:W_OutputCheck["+num2str(i)+"]["+num2str(j)+"]"
			Execute CommandStr

			CommandStr = "root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)+"="				// Output wave names
			CommandStr += "root:W_OutputWaveNames["+num2str(i)+"]["+num2str(j)+"]"
			Execute CommandStr

			CommandStr = "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1)+"="				// Input checkbox values
			CommandStr += "root:W_InputCheck["+num2str(i)+"]["+num2str(j)+"]"
			Execute CommandStr

			j += 1
		while (j<4)

		CommandStr = "root:MP:PM_Data:NRepeats"+num2str(i+1)	+"="											// Number of repeats
		CommandStr += "root:W_NRepeats["+num2str(i)+"]"
		Execute CommandStr

		CommandStr = "root:MP:PM_Data:ISI"+num2str(i+1)+"="													// Inter-stimulus interval
		CommandStr += "root:W_ISI["+num2str(i)+"]"	
		Execute CommandStr

		i += 1
	while (i<root:MP:PM_Data:NSteps)
		
	killwaves/Z W_OutputCheck								// Discard the loaded waves once they have been transferred to the globals
	killwaves/Z W_OutputWaveNames
	killwaves/Z W_InputCheck
	killwaves/Z W_NRepeats
	killwaves/Z W_ISI
	killwaves/Z W_NSteps
	killwaves/Z W_PatternName

	RemoveInfoBox(Handle)

	print "Loading pattern \""+root:MP:PM_Data:PatternName+"\" at "+time()

	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Loading a pattern\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\tLoading the pattern \""+root:MP:PM_Data:PatternName+"\" at time "+Time()+".\r"
	Notebook Parameter_Log ruler=Normal, text="\r\tDescription of this pattern follows.\r"

	DumpPatternToNoteBook()								// Put info about the newly loaded pattern in the notebook

	MakeMultiPatch_PatternMaker()							// Redraw the panel
	DoUpdate

End

//////////////////////////////////////////////////////////////////////////////////

Macro HidePatternMakerProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable	Handle

	Handle = ShowInfoBox("Storing values!")
	StorePatternMakerValues()
	RemoveInfoBox(Handle)
	DoWindow/K MultiPatch_PatternMaker

End

//////////////////////////////////////////////////////////////////////////////////

Macro GoToPatternMaker(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow MultiPatch_PatternMaker
	if (V_flag)								// If panel exists, show it
		DoWindow/F MultiPatch_PatternMaker
	else										// If panel does not exist, create it
		MakeMultiPatch_PatternMaker()
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Update the PatternMaker panel every time the number of steps is changed

Function ChgNStepsProc(STRUCT WMSetVariableAction &s) : SetVariableControl

	if (s.eventcode == 1 || s.eventcode == 8)
		StorePatternMakerValues()
		MakeMultiPatch_PatternMaker()
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Reads the values from the PatternMaker panel and stores them in the global variables
//// in root:MP:PM_Data:

Function StorePatternMakerValues()

	Silent 1

	Variable	i
	Variable	j
	String		CommandStr
	Variable	Handle
	
	NVAR		OldNSteps = root:MP:PM_Data:OldNSteps
	NVAR		NSteps = root:MP:PM_Data:NSteps

	Handle = ShowInfoBox("Reading PM panel!")
	
	DoStorePatternMakerCheckValues()
	
	i = 0
	do

		j = 0
		do
	
			CommandStr = "OutputOnOff_"+num2str(i+1)+"_"+num2str(j+1)								// Transfer value of output checkbox
			ControlInfo/W=MultiPatch_PatternMaker $CommandStr
			CommandStr = "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)+"="+num2str(V_value)
			Execute CommandStr
		
			CommandStr = "OutputWave_"+num2str(i+1)+"_"+num2str(j+1)								// Transfer value of the output wave popup menu
			ControlInfo/W=MultiPatch_PatternMaker $CommandStr
			CommandStr = "root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)+"=\""+S_value+"\""
			Execute CommandStr
		
			CommandStr = "InputOnOff_"+num2str(i+1)+"_"+num2str(j+1)								// Transfer value of input checkbox
			ControlInfo/W=MultiPatch_PatternMaker $CommandStr
			CommandStr = "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1)+"="+num2str(V_value)
			Execute CommandStr
		
			j += 1
		while(j<4)
		
		// (Note to self: NRepeats and ISI are updated automatically through the SetVar control box. Don't need to mess with them here.)

		i += 1
	while(i<OldNSteps)
	
	OldNSteps = NSteps												// Update the "old" number of steps

	RemoveInfoBox(Handle)

end

Function DoStorePatternMakerCheckValues()

	NVAR		RT_SealTestOnOff =			root:MP:PM_Data:RT_SealTestOnOff		// Realtime sealtest analysis on or off?
	NVAR		RT_VmOnOff =				root:MP:PM_Data:RT_VmOnOff			// Realtime membrane potential analysis on or off?
	NVAR		RT_EPSPOnOff =			root:MP:PM_Data:RT_EPSPOnOff		// Realtime EPSP analysis on or off?
	NVAR		RT_EPSPUseGrab =			root:MP:PM_Data:RT_EPSPUseGrab		// Use manual EPSPs?
	NVAR		RT_EPSPUseMatrix =			root:MP:PM_Data:RT_EPSPUseMatrix		// Use automatic EPSPs?
	NVAR		RT_StableBaseline	=	root:MP:PM_Data:RT_StableBaseline	// Boolean: Want to check the stability of the baseline?
	NVAR		RT_RepeatPattern =		root:MP:PM_Data:RT_RepeatPattern			// Boolean: Should the pattern be repeated?

	ControlInfo/W=MultiPatch_PatternMaker RT_SealTestCheck
	RT_SealTestOnOff = V_value
	ControlInfo/W=MultiPatch_PatternMaker RT_VmCheck
	RT_VmOnOff = V_value
	ControlInfo/W=MultiPatch_PatternMaker RT_EPSPCheck
	RT_EPSPOnOff = V_value
	ControlInfo/W=MultiPatch_PatternMaker RT_UseGrabCheck
	RT_EPSPUseGrab = V_value
	ControlInfo/W=MultiPatch_PatternMaker RT_UseMatrixCheck
	RT_EPSPUseMatrix = V_value
	ControlInfo/W=MultiPatch_PatternMaker RT_StableBaselineCheck
	RT_StableBaseline = V_value
	ControlInfo/W=MultiPatch_PatternMaker RT_RepeatPatternCheck
	RT_RepeatPattern = V_value
	
End

Function StorePatternMakerCheckValues(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			DoStorePatternMakerCheckValues()
			break
	endswitch

	return 0
End

//////////////////////////////////////////////////////////////////////////////////
//// Simulate a simple progress bar window

Function MakeProgressBar()

	Variable	xPos = 300
	Variable	yPos = 273
	Variable	Width = 320
	Variable	rowHeight = 20+4
	Variable	Height = 4+rowHeight*2
	
//	NVAR	ScSc = root:MP:ScSc
//	NVAR	Progress_Max = root:MP:Progress_Max
	
	xPos *= ScreenResolution/72
	yPos *= ScreenResolution/72

	DoWindow/K ProgressWin
	NewPanel /W=(xPos,yPos,xPos+Width,yPos+Height)/k=1
	DoWindow/C ProgressWin
	ModifyPanel cbRGB=(65534,65534,65534)

	ValDisplay theBar,pos={4,4+rowHeight*0},size={Width-4-4,rowHeight-4},title="Progress: "
	ValDisplay theBar,labelBack=(65535,65535,65535),fSize=12,frame=2
	ValDisplay theBar,limits={0,1,0},barmisc={0,0},mode= 3,value=#"root:MP:Progress_val"

	SetVariable theText,pos={4,4+rowHeight*1},size={Width-4-4,rowHeight-4},title=" "
	SetVariable theText,labelBack=(65535,65535,65535),fSize=12,frame=0
	SetVariable theText,noedit= 1,bodyWidth=(Width-4-4),value=root:MP:Progress_MessageStr

End

Function KillProgressBar()

	Variable		TickSave = Ticks
	do
		doXOPIdle
	while (TickSave+60.15*0.5>Ticks)
	DoWindow/K ProgressWin

End

Function UpdateProgressBar(TheValue,TheText)
	Variable		TheValue
	String		TheText

	NVAR		Progress_Val =			root:MP:Progress_Val
	NVAR		Progress_TickSave =		root:MP:Progress_TickSave
	SVAR		Progress_MessageStr =	root:MP:Progress_MessageStr

	Progress_Val = TheValue
	Progress_MessageStr = TheText

	DoWindow/F ProgressWin
	DoUpdate
	
	// Make sure progress bar is visible 
	do
		doXOPIdle
	while (Progress_TickSave+2>Ticks)
	Progress_TickSave = Ticks

End

//////////////////////////////////////////////////////////////////////////////////
//// A way of communicating important information temporarily to the user

Function ShowInfoBox(Message)
	String		Message								// The message to be displayed

	String		WindowName

	Variable	WinX = 390						// Panel x position
	Variable	WinY = 273						// Panel y position
	Variable	WinWidth = 300					// Panel width
	Variable	WinHeight = 40						// Panel height
	
	Variable	Margin = 4							// Margin around the colored box
	Variable	WinSpacing = WinHeight+32		// Spacing when using several infoboxes at the same time
		
	NVAR	Handle = root:MP:InfoBoxHandle		// Can use several info boxes at the same time, so keep track of them
	
	NVAR	ScSc = root:MP:ScSc
	
	Handle += 1									// Add a new window
	WinY += (Handle-1)*WinSpacing				// ...and put it where it can be seen

	NewPanel /W=(WinX*ScSc,WinY*ScSc,WinX*ScSc+WinWidth,WinY*ScSc+WinHeight) as "Information "+num2str(Handle)
	WindowName = "MultiPatch_InfoBox_"+num2str(Handle)
	DoWindow/C $WindowName

	SetDrawLayer UserBack
	SetDrawEnv linethick= 2,fillfgc= (65535,0,0),fillbgc= (65535,0,65535)
	DrawRect Margin,Margin,WinWidth-Margin,WinHeight-Margin
	SetDrawEnv fsize=18,fstyle=1,textxjust=1,textyjust=1,textrgb= (65535,65535,65535)
	DrawText ceil(WinWidth/2),ceil(WinHeight/2),Message

	DoUpdate
	
	Return Handle

End

Function RemoveInfoBox(PassedHandle)
	Variable	PassedHandle
	
	String		WindowName

	NVAR		Handle = root:MP:InfoBoxHandle		// Will create a bug if windows are removed in the wrong order, and then recreated in between... minor problem
	
	WindowName = "MultiPatch_InfoBox_"+num2str(PassedHandle)
	DoWindow/K $WindowName

	Handle -= 1										// Remove a window

	DoUpdate

End

//////////////////////////////////////////////////////////////////////////////////
//// Button: Sends the selected waves and records desired waves once

Function OnceProc(ctrlName) : ButtonControl
	String ctrlName
	
	PauseUpdate; Silent 1
	
	Variable	i = 0
	String		VarStr = ""
	String		VarStr2 = ""
	String		CommandStr = ""
	String		WaveListStr = ""												// List of names of input waves
	Variable	err
	Variable	NoInputs
	Variable	NoOutputs
	Variable	WaveDuration

	String		w1,w2,w3,w4													// Temporary names for output waves
	
	NVAR		SingleSendFlag =			root:MP:SingleSendFlag
	NVAR		RpipGenerated =			root:MP:RpipGenerated
	
	NVAR		SampleFreq = 				root:MP:SampleFreq
	NVAR		TotalDur = 					root:MP:TotalDur
	NVAR		SealTestPad1 = 				root:MP:SealTestPad1
	NVAR		SealTestPad2 = 				root:MP:SealTestPad2
	NVAR		SealTestDur = 				root:MP:SealTestDur
	
	NVAR		TotalDur = 					root:MP:TotalDur
	NVAR		TempStartAt =				root:MP:TempStartAt
	NVAR 		AcqGainSet=					root:MP:AcqGainSet
	
	SVAR		DummyStr =				root:MP:DummyStr

	WAVE/T	WaveInVarNames = 			root:MP:IO_Data:WaveInVarNames
	WAVE/T	WaveOutVarNames = 		root:MP:IO_Data:WaveOutVarNames
	
	WAVE		OutputOnOff =				root:MP:IO_Data:OutputOnOff
	
	//// Time the whole thing
	print "Starting single send at "+time()
	SingleSendFlag = 1										// Tell the PM_RT_Analysis procedure that scan was initiated using the 'Single Send' button
	RpipGenerated = 0										// BeginAcquisition that RPipProc did not call it
	
	//// Make sure the experiments is saved and therefore named
	if (StringMatch(IgorInfo(1),"Untitled"))
		Print "\tAborting -- experiment not saved!"
		Abort "You'd better save your experiment first!"
	endif

	//// Are there output waves on all selected channels?
	i = 0
	do
		if (OutputOnOff[i])														// Channel is checked for output
			CommandStr = "Out"+num2str(i+1)+"Popup"
			ControlInfo/W=MultiPatch_Switchboard $CommandStr
			if (StringMatch(S_Value,""))										// but there is no wave chosen
				Print "\tAborting -- No wave chosen for channel "+num2str(i+1)+"."
				Abort "No wave chosen for channel "+num2str(i+1)+"."
			endif
			if (!(exists(S_Value)))												// but wave does not exist
				Print "\tAborting -- Trying to send a wave that does not exist: "+S_value
				Abort "Trying to send a wave that does not exist: "+S_value
			endif
			WAVE w = $(S_Value)
			if (NumberByKey("NUMTYPE", waveinfo(w,0))==0)				// Wave is chosen, & exists, but is a textwave
				Print "\tAborting -- Trying to send a textwave: "+S_value
				Abort "Trying to send a textwave: "+S_value
			endif
		endif
		i+=1
	while(i<4)

	//// Take wave length for the input waves from the first output wave found, if none found, from the WaveCreator TotalDur variable
	NoOutputs = 1
	i = 0
	do
		if (OutputOnOff[i])														// Channel is checked for output
			NoOutputs = 0
			CommandStr = "Out"+num2str(i+1)+"Popup"
			ControlInfo/W=MultiPatch_Switchboard $CommandStr
			DummyStr = S_Value
			WaveDuration = pnt2x($DummyStr,numpnts($DummyStr)-1)*1000		// Length of the output wave [ms]
			i = Inf
		endif
		i+=1
	while(i<4)
	if (NoOutputs)
		WaveDuration = TotalDur
	endif

	//// Create new input waves
	NoInputs = 1
	WaveListStr = ""
	i = 0
	do
		CommandStr = "In"+num2str(i+1)
		ControlInfo/W=MultiPatch_Switchboard $CommandStr
		if (V_value)																				// Channel is checked for input
			NoInputs = 0

			VarStr = "StartAt"+num2str(i+1)														// Find out where suffix numbering of waves should start
			CommandStr = "root:MP:TempStartAt = root:MP:IO_Data:"+VarStr
			Execute CommandStr

			CommandStr = "root:MP:DummyStr = (root:MP:IO_Data:"+WaveInVarNames[i]				// Create wave name
			CommandStr += "+JS_num2digstr(4,"+num2str(TempStartAt)+"))"
			Execute CommandStr

			ProduceWave(DummyStr,SampleFreq,WaveDuration)										// Create the wave with the above name
			
			DA_StoreWaveStats(DummyStr,i+1)													// Store relevant data so that the wave can be fixed after acquisition

			WaveListStr += DummyStr+","+num2str(i)+","+num2str(AcqGainSet)+ ";"					// add per-channel gains:  increases resolution of datawaves
			//WaveListStr += DummyStr+","+num2str(i)+",1;"									// add a gain of 5  :  increases resolution of datawaves
																									//  KM 20100	  eliminates quantization problems: Made variable 22000
		endif
		i+=1
	while(i<4)
	
	if (NoInputs)
		Print "\tAbort -- You must have selected at least one input wave to be acquired, otherwise the waveform generator won't be triggered."
		Abort "You must have selected at least one input wave to be acquired, otherwise the waveform generator won't be triggered."
	endif

	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Single send\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\t\tTime: "+Time()+"\r"
	Notebook Parameter_Log ruler=Normal, text="\r\tUsing the following output channels:\r"
	i = 0
	do
		if (OutputOnOff[i])														// Channel is checked for output
			CommandStr = "Out"+num2str(i+1)+"Popup"
			ControlInfo/W=MultiPatch_Switchboard $CommandStr
			Notebook Parameter_Log ruler=TextRow, text="\t\tChannel "+num2str(i+1)+", output wave:\t"+S_Value+"\r"
		endif
		i+=1
	while(i<4)
	Notebook Parameter_Log ruler=Normal, text="\r\tUsing the following input channels:\r"
	i = 0
	do
		CommandStr = "In"+num2str(i+1)
		ControlInfo/W=MultiPatch_Switchboard $CommandStr
		if (V_value)															// Channel is checked for input

			VarStr = "StartAt"+num2str(i+1)									// Find out where suffix numbering of waves should start
			CommandStr = "root:MP:TempStartAt = root:MP:IO_Data:"+VarStr
			Execute CommandStr

			CommandStr = "root:MP:DummyStr = (root:MP:IO_Data:"+WaveInVarNames[i]			// Create wave name
			CommandStr += "+JS_num2digstr(4,"+num2str(TempStartAt)+"))"
			Execute CommandStr

			Notebook Parameter_Log ruler=TextRow, text="\t\tChannel "+num2str(i+1)+", input wave:\t"+DummyStr+"\r"

		endif
		i+=1
	while(i<4)
	Notebook Parameter_Log ruler=Normal, text="\r"
		
	//// Set up waveform generation
	
	w1 = ""
	w2 = ""
	w3 = ""
	w4 = ""

	if (OutputOnOff[0])															// output checked --> send wave
		ControlInfo/W=MultiPatch_Switchboard Out1Popup
		w1 = S_Value
	endif

	if (OutputOnOff[1])
		ControlInfo/W=MultiPatch_Switchboard Out2Popup
		w2 = S_Value
	endif

	if (OutputOnOff[2])
		ControlInfo/W=MultiPatch_Switchboard Out3Popup
		w3 = S_Value
	endif

	if (OutputOnOff[3])
		ControlInfo/W=MultiPatch_Switchboard Out4Popup
		w4 = S_Value
	endif
	
	PrepareToSend(w1,w2,w3,w4)												// Take care of sending the waves to the boards
	
	//// Set up data acquisition
	BeginAcquisition(WaveListStr)												// Data acquisition will trigger waveform generation
	
	//// Show the input waves if the user so desires...
	DA_DoShowInputs(0)

	//// Increase the suffix numbers of the channels that were used, if the user so desires
	ControlInfo/W=MultiPatch_Switchboard CountUp
	If (V_value)
		i = 0
		do
			CommandStr = "In"+num2str(i+1)
			ControlInfo/W=MultiPatch_Switchboard $CommandStr
			if (V_value)															// Channel is checked for input
				VarStr = "StartAt"+num2str(i+1)									// Find out where suffix numbering of waves should start
				CommandStr = "root:MP:IO_Data:"+VarStr+"+= 1"					// Next wave should have the next suffix number
				Execute CommandStr
			endif
			i+=1
		while(i<4)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// If the user zooms in on a part of the window showing the acquired waves, this checkbox
//// value decides whether that zoom-in should be kept for the next acquired waves.

Function DA_ToggleZoomProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

End

//////////////////////////////////////////////////////////////////////////////////
//// Change the units of the acquired waves

Function DA_ToggleUnitsProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR		pAUnits = root:MP:IO_Data:pAUnits									// Boolean: Convert to [pA] in v clamp (otherwise [A])
	NVAR		mVUnits = root:MP:IO_Data:mVUnits									// Boolean: Convert to [mV] in i clamp (otherwise [V])

	String		a,b
	
	ControlInfo/W=MultiPatch_Switchboard pAConvCheck
	pAUnits = V_value
	ControlInfo/W=MultiPatch_Switchboard mVConvCheck
	mVUnits = V_value
	if (pAUnits)
		a = "pA"
	else
		a = "A"
	endif
	if (mVUnits)
		b = "mV"
	else
		b = "V"
	endif
	Print "Toggling the units of the acquired waves at time "+Time()+"."
	Print "\tNow using ["+a+"] and ["+b+"]."

End

//////////////////////////////////////////////////////////////////////////////////
//// Store wave-specific data that is needed to fix the wave after acquisition. (See the below
//// function.)

Function DA_StoreWaveStats(WaveName,Number)
	String		WaveName
	Variable	Number
	
	WAVE		WaveWasAcq =			root:MP:FixAfterAcq:WaveWasAcq
	WAVE/T	WaveNames =			root:MP:FixAfterAcq:WaveNames

	WaveNames[Number-1] = WaveName								// Remember the wave name
	WaveWasAcq[Number-1] = 1										// Label this wave as being used for this particular send&acquire operation

End

//////////////////////////////////////////////////////////////////////////////////
//// Fix the wave after it has been acquired by the board. 
//// 1) Scale waves according to gains.
//// 2) Tag waves with time of acquisition.

Function DA_FixInputWavesAfterAcq()

	Variable	i

	String		CommandStr
	Variable		temp
	String		UnitsStr = ""

	NVAR		SampleFreq =			root:MP:SampleFreq	
	NVAR		RpipGenerated =		root:MP:RpipGenerated

	WAVE		VClampWave =			root:MP:IO_Data:VClampWave
	WAVE		InGainIClampWave =	root:MP:IO_Data:InGainIClampWave
	WAVE		InGainVClampWave =	root:MP:IO_Data:InGainVClampWave

	WAVE		WaveWasAcq =			root:MP:FixAfterAcq:WaveWasAcq
	WAVE/T		WaveNames =			root:MP:FixAfterAcq:WaveNames

	NVAR		pAUnits = root:MP:IO_Data:pAUnits									// Boolean: Convert to [pA] in v clamp (otherwise [A])
	NVAR		mVUnits = root:MP:IO_Data:mVUnits									// Boolean: Convert to [mV] in i clamp (otherwise [V])
	
	SVAR		BoardName =			root:BoardName								// ITC18 board? National Instruments?
	WAVE/Z		AcqGainSetValues =		root:AcqGainSetValues						// Possible input ranges
	NVAR		AcqGainSet =			root:MP:AcqGainSet							// Chosen input range
	NVAR/Z		ITC_Offset =				ITC_Offset									// ITC18 board sometimes has an offset on the inputs [units: board voltage, i.e. V before scaling with gain]
	
	Variable	CurrDateTime = DateTime											// Timestamp waves with this info
	String		CurrTime,CurrInfo													// Time and info strings about current wave
	sprintf		CurrTime,"%15.0f",CurrDateTime
	CurrTime = (Secs2Time(CurrDateTime,3)+"; "+Secs2date(CurrDateTime,2)+"; ")+CurrTime+";"

	i = 0
	do
		
		if (WaveWasAcq[i])
			
			CurrInfo = ""
			if (VClampWave[i])														// Should current clamp or voltage clamp gain be used?
				if (pAUnits)
					temp = InGainVClampWave[i]/1E3								// Particular for voltage clamp --> want units to mesh when making plots, avoiding "mnA" on axes
					UnitsStr = "pA"													// units --> pA
				else
					temp = InGainVClampWave[i]*1E9
					UnitsStr = "A"													// units --> A
				endif
			else
				if (mVUnits)
					temp = InGainIClampWave[i]/1E3
					UnitsStr = "mV"												// units --> mV
				else
					temp = InGainIClampWave[i]
					UnitsStr = "V"													// units --> V
				endif
			endif
			CommandStr = WaveNames[i]											// Futzing around to avoid Igor bug...
			WAVE	w = $CommandStr
			//// Scale the selected input wave according to its gain
			if ( (StrSearch(BoardName,"PCI",0)!=-1) %| (StringMatch(BoardName,"NI")) %| (StringMatch(BoardName,"NI_2PLSM")) )
				w /= temp
			else
				if (StringMatch(BoardName,"ITC18"))
					w /= (temp/AcqGainSetValues[AcqGainSet-1]*32768)
					if (!(VClampWave[i]))											// Don't account for offset if this channel is in voltage clamp
						w -= ITC_Offset
					endif
				endif
			endif
			ProduceUnitsOnYAxis(CommandStr,UnitsStr)							// Add units to the y axis of the waves
			//// Insert current time into wave note
			note/K w
			note w,CurrTime
			CurrInfo = "Gain: "+num2str(temp)+"; Units: "+UnitsStr+"; "
			note w,CurrInfo

			if (Exists("MM_HeaterExists"))
				NVAR/Z	MM_HeaterExists
				if (MM_HeaterExists)
					Execute "MM_DoReadHeater()"
					NVAR MM_TempBath
					NVAR MM_TempHeater
					NVAR MM_TempTarget
					CurrInfo = "TempBath: "+num2str(MM_TempBath)+"; TempHeater: "+num2str(MM_TempHeater)+"; TempTarget: "+num2str(MM_TempTarget)+"; "
					note w,CurrInfo
				endif
			endif
			
			if (Exists("Warner_Temp"))
				Execute "Warner_GetTemp()"
				NVAR/Z	Warner_Temp
				CurrInfo = "TempBath: "+num2str(Warner_Temp)+"; "
				note w,CurrInfo
			endif

			ControlInfo/W=MultiPatch_Switchboard StoreCheck
			if ((V_value)%&(RpipGenerated==0))
				Save/O/C/P=home w												// Save the acquired wave in the home path right away! Quick! Before the computer crashes!!!

			endif
		
		endif
		
		
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Fix the temp waves during gradual transfer of data from board
//// Scale temp waves according to gains.

Function DA_FixTempWavesDuringAcq()

	Variable	i

	String		CommandStr
	Variable		temp
	String		UnitsStr = ""

	NVAR		SampleFreq =			root:MP:SampleFreq	
	NVAR		RpipGenerated =		root:MP:RpipGenerated

	WAVE		VClampWave =			root:MP:IO_Data:VClampWave
	WAVE		InGainIClampWave =	root:MP:IO_Data:InGainIClampWave
	WAVE		InGainVClampWave =	root:MP:IO_Data:InGainVClampWave

	WAVE		WaveWasAcq =			root:MP:FixAfterAcq:WaveWasAcq

	NVAR		pAUnits = root:MP:IO_Data:pAUnits									// Boolean: Convert to [pA] in v clamp (otherwise [A])
	NVAR		mVUnits = root:MP:IO_Data:mVUnits									// Boolean: Convert to [mV] in i clamp (otherwise [V])
	
	SVAR		BoardName =			root:BoardName								// ITC18 board? National Instruments?
	WAVE/Z		AcqGainSetValues =		root:AcqGainSetValues						// Possible input ranges
	NVAR		AcqGainSet =			root:MP:AcqGainSet							// Chosen input range
	NVAR/Z		ITC_Offset =				ITC_Offset									// ITC18 board sometimes has an offset on the inputs [units: board voltage, i.e. V before scaling with gain]

	i = 0
	do
		
		if (WaveWasAcq[i])
			
			if (VClampWave[i])														// Should current clamp or voltage clamp gain be used?
				if (pAUnits)
					temp = InGainVClampWave[i]/1E3								// Particular for voltage clamp --> want units to mesh when making plots, avoiding "mnA" on axes
					UnitsStr = "pA"													// units --> pA
				else
					temp = InGainVClampWave[i]*1E9
					UnitsStr = "A"													// units --> A
				endif
			else
				if (mVUnits)
					temp = InGainIClampWave[i]/1E3
					UnitsStr = "mV"												// units --> mV
				else
					temp = InGainIClampWave[i]
					UnitsStr = "V"													// units --> V
				endif
			endif
			CommandStr = "Temp"+num2str(i+1)							// Operate on temp wave
			WAVE	w = $CommandStr
			//// Scale the selected input wave according to its gain
			if ( (StrSearch(BoardName,"PCI",0)!=-1) %| (StringMatch(BoardName,"NI")) %| (StringMatch(BoardName,"NI_2PLSM")) )
				w /= temp
//				print "%%%%",temp
			else
				if (StringMatch(BoardName,"ITC18"))
					w /= (temp/AcqGainSetValues[AcqGainSet-1]*32768)
					if (!(VClampWave[i]))											// Don't account for offset if this channel is in voltage clamp
						w -= ITC_Offset
					endif
				endif
			endif
			ProduceUnitsOnYAxis(CommandStr,UnitsStr)							// Add units to the y axis of the waves
		endif
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Kill input waves after acquisition, if the user so desires, to free up RAM.

Function DA_KillInputWavesAfterAcq()

	Variable	i
	
	String		ToWaveName
	NVAR		RpipGenerated =			root:MP:RpipGenerated

	WAVE		WaveWasAcq =				root:MP:FixAfterAcq:WaveWasAcq
	WAVE/T	WaveNames =				root:MP:FixAfterAcq:WaveNames

	i = 0
	do
		
		if (WaveWasAcq[i])																		// If wave was acquired...
			
			ToWaveName = "Temp"+num2str(i+1)
			Duplicate/O $(WaveNames[i]),$ToWaveName										// ... first copy the wave to the template wave shown in the input wave plot ...
			FilterThisWave(ToWaveName)															// If the user so desires, filter waves shown in Acquired Waves window (filtering will _not_ be saved)
			
			ControlInfo/W=MultiPatch_Switchboard KillCheck									// ... then kill the wave
			if ((V_value) %& (RpipGenerated==0))											// ... but only if the user so desired, and if acquisition was not triggered by RpipProcedure
				KillWaves/Z $(WaveNames[i])
			endif
		
		endif
		
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Unmark waves. Waves that were used were marked as used, and should be unmarked

Function DA_UnMarkInputWavesAfterAcq()

	Variable	i
	WAVE		WaveWasAcq =			root:MP:FixAfterAcq:WaveWasAcq

	i = 0
	do
		WaveWasAcq[i] = 0															// Mark all waves as not used for next round of send&acquire
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Trap for end of data acquisition scan.

Function DA_EndOfScanHook()
	
	SVAR		CustomProc =					root:MP:PM_Data:CustomProc			// This string not "" then Execute it!

	print "\tEnd-of-scan hook triggered at "+Time()+"."
	
	DA_FixInputWavesAfterAcq()			// Scale the waves
	PM_RT_Analysis()						// Plot sealtest, V_m, etc, if the user so desires
	DA_KillInputWavesAfterAcq()			// Kill the waves, if the user so desires
	DA_UnMarkInputWavesAfterAcq()		// Used waves were marked as used, and should be unmarked
	
	if (!(StringMatch(CustomProc,"")))
		print "Attention: Executing CustomProc = \""+CustomProc+"\""
		Execute(CustomProc)
	endif

	PM_SortOutXAxes(0)

	DA_ManagePatternAtEOSHook()

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle the autosaving of experiment

Function ToggleAutoSaveExpProc(ctrlName,Checked) : CheckBoxControl
	String		ctrlName
	Variable	Checked
	
	if (Checked)
		Print Time(),"Autosave experiment is now active." 
	else
		Print Time(),"Warning! You just opted not to autosave the experiment at the end of each pattern." 
		DoAlert 0,"Warning! You just opted not to autosave the experiment at the end of each pattern." 
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Auto-save experiment

Function DA_DoAutoSaveExperiment()

 	ControlInfo/W=MultiPatch_Switchboard AutoSaveOnOff	// Are we autosaving today?
 	if (V_value)
		DA_SaveExperiment("")
 	else
 		Print Time(),"WARNING!\r=== Autosaving option is not selected!!! ==="
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Save experiment

Function DA_SaveExperiment(ctrlName) : ButtonControl
	String ctrlName

	Print Time(),"Saving experiment..."
	SaveExperiment
	
End

//////////////////////////////////////////////////////////////////////////////////
//// DEMO-mode requires additional call of this bit, hence I need to split it up from
//// the rest of DA_EndOfScanHook() above. The reason for this is that End-of-scan hook is
//// only simulated in DEMO mode.

Function DA_ManagePatternAtEOSHook()

	NVAR		PatternRunning = 				root:MP:PM_Data:PatternRunning		// Boolean: Is a pattern currently running?
	NVAR		AcqInProgress =					root:MP:AcqInProgress				// Boolean: Is acquisition in progess?
	NVAR		PatternReachedItsEnd = 			root:MP:PM_Data:PatternReachedItsEnd	// Boolean: Did pattern just reach its end?
	NVAR		RT_DoRestartPattern =			root:MP:PM_Data:RT_DoRestartPattern	// Boolean: Restart the pattern? --> Used to restart pattern from EndOfScanHook
	
	Variable	ExternalTrigger
 	ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck	// Triggering is external!!!!
 	ExternalTrigger = V_value

	SVAR		BoardName =					root:BoardName							// ITC18 board? National Instruments?
	if (PatternReachedItsEnd)
		PM_FixAtEndOfPattern()			// Various things to fix after having finished a pattern
		PatternReachedItsEnd = 0
//		if ( (ExternalTrigger) %& (StringMatch(BoardName,"ITC18")) )
//			NVAR		ITC_VerboseMode =			ITC_VerboseMode					// Boolean: Verbose output for debugging purposes
//			if (ITC_VerboseMode)
//				Print "\t\t{DA_EndOfScanHook} is killing the background task, as External Trigger was selected."
//			endif
//			KillBackground				// Turn off the ITC_PollStation background task that is needed to find the end of the wave with ITC18
//		endif
	Endif
	
	if (RT_DoRestartPattern)				// Restart the pattern --> the pattern is a repeating pattern
		RT_DoRestartPattern = 0
		PM_StartPattern(1)
	endif

	AcqInProgress = 0;						// Flag that data acquisition is no longer in progress

	if ((ExternalTrigger) %& (PatternRunning))
		PM_PatternHandler()				// No background task is running in when there is no triggering, so need to start sending next wave in a pattern instantly!
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Do the actual displaying of the inputs.

Function DA_DoShowInputs(CalledFromPM)
	Variable	CalledFromPM													// == 1 if procedure was called from PatternMaker, == 0 otherwise

	String		CommandStr = ""
	String		VarStr = ""
	String		LegendStr = ""
	
	Variable	i = 0
	Variable	NDraw = 0
	Variable	FirstLegendEntry = 1
	Variable	KillWavesFlag

	Variable	XLeft															// Position and size of window
	Variable	YTop
	Variable	XRight
	Variable	YBottom

	Variable	ROI_x
	Variable	ROI_w
	
	Variable	Left1,Left2														// Zoom-in, if any
	Variable	Right1,Right2
	Variable	Bottom1,Bottom2
	Variable	ThereWasAGraph = 0											// Boolean: There was a graph -- otherwise zoom-in becomes a moot point
	
	NVAR		PatternRunning = 			root:MP:PM_Data:PatternRunning	// Boolean: Is a pattern running?
	NVAR		RT_ROIOnOff = 				root:MP:PM_Data:RT_ROIOnOff	// Boolean: Use the Region-Of-Interest function?
	NVAR		RT_ROI_Slot = 				root:MP:PM_Data:RT_ROI_Slot	// Which of the four ROI slots is currently used?

	WAVE		RT_ROI_x1 = 				root:MP:PM_Data:RT_ROI_x1		// Parameters that define the ROI
	WAVE		RT_ROI_x2 = 				root:MP:PM_Data:RT_ROI_x2
	WAVE		RT_ROI_y1 = 				root:MP:PM_Data:RT_ROI_y1
	WAVE		RT_ROI_y2 = 				root:MP:PM_Data:RT_ROI_y2
	WAVE		RT_ROI_yy1 = 				root:MP:PM_Data:RT_ROI_yy1		// KM 9/25/00
	WAVE		RT_ROI_yy2 = 				root:MP:PM_Data:RT_ROI_yy2

	WAVE		VClampWave =				root:MP:IO_Data:VClampWave

	NVAR		TempStartAt =				root:MP:TempStartAt
	SVAR		DummyStr =				root:MP:DummyStr
	WAVE/T	WaveInVarNames = 			root:MP:IO_Data:WaveInVarNames
	WAVE		OutputOnOff =				root:MP:IO_Data:OutputOnOff
	NVAR		InputOffset =				root:MP:InputOffset
	NVAR		CurrentStep =				root:MP:PM_Data:CurrentStep
	NVAR		AddThisChannel	=			root:MP:PM_Data:AddThisChannel	// Boolean: Add this channel input wave to graph?
	NVAR		NewStepBegun =			root:MP:PM_Data:NewStepBegun		// Boolean: A new step was just begun in the PatterHandler
	
	NVAR		ZoomFlag =					root:MP:IO_Data:ZoomFlag			// Boolean: Keep zoom-in on graph showing acquired waves when recreating it

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	ControlInfo/W=MultiPatch_Switchboard KillCheck							// The user wishes to kill the waves after acquisition...
	KillWavesFlag = V_value

	ControlInfo/W=MultiPatch_Switchboard ShowInputs							// Whether inputs should be shown or not, is always decided by the checkbox on the Switchboard panel
	if (V_value)																// Show the acquired waves
	
		if ( ((CalledFromPM) %& (!KillWavesFlag)) %| ((CalledFromPM) %& (NewStepBegun)) %| (!CalledFromPM))	
																				// Don't redisplay the graph if the PatterHandler is running and a new step is _not_ begun, coz you don't need to
																				// ...but you must always redisplay the graph if the PatternHandler is running and the automatic wave killing is not on
																				// ...On the other hand, if not called from PatternHandler, you should always display the graph

			DoWindow MultiPatch_ShowInputs											// If the window already exists...
			if (V_flag)
				GetWindow MultiPatch_ShowInputs, wsize								//  --> read its position
				XLeft = V_left
				YTop = V_top
				XRight = V_right
				YBottom = V_bottom
				DoWindow/F MultiPatch_ShowInputs									//  --> read its zoom-in
				GetAxis/Q left
				left1 = V_min
				left2 = V_max
				GetAxis/Q right
				right1 = V_min
				right2 = V_max
				GetAxis/Q bottom
				bottom1 = V_min
				bottom2 = V_max
				ThereWasAGraph = 1													// Remember that there was a graph
			else
				XLeft = 392
				YTop = 524
				XRight = 825
				YBottom = 724
				ThereWasAGraph = 0
			endif
		
			DoWindow/K MultiPatch_ShowInputs								// Kill window first, in order to completely re-create it
			i = 0																// Check which input channels are relevant this time
			do
				if (CalledFromPM)													// Depending on which routine called 'DA_DoShowInputs', different checkboxes decide which waves are to be shown
					CommandStr = "root:MP:PM_Data:AddThisChannel = InputCheck"+num2str(CurrentStep)+"_"+num2str(i+1)
					Execute CommandStr											// Channel was checked in the PatternMaker panel (hence, wave was acquired, and wave does exist)
				else
					CommandStr = "In"+num2str(i+1)								// Channel is checked for input on Switchboard panel (hence, wave was acquired, and wave does exist)
					ControlInfo/W=MultiPatch_Switchboard $CommandStr
					AddThisChannel = V_value
				endif
	
				if (AddThisChannel)													// Channel input wave should be added to the graph
	
					VarStr = "StartAt"+num2str(i+1)								// Find out where suffix numbering of waves should start
					CommandStr = "root:MP:TempStartAt = root:MP:IO_Data:"+VarStr
					Execute CommandStr
	
					if (KillWavesFlag)												// The user wishes to kill the waves after acquisition...
						DummyStr = "Temp"+num2str(i+1)						// ... so we must display a copy of the input wave to enable killing
					else
						CommandStr = "root:MP:DummyStr = (root:MP:IO_Data:"+WaveInVarNames[i]
						CommandStr += "+JS_num2digstr(4,"+num2str(TempStartAt)+"))"
						Execute CommandStr										// If no killing, just figure out the wave name, store it in 'DummyStr'
					endif
	
					if (NDraw==0)													// First wave to be added?
						
						if (VClampWave[i])											// If so, create graph
							Display/W=(XLeft,YTop,XRight,YBottom)/R $DummyStr as "Acquired waves"		// Voltage clamp waves to the right
						else
							Display/W=(XLeft,YTop,XRight,YBottom)/L $DummyStr as "Acquired waves"		// Current clamp waves to the left
						endif
						DoWindow/C MultiPatch_ShowInputs
						ControlBar 22
						Button sp1 pos={32*0,1},proc=ZoomSpike,size={28,18},title="Ap1" ,fSize=11,font="Arial",fColor=(ChannelColor_R[0],ChannelColor_G[0],ChannelColor_B[0])//,appearance={os9,all}
						Button sp2 pos={32*1,1},proc=ZoomSpike,size={28,18},title="Ap2" ,fSize=11,font="Arial",fColor=(ChannelColor_R[1],ChannelColor_G[1],ChannelColor_B[1])//,appearance={os9,all}
						Button sp3 pos={32*2,1},proc=ZoomSpike,size={28,18},title="Ap3" ,fSize=11,font="Arial",fColor=(ChannelColor_R[2],ChannelColor_G[2],ChannelColor_B[2])//,appearance={os9,all}
						Button sp4 pos={32*3,1},proc=ZoomSpike,size={28,18},title="Ap4" ,fSize=11,font="Arial",fColor=(ChannelColor_R[3],ChannelColor_G[3],ChannelColor_B[3])//,appearance={os9,all}
						Button sp0 pos={32*4,1},proc=ZoomSpike,size={40,18},title="Auto X"  ,fSize=11,font="Arial"//,appearance={os9,all}

						Button ROI0Go,pos={32*4+34+4+36+4,1},size={30+20,18},proc=PM_RT_GotoROIProc,title="Auto XY",fSize=11,font="Arial"//,appearance={os9,all}

						ROI_x = 32*4+34+4+40+4+36+4+70-10
						ROI_w = 18
						Button ROI1GoAcq,pos={ROI_x+ROI_w*0-50,1},size={ROI_w-4+50,18},proc=PM_RT_GotoROIProc,title="Go to ROI 1",fSize=11,font="Arial",fColor=(ChannelColor_R[0],ChannelColor_G[0],ChannelColor_B[0])//,appearance={os9,all}
						Button ROI2GoAcq,pos={ROI_x+ROI_w*1,1},size={ROI_w-4,18},proc=PM_RT_GotoROIProc,title="2",fSize=11,font="Arial",fColor=(ChannelColor_R[1],ChannelColor_G[1],ChannelColor_B[1])//,appearance={os9,all}
						Button ROI3GoAcq,pos={ROI_x+ROI_w*2,1},size={ROI_w-4,18},proc=PM_RT_GotoROIProc,title="3",fSize=11,font="Arial",fColor=(ChannelColor_R[2],ChannelColor_G[2],ChannelColor_B[2])//,appearance={os9,all}
						Button ROI4GoAcq,pos={ROI_x+ROI_w*3,1},size={ROI_w-4,18},proc=PM_RT_GotoROIProc,title="4",fSize=11,font="Arial",fColor=(ChannelColor_R[3],ChannelColor_G[3],ChannelColor_B[3])//,appearance={os9,all}
					
						ROI_x = 32*4+34+4+40+4+36+4+ROI_w*4+4+70+70-10-24
						ROI_w = 18
						Button ROI1Grab,pos={ROI_x+ROI_w*0-50,1},size={ROI_w-4+50,18},proc=PM_RT_TakeROIProc,title="Grab ROI 1",fSize=11,font="Arial",fColor=(ChannelColor_R[0],ChannelColor_G[0],ChannelColor_B[0])//,appearance={os9,all}
						Button ROI2Grab,pos={ROI_x+ROI_w*1,1},size={ROI_w-4,18},proc=PM_RT_TakeROIProc,title="2",fSize=11,font="Arial",fColor=(ChannelColor_R[1],ChannelColor_G[1],ChannelColor_B[1])//,appearance={os9,all}
						Button ROI3Grab,pos={ROI_x+ROI_w*2,1},size={ROI_w-4,18},proc=PM_RT_TakeROIProc,title="3",fSize=11,font="Arial",fColor=(ChannelColor_R[2],ChannelColor_G[2],ChannelColor_B[2])//,appearance={os9,all}
						Button ROI4Grab,pos={ROI_x+ROI_w*3,1},size={ROI_w-4,18},proc=PM_RT_TakeROIProc,title="4",fSize=11,font="Arial",fColor=(ChannelColor_R[3],ChannelColor_G[3],ChannelColor_B[3])//,appearance={os9,all}
						Button AutoROIGrabButton,pos={ROI_x+ROI_w*4,1},size={64,18},proc=PM_RT_AutoTakeROIProc,title="AutoGrab",fSize=11,font="Arial"
						
						Button ShowEPSPPos,pos={ROI_x+ROI_w*4+64+4,1},size={64,18},proc=PM_RT_ShowEPSPPosProc,title="EPSP pos?",fSize=11,font="Arial"
					
						Button FilterButton,pos={ROI_x+ROI_w*4+64+4+64+4,1},size={64,18},proc=PM_RT_SetUpFilterProc,title="Filter",fSize=11,font="Arial"
					
						ModifyGraph minor(bottom)=1
	
					else
	
						if (VClampWave[i])											// If not, add to previously created graph
							AppendToGraph/R $DummyStr							// Voltage clamp waves to the right
						else
							AppendToGraph/L $DummyStr							// Current clamp waves to the left
						endif
						ModifyGraph offset($DummyStr)={0,InputOffset*i}
	
					endif
					ModifyGraph rgb($DummyStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
	
					if (FirstLegendEntry)													// Create the text string for the legend
						FirstLegendEntry = 0
					else
						LegendStr = LegendStr+"\\r"
					endif
					LegendStr = LegendStr+"\\s("+DummyStr+")Ch#"+num2str(i+1)
					NDraw += 1
				endif
				i+=1
			while(i<4)
			
			CommandStr = "Textbox/N=Legend/A=LT \""+LegendStr+"\""					// Add legend to graph
			Execute CommandStr
			if (!CalledFromPM)																// Don't add button if a pattern is running -- it takes too much time
				Button AddToLog_Inputs,pos={32*4+40+4,1},size={30,18},proc=AddToLogProc,title="2log",fSize=11,font="Arial"//,appearance={os9,all}	// Add 'add-graph-to-log-file' button to graph
			endif
	
			if ((PatternRunning) %& (RT_ROIOnOff))										// Zoom in to the region of interest, when a pattern is used, and when the user has chosen do to so
				SetAxis /Z left,RT_ROI_y1[RT_ROI_Slot-1],RT_ROI_y2[RT_ROI_Slot-1]
				SetAxis /Z right,RT_ROI_yy1[RT_ROI_Slot-1],RT_ROI_yy2[RT_ROI_Slot-1]				// KM 9/25/00
				SetAxis bottom,RT_ROI_x1[RT_ROI_Slot-1],RT_ROI_x2[RT_ROI_Slot-1]
			else
				SetAxis/A
			endif
			
			if ((ZoomFlag) %& (ThereWasAGraph))
				SetAxis/Z left,left1,left2
				SetAxis/Z right,right1,right2
				SetAxis/Z bottom,bottom1,bottom2
			endif
	
		endif // Recreate the display?

	else

		DoWindow/K MultiPatch_ShowInputs

	endif // Want to show inputs?
	
End

//////////////////////////////////////////////////////////////////////////////////
//// When unchecking the "show inputs" flag remove the actual graph too.

Function DA_ToggleShowInputs(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked

	if (!checked)
		DoWindow/K MultiPatch_ShowInputs
		DoWindow/K From_Ch1
		DoWindow/K From_Ch2
		DoWindow/K From_Ch3
		DoWindow/K From_Ch4
	else
		DA_DoShowInputs(0)
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// With National Instruments board, there are up to two boards that can be reset.
//// With Instrutech ITC-18, there is always only one board.

Function ResetBothBoards(ctrlName) : ButtonControl
	String ctrlName
	
	print "Resetting board(s)..."
	SetUpBoards()
	print "\tBoard(s) reset at "+Time()

End

//////////////////////////////////////////////////////////////////////////////////

Function GoToWaveCreator(ctrlName) : ButtonControl
	String	ctrlName
	
	String	CommandStr
	
	NVAR	ShowFlag = root:MP:ShowFlag
	NVAR	ChannelNumber = root:MP:ChannelNumber

	DoWindow MultiPatch_WaveCreator
	if (V_Flag)
		DoWindow/F MultiPatch_WaveCreator
	else
		CommandStr = "MultiPatch_WaveCreator()"
		Execute CommandStr
		if (ShowFlag)
			WC_ShowWave(ChannelNumber)
		endif
	endif

End

//////////////////////////////////////////////////////////////////////////////////

Function GoToSwitchboard(ctrlName) : ButtonControl
	String ctrlName

	DoWindow/F MultiPatch_Switchboard

End

//////////////////////////////////////////////////////////////////////////////////
//// Bring the Average Panel to front, if it exists...

Function GoToAveragePanelProc(ctrlName) : ButtonControl
	String ctrlName

	DoWindow Averaging_Control
	if (V_Flag)
		DoWindow/F Averaging_Control
	else
		Abort "The Average Panel procedure was not loaded or needs to be initiated."
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Bring the LineScan Analysis Panel to front, if it exists...

Function GoToMP285PanelProc(ctrlName) : ButtonControl
	String ctrlName

	DoWindow MM_Panel
	if (V_Flag)
		DoWindow/F MM_Panel
	else
		Abort "The Scientifica MultiMove Panel procedure was not loaded or needs to be initiated."
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Bring the MP_DatAn panel to front, if it exists...

Function GoToDatAn(ctrlName) : ButtonControl
	String ctrlName

	DoWindow MultiPatch_DatAn
	if (V_Flag)
		DoWindow/F MultiPatch_DatAn
	else
		Abort "The MP Data Analysis macro was not loaded or needs to be initiated."
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Repeat CreateRange and Range2Pattern for all selected channels

Function WC_MultiRange(ctrlName) : ButtonControl
	String ctrlName
	
	WC_DoMultiRange()
	
End

Function WC_DoMultiRange()

	WAVE	OutputOnOff = root:MP:IO_Data:OutputOnOff				// The remembered settings for OutputOnOff for all four channels

	Variable	i
	
	Print "--- Starting DoMultiRange ---"
	Print "\t",Time(),Date()
	
	i = 0
	do
		print "=== DoMultiRange: Working on Channel#"+num2str(i+1)+" ==="
		if (OutputOnOff[i])
			Print "\tDoing this channel..."
			DoWindow/F MultiPatch_WaveCreator
			PopupMenu DestSelectPopup,mode=(i+1),win=MultiPatch_WaveCreator
			WC_ToggleDest("",i+1,"")
			WC_MakeRange("")
			Execute "WC_DoRange2Pattern()"
		else
			Print "\tIgnoring this channel..."
		endif
		i += 1
	while(i<4)
	
	DoWindow/K WC_RangeGraph

	Print "--- Done DoMultiRange ---"

end


//////////////////////////////////////////////////////////////////////////////////
//// Use the range to update the PatternMaker

Function WC_Range2Pattern(ctrlName) : ButtonControl
	String ctrlName
	
	Execute "WC_DoRange2Pattern()"
	
End

Macro WC_DoRange2Pattern()

	Variable	i,j,k
	String		CommandStr

	if (Exists("MP_Values")!=1)
		Abort "You must create the value range first. Use the \"Edit range\" button, or just do Make!"
	endif
	
	Variable	NValues = numpnts(root:MP_Values)

	if (NValues>root:MP:PM_Data:MaxSteps)
		Abort "A pattern can only contain "+root:MP:PM_Data:MaxSteps+" steps!"
	endif
	
	Variable	Handle = ShowInfoBox("Producing pattern!")

	root:MP:PM_Data:NSteps = NValues																				// The number of steps in the pattern
	root:MP:PM_Data:OldNSteps = NValues																			// Update the "old" number of steps

	j = root:MP:ChannelNumber-1

	i = 0
	do																												// Step counter
	
		// First set all output and input checkboxes to "used" or "not used" as defined by the output selector checkbox in the WaveCreator and Switchboard panels
		k = 0
		do

			CommandStr = "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(k+1)+"="
			CommandStr +=	 num2str(root:MP:IO_Data:OutputOnOff[k])												// Output checkbox values
			Execute CommandStr

			CommandStr = "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(k+1)+"="
			CommandStr +=	 num2str(root:MP:IO_Data:OutputOnOff[k])												// Input checkbox values
			Execute CommandStr
			
			k += 1
		while (k<4)

		CommandStr = "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)+"=1"					// Output checkbox values
		Execute CommandStr

		CommandStr = "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1)+"=1"					// Input checkbox values
		Execute CommandStr
		
		CommandStr = "root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)+"="					// Output wave names
		CommandStr += "\""+WC_RangeIndex2WaveName(root:MP:ChannelNumber,i)+"\""
		Execute CommandStr

		i += 1
	while (i<NValues)
		
	RemoveInfoBox(Handle)

	print "Updating PatternHandler based on range in WaveCreator at "+Time()

	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Creating a pattern based on range\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\tUpdating pattern \""+root:MP:PM_Data:PatternName+"\" at time "+Time()+".\r"
	Notebook Parameter_Log ruler=Normal, text="\r\tDescription of this pattern follows.\r"

	DumpPatternToNoteBook()								// Put info about the newly loaded pattern in the notebook

	MakeMultiPatch_PatternMaker()							// Redraw the panel
	DoUpdate

End

//////////////////////////////////////////////////////////////////////////////////
//// Make a series of waves accoring to the range of values specified
//// The checkboxes define which of the parameter values will be modified.

Function WC_MakeRange(ctrlName) : ButtonControl
	String ctrlName
	
	Variable	SpecialProtocol = 0
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key. Now using Txomin's special biexponential current injection protocol."
		SpecialProtocol = 1
	endif
	NVAR tau2 =				root:MP:SynapseTau2				// Falling phase tau of biexponential [ms]

	SVAR CurrWaveNameOut =	root:MP:CurrWaveNameOut		// Name of currently selected output wave

	NVAR ChannelNumber = 	root:MP:ChannelNumber		// Current channel
	NVAR SlotNumber = 		root:MP:SlotNumber			// Current slot

	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 		root:MP:PulseDispl			// Pulse displacement
	NVAR CommandLevel = 		root:MP:CommandLevel			// constant holding current/volt Command Level // 3/30/00 KM

	String		CommandStr
	Variable	i
	Variable	Which						// Which 
	
	if (Exists("MP_Values")!=1)
		Abort "MP_Values wave does not exist! Create it using the \"Edit range\" button, or just Make it."
	endif
	
	print "--- Making new waves with a range of values ---"
	print "\tTime:",Time()
	print "\tLocating parameter name"
	
	i = 0
	do
		CommandStr = "ParamCheckBox_"+num2str(i+1)
		ControlInfo/W=MultiPatch_WaveCreator $CommandStr
		if (V_value)
			Which = i+1
			i = Inf
		endif
		i += 1
	while (i<6)
	
	Make/T/O/N=(6) MP_SetVarName		// Figure out name of the setvariable box in question
	MP_SetVarName = {"NPulsesSetVar","PulseAmpSetVar","PulseDurSetVar","PulseFreqSetVar","DisplacedSetVar","CommandLevelSetVar"}
	// 1. NPulsesSetVar
	// 2. PulseAmpSetVar
	// 3. PulseDurSetVar
	// 4. PulseFreqSetVar
	// 5. DisplacedSetVar
	// 6. CommandLevelSetVar
	String	SetVarStr = MP_SetVarName[Which-1]
	KillWaves/Z MP_SetVarName
	ControlInfo/W=MultiPatch_WaveCreator $SetVarStr
	String	VarName = S_DataFolder+S_Value
	NVAR	Var = $VarName
	print "\t\t--> Found SetVar called \""+SetVarStr+"\", which corresponds to the variable \""+VarName+"\" of value "+num2str(Var)+"."
	WAVE w = MP_Values
	Variable NValues = numpnts(w)
	print "\tNumber of values:",NValues
	if (NValues>20)						// !@#$ Insist on having a larger range? --> Increase the value in the comparison to the right of the '>' sign! Then recompile!
		Beep
		Abort "This seems like an excessive value range!\rInsist? Alter code by searching Multipatch source for the string '!@#$'!"
	endif
	print "\tCreating waves"
	Variable	OldValue = Var								// Store away old value, so it can be restored
	String		OldName = CurrWaveNameOut				// Store away old name, so it can be restored
	String		TotName
	WC_RemoveOutputWaveGraph(1)												// Remove all old graphs showing output waves
	WC_RemoveOutputWaveGraph(2)
	WC_RemoveOutputWaveGraph(3)
	WC_RemoveOutputWaveGraph(4)
	DoWindow/K WC_RangeGraph
	Display/W=(15,175,374,474) as "Range of waves"
	DoWindow/C WC_RangeGraph
	i = 0
	do
		print "\t\tDoing value number "+num2str(i+1)+", which is "+num2str(w[i])
		TotName = WC_RangeIndex2WaveName(ChannelNumber,i)
		print "\t\t\t--> Wave name:",TotName
		Var = w[i]																	// Update the value at hand
		CurrWaveNameOut = TotName												// Update the output wave name, i.e. along with the suffix
		WC_ReadWaveCreatorDataAndStore(ChannelNumber,SlotNumber)			// Make sure to read the WaveCreator panel before creating the wave
		WC_CreateOneWave("DummyControlName")									// And finally, create the wave, take the notes, etc.
		AppendToGraph/W=WC_RangeGraph $(TotName)
		ModifyGraph RGB($(TotName))=(65535*(NValues-1-i)/(NValues-1),0,65535*i/(NValues-1))
		CurrWaveNameOut = OldName
		DoUpdate
		i += 1
	while (i<NValues)
	DoWindow/K $("Channel_"+num2str(ChannelNumber))
	DoWindow/F WC_RangeGraph
	Legend/A=LT
	ControlBar 22
	Button CloseThePlotsButton,pos={0,1},size={18,18},proc=WC_CloseThePlotsProc,title="X"
	Button SpreadTheTracesButton,pos={22,1},size={44,18},proc=WC_SpreadTheTracesProc,title="Spread",fSize=10
	Button CollectTheTracesButton,pos={22+48,1},size={44,18},proc=WC_SpreadTheTracesProc,title="Collect",fSize=10
	Button RenameForCyclingButton,pos={22+48+48,1},size={96,18},proc=WC_AdaptForCycling,title="Adapt for cycling",fSize=10
	Button AddToLog_Range,pos={22+48+48+100,1},size={60,18},proc=AddToLogProc,title="Add to log",fSize=10
	
	// Restore old values when done
	Var = OldValue
	WC_ReadWaveCreatorDataAndStore(ChannelNumber,SlotNumber)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Close all make range graph

Function WC_CloseThePlotsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	DoWindow/K WC_RangeGraph
	DoWindow/K Channel_1
	DoWindow/K Channel_2
	DoWindow/K Channel_3
	DoWindow/K Channel_4

End

//////////////////////////////////////////////////////////////////////////////////
//// Spread the traces in the make range graph

Function WC_SpreadTheTracesProc(ctrlName) : ButtonControl
	String		ctrlName
	
	if (StringMatch(ctrlName,"SpreadTheTracesButton"))
		DoSpreadTracesInGraph ("WC_RangeGraph",1)
	else
		DoSpreadTracesInGraph ("WC_RangeGraph",0)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Takes a range index number and the channel number and returns the compound output wave
//// wave name as a string.

Function/S WC_RangeIndex2WaveName(ChannelNumber,RangeIndex)
	Variable	ChannelNumber,RangeIndex

	SVAR CurrWaveNameOut =	root:MP:CurrWaveNameOut		// Name of currently selected output wave

	String		SuffixStr										// The suffix to be attached to the end of the wave name
	String		BaseName = CurrWaveNameOut					// Base name of the waves to be created, taken from the current output name
	String		TotName = ""									// Complete name of output wave, including the suffix
	
	WAVE		w = MP_Values
	
	SuffixStr = "_"+num2str(w[RangeIndex])
	SuffixStr = EliminateBadChars(SuffixStr)
	TotName = BaseName+SuffixStr

	Return	TotName

End

//////////////////////////////////////////////////////////////////////////////////
//// Edit the parameter range

Function WC_EditRange(ctrlName) : ButtonControl
	String ctrlName
	
	if (Exists("MP_Values")!=1)
		Make/O/N=(6) MP_Values
		MP_Values = x/5-0.3
	endif
	DoWindow/K MP_ValuesTable
	Edit/K=1/W=(263,359,466,692) MP_Values as "Parameter values"
	DoWindow/C MP_ValuesTable
	
End
	
//////////////////////////////////////////////////////////////////////////////////
//// Toggle the parameter-select checkboxes in the WaveCreator panel

Function WC_FlipParamProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	Variable	Which

	Which = str2num(ctrlName[strlen(ctrlName)-1,strlen(ctrlName)-1])
	WC_DoFlipParamProc(Which)

End

Function WC_DoFlipParamProc(Which)
	Variable	Which
	
	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	Variable	wid = 180
	
	String		CommandStr,WorkStr1

	Variable	i = 0
	do
		CommandStr = "ParamCheckBox_"+num2str(i+1)
		WorkStr1 = num2str(i+1)+"."
		if (i+1==Which)
			CheckBox $CommandStr,pos={260-wid+wid/6*i,413+19*4+2},labelBack=(rr,gg,bb),size={wid/6,17},proc=WC_FlipParamProc,title=WorkStr1,value=1,win=MultiPatch_WaveCreator
		else
			CheckBox $CommandStr,pos={260-wid+wid/6*i,413+19*4+2},labelBack=(rr,gg,bb),size={wid/6,17},proc=WC_FlipParamProc,title=WorkStr1,value=0,win=MultiPatch_WaveCreator
		endif
		i += 1
	while (i<6)

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle the input checkboxes in both panels

Function WC_ToggleInputOnOff(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable ChannelNumber = Str2Num(ctrlName[2])
	
	WC_DoTheToggleInputOnOff(checked,ChannelNumber)

End

//// This is the general InputOnOff toggle function that actually does the job

Function WC_DoTheToggleInputOnOff(Checked,ChannelNumberToggled)
	Variable Checked
	Variable ChannelNumberToggled									// The channel number whose InputOnOff was toggled
	
	Variable nChecked = 0
	
	Variable	n = 4
	Variable	i
	
	CheckBox $("In"+num2str(ChannelNumberToggled)),value=checked,win=MultiPatch_Switchboard

	i = 0
	do
		ControlInfo/W=MultiPatch_Switchboard $("In"+num2str(i+1))
		nChecked += V_Value
		i += 1
	while(i<n)

	if (nChecked == 0)
		Print "At least one input has to be checked."
		CheckBox $("In"+num2str(ChannelNumberToggled)),value=1,win=MultiPatch_Switchboard
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle the output checkboxes in both panels
//// First come the function calls that are channel specific, so that Igor knows which channel is concerned

Function WC_ToggleOutputOnOff(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable ChannelNumber = Str2Num(ctrlName[3])
	
	WC_DoTheToggleOutputOnOff(checked,ChannelNumber)

End

//// This is the general OutputOnOff toggle function that actually does the job

Function WC_DoTheToggleOutputOnOff(Checked,ChannelNumberToggled)
	Variable Checked
	Variable ChannelNumberToggled									// The channel number whose OutputOnOff was toggled

	NVAR	CurrChannelNumber = root:MP:ChannelNumber			// The channel currently displayed in the WaveCreator window
	NVAR	ShowFlag = root:MP:ShowFlag							// Show the waves as they are being constructed?

	WAVE	OutputOnOff = root:MP:IO_Data:OutputOnOff				// The remembered settings for OutputOnOff for all four channels

	SVAR		BoardName =			root:BoardName				// ITC18 board? National Instruments?

	String CommandStr = ""
	
	OutputOnOff[ChannelNumberToggled-1] = Checked				// Store the setting in the appropriate location
	
	CommandStr = "CheckBox Out"+num2str(ChannelNumberToggled)+" pos={100,"+num2str(42+(ChannelNumberToggled-1)*75)+"},size={16+60,20},proc=WC_ToggleOutputOnOff"+",title=\"Output:\",value=root:MP:IO_Data:OutputOnOff["+num2str(ChannelNumberToggled-1)+"],win=MultiPatch_Switchboard"
	Execute CommandStr											// Redraw corresponding checkbox in the Switchboard panel

	DoWindow MultiPatch_WaveCreator
	if ( (V_Flag) %& (CurrChannelNumber == ChannelNumberToggled)	)	// The channel that is currently on display in WaveCreator is the same that was just OutputOnOff-toggled
		CommandStr = "CheckBox Out"+num2str(ChannelNumberToggled)+" pos={8,329},size={124,17},proc=WC_ToggleOutputOnOff"+",title=\"Use this channel\",value="+num2str(OutputOnOff[ChannelNumberToggled-1])+",win=MultiPatch_WaveCreator"
		Execute CommandStr										// If applicable, redraw the corresponding checkbox in the WaveCreator panel
		if (ShowFlag)
			WC_ShowWave(ChannelNumberToggled)					// Redraw the graph to indicate that the wave being created (and displayed) has a channel that is not in use
		endif
	endif
	
	//// Jesper, 2008-12-16: Hardwiring the ITC18 behavior for all board types, since it makes most sense usually anyhow
//	if (StringMatch(BoardName,"ITC18"))				// With the ITC-18, every input channel has to be matched to an output channel, or acquisition will be mucked up (mostly because I am lazy...)
		WC_DoTheToggleInputOnOff(OutputOnOff[ChannelNumberToggled-1],ChannelNumberToggled)
//	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Read the data in the WaveCreator window and store in the variables indexed by the argument
//// 'Channel'.

Function WC_ReadWaveCreatorDataAndStore(Channel,Slot)
	Variable	Channel,Slot

	String 		CommandStr
	
	WAVE PulseAmpWave = 			root:MP:IO_Data:PulseAmp		// Stored data
	WAVE ChannelTypeWave = 		root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 			root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 			root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 			root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 		root:MP:IO_Data:PulseDispl
	WAVE CommandLevelWave = 	root:MP:IO_Data:CommandLevel		// 3/30/00 KM
	
	WAVE/T WaveNamesOutWave =	root:MP:IO_Data:WaveNamesOutWave
	SVAR CurrWaveNameOut =		root:MP:CurrWaveNameOut

	ControlInfo/W=MultiPatch_WaveCreator TypePopup
	ChannelTypeWave[Channel-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator NPulsesSetVar
	NPulsesWave[Channel-1][Slot-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator PulseAmpSetVar
	PulseAmpWave[Channel-1][Slot-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator PulseDurSetVar
	PulseDurWave[Channel-1][Slot-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator PulseFreqSetVar
	PulseFreqWave[Channel-1][Slot-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator DisplacedSetVar
	PulseDisplWave[Channel-1][Slot-1] = V_value
	CommandStr = "root:MP:IO_Data:WaveNamesOut"+num2str(Channel)+" = root:MP:CurrWaveNameOut"
	Execute CommandStr
	ControlInfo/W=MultiPatch_WaveCreator CommandLevelSetVar		// 3/30/00 KM
	CommandLevelWave[Channel-1] = V_value							// 3/30/00 KM

	WaveNamesOutWave[Channel-1] = CurrWaveNameOut
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles displayed data as slot number is changed

Function WC_ToggleSlot(ctrlName,popNum,popStr) : PopupMenuControl
	String 		ctrlName
	Variable 	popNum
	String 		popStr
	
	String	CommandStr

	NVAR ChannelNumber =		root:MP:ChannelNumber		// Wave number
	NVAR SlotNumber =			root:MP:SlotNumber			// Slot number
	NVAR PreviousSlot =		root:MP:PreviousSlot			// Previous slot number
	NVAR ChannelType = 		root:MP:ChannelType			// Wave type
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 		root:MP:PulseDispl			// Pulse displacement
	NVAR BiphasicFlag = 		root:MP:BiphasicFlag			// Biphasic flag
	NVAR CommandLevel=		root:MP:CommandLevel			// holding current/volt command level   3/30/00 KM

	WAVE PulseAmpWave = 		root:MP:IO_Data:PulseAmp		// Stored dittos
	WAVE ChannelTypeWave = 	root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 		root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 		root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 	root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 	root:MP:IO_Data:PulseDispl
	WAVE BiphasicFlagWave =	root:MP:IO_Data:BiphasicFlag	
	WAVE CommandLevelWave =	root:MP:IO_Data:CommandLevel	// 3/30/00 KM
	WAVE OutputOnOff =		root:MP:IO_Data:OutputOnOff	// Update the output checkbox

	NVAR	UseSlotFlag = 		root:MP:UseSlotFlag				// Use this slot?
	WAVE	UseSlotWave = 		root:MP:IO_Data:UseSlotWave	// Same, store away
	NVAR	AddSlotFlag = 		root:MP:AddSlotFlag				// Slot is additive?
	WAVE	AddSlotWave = 		root:MP:IO_Data:AddSlotWave	// Same, store away
	NVAR	SynapseSlotFlag = root:MP:SynapseSlotFlag			// Slot is a biexponential?
	WAVE	SynapseSlotWave = root:MP:IO_Data:SynapseSlotWave	// Same, store away
	NVAR	RampFlag = 			root:MP:RampFlag					// Ramp?
	WAVE	RampWave = 			root:MP:IO_Data:RampWave		// Same, store away
	
	//// First save potentially just altered data
	WC_ReadWaveCreatorDataAndStore(ChannelNumber,PreviousSlot)

	//// Then load and display previously stored away data
	SlotNumber =  popNum
	UseSlotFlag = UseSlotWave[ChannelNumber-1][SlotNumber-1]			// Boolean: Use this slot?
	AddSlotFlag = AddSlotWave[ChannelNumber-1][SlotNumber-1]			// Boolean: Is this slot additive or absolute?
	SynapseSlotFlag = SynapseSlotWave[ChannelNumber-1][SlotNumber-1]	// Boolean: Is this slot a pulse or a biexponential?
	RampFlag = RampWave[ChannelNumber-1][SlotNumber-1]					// Boolean: Is this slot a pulse or a ramp?

	NPulses = NPulsesWave[ChannelNumber-1][SlotNumber-1]					// Load number of pulses
	ChannelType = ChannelTypeWave[ChannelNumber-1]							// Load wave type
	PulseAmp = PulseAmpWave[ChannelNumber-1][SlotNumber-1]				// Load pulse amplitude
	PulseDur = PulseDurWave[ChannelNumber-1][SlotNumber-1]				// Load pulse duration
	PulseFreq = PulseFreqWave[ChannelNumber-1][SlotNumber-1]			// Load pulse frequency
	PulseDispl = PulseDisplWave[ChannelNumber-1][SlotNumber-1]			// Load pulse displacement
	CommandLevel = CommandLevelWave[ChannelNumber-1]						// Load holding current/volt command level  3/30/00 KM
	BiphasicFlag = BiphasicFlagWave[ChannelNumber-1][SlotNumber-1]	// Load biphasic?
	CommandStr = "root:MP:CurrWaveNameOut = root:MP:IO_Data:WaveNamesOut"+num2str(ChannelNumber)			// Change the output wave name
	Execute CommandStr

	//// Refresh the slot check box
	WC_ToggleSlotOnDisplay()
	
	//// Show the wave?
	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
	//// Redefine previous slot to be present slot
	PreviousSlot = SlotNumber
	PopupMenu SlotNumberPopup,mode=SlotNumber,win=MultiPatch_WaveCreator		// Only necessary if called by other routine rather than through popup
	
	ControlUpdate/A/W=MultiPatch_WaveCreator

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles slot checkboxes on panel

Function WC_ToggleSlotOnDisplay()

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd

	NVAR	UseSlotFlag = 			root:MP:UseSlotFlag				// Use this slot?
	NVAR	AddSlotFlag = 			root:MP:AddSlotFlag				// Slot is additive?
	NVAR	SynapseSlotFlag = 		root:MP:SynapseSlotFlag		// Slot is a biexponential?
	NVAR	RampFlag = 			root:MP:RampFlag				// Ramp?
	NVAR	ChannelType = 			root:MP:ChannelType			// Wave type

	CheckBox UseSlotCheck,pos={176-4,160},size={56,20},title="Use",labelBack=(rr,gg,bb),proc=WC_ToggleUseSlot,value=UseSlotFlag
	CheckBox AddSlotCheck,pos={176-4,160+13},size={56,20},title="Add",labelBack=(rr,gg,bb),proc=WC_ToggleAddSlot,value=AddSlotFlag
	CheckBox SynapseSlotCheck,pos={176-4,160+2*13},size={56,20},title="Biexp",labelBack=(rr,gg,bb),proc=WC_ToggleSynapseSlot,value=SynapseSlotFlag
	CheckBox RampCheck,pos={176+40,173},size={56,20},proc=WC_ToggleRampSlot,title="Ramp",labelBack=(rr,gg,bb),value=RampFlag
	WC_DoToggleBiphasicOnDisplay(ChannelType)

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles displayed data as channel is changed

Function WC_ToggleDest(ctrlName,popNum,popStr) : PopupMenuControl
	String 		ctrlName
	Variable 	popNum
	String 		popStr

	String 		CommandStr
	
	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd

	String WorkStr1,WorkStr2

	NVAR ChannelNumber =		root:MP:ChannelNumber			// Wave number
	NVAR PreviousChannel = 	root:MP:PreviousChannel		// Previous wave number
	NVAR ChannelType = 		root:MP:ChannelType			// Wave type
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 			root:MP:PulseDispl				// Pulse displacement
	NVAR BiphasicFlag = 		root:MP:BiphasicFlag			// Biphasic flag
	NVAR CommandLevel=		root:MP:CommandLevel			// holding current/volt command level   3/30/00 KM

	WAVE PulseAmpWave = 		root:MP:IO_Data:PulseAmp		// Stored dittos
	WAVE ChannelTypeWave = 	root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 		root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 		root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 		root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 	root:MP:IO_Data:PulseDispl
	WAVE BiphasicFlagWave =	root:MP:IO_Data:BiphasicFlag	
	WAVE CommandLevelWave =	root:MP:IO_Data:CommandLevel	// 3/30/00 KM
	WAVE OutputOnOff =			root:MP:IO_Data:OutputOnOff	// Update the output checkbox

	NVAR	UseSlotFlag = 			root:MP:UseSlotFlag				// Use this slot?
	NVAR	SlotNumber =			root:MP:SlotNumber			// Slot number
	WAVE	UseSlotWave = 			root:MP:IO_Data:UseSlotWave	// Same, store away
	
	NVAR	AddSlotFlag = 			root:MP:AddSlotFlag				// Is this slot additive? (otherwise absolute)
	WAVE	AddSlotWave = 			root:MP:IO_Data:AddSlotWave	// Same, store away

	NVAR	SynapseSlotFlag = 		root:MP:SynapseSlotFlag			// Is this slot a biexp? (otherwise a pulse)
	WAVE	SynapseSlotWave = 		root:MP:IO_Data:SynapseSlotWave	// Same, store away

	//// First save potentially just altered data
	WC_ReadWaveCreatorDataAndStore(PreviousChannel,SlotNumber)

	//// Then load and display previously stored away data
	ChannelNumber = popNum												// Find destination channel on panel
	UseSlotFlag = UseSlotWave[ChannelNumber-1][SlotNumber-1]			// Is this slot on this channel in use?
	AddSlotFlag = AddSlotWave[ChannelNumber-1][SlotNumber-1]			// Is this slot additive? (otherwise absolute)
	SynapseSlotFlag = SynapseSlotWave[ChannelNumber-1][SlotNumber-1]		// Is this slot biexponential? (otherwise pulses)
	NPulses = NPulsesWave[ChannelNumber-1][SlotNumber-1]			// Load number of pulses
	ChannelType = ChannelTypeWave[ChannelNumber-1]					// Load wave type
	PulseAmp = PulseAmpWave[ChannelNumber-1][SlotNumber-1]			// Load pulse amplitude
	PulseDur = PulseDurWave[ChannelNumber-1][SlotNumber-1]			// Load pulse duration
	PulseFreq = PulseFreqWave[ChannelNumber-1][SlotNumber-1]		// Load pulse frequency
	PulseDispl = PulseDisplWave[ChannelNumber-1][SlotNumber-1]		// Load pulse displacement
	CommandLevel = CommandLevelWave[ChannelNumber-1]				// Load holding current/volt command level  3/30/00 KM
	BiphasicFlag = BiphasicFlagWave[ChannelNumber-1][SlotNumber-1]	// Load biphasic?
	CommandStr = "root:MP:CurrWaveNameOut = root:MP:IO_Data:WaveNamesOut"+num2str(ChannelNumber)			// Change the output wave name
	Execute CommandStr

	//// Refresh the slot check box
	WC_ToggleSlotOnDisplay()

	//// Refresh the type popup menu
	WC_RefreshTypePopup(ChannelType)
	
	//// Redraw panel according to type of chosen channel
	WC_DoToggleTypeOnDisplay(ChannelType)

	//// Kill previous OutputOnOff checkbox & create a new one
	CommandStr = "KillControl Out"+num2str(PreviousChannel)
	Execute CommandStr
	CommandStr = "Out"+num2str(ChannelNumber)
	WorkStr1 = "WC_ToggleOutputOnOff"
	CheckBox $CommandStr,pos={8,329},size={124,17},labelBack=(rr,gg,bb),proc=$WorkStr1,title="Use this channel",value=OutputOnOff[ChannelNumber-1]

	//// Change the name of the wave descriptor
	CommandStr = "root:MP:IO_Data:WaveDescriptor"+num2str(PreviousChannel)+" = root:MP:CurrWaveDescriptor"	// Save previous
	Execute CommandStr
	CommandStr = "root:MP:CurrWaveDescriptor = root:MP:IO_Data:WaveDescriptor"+num2str(ChannelNumber)		// Update to new
	Execute CommandStr

	//// Show the wave?
	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
	//// Redefine previous to be present channel
	PreviousChannel = ChannelNumber
	PopupMenu DestSelectPopup,mode=ChannelNumber,win=MultiPatch_WaveCreator	// Only necessary if this routine is called by another routine and not by the popup menu
	
	ControlUpdate/A/W=MultiPatch_WaveCreator
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles displayed data as channel is changed
//// ControlUpdate does not update pop-up menus in Igor! -- Must update it "manually" by
//// recreating it

Function WC_RefreshTypePopup(ChannelType)
	Variable	ChannelType

	PopupMenu TypePopup,pos={8,181},size={147,19},title="Type: ",proc=WC_ToggleType
	PopupMenu TypePopup,mode=ChannelType,value= #"\"Intra (I clamp);Extracellular;Intra (V clamp);\""
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles data as the type of wave (intra i clamp, extracellular, or intra v clamp) is changed.

Function WC_ToggleType(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	String CommandStr
	
	NVAR ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR ChannelType = 		root:MP:ChannelType			// Wave type
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur =			root:MP:PulseDur				// Pulse duration
	NVAR BiphasicFlag = 		root:MP:BiphasicFlag			// Biphasic flag
	
	WAVE ChannelTypeWave = 	root:MP:IO_Data:ChannelType
	WAVE BiphasicFlagWave = 	root:MP:IO_Data:BiphasicFlag
	
	BiphasicFlag = BiphasicFlagWave[ChannelNumber-1]			// Was wave set to biphasic previously?
	
	ControlInfo/W=MultiPatch_WaveCreator TypePopup				// Find the present type of wave
	ChannelType = V_value
	ChannelTypeWave[ChannelNumber-1] = V_value

	WC_DoToggleTypeOnDisplay(ChannelType)						// Toggle the WaveCreator display accordingly

	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles the biphasic checkbox on the panel

Function WC_DoToggleBiphasicOnDisplay(ChannelType)
	Variable	ChannelType
	
	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd

	NVAR	BiphasicFlag = root:MP:BiphasicFlag
	
	DoWindow/F MultiPatch_WaveCreator
	if (ChannelType==1)											// Intracellular current clamp
		CheckBox BiphasicCheck,disable=2
		CheckBox SynapseSlotCheck, disable=0
		CheckBox RampCheck, disable=0
	endif
	if (ChannelType==2)											// Extracellular
		CheckBox BiphasicCheck,disable=0
		CheckBox SynapseSlotCheck, disable=2
		CheckBox RampCheck, disable=2
	endif
	if (ChannelType==3)											// Intracellular voltage clamp
		CheckBox BiphasicCheck,disable=2
		CheckBox SynapseSlotCheck, disable=0
		CheckBox RampCheck, disable=0
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles the wavecreator display according to the type of wave that is currently being
//// processed.

Function WC_DoToggleTypeOnDisplay(ChannelType)
	Variable	ChannelType

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	String		CommandStr

	DoWindow/F MultiPatch_WaveCreator

	WC_DoToggleBiphasicOnDisplay(ChannelType)					// N.B.! Biphasic checkbox is toggled separately

	if (ChannelType==1)											// Intracellular current clamp
		SetVariable PulseAmpSetVar,pos={8,219},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="2. Pulse amplitude [nA]: "
		SetVariable PulseAmpSetVar,limits={-Inf,Inf,0.010},value=root:MP:PulseAmp
		SetVariable PulseDurSetVar,pos={8,237},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="3. Pulse duration [ms]: "
		SetVariable PulseDurSetVar,limits={0,Inf,1},value=root:MP:PulseDur
		SetVariable CommandLevelSetVar,pos={8,309-18},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="6. Command level [nA]:"
		SetVariable CommandLevelSetVar,limits={-Inf,Inf,0.010},value=root:MP:CommandLevel	// 3/30/00 KM
	endif
	if (ChannelType==2)											// Extracellular
		SetVariable PulseAmpSetVar,pos={8,219},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="2. Pulse amplitude [V]: "
		SetVariable PulseAmpSetVar,limits={-Inf,Inf,5},value=root:MP:PulseAmp
		SetVariable PulseDurSetVar,pos={8,237},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="3. Pulse duration [samples]: "
		SetVariable PulseDurSetVar,limits={0,Inf,1},value=root:MP:PulseDur
		SetVariable CommandLevelSetVar,pos={8,309-18},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="6. Command level [V]:"
		SetVariable CommandLevelSetVar,limits={-Inf,Inf,0.010},value=root:MP:CommandLevel
	endif
	if (ChannelType==3)											// Intracellular voltage clamp
		SetVariable PulseAmpSetVar,pos={8,219},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="2. Pulse amplitude [V]: "
		SetVariable PulseAmpSetVar,limits={-Inf,Inf,0.005},value=root:MP:PulseAmp
		SetVariable PulseDurSetVar,pos={8,237},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="3. Pulse duration [ms]: "
		SetVariable PulseDurSetVar,limits={0,Inf,1},value=root:MP:PulseDur
		SetVariable CommandLevelSetVar,pos={8,309-18},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="6. Command level [V]:"
		SetVariable CommandLevelSetVar,limits={-Inf,Inf,0.005},value=root:MP:CommandLevel	// 3/30/00 KM
	endif

	ControlUpdate/A/W=MultiPatch_WaveCreator

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggles the create appends flag

Function WC_ToggleCreateAppendsProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	NVAR		CreateAppendsFlag = root:MP:CreateAppendsFlag
	
	CreateAppendsFlag = checked
	if (CreateAppendsFlag)
		print "--- All wave creation now appends to previously existing waves ---"
		print "\t",Date(),Time()
	else
		print "--- Wave creation does not append to previously existing waves ---"
		print "\t",Date(),Time()
	endif
	
End
	
//////////////////////////////////////////////////////////////////////////////////
//// Toggles the seal test at the beginning of the output waves on/off

Function WC_ToggleSealTest(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	String		CommandStr
	
	NVAR ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR SealTestFlag = 		root:MP:SealTestFlag			// Seal test flag

	ControlInfo/W=MultiPatch_WaveCreator SealTestCheck		// Want seal test at beginning of wave?
	SealTestFlag = V_value

	WC_SealTestParamsUpdate()
	
	ControlUpdate/A/W=MultiPatch_WaveCreator

	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////

Function WC_SealTestParamsUpdate()

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	NVAR SealTestFlag = 		root:MP:SealTestFlag			// Seal test flag

	if (SealTestFlag==1)

		SetVariable SealTestDurSetVar,pos={8,97},size={250,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="Duration [ms] :"
		SetVariable SealTestDurSetVar,limits={0,Inf,10},value= root:MP:SealTestDur

		SetVariable SealTestPad1SetVar,pos={8,115},size={123,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="Pad1 [ms]:"
		SetVariable SealTestPad1SetVar,limits={0,Inf,10},value= root:MP:SealTestPad1
		SetVariable SealTestPad2SetVar,pos={135,115},size={123,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="Pad2 [ms]:"
		SetVariable SealTestPad2SetVar,limits={0,Inf,10},value= root:MP:SealTestPad2

		SetVariable SealTestAmp_ISetVar,pos={8,133},size={123,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="Iclamp:"
		SetVariable SealTestAmp_ISetVar,limits={-Inf,Inf,0.01},value= root:MP:SealTestAmp_I
		SetVariable SealTestAmp_VSetVar,pos={135,133},size={123,17},labelBack=(rr,gg,bb),proc=WC_UpdateAfterSetVarChange,title="Vclamp:"
		SetVariable SealTestAmp_VSetVar,limits={-Inf,Inf,0.001},value= root:MP:SealTestAmp_V
		
	else

		DoWindow/F MultiPatch_WaveCreator
		KillControl SealTestAmp_ISetVar
		KillControl SealTestAmp_VSetVar
		KillControl SealTestDurSetVar
		KillControl SealTestPad1SetVar
		KillControl SealTestPad2SetVar

	endif

EndMacro

//////////////////////////////////////////////////////////////////////////////////
//// If the wave type is extracellular, then this function toggles the stimulus between biphasic
//// and monophasic

Function WC_ToggleBiphasic(ctrlName,Checked) : CheckBoxControl
	String ctrlName
	Variable Checked

	String CommandStr

	NVAR ShowFlag = 			root:MP:ShowFlag					// Show the wave as the user creates it?
	NVAR ChannelNumber = 		root:MP:ChannelNumber				// Wave number
	NVAR SlotNumber = 		root:MP:SlotNumber				// Slot number
	NVAR BiphasicFlag = 		root:MP:BiphasicFlag				// Biphasic flag
	WAVE BiphasicFlagWave = 	root:MP:IO_Data:BiphasicFlag		// Same, setting for each channel
	
	ControlInfo/W=MultiPatch_WaveCreator BiphasicCheck			// Want biphasic stimulus?
	BiphasicFlag = V_value											// Update current (displayed) setting
	BiphasicFlagWave[ChannelNumber-1][SlotNumber-1] = BiphasicFlag	// Update background setting for channel & slot in question

	ControlUpdate/A/W=MultiPatch_WaveCreator

	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////
//// Remove extracellular stim artifacts of traces in top graph

Function WC_MakeBiExpPanel()

	Variable	linH = 22

	Variable	ScSc = 72/ScreenResolution				// Screen resolution
	
	Variable	xPos = 100
	Variable	yPos = 60
	Variable	Width = 260
	Variable	Height = 32//+linH*9+4

	NVAR		tau1 = root:MP:SynapseTau1	// Rising phase tau of biexponential [ms]
	NVAR		tau2 = root:MP:SynapseTau2	// Falling phase tau of biexponential [ms]

	DoWindow/K BiExpPanel
	NewPanel /W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc)
	DoWindow/C BiExpPanel
	SetDrawLayer UserBack
	SetDrawEnv fsize= 14,fstyle= 1+4,textxjust= 1,textyjust= 2
	DrawText Width/2,6,"Settings for Biexponentials"
	
	Variable	ySkip = 32
	SetVariable Tau1SetVar,pos={4+Width*0/2,ySkip},size={Width/2-4,18},title="Tau 1 [ms]:",proc=WC_UpdateAfterSetVarChange
	SetVariable Tau1SetVar,limits={0,Inf,0.1},value=root:MP:SynapseTau1
	SetVariable Tau2SetVar,pos={4+Width*1/2,ySkip},size={Width/2-4,18},title="Tau 2 [ms]:",proc=WC_UpdateAfterSetVarChange
	SetVariable Tau2SetVar,limits={0,Inf,1},value=root:MP:SynapseTau2
	ySkip += linH
	Button KillPanelButton,pos={4,ySkip},size={Width-4,18},title="Close this panel",fColor=(65535,65535/2,65535/2),proc=WC_CloseBiExpPanel
	ySkip += linH

	Height = ySkip+4
	MoveWindow/W=BiExpPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc		// Adjust panel size based on number of controls added to it...

End

Function WC_CloseBiExpPanel(ctrlName) : ButtonControl
	String ctrlName

	DoWindow/K BiExpPanel

End

//////////////////////////////////////////////////////////////////////////////////
//// This toggles whether the current slot contains pulses or synapse-like biexponentials

Function WC_ToggleSynapseSlot(ctrlName,Checked) : CheckBoxControl
	String		ctrlName
	Variable	Checked

	NVAR	ShowFlag = 				root:MP:ShowFlag				// Show the wave as the user creates it?

	NVAR	SynapseSlotFlag = 		root:MP:SynapseSlotFlag			// Is this slot biexp? (otherwise pulse)
	WAVE	SynapseSlotWave = 		root:MP:IO_Data:SynapseSlotWave	// Same, store away
	NVAR	ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR	SlotNumber =			root:MP:SlotNumber			// Slot number

	Variable Keys = GetKeyState(0)
	if (Keys & 2^2)
		Print "\tYou pressed the Shift key -- Bringing up the settings panel for biexponentials."
		WC_ToggleSlotOnDisplay()
		WC_MakeBiExpPanel()
	else
		SynapseSlotFlag = Checked
		SynapseSlotWave[ChannelNumber-1][SlotNumber-1] = SynapseSlotFlag
		//// Show the wave?
		if (ShowFlag)
			WC_ShowWave(ChannelNumber)
		endif
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// This toggles whether the current slot is an additive slot or an absolute slot

Function WC_ToggleAddSlot(ctrlName,Checked) : CheckBoxControl
	String ctrlName
	Variable Checked

	NVAR	ShowFlag = 				root:MP:ShowFlag				// Show the wave as the user creates it?

	NVAR	AddSlotFlag = 			root:MP:AddSlotFlag				// Is this slot additive? (otherwise absolute)
	WAVE	AddSlotWave = 			root:MP:IO_Data:AddSlotWave	// Same, store away
	NVAR	ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR	SlotNumber =			root:MP:SlotNumber			// Slot number

	AddSlotFlag = Checked
	AddSlotWave[ChannelNumber-1][SlotNumber-1] = AddSlotFlag

	//// Show the wave?
	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// This toggles whether the current slot is a ramp or a pulse

Function WC_ToggleRampSlot(ctrlName,Checked) : CheckBoxControl
	String ctrlName
	Variable Checked

	NVAR	ShowFlag = 				root:MP:ShowFlag				// Show the wave as the user creates it?

	NVAR	RampFlag = 			root:MP:RampFlag				// Is this slot a ramp? (otherwise pulse)
	WAVE	RampWave = 			root:MP:IO_Data:RampWave		// Same, store away
	NVAR	ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR	SlotNumber =			root:MP:SlotNumber			// Slot number

	RampFlag = Checked
	RampWave[ChannelNumber-1][SlotNumber-1] = RampFlag

	//// Show the wave?
	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// This toggles whether the current slot is being used

Function WC_ToggleUseSlot(ctrlName,Checked) : CheckBoxControl
	String ctrlName
	Variable Checked

	NVAR	ShowFlag = 				root:MP:ShowFlag				// Show the wave as the user creates it?

	NVAR	UseSlotFlag = 			root:MP:UseSlotFlag				// Use this slot?
	WAVE	UseSlotWave = 			root:MP:IO_Data:UseSlotWave	// Same, store away
	NVAR	ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR	SlotNumber =			root:MP:SlotNumber			// Slot number
	
	UseSlotFlag = Checked
	UseSlotWave[ChannelNumber-1][SlotNumber-1] = UseSlotFlag

	//// Show the wave?
	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// This just toggles whether the wave should be shown or not, as parameters are being selected

Function WC_ToggleShow(ctrlName,Checked) : CheckBoxControl
	String ctrlName
	Variable Checked

	String CommandStr

	NVAR ChannelNumber = 		root:MP:ChannelNumber			// Wave number
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?

	ShowFlag = checked
	
	ControlUpdate/A/W=MultiPatch_WaveCreator

	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	else
		WC_RemoveOutputWaveGraph(1)
		WC_RemoveOutputWaveGraph(2)
		WC_RemoveOutputWaveGraph(3)
		WC_RemoveOutputWaveGraph(4)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Short function needed to update the graph window when a SetVar is altered, 
//// if the show flag is active

Function WC_UpdateAfterSetVarChange(STRUCT WMSetVariableAction &s) : SetVariableControl

	if (s.eventcode == 1 || s.eventcode == 2)
		WC_DoUpdateAfterSetVarChange()
	endif

End

Function WC_DoUpdateAfterSetVarChange()
	
	String CommandStr

	NVAR SampleFreq = 			root:MP:SampleFreq				// Sampling frequency [Hz]
	NVAR TotalDur = 			root:MP:TotalDur				// Total wave duration [ms]
	NVAR SealTestDur = 		root:MP:SealTestDur			// Seal test duration [ms]
	NVAR SealTestPad1 = 		root:MP:SealTestPad1			// Seal test padding, before
	NVAR SealTestPad2 = 		root:MP:SealTestPad2			// Seal test padding, after
	NVAR SealTestAmp_I = 		root:MP:SealTestAmp_I			// Seal test amplitude i clamp [nA]
	NVAR SealTestAmp_V = 		root:MP:SealTestAmp_V			// Seal test amplitude v clamp [nA]
	NVAR SealTestFlag = 		root:MP:SealTestFlag			// Seal test flag

	NVAR ChannelNumber =		root:MP:ChannelNumber			// Wave number
	NVAR SlotNumber =			root:MP:SlotNumber			// Slot number
	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 			root:MP:PulseDispl				// Pulse displacement
	NVAR CommandLevel = 		root:MP:CommandLevel			// constant holding current/volt Command Level // 3/30/00 KM

	WAVE PulseAmpWave = 		root:MP:IO_Data:PulseAmp		// Stored dittos
	WAVE ChannelTypeWave = 	root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 		root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 		root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 		root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 	root:MP:IO_Data:PulseDispl
	WAVE CommandLevelWave = 	root:MP:IO_Data:CommandLevel  // 3/30/00 KM

	WAVE/T WaveNamesOutWave =	root:MP:IO_Data:WaveNamesOutWave
	SVAR CurrWaveNameOut =		root:MP:CurrWaveNameOut

	//// Save potentially just altered data
	ControlInfo/W=MultiPatch_WaveCreator SampleFreqSetVar
	SampleFreq = V_value
	ControlInfo/W=MultiPatch_WaveCreator DurationSetVar
	TotalDur = V_value

	ControlInfo/W=MultiPatch_WaveCreator SealTestCheck		// Want seal test at beginning of wave?
	SealTestFlag = V_value

	if (SealTestFlag==1)
		ControlInfo/W=MultiPatch_WaveCreator SealTestDurSetVar
		SealTestDur = V_value

		ControlInfo/W=MultiPatch_WaveCreator SealTestPad1SetVar
		SealTestPad1 = V_value
		ControlInfo/W=MultiPatch_WaveCreator SealTestPad2SetVar
		SealTestPad2 = V_value

		ControlInfo/W=MultiPatch_WaveCreator SealTestAmp_ISetVar	
		SealTestAmp_I = V_value

		ControlInfo/W=MultiPatch_WaveCreator SealTestAmp_VSetVar	
		SealTestAmp_V = V_value

	endif

	ControlInfo/W=MultiPatch_WaveCreator NPulsesSetVar
	NPulses = V_value
	NPulsesWave[ChannelNumber-1][SlotNumber-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator PulseAmpSetVar
	PulseAmp = V_value
	PulseAmpWave[ChannelNumber-1][SlotNumber-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator PulseDurSetVar
	PulseDur = V_value
	PulseDurWave[ChannelNumber-1][SlotNumber-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator PulseFreqSetVar
	PulseFreq = V_value
	PulseFreqWave[ChannelNumber-1][SlotNumber-1] = V_value
	ControlInfo/W=MultiPatch_WaveCreator DisplacedSetVar
	PulseDispl = V_value
	PulseDisplWave[ChannelNumber-1][SlotNumber-1] = V_value
	CommandStr = "root:MP:IO_Data:WaveNamesOut"+num2str(ChannelNumber)+" = root:MP:CurrWaveNameOut"
	Execute CommandStr
	ControlInfo/W=MultiPatch_WaveCreator CommandLevelSetVar		//  3/30/00 KM
	CommandLevel = V_value
	CommandLevelWave[ChannelNumber-1] = V_value

	WaveNamesOutWave[ChannelNumber-1] = CurrWaveNameOut

	if (ShowFlag)
		WC_ShowWave(ChannelNumber)
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// This function takes the wave descriptor on channel 'ChannelNumber' and produces the complete
//// output wave from it.

Function WC_Descriptor2Wave(WaveName,ChannelNumber)
	String		WaveName
	Variable	ChannelNumber
	
	Variable	AddTime = 0
	Variable	AddTimeStore = 0
	Variable	i

	NVAR	NSlots =				root:MP:IO_Data:NSlots			// Total number of slots
	WAVE	AddSlotWave = 			root:MP:IO_Data:AddSlotWave	// Is slot additive?
	WAVE	RampWave = 			root:MP:IO_Data:RampWave		// Is slot a ramp?
	WAVE	SynapseSlotWave = 		root:MP:IO_Data:SynapseSlotWave	// Is slot a biexponential?
	WAVE	UseSlotWave = 			root:MP:IO_Data:UseSlotWave	// Use this slot?
	
	NVAR SampleFreq = 			root:MP:SampleFreq				// Sampling frequency [Hz]
	NVAR TotalDur = 			root:MP:TotalDur				// Total wave duration [ms]
	NVAR SealTestDur = 		root:MP:SealTestDur			// Seal test duration [ms]
	NVAR SealTestPad1 = 		root:MP:SealTestPad1			// Seal test padding, before
	NVAR SealTestPad2 = 		root:MP:SealTestPad2			// Seal test padding, after
	NVAR SealTestAmp_I = 		root:MP:SealTestAmp_I			// Seal test amplitude i clamp [nA]
	NVAR SealTestAmp_V = 		root:MP:SealTestAmp_V			// Seal test amplitude v clamp [nA]
	NVAR SealTestFlag = 		root:MP:SealTestFlag			// Seal test flag
	NVAR ST_SealTestAtEnd =	root:MP:ST_Data:ST_SealTestAtEnd	// Add test pulse at end?

	NVAR ShowFlag = 			root:MP:ShowFlag				// Show the wave as the user creates it?
	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 			root:MP:PulseDispl				// Pulse displacement
	NVAR CommandLevel = 		root:MP:CommandLevel			// constant holding current/volt Command Level // 3/30/00 KM

	WAVE PulseAmpWave = 			root:MP:IO_Data:PulseAmp		// Stored dittos
	WAVE ChannelTypeWave =	 	root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 			root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 			root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 			root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 		root:MP:IO_Data:PulseDispl
	WAVE BiphasicFlagWave =		root:MP:IO_Data:BiphasicFlag	
	WAVE CommandLevelWave = 	root:MP:IO_Data:CommandLevel

	ProduceWave(WaveName,SampleFreq,TotalDur)

	if (SealTestFlag)
		if (ST_SealTestAtEnd)
			if (ChannelTypeWave[ChannelNumber-1]==1)			// Sealtest for intracellular wave in current clamp
				ProducePulses(WaveName,TotalDur-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
			endif
			if (ChannelTypeWave[ChannelNumber-1]==3)			// Sealtest for intracellular wave in voltage clamp
				ProducePulses(WaveName,TotalDur-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
			endif
			AddTime = 0
		else
			if (ChannelTypeWave[ChannelNumber-1]==1)			// Sealtest for intracellular wave in current clamp
				ProducePulses(WaveName,SealTestPad1,1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
			endif
			if (ChannelTypeWave[ChannelNumber-1]==3)			// Sealtest for intracellular wave in voltage clamp
				ProducePulses(WaveName,SealTestPad1,1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
			endif
			AddTime = SealTestPad1+SealTestDur+SealTestPad2
		endif
	else
		AddTime = 0
	endif

	AddTimeStore = AddTime
	i = 0
	do															// Process each slot --> i equals slot number minus one
		if (UseSlotWave[ChannelNumber-1][i])
			AddTime = AddTimeStore
			AddTime += PulseDisplWave[ChannelNumber-1][i]
			if (NPulsesWave[ChannelNumber-1][i]!=0)
				if ( (ChannelTypeWave[ChannelNumber-1]==1) %| (ChannelTypeWave[ChannelNumber-1]==3) )		// Intracellular current clamp or voltage clamp
					ProducePulses(WaveName,AddTime,NPulsesWave[ChannelNumber-1][i],PulseDurWave[ChannelNumber-1][i],PulseFreqWave[ChannelNumber-1][i],PulseAmpWave[ChannelNumber-1][i],AddSlotWave[ChannelNumber-1][i],0,SynapseSlotWave[ChannelNumber-1][i],RampWave[ChannelNumber-1][i])
				endif
				if (ChannelTypeWave[ChannelNumber-1]==2)															// Extracellular
					ProducePulses(WaveName,AddTime,NPulsesWave[ChannelNumber-1][i],(PulseDurWave[ChannelNumber-1][i]-1)/SampleFreq*1000,PulseFreqWave[ChannelNumber-1][i],PulseAmpWave[ChannelNumber-1][i],AddSlotWave[ChannelNumber-1][i],0,0,0)
					if (BiphasicFlagWave[ChannelNumber-1][i])
						ProducePulses(WaveName,AddTime+(PulseDurWave[ChannelNumber-1][i]-0)/SampleFreq*1000,NPulsesWave[ChannelNumber-1][i],(PulseDurWave[ChannelNumber-1][i]-1)/SampleFreq*1000,PulseFreqWave[ChannelNumber-1][i],-PulseAmpWave[ChannelNumber-1][i],AddSlotWave[ChannelNumber-1][i],0,0,0)
					endif
				endif
			endif
		endif

		i += 1
	while (i<NSlots)
	
	WAVE	w = $WaveName
	w += CommandLevelWave[ChannelNumber-1]
	w[numpnts(w)-1]=0											// Correct for the nasty bug reported by Kate (only pertains to NI boards?)

End

//////////////////////////////////////////////////////////////////////////////////
//// This function shows the wave as the parameters are being selected.

Function WC_ShowWave(ChannelNumber)
	Variable	ChannelNumber
	
	String		UnitsStr = ""
	
	WAVE 		ChannelTypeWave =	 	root:MP:IO_Data:ChannelType

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	WC_Descriptor2Wave("MP_ShowWave",ChannelNumber)							// Produce the complete wave

	if (ChannelTypeWave[ChannelNumber-1] == 1)
		UnitsStr = "nA"
	endif
	if (ChannelTypeWave[ChannelNumber-1] == 2)
		UnitsStr = "V"
	endif
	if (ChannelTypeWave[ChannelNumber-1] == 3)
		UnitsStr = "V"
	endif
	ProduceUnitsOnYAxis("MP_ShowWave",UnitsStr)									// Add units to the y axis

	WC_RemoveOutputWaveGraph(1)													// Remove all old graphs showing output waves
	WC_RemoveOutputWaveGraph(2)
	WC_RemoveOutputWaveGraph(3)
	WC_RemoveOutputWaveGraph(4)

	WC_DisplayOutputWaveGraph(ChannelNumber,1,1)									// Display this output wave
	
	ModifyGraph RGB(MP_ShowWave)=(ChannelColor_R[ChannelNumber-1],ChannelColor_G[ChannelNumber-1],ChannelColor_B[ChannelNumber-1])
	
	DoWindow/F MultiPatch_WaveCreator												// Put the wave creator panel in front

End

//////////////////////////////////////////////////////////////////////////////////
//// Remove the graph that corresponds to the output wave of the number that is passed as an
//// argument.
//// The passed argument 'PrevChan' should range 1 through 4.

Function WC_RemoveOutputWaveGraph(Channel)
	Variable		Channel
	
	String	GraphName
	
	SVAR	GraphBaseName = 	root:MP:GraphBaseName
	
	GraphName = GraphBaseName+num2str(Channel)							// Create graph name
	DoWindow/K $GraphName													// Kill previous graph

End

//////////////////////////////////////////////////////////////////////////////////
//// Display the output wave of the number that is passed as an argument.
//// The passed argument 'Number' should range 1 through 4.
//// The argument 'WhereFlag' signals whether one or several graphs are to be displayed, which, in
//// turn, affects the position of the current graph to be generated.
//// *** Change: 'WhichFlag' = 1 means that the wave 'MP_ShowWave' will be displayed. 2/23/00 J.Sj. ***

Function WC_DisplayOutputWaveGraph(Number,WhereFlag,WhichFlag)
	Variable Number,WhereFlag,WhichFlag

	Variable		G_X = 32// 675-140						// Graph position, X
	Variable		G_Y = 150						// Graph position, Y	
	Variable		G_Width = 340					// Width of graph windows
	Variable		G_Height = 120					// Height of graph windows
	Variable		G_Y_Grout = 32				// Y spacing for graph windows
	
	String			LegendStr = ""					// Text in legend
	String			CommandStr = ""				// Use with execute
	String			WaveName						// The name of the wave to be displayed
	String			GraphName = ""					// Name of the graph window

	WAVE/T	WaveNamesOutWave =	root:MP:IO_Data:WaveNamesOutWave
	SVAR		STSuffix =				root:MP:IO_Data:STSuffix
	
	SVAR		GraphBaseName =		root:MP:GraphBaseName
	
	WAVE		OutputOnOff =			root:MP:IO_Data:OutputOnOff
	WAVE		ChannelType =			root:MP:IO_Data:ChannelType
	
	if (WhereFlag)																		// A single graph to be displayed --> reposition it
		G_X = 32//558
		G_Y = 488+32+24
		G_Width = 400
		G_Height = 160
		G_Y_Grout = -G_Height
	endif
	
	Number -= 1																		// Change indexing notation for the below lines of code
	GraphName = GraphBaseName+num2str(Number+1)								// Create graph name

	//// Create the wave name
	WaveName = WaveNamesOutWave[Number]	
	ControlInfo/W=MultiPatch_WaveCreator STCheck									// Is this a SpikeTiming wave or not?
	if (V_value)
		WaveName += STSuffix															// If so, add the appropriate suffix to the wave
	endif
	LegendStr = WaveName																// Make legend string
	if (WhichFlag)
		WaveName = "MP_ShowWave"													// Display "un-created" wave -- this should override the above lines (but not for the legend)
	endif

	if (OutputOnOff[Number]!=1)
		LegendStr += " {not used}"
	endif
	
	DisplayOneWave(WaveName,GraphName,"",LegendStr,G_X,G_Y+(G_Height+G_Y_Grout)*Number,G_Width,G_Height)

	//  Bound axis to zero, so that one can see small offsets from 0 due to CommandLevel.
	GetAxis/Q left
	if (V_min>0)
		setAxis left 0,V_max
	endif
	if (V_max<0)
		setAxis left V_min,0
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// This function makes some notes for the below two macros, describing the general parameters
//// for the wave creation.

Function WC_BasicNotesForWaveCreation(SecondLineString)
	String		SecondLineString

	NVAR SampleFreq = 			root:MP:SampleFreq				// Sampling frequency [Hz]
	NVAR TotalDur = 			root:MP:TotalDur				// Total wave duration [ms]
	NVAR SealTestDur = 		root:MP:SealTestDur			// Seal test duration [ms]
	NVAR SealTestPad1 = 		root:MP:SealTestPad1			// Seal test padding, before
	NVAR SealTestPad2 = 		root:MP:SealTestPad2			// Seal test padding, after
	NVAR SealTestAmp_I = 		root:MP:SealTestAmp_I			// Seal test amplitude i clamp [nA]
	NVAR SealTestAmp_V = 		root:MP:SealTestAmp_V			// Seal test amplitude v clamp [nA]
	NVAR SealTestFlag = 		root:MP:SealTestFlag			// Seal test flag
	NVAR ST_SealTestAtEnd =	root:MP:ST_Data:ST_SealTestAtEnd
	NVAR	CreateAppendsFlag = root:MP:CreateAppendsFlag		// Boolean: Wave creation appends to previously existing waves

	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Creating new stimulus waves\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\t"+SecondLineString+"\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+"\r\r"
	
	Notebook Parameter_Log ruler=Normal, text="\tGeneral parameters\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSample frequency:\t"+num2str(SampleFreq)+"\tHz\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tTotal wave duration:\t"+num2str(TotalDur)+"\tms\r"
	if (CreateAppendsFlag)
		Notebook Parameter_Log ruler=TextRow, text="\t\tAppended to previous wave:\tYes\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tAppended to previous wave:\tNo\r"
	endif
	if (SealTestFlag)
		Notebook Parameter_Log ruler=TextRow, text="\t\tTest pulse? \tYes\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tTest pulse duration:\t"+num2str(SealTestDur)+"\tms\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tTest pulse pad before:\t"+num2str(SealTestPad1)+"\tms\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tTest pulse pad after:\t"+num2str(SealTestPad2)+"\tms\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tTest pulse amplitude (I-clamp):\t"+num2str(SealTestAmp_I)+"\tnA\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tTest pulse amplitude (V-clamp):\t"+num2str(SealTestAmp_V)+"\tV\r"
		if (ST_SealTestAtEnd)
			Notebook Parameter_Log ruler=TextRow, text="\t\tTest pulse at end? \tYes\r"
		else
			Notebook Parameter_Log ruler=TextRow, text="\t\tTest pulse at end? \tNo\r"
		endif
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tTest pulse?\tNo\r"
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// This function takes down detailed notes about the parameters for the individual channels

Function WC_DetailedNotesForWaveCreation(WaveName,ChannelNumber)
	String		WaveName
	Variable	ChannelNumber
	
	String		CommandStr
	String		WorkStr
	Variable	i
	
	NVAR	NSlots =			root:MP:IO_Data:NSlots			// Total number of slots

	WAVE PulseAmpWave = 		root:MP:IO_Data:PulseAmp		// Stored dittos
	WAVE ChannelTypeWave = 	root:MP:IO_Data:ChannelType
	WAVE NPulsesWave = 		root:MP:IO_Data:NPulses
	WAVE PulseDurWave = 		root:MP:IO_Data:PulseDur
	WAVE PulseFreqWave = 		root:MP:IO_Data:PulseFreq
	WAVE PulseDisplWave = 	root:MP:IO_Data:PulseDispl
	WAVE BiphasicFlagWave =	root:MP:IO_Data:BiphasicFlag	
	WAVE CommandLevelWave =	root:MP:IO_Data:CommandLevel	// 3/30/00 KM
	WAVE OutputOnOff =			root:MP:IO_Data:OutputOnOff	// Update the output checkbox

	WAVE UseSlotWave = 		root:MP:IO_Data:UseSlotWave	// Use this slot? [Channel][Slot]
	WAVE AddSlotWave = 		root:MP:IO_Data:AddSlotWave	// Is slot additive (or absolute)? [Channel][Slot]
	WAVE RampWave = 			root:MP:IO_Data:RampWave		// Is slot ramp or pulse? [Channel][Slot]
	WAVE SynapseSlotWave = 	root:MP:IO_Data:SynapseSlotWave	// Biexponential slot, or a pulse? [Channel][Slot]

	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Normal, text="\r\tChannel #"+num2str(ChannelNumber)+"\r"
	Notebook Parameter_Log ruler=TextRow, text="\t\tWave name:\t"+WaveName+"\r"

	if (ChannelTypeWave[ChannelNumber-1]==1)
		Notebook Parameter_Log ruler=TextRow, text="\t\tType:\tIntracellular\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tType:\tExtracellular\r"
	endif
	Notebook Parameter_Log ruler=Normal, text="\t\tNumber of pulses:\r"
	WorkStr = ""
	i = 0
	do
		WorkStr += num2str(NPulsesWave[ChannelNumber-1][i])
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	if (ChannelTypeWave[ChannelNumber-1]==1)
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude:\t\tnA\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude:\t\tV\r"
	endif
	WorkStr = ""
	i = 0
	do
		WorkStr += num2str(PulseAmpWave[ChannelNumber-1][i])
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	if (ChannelTypeWave[ChannelNumber-1]==1)
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration:\t\tms\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration:\t\tsamples\r"
	endif
	WorkStr = ""
	i = 0
	do
		WorkStr += num2str(PulseDurWave[ChannelNumber-1][i])
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	Notebook Parameter_Log ruler=Normal, text="\t\tPulse frequency:\t\tHz\r"
	WorkStr = ""
	i = 0
	do
		WorkStr += num2str(PulseFreqWave[ChannelNumber-1][i])
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	Notebook Parameter_Log ruler=Normal, text="\t\tDisplaced rel. origin:\t\tms\r"
	WorkStr = ""
	i = 0
	do
		WorkStr += num2str(PulseDisplWave[ChannelNumber-1][i])
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	if (ChannelTypeWave[ChannelNumber-1]==1)
		Notebook Parameter_Log ruler=Normal, text="\t\tCommand level:\t"+num2str(CommandLevelWave[ChannelNumber-1])+"\tnA\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tCommand level:\t"+num2str(CommandLevelWave[ChannelNumber-1])+"\tV\r"
	endif

	if (OutputOnOff[ChannelNumber-1])
		Notebook Parameter_Log ruler=TextRow, text="\t\tIs output channel used?\tYes\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tIs this output channel used?\tNo\r"
	endif
	
	Notebook Parameter_Log ruler=TextRow, text="\t\tIs slot additive or absolute?\r"
	WorkStr = ""
	i = 0
	do
		if (AddSlotWave[ChannelNumber-1][i])
			WorkStr += "Add"
		else
			WorkStr += "Abs"
		endif
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	Notebook Parameter_Log ruler=TextRow, text="\t\tIs slot a ramp or a pulse?\r"
	WorkStr = ""
	i = 0
	do
		if (RampWave[ChannelNumber-1][i])
			WorkStr += "Rmp"
		else
			WorkStr += "Pls"
		endif
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	Notebook Parameter_Log ruler=TextRow, text="\t\tDoes slot contain pulses or biexponential (EPSP-like) shapes?\r"
	WorkStr = ""
	i = 0
	do
		if (SynapseSlotWave[ChannelNumber-1][i])
			WorkStr += "Biexp"
		else
			WorkStr += "Pulse"
		endif
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	Notebook Parameter_Log ruler=TextRow, text="\t\tIs slot used?\r"
	WorkStr = ""
	i = 0
	do
		if (UseSlotWave[ChannelNumber-1][i])
			WorkStr += "Yes"
		else
			WorkStr += "No"
		endif
		if (i!=NSlots-1)
			WorkStr += "\t"
		endif
		i += 1
	while (i<NSlots)
	Notebook Parameter_Log ruler=SlotTabRow, text="\t\t"+WorkStr+"\r"

	CommandStr = "Notebook Parameter_Log ruler=Normal, text=\"\\t\\tScaled by division with output gain:\\t\"+num2str(root:MP:IO_Data:OutGain"+num2str(ChannelNumber)+")+\"\\r\\r\""
	Execute CommandStr

End

//////////////////////////////////////////////////////////////////////////////////
//// This macro creates one of the output waves and makes a notebook saving the data describing
//// the wave.

Function WC_CreateOneWave(ctrlName) : ButtonControl
	String ctrlName

	NVAR		ChannelNumber =		root:MP:ChannelNumber
	NVAR		SlotNumber =			root:MP:SlotNumber			// Slot number
	NVAR		ShowFlag =				root:MP:ShowFlag

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B
	
	String		currWave

	WC_ReadWaveCreatorDataAndStore(ChannelNumber,SlotNumber)												// Read the WaveCreator panel data first
	print Time() + ": Creating the wave for channel "+num2str(ChannelNumber)+"."
	WC_BasicNotesForWaveCreation("Generating new stimulus wave for channel "+num2str(ChannelNumber)+".")	// Take general notes
	WC_DoCreateOutputWave(ChannelNumber)																		// Create the wave, take notes about it, and show it, if desired
	if ((ShowFlag) %& (!(StringMatch("DummyControlName",ctrlName))))
		WC_RemoveOutputWaveGraph(1)																			// Remove old create-graphs, if any
		WC_RemoveOutputWaveGraph(2)
		WC_RemoveOutputWaveGraph(3)
		WC_RemoveOutputWaveGraph(4)
		WC_DisplayOutputWaveGraph(ChannelNumber,1,0)															// Display the wave, if desired
		currWave = StringFromList(0,WaveList("*",";","WIN:"))
		ModifyGraph RGB($(currWave))=(ChannelColor_R[ChannelNumber-1],ChannelColor_G[ChannelNumber-1],ChannelColor_B[ChannelNumber-1])
	endif
	Notebook Parameter_Log ruler=Normal, text="\r"
	print Time() + ": Wave for channel "+num2str(ChannelNumber)+" created."
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Kill the WaveCreator panel

Function WC_KillWCPanel(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		ChannelNumber =		root:MP:ChannelNumber
	NVAR		SlotNumber =			root:MP:SlotNumber			// Slot number

	WC_ReadWaveCreatorDataAndStore(ChannelNumber,SlotNumber)
	DoWindow/K MultiPatch_WaveCreator																		// Kill the WC panel
	WC_RemoveOutputWaveGraph(1)																			// Remove all old graphs showing output waves
	WC_RemoveOutputWaveGraph(2)
	WC_RemoveOutputWaveGraph(3)
	WC_RemoveOutputWaveGraph(4)
	DoWindow/K WC_RangeGraph

end
	
//////////////////////////////////////////////////////////////////////////////////
//// This takes the waves in WC_RangeGraph and duplicates them to waves
//// named Out_x_ST_1, Out_x_ST_2, etc., to enable usage with the cycling of
//// waves function in the ST_Creator

Function WC_AdaptForCycling(ctrlName) : ButtonControl
	String ctrlName

	DoWindow/F WC_RangeGraph
	
	String		ListOfWaves = WaveList("*",";","WIN:")
	Variable	n = ItemsInList(ListOfWaves)
	Variable	i
	
	String		currWave
	String		targetWave

	//// FROM WAVE CREATOR
	NVAR ChannelNumber = 		root:MP:ChannelNumber				// Current channel

	//// GENERAL
	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves

	Variable	nDigs = 1											// Number of digits in the suffix number appended at the end of the waves
	
	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Adapting waves for cycling pattern\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+"\r\r"
	
	i = 0
	do
		currWave = StringFromList(i,ListOfWaves)
		targetWave = ST_BaseName+num2str(ChannelNumber)+ST_Suffix+"_"+JS_num2digstr(nDigs,i+1)
		Print i+1,"\tTaking the wave \""+currWave+"\" and duplicating it to \""+targetWave+"\""
		Notebook Parameter_Log ruler=Normal, text="\tDuplicating \""+currWave+"\" to \""+targetWave+"\"\r"
		Duplicate/O $currWave,$targetWave
		i += 1
	while (i<n)
	Notebook Parameter_Log ruler=Normal, text="\r"

End

//////////////////////////////////////////////////////////////////////////////////
//// This macro creates the waves and makes a notebook saving the data describing the waves.

Function WC_CreateOutputWaves(ctrlName) : ButtonControl
	String ctrlName
	
	Variable		j
	
	NVAR		ChannelNumber =		root:MP:ChannelNumber
	NVAR		SlotNumber =			root:MP:SlotNumber			// Slot number
	NVAR		ShowFlag =				root:MP:ShowFlag

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	print Time() + ": Creating the output waves."
	WC_ReadWaveCreatorDataAndStore(ChannelNumber,SlotNumber)											// Read the WaveCreator panel data for current channel
	WC_BasicNotesForWaveCreation("Generating new stimulus waves.")										// Take general notes
	String		currWave
	j = 0
	do
		WC_DoCreateOutputWave(j+1)																			// Create one wave at a time
		if (ShowFlag)
			WC_DisplayOutputWaveGraph(j+1,0,0)															// Display the wave, if desired
//			Legend/C/N=text0/J/B=(ChannelColor_R[j],ChannelColor_G[j],ChannelColor_B[j])
			currWave = StringFromList(0,WaveList("*",";", "WIN:"))										// I know there is only one trace per graph, so this is allowed
			ModifyGraph RGB($(currWave)) = (ChannelColor_R[j],ChannelColor_G[j],ChannelColor_B[j])
		endif
		j += 1
	while (j<4)

	Notebook Parameter_Log ruler=Normal, text="\r"
	print Time() + ": Waves created."
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Do the actual work for the above macros.

Function WC_DoCreateOutputWave(ChannelNumber)
	Variable		ChannelNumber		// ChannelNumber, 1 through 4

	String			WaveName			// Remember the wave name
	
	WAVE/T	WaveNamesOutWave =	root:MP:IO_Data:WaveNamesOutWave
	SVAR		STSuffix =				root:MP:IO_Data:STSuffix
	NVAR		CreateAppendsFlag = 	root:MP:CreateAppendsFlag				// Boolean: Wave creation appends to previously existing waves

	WaveName = WaveNamesOutWave[ChannelNumber-1]
	ControlInfo/W=MultiPatch_WaveCreator STCheck							// Is this a SpikeTiming wave or not?
	if (V_value)
		WaveName += STSuffix													// If so, add the appropriate suffix to the wave
	endif

	WC_DetailedNotesForWaveCreation(WaveName,ChannelNumber)				// Take detailed notes about this channel
	if (CreateAppendsFlag)
		Duplicate/O $WaveName,ConcatTempWave
	endif
	WC_Descriptor2Wave(WaveName,ChannelNumber)							// Produce the complete wave
	ProduceScaledWave(WaveName,ChannelNumber,0)							// Scale this wave according to the gain so that it is ready to be used (zero -> read mode from WaveCreator)
	if (CreateAppendsFlag)
		WAVE	CurrWave = $WaveName
		InsertPoints 0,numpnts(ConcatTempWave),CurrWave
		CurrWave[0,numpnts(ConcatTempWave)-1] = ConcatTempWave[p]
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Zoom in on spikes in acquired waves window

Function ZoomSpike(ctrlName) : ButtonControl
	String ctrlName
	
	//// INDUCTION
	NVAR	Ind_ConcatFlag =	root:MP:ST_Data:Ind_ConcatFlag		// Boolean: Concatenate induction wave with a previously existing induction wave
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1	// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// BASELINE
	NVAR	Base_Spacing =	 	root:MP:ST_Data:Base_Spacing		// The spacing between the pulses in the baseline [ms]
	NVAR	Base_Freq = 		root:MP:ST_Data:Base_Freq			// The frequency of the pulses [Hz]
	NVAR	Base_NPulses = 	root:MP:ST_Data:Base_NPulses		// The number of pulses for each channel during the baseline
	NVAR	Base_WaveLength =	root:MP:ST_Data:Base_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Base_Recovery =	root:MP:ST_Data:Base_Recovery		// Boolean: Recovery pulse?
	NVAR	Base_RecoveryPos =root:MP:ST_Data:Base_RecoveryPos	// Position of recovery pulse relative to end of train [ms]
	NVAR	Base_AmplitudeIClamp = root:MP:ST_Data:Base_AmplitudeIClamp	// The pulse amplitude for baseline current clamp pulses [nA]
	NVAR	Base_DurationIClamp = 	root:MP:ST_Data:Base_DurationIClamp		// The pulse duration for baseline current clamp pulses [ms]
	
	NVAR	ST_SealTestAtEnd =	root:MP:ST_Data:ST_SealTestAtEnd
	NVAR	Base_Sealtest =		root:MP:ST_Data:Base_Sealtest

	NVAR	ST_StartPad = 		root:MP:ST_Data:ST_StartPad		// The padding at the start of the waves [ms]
	
	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V
	
	Variable Origin = ST_StartPad+SealTestPad1+SealTestDur+SealTestPad2
	if ((ST_SealTestAtEnd) %| (!Base_Sealtest))
		Origin = ST_StartPad
	endif
	Variable Spacing,SpikeStart,SpikeEnd
	Variable	Padding = 2

	Variable Keys = GetKeyState(0)
	if (Keys & 2^2)			// If holding shift key, also do Auto y axis in combination with whatever else is chosen
		SetAxis/A left
	endif

	Variable	SpikeNo = str2num(ctrlName[2,2])
	DoWindow/F MultiPatch_ShowInputs
	if (V_flag)
		Spacing = Base_Spacing + (Base_NPulses-1)*1000/Base_Freq
		if (Base_Recovery)
			Spacing += Base_RecoveryPos 
		endif
		SpikeStart = (Origin+Spacing*(SpikeNo-1)-Padding)/1000
		SpikeEnd = (Origin+Spacing*(SpikeNo-1)+Base_DurationIClamp+Padding)/1000
		if (SpikeNo==0)
			if (!(Keys & 2^2))
				SetAxis/A bottom		// Only do Auto x axis if not doing Auto y axis at the same time
			endif
		else
			SetAxis bottom,SpikeStart,SpikeEnd
		endif
	endif

End
	
//////////////////////////////////////////////////////////////////////////////////
//// Depending on which "button" that called this function, either a layout or a graph will be added
//// to the parameter log file. It is easier to look at a graph, than it is to stare yourself blind at a
//// zillion parameters!

Function AddToLogProc(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		ChannelNumber =		root:MP:ChannelNumber			// Wave number
	SVAR		GraphBaseName =		root:MP:GraphBaseName			// Base name for output graphs
	SVAR		CurrentWave =			root:MP:CurrWaveNameOut		// Current wave

	String		GraphName
	Variable	i

	Notebook Parameter_Log selection={endOfFile, endOfFile}
	
	if (StringMatch(ctrlName,"AddToLog_Range"))
		i = 0
		String	CommandStr
		Variable	Which
		do
			CommandStr = "ParamCheckBox_"+num2str(i+1)
			ControlInfo/W=MultiPatch_WaveCreator $CommandStr
			if (V_value)
				Which = i+1
				i = Inf
			endif
			i += 1
		while (i<6)
		
		Make/T/O/N=(6) MP_SetVarName		// Figure out name of the setvariable box in question
		MP_SetVarName = {"NPulsesSetVar","PulseAmpSetVar","PulseDurSetVar","PulseFreqSetVar","DisplacedSetVar","CommandLevelSetVar"}
		// 1. NPulsesSetVar
		// 2. PulseAmpSetVar
		// 3. PulseDurSetVar
		// 4. PulseFreqSetVar
		// 5. DisplacedSetVar
		// 6. CommandLevelSetVar
		String	SetVarStr = MP_SetVarName[Which-1]
		String	ParamChoiceStr 
		ControlInfo/W=MultiPatch_WaveCreator $SetVarStr
		Variable dummy1,dummy2
		dummy2 = strsearch(S_recreation,"title",0,2)
		dummy1 = strsearch(S_recreation,"\"",dummy2,2)
		dummy2 = strsearch(S_recreation,"\"",dummy1+1,2)
		ParamChoiceStr = S_recreation[dummy1+1,dummy2-3]

		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="The range of waves for Channel #"+num2str(ChannelNumber)+"\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\tThe chosen variable is:       "+ParamChoiceStr+"\r"
		Notebook Parameter_Log ruler=Normal, text="\r"
		Notebook Parameter_Log ruler=ImageRow, picture={WC_RangeGraph,-1,1},selection={startOfParagraph, endOfParagraph}, convertToPNG=1, selection={endOfFile, endOfFile},text="\r"
		Notebook Parameter_Log ruler=Normal, text="\r"
	endif

	if (StringMatch(ctrlName,"AddToLog_OneOutput"))
		GraphName = GraphBaseName+num2str(ChannelNumber)
		if (StringMatch(WinList(GraphName,";","WIN:1"),""))
			Abort "You must create the waves first!"
		endif
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="The output wave \""+CurrentWave+"\"\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r"
		Notebook Parameter_Log ruler=ImageRow, picture={$GraphName,-1,1},selection={startOfParagraph, endOfParagraph}, convertToPNG=1, selection={endOfFile, endOfFile},text="\r"
		Notebook Parameter_Log ruler=Normal, text="\r"
	endif

	if (StringMatch(ctrlName,"AddToLog_AllOutputs"))
		i = 0
		do
			GraphName = GraphBaseName+num2str(i+1)
			if (StringMatch(WinList(GraphName,";","WIN:1"),""))
				Abort "You must create the waves first!"
			endif
			i += 1
		while (i<4)
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="The output waves\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r"
		i = 0
		do
			GraphName = GraphBaseName+num2str(i+1)
			Notebook Parameter_Log ruler=ImageRow, picture={$GraphName,-1,1},selection={startOfParagraph, endOfParagraph}, convertToPNG=1, selection={endOfFile, endOfFile},text="\r"
			i += 1
		while (i<4)
		Notebook Parameter_Log ruler=Normal, text="\r"
	endif

	if (StringMatch(ctrlName,"AddToLog_Inputs"))
		if (StringMatch(WinList("MultiPatch_ShowInputs",";","WIN:1"),""))
			Abort "You must record the inputs first!"
		endif
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="The acquired waves\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r"
		Notebook Parameter_Log ruler=ImageRow, picture={MultiPatch_ShowInputs,-1,1},selection={startOfParagraph, endOfParagraph}, convertToPNG=1, selection={endOfFile, endOfFile},text="\r"
		Notebook Parameter_Log ruler=Normal, text="\r"
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// This function sends the command string as an AppleEvent to the computer specified by 
//// machinStr

Function sendScript(commandStr,applicationStr,machineStr)

	string commandStr,applicationStr,machineStr
	string sendScriptStr,prefixStr,suffixStr

	prefixStr = "tell application \""+applicationStr+"\" of machine \"" + machineStr + "\"\ractivate\r"
	suffixStr = "\rend tell"
	sendScriptStr =prefixStr + commandStr + suffixStr

	ExecuteScriptText /Z sendScriptStr

	if  (!((stringmatch(S_Value,"\"\""))%|(stringmatch(S_Value,""))))
		Beep;
		Beep;
		Abort "Could not execute AppleScript: "+S_Value
	endif;

End

//////////////////////////////////////////////////////////////////////////////////
//// Below are procedures related to the video capture functions

//// Toggle the real-time video acquisition window on and off

Macro ToggleVideoProc(ctrlName,Checked) : CheckBoxControl
	String		ctrlName
	Variable	Checked
	
	String		scriptStr
//	SVAR		MasterName = root:MP:MasterName
	
	if (Checked)

		scriptStr = "tell application \"Finder\" of machine \""+root:MP:MasterName+"\"\r"
		scriptStr += "activate\r"
		scriptStr += "select file \"Apple Video Player\" of folder \"Favorites\" of folder \"System Folder\" of startup disk\r"
		scriptStr += "open selection\r"
		scriptStr += "end tell\r"
		scriptStr += "tell application \"Igor Pro\" of machine \""+root:MP:MasterName+"\"\r"
		scriptStr += "activate\r"
		scriptStr += "end tell\r"

		ExecuteScriptText /Z scriptStr

	else

		scriptStr = "tell application \"Apple Video Player\" of machine \""+root:MP:MasterName+"\"\r"
		scriptStr += "quit\r"
		scriptStr += "end tell\r"
		scriptStr += "tell application \"Igor Pro\" of machine \""+root:MP:MasterName+"\"\r"
		scriptStr += "activate\r"
		scriptStr += "end tell\r"

		ExecuteScriptText /Z scriptStr

	endif

end

//// Grab one frame and display it

Macro GrabFrameProc(ctrlName) : ButtonControl
	String		ctrlName
	
	DoGrab()

	DoWindow/K GrabbedImageLayout
	LoadPict /O "Clipboard", GrabbedImage
	Layout/C=1/W=(5,42,450,410) GrabbedImage(64,64,384,304)/O=8
	ModifyLayout frame=1
	ModifyLayout mag=1, units=1
	DoWindow/C GrabbedImageLayout
	
end

Macro DoGrab()

	String		scriptStr

	scriptStr = ""

	ControlInfo/W=MultiPatch_Switchboard VideoOnOff
	if (!(V_value))																// Open Apple Video Player if it is not opened before

		scriptStr += "tell application \"Finder\" of machine \""+MasterName+"\"\r"
		scriptStr += "activate\r"
		scriptStr += "select file \"Apple Video Player\" of folder \"Favorites\" of folder \"System Folder\" of startup disk\r"
		scriptStr += "open selection\r"
		scriptStr += "end tell\r"

	endif

	scriptStr += "tell application \"Apple Video Player\" of machine \""+MasterName+"\"\r"
	scriptStr += "activate\r"
	scriptStr += "copy video\r"
	scriptStr += "end tell\r"
	scriptStr += "tell application \"Igor Pro\" of machine \""+MasterName+"\"\r"
	scriptStr += "activate\r"
	scriptStr += "end tell\r"

	ExecuteScriptText /Z scriptStr
	

	ControlInfo/W=MultiPatch_Switchboard VideoOnOff
	if (!(V_value))																// Close Apple Video Player if it was not opened before

		scriptStr = ""
		scriptStr += "tell application \"Apple Video Player\" of machine \""+MasterName+"\"\r"
		scriptStr += "quit\r"
		scriptStr += "end tell\r"
		scriptStr += "tell application \"Igor Pro\" of machine \""+MasterName+"\"\r"
		scriptStr += "activate\r"
		scriptStr += "end tell\r"

		ExecuteScriptText /Z scriptStr
	
	endif

EndMacro

//// Add the grabbed fram to the log file for future reference

Macro FrameToLogProc(ctrlName) : ButtonControl
	String ctrlName

	Notebook Parameter_Log selection={endOfFile, endOfFile}

	DoGrab()
	
	Notebook Parameter_Log ruler=Normal, text="\r"		// Add to notebook
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Image\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r"
	Notebook Parameter_Log ruler=Normal, text="\tAdded to log file at "+time()+"\r"
	Notebook Parameter_Log ruler=ImageRow, scaling={50, 50}, frame=1,picture={GrabbedImage,-1,1},selection={startOfParagraph, endOfParagraph}, convertToPNG=1, selection={endOfFile, endOfFile},text="\r"
	Notebook Parameter_Log ruler=Normal, text="\r"
	
end

//////////////////////////////////////////////////////////////////////////////////
//// Run pattern, as specified by the PatternMaker panel

Function PM_PatternProc(ctrlName) : ButtonControl
	String		ctrlName

	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning			// Boolean: A pattern is currently running
	NVAR		RT_RepeatPattern =		root:MP:PM_Data:RT_RepeatPattern			// Boolean: Should the pattern be repeated?
	NVAR		RT_RepeatFirst = 		root:MP:PM_Data:RT_RepeatFirst			// Boolean: First repeat of pattern?
	NVAR		RT_RepeatNTimes =		root:MP:PM_Data:RT_RepeatNTimes			// How many times should it be repeated?
	NVAR		RT_DoRestartPattern =	root:MP:PM_Data:RT_DoRestartPattern		// Boolean: Restart the pattern? --> Used to restart pattern from EndOfScanHook

	if (!(PatternRunning))
		if ( (RT_RepeatPattern) %& (RT_RepeatNTimes <= 0) )
			Abort "You would like to repeat the pattern how many times did you say???"
		endif
	endif

	RT_RepeatFirst = 1
	RT_DoRestartPattern = 0								// Just to be on the safe side...

	if (PatternRunning)									// Toggle between running a pattern and not running a pattern
		PM_TerminatePattern()
	else
		PM_StartPattern(0)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// This function terminates a pattern that is already running.
//// N.B.! It does not "end" a pattern naturally, it _terminates_ it!

Function PM_TerminatePattern()

	String		CommandStr														// For executes
	Variable	i,dt

	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning
	NVAR		PatternReachedItsEnd = 	root:MP:PM_Data:PatternReachedItsEnd
	NVAR		CurrentStep = 			root:MP:PM_Data:CurrentStep
	NVAR		IterCounter = 			root:MP:PM_Data:IterCounter				// Counts down the iterations in a particular step
	NVAR		DummyIterCounter = 	root:MP:PM_Data:DummyIterCounter		// Counts up the iterations in a particular step -- for display purposes only
	NVAR		TotalIterCounter =	 	root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	NVAR		StartISI = 				root:MP:PM_Data:ISI1
	NVAR		StartMaxIter = 			root:MP:PM_Data:NRepeats1
	NVAR		CurrISI =				root:MP:PM_Data:CurrISI
	NVAR		TimerRef =				root:MP:PM_Data:TimerRef
	NVAR		NewStepBegun =		root:MP:PM_Data:NewStepBegun
	NVAR		NoWavesOnSlave = 		root:MP:PM_Data:NoWavesOnSlave			// Boolean: Flags that there are no waves at all to be sent on the slave computer
	SVAR		PatternName = 			root:MP:PM_Data:PatternName
	
	SVAR		InName1 = 				root:MP:IO_Data:WaveNamesIn1
	SVAR		InName2 = 				root:MP:IO_Data:WaveNamesIn2
	SVAR		InName3 = 				root:MP:IO_Data:WaveNamesIn3
	SVAR		InName4 = 				root:MP:IO_Data:WaveNamesIn4

	SVAR		MasterName =			root:MP:MasterName

	WAVE		SuffixCounter =			root:MP:PM_Data:SuffixCounter
	WAVE		UseInputFlags =			root:MP:PM_Data:UseInputFlags		// These flags keep track of whether an input channel is being used during a pattern

	PatternRunning = 0
	print "Pattern was interrupted at "+Time()
	dt = StopMSTimer(TimerRef)/1E6										// Read the timer and stop it (toss away the read value)
	KillBackground

	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Interrupting pattern\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\tThe pattern \""+PatternName+"\" was interrupted by user at time "+Time()+".\r"
	Notebook Parameter_Log ruler=TabRow, text="\r\tThe pattern reached iteration #"+num2str(DummyIterCounter)+" of step #"+num2str(CurrentStep)+".\r"

	//// Find out where suffix numbering of waves is ending
	i = 0											// Column/channel counter
	do
		CommandStr = 		"root:MP:PM_Data:SuffixCounter["+num2str(i)+"] = "
		CommandStr +=		"root:MP:IO_Data:StartAt"+num2str(i+1)
		Execute CommandStr
		i += 1
	while (i<4)
	Notebook Parameter_Log ruler=TabRow, text="\r\tThe last input waves to be used with this pattern were:\r"
	if (UseInputFlags[0])
		Notebook Parameter_Log ruler=TabRow, text="\t\tCh #1:\t"+InName1+JS_num2digstr(4,SuffixCounter[0]-1)+"\r"
	endif
	if (UseInputFlags[1])
		Notebook Parameter_Log ruler=TabRow, text="\t\tCh #2:\t"+InName2+JS_num2digstr(4,SuffixCounter[1]-1)+"\r"
	endif
	if (UseInputFlags[2])
		Notebook Parameter_Log ruler=TabRow, text="\t\tCh #3:\t"+InName3+JS_num2digstr(4,SuffixCounter[2]-1)+"\r"
	endif
	if (UseInputFlags[3])
		Notebook Parameter_Log ruler=TabRow, text="\t\tCh #4:\t"+InName4+JS_num2digstr(4,SuffixCounter[3]-1)+"\r"
	endif
	Notebook Parameter_Log ruler=TabRow, text="\r"

	PM_FixAtEndOfPattern()							// Various things to fix after having finished a pattern

End

//////////////////////////////////////////////////////////////////////////////////
//// This function initiates and starts a pattern

Function PM_StartPattern(RepeatingPattern)
	Variable	RepeatingPattern													// Boolean: A repeating pattern?

	String		CommandStr														// For executes
	Variable	i,dt

	SVAR		BoardName =			root:BoardName								// ITC18 board? National Instruments?

	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning
	NVAR		PatternReachedItsEnd = 	root:MP:PM_Data:PatternReachedItsEnd
	NVAR		CurrentStep = 			root:MP:PM_Data:CurrentStep
	NVAR		IterCounter = 			root:MP:PM_Data:IterCounter				// Counts down the iterations in a particular step
	NVAR		DummyIterCounter = 	root:MP:PM_Data:DummyIterCounter		// Counts up the iterations in a particular step -- for display purposes only
	NVAR		TotalIterCounter =	 	root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	NVAR		StartISI = 				root:MP:PM_Data:ISI1
	NVAR		StartMaxIter = 			root:MP:PM_Data:NRepeats1
	NVAR		CurrISI =				root:MP:PM_Data:CurrISI
	NVAR		TimerRef =				root:MP:PM_Data:TimerRef
	NVAR		NewStepBegun =		root:MP:PM_Data:NewStepBegun
	NVAR		NoWavesOnSlave = 		root:MP:PM_Data:NoWavesOnSlave			// Boolean: Flags that there are no waves at all to be sent on the slave computer
	SVAR		PatternName = 			root:MP:PM_Data:PatternName
	
	SVAR		InName1 = 				root:MP:IO_Data:WaveNamesIn1
	SVAR		InName2 = 				root:MP:IO_Data:WaveNamesIn2
	SVAR		InName3 = 				root:MP:IO_Data:WaveNamesIn3
	SVAR		InName4 = 				root:MP:IO_Data:WaveNamesIn4

	SVAR		MasterName =			root:MP:MasterName

	WAVE		SuffixCounter =			root:MP:PM_Data:SuffixCounter
	WAVE		UseInputFlags =			root:MP:PM_Data:UseInputFlags		// These flags keep track of whether an input channel is being used during a pattern

	NVAR		RT_RepeatFirst = 		root:MP:PM_Data:RT_RepeatFirst
	NVAR		RT_IPI =				root:MP:PM_Data:RT_IPI			// Inter-pattern-interval [s]
	
	NVAR		StartTicks =			root:MP:PM_Data:StartTicks		// The ticks when first starting a pattern -- used to keep track of time
	
	if (!(RepeatingPattern))												// Only do some of the things the first time around when repeating a pattern
		print Time()+": Preparing to run pattern."
	
		//// Make sure the experiments is saved and therefore named
		if (StringMatch(IgorInfo(1),"Untitled"))
			Print "\tAborting -- experiment not saved!"
			Abort "You'd better save your experiment first!"
		endif
	
		DoWindow MultiPatch_PatternMaker
		if (V_flag)											// If PatternMaker panel exists, then...
			CommandStr = "StorePatternMakerValues()"	// ...re-read the values from the PatternMaker panel, to make sure they are up to date
			Execute CommandStr
		endif
		if (PM_CheckWaves())								// Make sure that all the waves that are involved do exist and that they are okay (same size for each step, etc...)
			Abort "One or more errors occurred.\rSee command window for details."
		endif
	endif

	PM_RT_Prepare()										// Prepare for the realtime analysis of acquired data
	PatternRunning = 1
	PatternReachedItsEnd = 0
	TogglePatternButtons("Stop pattern")
	print Time()+": Starting pattern -------------------------------------------------"

	if (!(RepeatingPattern))								// Only do some of the things the first time around when repeating a pattern

		//// Take automatic notes
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Starting pattern\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r\tStarting pattern \""+PatternName+"\" at time "+Time()+".\r"

		ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck
		if (V_Value)												// **** Triggering is external!! ****
			Print "\tNOTE! This pattern is externally triggered! Timings are determined by trigger source."
			Notebook Parameter_Log ruler=Normal, text="\r\tNOTE! This pattern is externally triggered! Timings are determined by trigger source.\r"
		endif

		i = 0											// Column/channel counter
		do
			CommandStr = 		"root:MP:PM_Data:SuffixCounter["+num2str(i)+"] = "
			CommandStr +=		"root:MP:IO_Data:StartAt"+num2str(i+1)
			Execute CommandStr
			i += 1
		while (i<4)
		Notebook Parameter_Log ruler=TabRow, text="\r\tThe following input waves will be the first to be used with this pattern:\r"
		if (UseInputFlags[0])
			Notebook Parameter_Log ruler=TabRow, text="\t\tCh #1:\t"+InName1+JS_num2digstr(4,SuffixCounter[0])+"\r"
		endif
		if (UseInputFlags[1])
			Notebook Parameter_Log ruler=TabRow, text="\t\tCh #2:\t"+InName2+JS_num2digstr(4,SuffixCounter[1])+"\r"
		endif
		if (UseInputFlags[2])
			Notebook Parameter_Log ruler=TabRow, text="\t\tCh #3:\t"+InName3+JS_num2digstr(4,SuffixCounter[2])+"\r"
		endif
		if (UseInputFlags[3])
			Notebook Parameter_Log ruler=TabRow, text="\t\tCh #4:\t"+InName4+JS_num2digstr(4,SuffixCounter[3])+"\r\r"
		endif
		Notebook Parameter_Log ruler=TabRow, text="\r"
	
		Notebook Parameter_Log ruler=Normal, text="\tDescription of \""+PatternName+"\" follows:\r"
		CommandStr = "DumpPatternToNoteBook()"		// This procedure dumps a description of the pattern to the notebook
		Execute CommandStr
		
		Clear_tVectors()								// These vectors keep track of the timings of the waves during a pattern
		
	endif

	CurrentStep = 1									// Start pattern at the first step! {Counts from 1 and up}
	IterCounter = StartMaxIter							// Set the number of iterations to start with, as defined by the first step {Counts down to zero from StartMaxIter}
	DummyIterCounter = 0								// Same, but will count up, for display purposes {Counts from 0 and up}
	TotalIterCounter = 0								// Analogous, but counts the total number of iterations, i.e. does not restart for each step in the pattern {Counts from 0 and up}
	NewStepBegun = 1									// Starting a pattern is the same as starting a new step, so this should be flagged true with this boolean

	PM_DrawDot(1)										// Draw red dot at step #1
	
	ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck
	if (V_Value)												// **** Triggering is external!! ****
		if (!(RepeatingPattern))
			PM_SetBackground()								// This routine is found in the MP_Board_x procedure file
			StartTicks = Ticks								// Don't reset the pattern timer unless if it is a repeating pattern.
		endif
		dt = StopMSTimer(1)									// Avoid deceptive bug which sneaks up on you slowly, as the MSTimer slots fill up without you noticing it!
		TimerRef = StartMSTimer
		if (!(RepeatingPattern))
			PM_PatternHandler()								// Call PatternHandler directly when triggering is external -- can't rely on background task, as the
															// external timing source may not be as precise as the background task
															// Also, a repeating pattern will call PatternHandler from EndOfScanHook(), so don't do it here as well.
		endif
	else														// **** Triggering is internal!! ****
		if (!(RepeatingPattern))									// (A background task cannot alter itself while running)
			PM_SetBackground()								// This routine is found in the MP_Board_x procedure file
			StartTicks = Ticks								// Don't reset the pattern timer unless if it is a repeating pattern.
		endif
		dt = StopMSTimer(1)									// Avoid deceptive bug which sneaks up on you slowly, as the MSTimer slots fill up without you noticing it!
		TimerRef = StartMSTimer
		if (RepeatingPattern)
			if (StringMatch(BoardName,"ITC18"))				// Account for the fact that the end-of-scan hook is simulated with ITC18
				CtrlBackground start=(Ticks+60.15*(RT_IPI-CurrISI)),period=60.15*StartISI	// Keep repeating the background task -- use InterPatternInterval parameter for delay
			else
				CtrlBackground start=(Ticks+60.15*RT_IPI),period=60.15*StartISI	// Keep repeating the background task -- use InterPatternInterval parameter for delay
			endif
			CurrISI = StartISI								// Store away the current ISI (for use with ITC18 simulated end-of-scan hook)
		else
			CtrlBackground start, period=60.15*StartISI	// Start the background task afresh
			CurrISI = StartISI								// Store away the current ISI (for use with ITC18 simulated end-of-scan hook)
		endif
	endif
	
	PM_SortOutXAxes(1)

End

//////////////////////////////////////////////////////////////////////////////////
//// Draw a red dot in the PatternMaker window at the position of the step

Function PM_DrawDot(TheCurrentStep)
	Variable		TheCurrentStep					// The current step!

	Variable	OriY = 117+29						// Reference point in y direction
	Variable	SpLines	= 22						// Spacing of lines

	if (TheCurrentStep==0)
		KillControl/W=MultiPatch_PatternMaker TheDot
	else
		ValDisplay TheDot,pos={2,OriY+TheCurrentStep*SpLines+4},size={10,10},frame=3,limits={0,200,5},barmisc={0,0},bodyWidth= 10,mode= 1,value=200,win=MultiPatch_PatternMaker
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Prepare the slave computer to run the pattern, by sending waves and descriptors of the pattern
//// to the slave.

Function PM_PrepareSlave(RepeatingPattern)
	Variable		RepeatingPattern				// Boolean: Pattern is a repeating pattern

	Variable		i,j,k,m
	Variable		Counter
	Variable		Length
	Variable		StepsToAdd
	Variable		TextWaveOnThisStep			// Boolean: Current step has a text wave on it
	
	String			CommandStr					// For executes
	String			WorkStr2
	
	NVAR			NoWavesOnSlave =			root:MP:PM_Data:NoWavesOnSlave	// Boolean: Flags that there are no waves at all to be sent on the slave computer

	NVAR			WorkVar =					root:MP:PM_Data:WorkVar
	SVAR			WorkStr =					root:MP:PM_Data:WorkStr
	NVAR			NSteps =					root:MP:PM_Data:NSteps
	NVAR			MaxSteps =					root:MP:PM_Data:MaxSteps

	SVAR			MasterName = 				root:MP:MasterName

	WAVE			PMWaveDuration = 			root:MP:PM_Data:PMWaveDuration
	
	StepsToAdd = 0

	if (!RepeatingPattern)
	
		print "\tPreparing to send data about pattern to slave computer."
		
		print "\t\tKilling all waves on slave computer."
		sendScript("do script \"DoKillWaves()\"","Igor Pro",MasterName+" Slave");
		
		print "\t\tSetting up variables etc. on slave computer."
		sendScript("do script \"SetUpPMData("+num2str(MaxSteps)+")\"","Igor Pro",MasterName+" Slave");

		print "\t\tSearching pattern for waves that are sent from the slave computer."
		
		make/O/T/N=(1) Ch3WaveNames				// Names of output waves for channel 3
		make/O/T/N=(1) Ch4WaveNames				// Names of output waves for channel 4
		make/O/N=(1) nRepeats						// Number of repeats for each step
		make/O/N=(1) ISI								// Interstim intervals for each step
		make/O/N=(1) WaveDur						// Wave duration for each step
	
		Variable	CycleLen = -1

		NoWavesOnSlave = 1
		i = 0											// Line/step counter
		do
		
			print "\t\t\tSearching step: "+num2str(i+1)
	
			j = 2										// Column/channel counter [Only do channels three and four!]
			do
	
				WorkStr = ""							// Reset the wave name
	
				CommandStr = "root:MP:PM_Data:WorkVar = root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)
				Execute CommandStr												// For step i, is output channel j checked?
				if (WorkVar)														// If so, send the corresponding wave to slave computer
				
					NoWavesOnSlave = 0											// At least one wave is to be sent on the slave computer
	
					CommandStr = "root:MP:PM_Data:WorkStr = root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)
					Execute CommandStr											// Name of this wave is now in WorkStr
					
					if (WaveExists($WorkStr))										// Wave does exist...
						if (WaveType($WorkStr)==0)									// ...but is a text wave
							TextWaveOnThisStep = 1
							WAVE/T	www = $WorkStr
							print "\t\t\t\tFinding a textwave on this step --> Finding out whether textwave is cycling textwave or random pattern."

							Length = numpnts($WorkStr)
							CycleLen = -1
							k = 1
							do
								if (stringmatch(www[0],www[k]))
									CycleLen = k
									k = Inf
								endif
								k += 1
							while (k<Length)
							if (CycleLen == -1)
								CycleLen = Length-1
							endif
							print "\t\t\t\t\tCycle length:",CycleLen,"\tIterations in this step:",Length

							k = 0														// ...so read all the numerical wave names from the text wave
							do
								WorkStr2 = www[k]
								if (k<CycleLen)
									print "\t\t\t\tSaving the wave \""+WorkStr2+"\" on the slave computer harddrive."
									CommandStr =  "Save/C/O/P=Slave_Path "+WorkStr2	// ...and save the (unique, non-repeating) numerical waves in the data path of slave computer
									Execute CommandStr
								endif
								if (j==2)
									Ch3WaveNames[Counter] = {WorkStr2}
								else
									Ch4WaveNames[Counter] = {WorkStr2}
								endif
								Counter += 1
								k += 1
							while (k<Length)
							Counter -= Length											// Go back, coz other parameters need to be stored too
						else
							TextWaveOnThisStep = 0									// No text wave on this step
							print "\t\t\t\tSaving the wave \""+WorkStr+"\" on the slave computer harddrive."
							CommandStr =  "Save/C/O/P=Slave_Path "+WorkStr		// Save this numerical wave in the data path of slave computer
							Execute CommandStr
							if (j==2)
								Ch3WaveNames[Counter] = {WorkStr}
							else
								Ch4WaveNames[Counter] = {WorkStr}
							endif
//							Counter += 1;Counter -= 1									// In reality, this should be here too.
							Length = 1
						endif
					endif
					
				endif
	
				j += 1
			while (j<4)
	
			j = 0
			do
				//// How many iterations are there in this step?
				if (TextWaveOnThisStep)
					nRepeats[Counter] = {1}												// If there was a text wave, the create the same number of steps with only one repetition each
				else	
					CommandStr = "root:MP:PM_Data:WorkVar = root:MP:PM_Data:NRepeats"+num2str(i+1)
					Execute CommandStr													// Reset the iteration counter according to number of repeats for this step
					nRepeats[Counter] = {WorkVar}
				endif
				
				//// What's the ISI of this step?
				CommandStr = "root:MP:PM_Data:WorkVar = root:MP:PM_Data:ISI"+num2str(i+1)
				Execute CommandStr
				ISI[Counter] = {WorkVar}
		
				//// What's the duration of the waves of this step?
				WaveDur[Counter] = {PMWaveDuration[i]}								// PMWaveDuration was updated in PM_CheckWaves()

				Counter += 1
				j += 1
			while (j<Length)

			StepsToAdd += (Length-1)													// Several waves within a step (as described by a text wave) will appear on slave computer as multiple steps
																						// This variable accounts for the additional steps

			i += 1
		while (i<NSteps)
		
	endif
	
	if (!NoWavesOnSlave)
	
		if (!RepeatingPattern)
			//// Save the description of the pattern on the slave computer
			Save/O/T/P=Slave_Path Ch3WaveNames,Ch4WaveNames,ISI,nRepeats,WaveDur as "PatternData"
		endif
		
		//// Tell slave computer to load the data and prepare to run the pattern
		print "\t\tTelling slave computer to prepare to run pattern."
		sendScript("do script \"PrepareToRunPattern("+num2str(NSteps+StepsToAdd)+")\"","Igor Pro",MasterName+" Slave");
		
	else

		print "\t\tNo waves need to be sent on the slave computer."
	
	endif

	KillWaves/Z Ch3WaveNames,Ch4WaveNames,ISI,nRepeats,WaveDur

End

//////////////////////////////////////////////////////////////////////////////////
//// This function checks that all the output waves in the PatternMaker panel are okay, that they are
//// of the same size, and that they exist.

Function PM_CheckWaves()

	Variable		i,j,k
	Variable		ErrorState = 0					// ErrorState = 1 means an error occurred
	Variable		NumPoints						// Length of the wave
	Variable		FirstWave						// Boolean: Checking the first wave?
	Variable		NoInputs						// Boolean: No input wave selected (at least one input is needed to trigger waveform generation)
	Variable		ThisStepUseTextWave			// Boolean: When using a text wave (a list of numerical waves to be sent) in a step, make sure all waves in that step are text waves
	
	String			CommandStr					// For executes
	String			WorkStr2
	
	NVAR			WorkVar =					root:MP:PM_Data:WorkVar
	SVAR			WorkStr =					root:MP:PM_Data:WorkStr
	NVAR			NSteps =					root:MP:PM_Data:NSteps

	WAVE			UseInputFlags =				root:MP:PM_Data:UseInputFlags
	WAVE			PMWaveDuration = 			root:MP:PM_Data:PMWaveDuration
	
	print "\tChecking waves and channels."

	UseInputFlags[0] = 0							// These flags keep track of whether an input channel is being used during a pattern
	UseInputFlags[1] = 0
	UseInputFlags[2] = 0
	UseInputFlags[3] = 0

	i = 0											// Line/step counter
	do

		FirstWave = 1
		NoInputs = 1
		j = 0										// Column/channel counter
		do

			CommandStr = "root:MP:PM_Data:WorkVar = root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr												// For step i, is output channel j checked?
			if (WorkVar)														// If so, check the corresponding wave
				CommandStr = "root:MP:PM_Data:WorkStr = root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)
				Execute CommandStr											// Check the chosen wave

				if (!WaveExists($WorkStr))									// Does it exist?
					print "\t\tThe output wave \""+WorkStr+"\" in step "+num2str(i+1)+", channel "+num2str(j+1)+", does not appear to exist."
					ErrorState = 1
				endif

				if (WaveExists($WorkStr))										// Wave does exist...
					if (WaveType($WorkStr)==0)									// ...but is a text wave
						WAVE/T	www = $WorkStr
						CommandStr = www[0]
						if (FirstWave)
							FirstWave = 0
							ThisStepUseTextWave = 1
							NumPoints = numpnts($CommandStr)					// The length of the wave [points]
							PMWaveDuration[i] = pnt2x($CommandStr,NumPoints-1)	// The duration of the wave [seconds!!!!] (store for when sending pattern data to slave)
							k = 1
						else
							if (!(ThisStepUseTextWave))
								print "\t\tIn step "+num2str(i+1)+", text waves and numerical waves are mixed."
								print "\t\tThis is not allowed."
								ErrorState = 1
							endif
							k = 0
						endif
						// Verify that number of steps and number of waves in text wave match
						WorkStr2 = "root:MP:PM_Data:NRepeats"+num2str(i+1)
						NVAR	nRepsHere = $WorkStr2
						if (nRepsHere!=numpnts(www))
							print "\t\tThe text wave \""+WorkStr+"\" has "+num2str(numpnts(www))+" iterations, but step "+num2str(i+1)+" has "+num2str(nRepsHere)+" iterations."
							print "\t\tThey should match!"
							ErrorState = 1
						endif
						// Verify that all the waves in the text wave exist and that they match in length
						do
							CommandStr = www[k]
							// Does it exist?
							if (!WaveExists($CommandStr))
								print "\t\tThe output wave \""+CommandStr+"\" in step "+num2str(i+1)+", channel "+num2str(j+1)+", does not appear to exist."
								ErrorState = 1
							endif
							// Does length match?
							if (NumPoints != numpnts($CommandStr))
								print "\t\tThe output wave \""+CommandStr+"\" in step "+num2str(i+1)+", channel "+num2str(j+1)+", does not match the length of the other waves in the same step."
								k = Inf
								ErrorState = 1
							endif
							k += 1
						while (k<nRepsHere)
					else
						if (FirstWave)												// If wave does exist, and it is not a text wave, make sure it is of the same size as the other wave in the same step
							FirstWave = 0
							ThisStepUseTextWave = 0
							NumPoints = numpnts($WorkStr)						// The length of the wave [points]
							PMWaveDuration[i] = pnt2x($WorkStr,NumPoints-1)	// The duration of the wave [seconds!!!!] (store for when sending pattern data to slave)
						else
							if (ThisStepUseTextWave)
								print "\t\tIn step "+num2str(i+1)+", text waves and numerical waves are mixed."
								print "\t\tThis is not allowed."
								ErrorState = 1
							endif
							if (NumPoints != numpnts($WorkStr))
								print "\t\tThe output wave \""+WorkStr+"\" in step "+num2str(i+1)+", channel "+num2str(j+1)+", does not match the length of the other waves in the same step."
								ErrorState = 1
							endif
						endif
					endif
				endif


				UseInputFlags[j] = 1											// This channel is now tagged as being used in this pattern

			endif

			CommandStr = "root:MP:PM_Data:WorkVar = InputCheck"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr												// Is any input channel selected for this step?
			if (WorkVar)
				NoInputs = 0
			endif

			j += 1
		while (j<4)
		
		if (FirstWave)															// No output waves were selected for this step
			print "\t\tNo output channels were checked for step "+num2str(i+1)+"."
			ErrorState = 1
		endif
		
		if (NoInputs)															// No input waves were selected for this step
			print "\t\tNo input channels were checked for step "+num2str(i+1)+"."
			ErrorState = 1
		endif

		i += 1
	while (i<NSteps)
	
	Return ErrorState

End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	Small function to return the amount of LTP/LTD produced in a three-step pattern...

Function PM_RT_ShowChangeProc(ctrlName) : ButtonControl
	String ctrlName

	Variable	Verbose = 0

	NVAR		DummyIterCounter = 		root:MP:PM_Data:DummyIterCounter		// Counts up the iterations in a particular step
	NVAR		CurrentStep =			root:MP:PM_Data:CurrentStep
	NVAR		NSteps =				root:MP:PM_Data:NSteps
	NVAR		nRep1 =					root:MP:PM_Data:NRepeats1
	NVAR		nRep2 = 				root:MP:PM_Data:NRepeats2
	NVAR		nRep3 = 				root:MP:PM_Data:NRepeats3
	
	NVAR		RT_EPSPOnOff =			root:MP:PM_Data:RT_EPSPOnOff		// Realtime EPSP analysis on or off?
	NVAR		RT_EPSPUseGrab =			root:MP:PM_Data:RT_EPSPUseGrab		// Use manual EPSPs?
	NVAR		RT_EPSPUseMatrix =			root:MP:PM_Data:RT_EPSPUseMatrix		// Use automatic EPSPs?

	//// CONNECTIVITY
	WAVE		Conn_Matrix =			root:MP:PM_Data:Conn_Matrix			// Connectivity matrix describing which cells are connected to which
	WAVE		Pos_Matrix =			root:MP:PM_Data:Pos_Matrix				// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]
	
	variable	i,j

	if (Verbose)
		Print "Found "+num2str(NSteps)+" steps."
		print "\tFirst:",nRep1
		print "\tSecond:",nRep2
		print "\tThird:",nRep3
		print "Current step is ",CurrentStep
	endif
	print "Current repeat is ",DummyIterCounter
	
	if ((RT_EPSPOnOff) %& (RT_EPSPUseGrab))
		if (CurrentStep>=3)
			i = 0
			do
				ControlInfo $("Ch"+num2str(i+1)+"Check")
				if (V_Value)
					WAVE	w = $("RT_EPSPWave"+num2str(i+1))
					if (DummyIterCounter>60)
						printf "\tCh#"+num2str(i+1)+": %5.1f %\t",mean(w,nRep1+nRep2+60,nRep1+nRep2+DummyIterCounter-1)/mean(w,0,nRep1-1)*100
					else
						printf "\tCh#"+num2str(i+1)+": %5.1f %\t",mean(w,nRep1+nRep2,nRep1+nRep2+DummyIterCounter-1)/mean(w,0,nRep1-1)*100
					endif
				endif
				i += 1
			while (i<4)
		endif
		print "\r"
	endif

	if ((RT_EPSPOnOff) %& (RT_EPSPUseMatrix))
		i = 0
		do
			j = 0
			do
				if (i!=j)
					if (Conn_Matrix[i][j])
						if (Pos_Matrix[i][j]!=-1)
							WAVE	w = $("RT_EPSPMatrix"+num2str(i+1)+num2str(j+1))
							if (DummyIterCounter>60)
								printf "\t"+num2str(i+1)+"->"+num2str(j+1)+": %5.1f %\t",mean(w,nRep1+nRep2+60,nRep1+nRep2+DummyIterCounter-1)/mean(w,0,nRep1-1)*100
							else
								printf "\t"+num2str(i+1)+"->"+num2str(j+1)+": %5.1f %\t",mean(w,nRep1+nRep2,nRep1+nRep2+DummyIterCounter-1)/mean(w,0,nRep1-1)*100
							endif
						endif
					endif
				endif
				j += 1
			while (j<4)
			i += 1
		while (i<4)
		print "\r"
	endif

End

//////////////////////////////////////////////////////////////////////////
//// Sort out graph x axes when pattern is running

Function PM_SortOutXAxes(ForceRescaling)
	Variable		ForceRescaling

	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning
	NVAR		PatternReachedItsEnd = 	root:MP:PM_Data:PatternReachedItsEnd
	NVAR		TotalIterCounter =	 	root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	
	Variable	stepSize = 6
	
	DoWindow RT_SealTestGraph
	Variable	A = V_flag
	DoWindow RT_VmGraph
	Variable	B = V_flag
	DoWindow RT_EPSPGraph
	Variable	C = V_flag
	Variable D = 0
	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			DoWindow RT_TempGraph
			D = V_flag
		endif
	endif
	if (Exists("Warner_Temp"))
		NVAR/Z	Warner_Temp
		DoWindow RT_TempGraph
		D = V_flag
	endif

	if (PatternReachedItsEnd)						// Done at "natural" ending of a pattern
		if (A)
			SetAxis/A/W=RT_SealTestGraph/Z bottom
		endif
		if (B)
			SetAxis/A/W=RT_VmGraph/Z bottom
		endif
		if (C)
			SetAxis/A/W=RT_EPSPGraph/Z bottom
		endif
		if (D)
			SetAxis/A/W=RT_TempGraph/Z bottom
		endif
	endif
	if (PatternRunning)							// Done while pattern is running
		if (A)
			SetAxis/W=RT_SealTestGraph/Z bottom,*,Ceil(TotalIterCounter/stepSize)*stepSize
		endif
		if (B)
			SetAxis/W=RT_VmGraph/Z bottom,*,Ceil(TotalIterCounter/stepSize)*stepSize
		endif
		if (C)
			SetAxis/W=RT_EPSPGraph/Z bottom,*,Ceil(TotalIterCounter/stepSize)*stepSize
		endif
		if (D)
			SetAxis/A/W=RT_TempGraph/Z bottom,*,Ceil(TotalIterCounter/stepSize)*stepSize
		endif
	else
		if (ForceRescaling)							// Done when pattern is terminated and when plots are redrawn but pattern is not running any longer
			if (A)
				SetAxis/W=RT_SealTestGraph/Z bottom,*,TotalIterCounter-1
			endif
			if (B)
				SetAxis/W=RT_VmGraph/Z bottom,*,TotalIterCounter-1
			endif
			if (C)
				SetAxis/W=RT_EPSPGraph/Z bottom,*,TotalIterCounter-1
			endif
			if (D)
				SetAxis/A/W=RT_TempGraph/Z bottom,*,TotalIterCounter-1
			endif
		endif
	endif

End

//////////////////////////////////////////////////////////////////////////
//// This function handles the patterns in the background

Function PM_PatternHandler()

	Variable	ReturnValue = 0							// 0 = Okay, 1 = Stop, 2 = Stop with error
	
	Variable	dt											// Delta time between stimuli
	
	String		CommandStr								// Used for executes
	Variable	i
	Variable	WaitCounter								// Wait for a random amount of time

	SVAR		BoardName =			root:BoardName								// ITC18 board? National Instruments?

	NVAR		CurrentStep =			root:MP:PM_Data:CurrentStep
	NVAR		CurrISI =				root:MP:PM_Data:CurrISI
	NVAR		NSteps =				root:MP:PM_Data:NSteps
	NVAR		IterCounter =			root:MP:PM_Data:IterCounter				// Counts down the iterations in a particular step
	NVAR		DummyIterCounter = 	root:MP:PM_Data:DummyIterCounter		// Counts up the iterations in a particular step
	NVAR		TotalIterCounter =	 	root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning
	NVAR		PatternReachedItsEnd = 	root:MP:PM_Data:PatternReachedItsEnd
	NVAR		TimerRef =				root:MP:PM_Data:TimerRef
	NVAR		NewStepBegun =		root:MP:PM_Data:NewStepBegun
	SVAR		PatternName = 			root:MP:PM_Data:PatternName
	
	NVAR		StartTicks =			root:MP:PM_Data:StartTicks				// The ticks counter when the pattern was started
	NVAR		ElapsedMins =			root:MP:PM_Data:ElapsedMins				// Number of minutes elapsed since the start of the recording
	NVAR		ElapsedSecs =			root:MP:PM_Data:ElapsedSecs				// Number of seconds (minus the above minutes) elapsed since the start of the recording
	Variable	CurrTicks															// Current ticks value -- just to keep consistency as ticks keeps changing

	NVAR		ISINoise =				root:MP:PM_Data:ISINoise					// The amplitude of the uniform noise to be added to the ISI
	
	WAVE		dt_vector =				root:MP:PM_Data:dt_vector					// Store the dt:s
	WAVE/T	t_vector =				root:MP:PM_Data:t_vector					// Store the times

	SVAR		InName1 = 				root:MP:IO_Data:WaveNamesIn1				// Input wave base names
	SVAR		InName2 = 				root:MP:IO_Data:WaveNamesIn2
	SVAR		InName3 = 				root:MP:IO_Data:WaveNamesIn3
	SVAR		InName4 = 				root:MP:IO_Data:WaveNamesIn4

	WAVE		SuffixCounter =			root:MP:PM_Data:SuffixCounter				// The suffix counter wave
	WAVE		UseInputFlags =			root:MP:PM_Data:UseInputFlags				// Keep track of which channels are used in this pattern	
	
	NVAR		RT_RepeatPattern =		root:MP:PM_Data:RT_RepeatPattern			// Boolean: Should the pattern be repeated?
	NVAR		RT_RepeatFirst = 		root:MP:PM_Data:RT_RepeatFirst			// Boolean: First repeat of pattern?
	NVAR		RT_RepeatNTimes =		root:MP:PM_Data:RT_RepeatNTimes			// How many times should it be repeated?
	NVAR		RT_DoRestartPattern =	root:MP:PM_Data:RT_DoRestartPattern		// Boolean: Restart the pattern? --> Used to restart pattern from EndOfScanHook

	WaitCounter = (enoise(ISINoise/2)+ISINoise/2+0.005)/1.42467*1E6			// Add random time delay to account for 60Hz noise
	do
		WaitCounter -= 1
	while (WaitCounter>0)

	dt = StopMSTimer(TimerRef)/1E6												// Read the timer and stop it
	TimerRef = StartMSTimer														// Restart the timer

	DummyIterCounter += 1

	CurrTicks = Ticks
	print "\tPatternHandler -- total iteration #: "+num2str(TotalIterCounter+1)+" -- t: "+Time()+" -- dt: "+num2str(round(dt))+" -- step: "+num2str(CurrentStep)+" -- repeat: "+num2str(DummyIterCounter)+" -- elapsed: "+num2str((CurrTicks-StartTicks)/60.15/60)+" min "	// Display the same data
	
	ElapsedMins = Floor((CurrTicks-StartTicks)/60.15/60)
	ElapsedSecs = Floor( ((CurrTicks-StartTicks)/60.15/60 - ElapsedMins )*60)

	dt_vector[TotalIterCounter] = dt												// Store dt and t for future reference
	t_vector[TotalIterCounter] = Time()

	PM_SendWaves()																// *** Send the waves ***

	TotalIterCounter += 1															// Count up
	
	IterCounter -= 1
	if (IterCounter == 0)
		
		NewStepBegun = 1
		CurrentStep += 1
		PM_DrawDot(CurrentStep)
		if (CurrentStep > NSteps)													// Reached total number of steps in pattern?  If so, clean up and quit background task
			if (!(StringMatch(BoardName,"ITC18")))
				ReturnValue = 1													// Recall that the ITC18 requires a simulated end-of-scan hook, so don't interrupt background task just yet
			endif
			PatternRunning = 0
			PatternReachedItsEnd = 1
			dt = StopMSTimer(TimerRef)/1E6										// Read the timer and stop it (toss away the read value)

			if ( (!(RT_RepeatPattern)) %| (RT_RepeatNTimes == 1) )				// Dump notes at end of pattern, if it is not a repeating pattern (produces too much junk)
				print "\t\t\tReaching the end of the pattern at "+Time()+"."
				//// Take automatic notes
				Notebook Parameter_Log selection={endOfFile, endOfFile}
				Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Pattern reached its end\r",textRGB=(0,0,0)
				Notebook Parameter_Log ruler=Normal, text="\r\tThe pattern \""+PatternName+"\" reached its end at time "+Time()+".\r"
	
				//// Find out where suffix numbering of waves is ending
				i = 0											// Column/channel counter
				do
					CommandStr = 		"root:MP:PM_Data:SuffixCounter["+num2str(i)+"] = "
					CommandStr +=		"root:MP:IO_Data:StartAt"+num2str(i+1)
					Execute CommandStr
					i += 1
				while (i<4)
				Notebook Parameter_Log ruler=TabRow, text="\r\tThe following input waves were the last to be used with this pattern:\r"
				if (UseInputFlags[0])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #1:\t"+InName1+JS_num2digstr(4,SuffixCounter[0]-1)+"\r"
				endif
				if (UseInputFlags[1])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #2:\t"+InName2+JS_num2digstr(4,SuffixCounter[1]-1)+"\r"
				endif
				if (UseInputFlags[2])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #3:\t"+InName3+JS_num2digstr(4,SuffixCounter[2]-1)+"\r"
				endif
				if (UseInputFlags[3])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #4:\t"+InName4+JS_num2digstr(4,SuffixCounter[3]-1)+"\r"
				endif
				Notebook Parameter_Log ruler=TabRow, text="\r"
			endif
			
			if (RT_RepeatPattern)													// Keep track of whether the entire pattern should be repeated
				RT_RepeatFirst = 0
				RT_RepeatNTimes -= 1
				if (!(RT_RepeatNTimes <= 0))
					ReturnValue = 0
					RT_DoRestartPattern = 1										// This causes the End-Of-Scan Hook to restart the pattern
				else
					RT_DoRestartPattern = 0
				endif
			endif

		else																			// Pattern did not reach its end --> move to the next step in pattern

			if (!(RT_RepeatPattern))												// Dump notes at new step of pattern, if it is not a repeating pattern (produces too much junk)

				//// Take automatic notes
				Notebook Parameter_Log selection={endOfFile, endOfFile}
				Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="PatternHandler: Start of step #"+num2str(CurrentStep)+"\r",textRGB=(0,0,0)
				Notebook Parameter_Log ruler=Normal, text="\r\tThe pattern \""+PatternName+"\" reached the end of step #"+num2str(CurrentStep-1)+" at time "+Time()+".\r"
	
				//// Find out where suffix numbering is at right now
				i = 0											// Column/channel counter
				do
					CommandStr = 		"root:MP:PM_Data:SuffixCounter["+num2str(i)+"] = "
					CommandStr +=		"root:MP:IO_Data:StartAt"+num2str(i+1)
					Execute CommandStr
					i += 1
				while (i<4)
				Notebook Parameter_Log ruler=TabRow, text="\r\tThe first input waves to be used in the step #"+num2str(CurrentStep)+" are named as follows:\r"
				if (UseInputFlags[0])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #1:\t"+InName1+JS_num2digstr(4,SuffixCounter[0])+"\r"
				endif
				if (UseInputFlags[1])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #2:\t"+InName2+JS_num2digstr(4,SuffixCounter[1])+"\r"
				endif
				if (UseInputFlags[2])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #3:\t"+InName3+JS_num2digstr(4,SuffixCounter[2])+"\r"
				endif
				if (UseInputFlags[3])
					Notebook Parameter_Log ruler=TabRow, text="\t\tCh #4:\t"+InName4+JS_num2digstr(4,SuffixCounter[3])+"\r"
				endif
				Notebook Parameter_Log ruler=TabRow, text="\r"

			endif

			//// How many iterations are there in the next step?
			CommandStr = "root:MP:PM_Data:IterCounter = root:MP:PM_Data:NRepeats"+num2str(CurrentStep)
			Execute CommandStr													// Reset the iteration counter according to number of repeats for this step
			DummyIterCounter = 0												// Note that DummyIterCounter starts at zero
			
			//// What's the ISI of the next step?
			ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck
			if ((!(StringMatch(BoardName,"ITC18"))) %& (!(V_Value)) )
				CommandStr = "CtrlBackground period=60.15*root:MP:PM_Data:ISI"+num2str(CurrentStep)
				Execute CommandStr
			endif

			//// Store away the ISI of the next step too...
			CommandStr = "root:MP:PM_Data:CurrISI = root:MP:PM_Data:ISI"+num2str(CurrentStep)
			Execute CommandStr

		endif // CurrentStep>NSteps
		
	else

		NewStepBegun = 0

	endif // IterCounter == 0

//	if (StringMatch(BoardName,"ITC18"))									// If ITC-18 running with external trigger, then simulate End-of-Scan-Hook here.
//		ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck
//		if (V_value)
//			DA_EndOfScanHook()
//		endif
//	endif

	if (StringMatch(BoardName,"DEMO"))									// DEMO mode requires that some bits of End-of-Scan-Hook are called here.
		DA_EndOfScanHook()
	endif

	return ReturnValue

End

//////////////////////////////////////////////////////////////////////////////////
//// Send the waves specified in a particular step of a pattern.

Function PM_SendWaves()

	Variable	i

	String		WaveListStr = ""													// List of names of input waves -- use with acquisition
	String		WaveListStr2 = ""													// List of names of input waves -- use for display purposes
	String		CommandStr
	String		VarStr
	
	Variable	ThisIsATextWave													// Boolean

	SVAR		BoardName =				root:BoardName							// ITC18 board? National Instruments?

	NVAR		TempStartAt =				root:MP:TempStartAt
	NVAR 		AcqGainSet=					root:MP:AcqGainSet						// added variable 22000  KM
	SVAR		DummyStr =				root:MP:DummyStr
	NVAR		WorkVar =					root:MP:PM_Data:WorkVar
	NVAR		WorkVar2 =				root:MP:PM_Data:WorkVar2
	NVAR		WorkVar3 =				root:MP:PM_Data:WorkVar3
	NVAR		CurrentStep =				root:MP:PM_Data:CurrentStep
	NVAR		DummyIterCounter = 		root:MP:PM_Data:DummyIterCounter	// Counts up the iterations in a particular step
	SVAR		w1 = 						root:MP:PM_Data:w1					// Names of output waves
	SVAR		w2 = 						root:MP:PM_Data:w2
	SVAR		w3 = 						root:MP:PM_Data:w3
	SVAR		w4 = 						root:MP:PM_Data:w4
	NVAR		SampleFreq = 				root:MP:SampleFreq
	
	WAVE		PMWaveDuration =			root:MP:PM_Data:PMWaveDuration		// The duration of waves [in seconds!!!] (due to compatibility with slave computer)

	WAVE/T	WaveInVarNames = 			root:MP:IO_Data:WaveInVarNames
	WAVE/T	WaveOutVarNames = 		root:MP:IO_Data:WaveOutVarNames

	//// Figure out input wave names
	WaveListStr = "";
	WaveListStr2 = "";
	w1 = "";
	w2 = "";
	w3 = "";
	w4 = "";

	i = 0
	do

		CommandStr = "root:MP:PM_Data:WorkVar = root:MP:PM_Data:InputCheck"+num2str(CurrentStep)+"_"+num2str(i+1)
		Execute CommandStr																			// Is input channel i in step 'CurrentStep' checked for input?

		if (WorkVar)

			VarStr = "StartAt"+num2str(i+1)															// Find out where suffix numbering of waves should start
			CommandStr = "root:MP:TempStartAt = root:MP:IO_Data:"+VarStr
			Execute CommandStr

			CommandStr = "root:MP:DummyStr = (root:MP:IO_Data:"+WaveInVarNames[i]				// Create wave name
			CommandStr += "+JS_num2digstr(4,"+num2str(TempStartAt)+"))"
			Execute CommandStr

			ProduceWave(DummyStr,SampleFreq,PMWaveDuration[CurrentStep-1]*1000)				// Create the wave with the above name

			WaveListStr += DummyStr+","+num2str(i)+","+num2str(AcqGainSet)+ ";"				// Add name to list of input waves -- Per-channel gain of 5x to reduce quantization noise
			sprintf CommandStr,"%s \t",DummyStr
			WaveListStr2 += CommandStr																// This list of waves is only used for display purposes

			DA_StoreWaveStats(DummyStr,i+1)														// Store info about wave so that it can be fixed after data acquisition

		endif

		i+=1
	while(i<4)
	
	//// Figure out output wave names
	i = 0
	do
		CommandStr = "root:MP:PM_Data:WorkVar = root:MP:PM_Data:OutputCheck"+num2str(CurrentStep)+"_"+num2str(i+1)
		Execute CommandStr													// For step 'CurrentStep', is output channel i checked?
		if (WorkVar)
			CommandStr = "root:MP:PM_Data:w"+num2str(i+1)+" = root:MP:PM_Data:OutputWave"+num2str(CurrentStep)+"_"+num2str(i+1)
			Execute CommandStr												// If so, figure out the wave name
			SVAR	w = root:MP:PM_Data:$("w"+num2str(i+1))
			ThisIsATextWave = 0
			if (WaveExists($w))
				if (WaveType($w)==0)										// This wave is a text wave -- take 
					WAVE/T	www = $w
					VarStr = www[DummyIterCounter-1]						// Name of the wave to be sent
					w = VarStr													// Correct the current string variable accordingly
				endif
			endif
		endif
		i += 1
	while (i<4)

	//// Set up waveform generation
	
	if ( (StringMatch(BoardName,"ITC18")) %| (StringMatch(BoardName,"NI_2PLSM")) %| (StringMatch(BoardName,"PCI-6363")) %| (StringMatch(BoardName,"DEMO")) )
		PrepareToSend(w1,w2,w3,w4)											// Take care of sending the waves to the boards (ITC18 & NI_MultiBoard)
	else
		if (StringMatch(BoardName,"NI"))
			PrepareToSend(w1,w2,"","")										// Take care of sending the waves to the boards (NI)
		else
			Abort "PM_SendWaves: Strange error! Unsupported board?"
		endif
	endif
	
	//// Set up data acquisition

	BeginAcquisition(WaveListStr)												// Data acquisition will trigger waveform generation

	//// Report to user which waves are being used in this step
//	print "\t\tSending waves:\t\t"+w1+" \t\t"+w2+" \t\t"+w3+" \t\t"+w4
//	print "\t\tAcquiring waves:\t"+WaveListStr2
	
	//// Show the input waves if the user so desires...
	DA_DoShowInputs(1)

	//// Increase the suffix numbers of the channels that were used
	//// N.B.! With patterns, this is done whether or not the user has explicityly chosen to have the suffices increased,
	//// otherwise entire pattern runs might be spoiled if the user forgets to check the 'CountUp' checkbox for increasing
	//// the suffix numbering.
	i = 0
	do

		CommandStr = "root:MP:PM_Data:WorkVar = InputCheck"+num2str(CurrentStep)+"_"+num2str(i+1)
		Execute CommandStr													// Is input channel i in step 'CurrentStep' checked for input?

		if (WorkVar)
			VarStr = "StartAt"+num2str(i+1)									// Find out where suffix numbering of waves should start
			CommandStr = "root:MP:IO_Data:"+VarStr+" += 1"					// Next wave should have the next suffix number
			Execute CommandStr
		endif

		i+=1
	while(i<4)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Get time as a string, use for time-stamping of wave names

Function/S PM_DateTime2String(theDateTime)
	Variable		theDateTime
	
	String		WorkStr = Secs2Time(theDateTime,3)
	String		TimeStr = WorkStr[0,1]+"_"+ WorkStr[3,4]+"_"+WorkStr[6,7]

	Return TimeStr

End

//////////////////////////////////////////////////////////////////////////////////
//// Various things that need to be fixed at the end of a run of a pattern

Function PM_FixAtEndOfPattern()

	String		WorkStr = ""
	String		WaveStr = ""
	String		TimeStr = ""
	
	Variable	i,j

	NVAR		DataLength =			 	root:MP:PM_Data:TotalIterCounter		// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	NVAR		RT_SealTestCheck =		root:MP:PM_Data:RT_SealTestOnOff		// Realtime sealtest analysis on or off?
	NVAR		RT_VmCheck =				root:MP:PM_Data:RT_VmOnOff				// Realtime membrane potential analysis on or off?
	NVAR		RT_EPSPOnOff =				root:MP:PM_Data:RT_EPSPOnOff			// Realtime EPSP analysis on or off?
	NVAR		RT_EPSPUseGrab =			root:MP:PM_Data:RT_EPSPUseGrab		// Use manual EPSPs?
	NVAR		RT_EPSPUseMatrix =		root:MP:PM_Data:RT_EPSPUseMatrix		// Use automatic EPSPs?
	
	WAVE		RT_PatternSuffixWave														// Keep track of all old pattern runs by remembering the timestamp

	//// CONNECTIVITY
	WAVE		Conn_Matrix =				root:MP:PM_Data:Conn_Matrix			// Connectivity matrix describing which cells are connected to which
	WAVE		Pos_Matrix =				root:MP:PM_Data:Pos_Matrix				// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]

	WAVE		UseInputFlags =			root:MP:PM_Data:UseInputFlags			// These flags keep track of whether an input channel is being used during a pattern
	WAVE		VClampWave =				root:MP:IO_Data:VClampWave				// Boolean: Channel is in voltage clamp or in current clamp?

	Print Time()+":\tPattern finished -- Cleaning up... -------------------------------"

	TogglePatternButtons("Run pattern")
	
	Variable	theDateTime = DateTime
	RT_PatternSuffixWave[numpnts(RT_PatternSuffixWave)] = {theDateTime}	// Keep track of all old pattern runs by remembering the timestamp
	
	TimeStr = PM_DateTime2String(theDateTime)										// Get time as a string, use for time-stamping of wave names

	PM_DrawDot(0)																			// Remove the red dot!
	PM_SortOutXAxes(1)

	Notebook Parameter_Log selection={endOfFile, endOfFile}

	if (RT_SealTestCheck)															// Test pulse
		Print "\tCopying the sealtest waves to the root and time-stamping them "+TimeStr+"."
		Notebook Parameter_Log ruler=Normal, text="\tThe sealtest waves were copied to the root and time-stamped with "+TimeStr+".\r"
		i = 0
		do
			if (UseInputFlags[i])
				WaveStr = "RT_SealTestWave"+num2str(i+1)
				Duplicate/R=(0,DataLength-1) $(WaveStr),$(WaveStr+"_"+TimeStr)
			endif
			i += 1
		while (i<4)
	endif

	if (RT_VmCheck)																// Membrane Potential
		Print "\tCopying the membrane potential/current waves to the root and time-stamping them "+TimeStr+"."
		Notebook Parameter_Log ruler=Normal, text="\tThe membrane potential/current waves were copied to the root\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tand time-stamped with "+TimeStr+".\r"
		i = 0
		do
			if (UseInputFlags[i])
				WaveStr = "RT_VmImWave"+num2str(i+1)
				Duplicate/R=(0,DataLength-1) $(WaveStr),$(WaveStr+"_"+TimeStr)
				Note $(WaveStr+"_"+TimeStr),"vClamp:"+num2str(vClampWave[i])+";"
			endif
			i += 1
		while (i<4)
	endif
	
	String/G $("PM_RT_EPSPwaveList_"+TimeStr)/N=EPSPwaveList			// When plotting previously run patterns, this list keeps track of what to plot
	EPSPwaveList = ""

	if ((RT_EPSPOnOff) %& (RT_EPSPUseGrab))									// Manual EPSP amplitude
		Print "\tCopying the EPSP amplitude waves [manual positions] to the root and time-stamping them "+TimeStr+"."
		Notebook Parameter_Log ruler=Normal, text="\tThe amplitude waves [manual positions] were copied to the root and time-stamped with "+TimeStr+".\r"
		i = 0
		do
			if (UseInputFlags[i])
				WaveStr = "RT_EPSPWave"+num2str(i+1)
				Duplicate/R=(0,DataLength-1) $(WaveStr),$(WaveStr+"_"+TimeStr)
				EPSPwaveList += WaveStr+"_"+TimeStr+","+num2str(VClampWave[i])+";"			// waveName,VorIclamp
			endif
			i += 1
		while (i<4)
	endif

	if ((RT_EPSPOnOff) %& (RT_EPSPUseMatrix))									// Automatic EPSP amplitude
		Print "\tCopying the EPSP amplitude waves [automatic positions] to the root and time-stamping them "+TimeStr+"."
		Notebook Parameter_Log ruler=Normal, text="\tThe amplitude waves [automatic positions] were copied to the root and time-stamped with "+TimeStr+".\r"
		i = 0
		do
			j = 0
			do
				if (i!=j)
					if (Conn_Matrix[i][j])
						if (Pos_Matrix[i][j]!=-1)
							WaveStr = "RT_EPSPMatrix"+num2str(i+1)+num2str(j+1)
							Duplicate/R=(0,DataLength-1) $(WaveStr), $(WaveStr+"_"+TimeStr)
							EPSPwaveList += WaveStr+"_"+TimeStr+","+num2str(VClampWave[j])+";"			// matrix goes from [i] to [j], hence VClampWave[j]
						endif
					endif
				endif
				j += 1
			while (j<4)
			i += 1
		while (i<4)
	endif

	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			Print "\tCopying the temperature wave to the root and time-stamping it with "+TimeStr+"."
			Notebook Parameter_Log ruler=Normal, text="\tThe temperature wave was copied to the root and time-stamped with "+TimeStr+".\r"
			WaveStr = "RT_TempWave"
			Duplicate/R=(0,DataLength-1) $(WaveStr), $(WaveStr+"_"+TimeStr)
			WaveStr = "RT_HeaterTempWave"
			Duplicate/R=(0,DataLength-1) $(WaveStr), $(WaveStr+"_"+TimeStr)
			WaveStr = "RT_TargetTempWave"
			Duplicate/R=(0,DataLength-1) $(WaveStr), $(WaveStr+"_"+TimeStr)
		endif
	endif

	if (Exists("Warner_Temp"))
		NVAR/Z	Warner_Temp
		Print "\tCopying the temperature wave to the root and time-stamping it with "+TimeStr+"."
		Notebook Parameter_Log ruler=Normal, text="\tThe temperature wave was copied to the root and time-stamped with "+TimeStr+".\r"
		WaveStr = "RT_TempWave"
		Duplicate/R=(0,DataLength-1) $(WaveStr), $(WaveStr+"_"+TimeStr)
	endif

	Print "\tCopying the t and dt waves to the root and time-stamping them "+TimeStr+"."
	Notebook Parameter_Log ruler=Normal, text="\tThe t and dt waves were copied to the root and time-stamped with "+TimeStr+".\r\r"
	
	Duplicate/R=(0,DataLength-1) root:MP:PM_Data:dt_vector, $("dt_vector_"+TimeStr)				// Copy dt vector to root and datestamp it
	Duplicate/R=(0,DataLength-1) root:MP:PM_Data:t_vector, $("t_vector_"+TimeStr)				// Copy t vector to root and datestamp it

	DA_DoAutoSaveExperiment()

End

//////////////////////////////////////////////////////////////////////////////////
//// Dump a description of the pattern to the parameter log notebook

Macro DumpPatternToNoteBook()

//	NVAR		NSteps =				root:MP:PM_Data:NSteps
//	SVAR		PatternName = 			root:MP:PM_Data:PatternName

	String		CommandStr
	String		OutYN
	String		InYN
	String		OutWave
	
	Variable	i
	Variable	j

	Notebook Parameter_Log selection={endOfFile, endOfFile}

	if (root:MP:PM_Data:RT_RepeatPattern)
		Notebook Parameter_Log ruler=TabRow, text="\r\tPattern will be repeated "+num2str(root:MP:PM_Data:RT_RepeatNTimes)+" times.\r"
	endif

	i = 0
	do

		CommandStr = "root:MP:PM_Data:WorkVar="												// Number of repeats
		CommandStr += "NRepeats"+num2str(i+1)
		Execute CommandStr

		CommandStr = "root:MP:PM_Data:WorkVar2="												// Inter-stimulus interval
		CommandStr += "ISI"+num2str(i+1)
		Execute CommandStr
	

		Notebook Parameter_Log ruler=TabRow, text="\r\tStep #"+num2str(i+1)+":\tRepeats: "+num2str(root:MP:PM_Data:WorkVar)+"\tISI: "+num2str(root:MP:PM_Data:WorkVar2)+" sec\r"

		j = 0
		do
		
			CommandStr = "root:MP:PM_Data:WorkVar="											// Input checkbox values
			CommandStr += "InputCheck"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr

			if (root:MP:PM_Data:WorkVar==1)
				InYN = "Yes"
			else
				InYN = "No"
			endif
			
			CommandStr = "root:MP:PM_Data:WorkVar="											// Output checkbox values
			CommandStr += "OutputCheck"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr

			CommandStr = "root:MP:PM_Data:WorkStr="											// Output wave names
			CommandStr += "OutputWave"+num2str(i+1)+"_"+num2str(j+1)
			Execute CommandStr

			if (root:MP:PM_Data:WorkVar==1)
				OutYN = "Yes"
				OutWave = root:MP:PM_Data:WorkStr
				Notebook Parameter_Log ruler=TabRow, text="\t\tCh#"+num2str(j+1)+"\tInput? "+InYN+"\tOutput? "+OutYN+"\tWave name: "+OutWave+"\r"
			else
				OutYN = "No"
				OutWave = ""
				Notebook Parameter_Log ruler=TabRow, text="\t\tCh#"+num2str(j+1)+"\tInput? "+InYN+"\tOutput? "+OutYN+"\t\r"
			endif

			j += 1
		while (j<4)

		i += 1
	while (i<root:MP:PM_Data:NSteps)
	
	Notebook Parameter_Log ruler=Normal, text="\r"

End

//////////////////////////////////////////////////////////////////////////////////
//// Close all the plots that are related to the RT PM procedures

Function PM_RT_CloseThePlotsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	DoWindow/K RT_SealTestGraph
	DoWindow/K RT_VmGraph
	DoWindow/K RT_EPSPGraph

	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			DoWindow/K RT_TempGraph
		endif
	endif

	if (Exists("Warner_Temp"))
		DoWindow/K RT_TempGraph
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Bring all the plots that are related to the RT PM procedures to the front

Function PM_RT_BringThePlotsToFrontProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable	anyWindows = 0
	
	DoWindow/F RT_SealTestGraph
	anyWindows = (anyWindows %| V_Flag)
	DoWindow/F RT_VmGraph
	anyWindows = (anyWindows %| V_Flag)
	DoWindow/F RT_EPSPGraph
	anyWindows = (anyWindows %| V_Flag)
	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			DoWindow/F RT_TempGraph
			anyWindows = (anyWindows %| V_Flag)
		endif
	endif
	if (Exists("Warner_Temp"))
		DoWindow/F RT_TempGraph
		anyWindows = (anyWindows %| V_Flag)
	endif
	if (!(AnyWindows))							// None of the windows found -- user may have killed them -- let's redraw windows
		PM_RT_Prepare_Waves_n_Graphs(0)
		PM_SortOutXAxes(1)
	endif

	DoWindow/F MultiPatch_ShowInputs

End

//////////////////////////////////////////////////////////////////////////////////
//// Resize the plots that are related to the RT PM procedures

Function PM_RT_ResizeThePlotsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable		WinX = 392
	Variable		WinY = 44+16
	Variable		WinYSp = 160
	Variable		WinHeight = WinYSp-32
	Variable		WinWidth = 415
	Variable		i
	Variable		LargeX = 8
	Variable		LargeWidth = 820//960
	Variable		LargeHeight = 160
	
	NVAR		SizeMode = root:MP:PM_Data:SizeMode
	
	if (SizeMode)
		SizeMode = 0
		WinX = LargeX
		WinWidth = LargeWidth
		WinHeight = LargeHeight
	else
		SizeMode = 1
	endif
		
	
	i = 0
	DoWindow RT_SealTestGraph
	if (V_Flag)
		DoWindow/F RT_SealTestGraph
		MoveWindow WinX,WinY+WinYSp*i,WinX+WinWidth,WinY+WinHeight+WinYSp*i	
		DoXOPIdle
	endif
	i += 1

	DoWindow RT_VmGraph
	if (V_Flag)
		DoWindow/F RT_VmGraph
		MoveWindow WinX,WinY+WinYSp*i,WinX+WinWidth,WinY+WinHeight+WinYSp*i	
		DoXOPIdle
	endif
	i += 1

	DoWindow RT_EPSPGraph
	if (V_Flag)
		DoWindow/F RT_EPSPGraph
		if (!SizeMode)
			MoveWindow 11,410,560,660
		else
			MoveWindow WinX,WinY+WinYSp*i,WinX+WinWidth,WinY+WinHeight+WinYSp*i	
		endif
		DoXOPIdle
	endif
	i += 1

	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			DoWindow RT_TempGraph
			if (V_Flag)
				DoWindow/F RT_TempGraph
				MoveWindow WinX,WinY+WinYSp*i,WinX+WinWidth,WinY+WinHeight+WinYSp*i	
				DoXOPIdle
			endif
		endif
	endif

	if (Exists("Warner_Temp"))
		DoWindow RT_TempGraph
		if (V_Flag)
			DoWindow/F RT_TempGraph
			MoveWindow WinX,WinY+WinYSp*i,WinX+WinWidth,WinY+WinHeight+WinYSp*i	
			DoXOPIdle
		endif
	endif

	DoWindow/F RT_EPSPGraph
	DoWindow/F MultiPatch_ShowInputs
	DoXOPIdle

End

//////////////////////////////////////////////////////////////////////////////////
//// Change appearance of the plots

Function PM_RT_AppearanceModeProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable	i,j,k
	String		WaveStr
	
	NVAR		AppearanceMode = 			root:MP:PM_Data:AppearanceMode
	
	WAVE		ChannelColor_R = 			root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = 			root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = 			root:MP:IO_Data:ChannelColor_B
	
	NVAR		RT_EPSPUseGrab =			root:MP:PM_Data:RT_EPSPUseGrab 			// Use manually positioned EPSPs?
	NVAR		RT_EPSPUseMatrix =			root:MP:PM_Data:RT_EPSPUseMatrix 	// Use automatically positioned EPSPs?

	WAVE		Conn_Matrix =			root:MP:PM_Data:Conn_Matrix					// Connectivity matrix describing which cells are connected to which

	NVAR			RT_nPlotRepeats = root:MP:PM_Data:RT_nPlotRepeats
	WAVE			RT_PatternSuffixWave													// Keep track of all old pattern runs by remembering the timestamp
	Variable		nPlotRepeatsAdjusted = RT_nPlotRepeats
	Variable		nPriorRuns = numpnts(RT_PatternSuffixWave)					// This many prior runs have been stored
	if (RT_nPlotRepeats>nPriorRuns)													// Do not try to plot more prior runs than are available to plot
		nPlotRepeatsAdjusted = nPriorRuns
	endif
	String	currTrace,currEntry,currTimeStr
	Variable	currMode,currTimeStamp
	Variable	nWaves,ii,jj,kk,lastjj,countDownFromLastRun

	if (!(StringMatch(ctrlName,"NoCountUp")))
		AppearanceMode += 1
		if (AppearanceMode>2)
			AppearanceMode = 0
		endif
		Print "\t\tChanging graph appearance -- mode =",AppearanceMode
	endif
	
	if (AppearanceMode==1)
		DoWindow RT_SealTestGraph
		if (V_flag)
			ModifyGraph/W=RT_SealTestGraph/Z msize=3,marker=19
			ModifyGraph/W=RT_SealTestGraph/Z useMrkStrokeRGB=1
		endif
		DoWindow RT_VmGraph
		if (V_flag)
			ModifyGraph/W=RT_VmGraph/Z msize=3,marker=19
			ModifyGraph/W=RT_VmGraph/Z useMrkStrokeRGB=1
		endif
		DoWindow RT_EPSPGraph
		if (V_flag)
			ModifyGraph/W=RT_EPSPGraph/Z msize=3
			ModifyGraph/W=RT_EPSPGraph/Z useMrkStrokeRGB=1
		endif
		
		i = 0
		do
	
			DoWindow RT_SealTestGraph
			if (V_flag)
				WaveStr = "RT_SealtestWave"+num2str(i+1)
				ModifyGraph/W=RT_SealTestGraph/Z RGB($WaveStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
			endif
	
			DoWindow RT_VmGraph
			if (V_flag)
				WaveStr = "RT_VmImWave"+num2str(i+1)
				ModifyGraph/W=RT_VmGraph/Z RGB($WaveStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
			endif
	
			DoWindow RT_EPSPGraph
			if (V_flag)
				if (RT_EPSPUseGrab)
					WaveStr = "RT_EPSPWave"+num2str(i+1)
					ModifyGraph/W=RT_EPSPGraph/Z RGB($WaveStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
					ModifyGraph/W=RT_EPSPGraph/Z marker($WaveStr)=19
					ModifyGraph/W=RT_EPSPGraph/Z mSize($WaveStr)=3
				endif
				if (RT_EPSPUseMatrix)
					j = 0
					k = 0
					do
						if (Conn_Matrix[j][i])
							WaveStr = "RT_EPSPMatrix"+num2str(j+1)+num2str(i+1)
							ModifyGraph/W=RT_EPSPGraph/Z RGB($WaveStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
							ModifyGraph/W=RT_EPSPGraph/Z marker($WaveStr)=(16+k)
							ModifyGraph/W=RT_EPSPGraph/Z mSize($WaveStr)=3
							k += 1
						endif
						j += 1
					while (j<4)
				endif
			endif
	
			i += 1
		while (i<4)
		
		// Modify appearance of input resistance and membrane potential / holding current from previous runs
		if (nPlotRepeatsAdjusted>0)
			k = 0
			countDownFromLastRun = nPriorRuns-1
			do
				currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
				currTimeStr = PM_DateTime2String(currTimeStamp)	
				i = 0
				do
					WaveStr = "RT_SealTestWave"+num2str(i+1)+"_"+currTimeStr
					if (Exists(WaveStr))
						ModifyGraph/W=RT_SealTestGraph/Z RGB($WaveStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
					endif
					WaveStr = "RT_VmImWave"+num2str(i+1)+"_"+currTimeStr
					if (Exists(WaveStr))
						ModifyGraph/W=RT_VmGraph/Z RGB($WaveStr)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
					endif
					i += 1
				while(i<4)
				countDownFromLastRun -= 1
				k += 1
			while(k<nPlotRepeatsAdjusted)
		endif
		
		// Modify appearance of responses from previous runs
		if (nPlotRepeatsAdjusted>0)
			k = 0
			countDownFromLastRun = nPriorRuns-1
			do
				currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
				currTimeStr = PM_DateTime2String(currTimeStamp)	
				SVAR	EPSPwaveList = $("PM_RT_EPSPwaveList_"+currTimeStr)
				nWaves = ItemsInList(EPSPwaveList)
				if (nWaves>0)
					i = 0
					kk = 0
					jj = -100
					do
						currEntry = StringFromList(i,EPSPwaveList)
						currTrace = StringFromList(0,currEntry,",")
						currMode = Str2Num(StringFromList(1,currEntry,","))
						if (StringMatch(currTrace[0,12],"RT_EPSPMatrix"))		// This is a connectivity matrix trace
							ii = str2num(currTrace[13,13])-1
							lastjj = jj
							jj = str2num(currTrace[14,14])-1
							if (jj==lastjj)
								kk += 1
							else
								kk = 0
							endif
							ModifyGraph/W=RT_EPSPGraph/Z RGB($currTrace)=(ChannelColor_R[jj],ChannelColor_G[jj],ChannelColor_B[jj])
							ModifyGraph/W=RT_EPSPGraph/Z marker($currTrace)=(16+kk)
							ModifyGraph/W=RT_EPSPGraph/Z mSize($currTrace)=3
						else																	// This is a manual grab trace
							ii = str2num(currTrace[11,11])-1
							ModifyGraph/W=RT_EPSPGraph/Z RGB($currTrace)=(ChannelColor_R[ii],ChannelColor_G[ii],ChannelColor_B[ii])
							ModifyGraph/W=RT_EPSPGraph/Z marker($currTrace)=19
							ModifyGraph/W=RT_EPSPGraph/Z mSize($currTrace)=3
						endif
						i += 1
					while(i<nWaves)
				endif
				countDownFromLastRun -= 1
				k += 1
			while(k<nPlotRepeatsAdjusted)
		endif

	else

		if (AppearanceMode==2)

			DoWindow RT_SealTestGraph
			if (V_flag)
				ModifyGraph/W=RT_SealTestGraph/Z useMrkStrokeRGB=0
			endif
			DoWindow RT_VmGraph
			if (V_flag)
				ModifyGraph/W=RT_VmGraph/Z useMrkStrokeRGB=0
			endif
			DoWindow RT_EPSPGraph
			if (V_flag)
				ModifyGraph/W=RT_EPSPGraph/Z useMrkStrokeRGB=0
			endif

			i = 0
			do
		
				DoWindow RT_SealTestGraph
				if (V_flag)
					WaveStr = "RT_SealtestWave"+num2str(i+1)
					ModifyGraph/W=RT_SealTestGraph/Z RGB($WaveStr)=(65535*(3-i)/3,0,65535*i/3),Marker($WaveStr)=19,mSize=2
				endif

				DoWindow RT_VmGraph
				if (V_flag)
					WaveStr = "RT_VmImWave"+num2str(i+1)
					ModifyGraph/W=RT_VmGraph/Z RGB($WaveStr)=(65535*(3-i)/3,0,65535*i/3),Marker($WaveStr)=19,mSize=2
				endif
		
				DoWindow RT_EPSPGraph
				if (V_flag)
					if (RT_EPSPUseGrab)
						WaveStr = "RT_EPSPWave"+num2str(i+1)
						ModifyGraph/W=RT_EPSPGraph/Z RGB($WaveStr)=(65535*(3-i)/3,0,65535*i/3),Marker($WaveStr)=19
						ModifyGraph/W=RT_EPSPGraph/Z mSize($WaveStr)=2
					endif
					if (RT_EPSPUseMatrix)
						j = 0
						k = 0
						do
							if (Conn_Matrix[j][i])
								WaveStr = "RT_EPSPMatrix"+num2str(j+1)+num2str(i+1)
								ModifyGraph/W=RT_EPSPGraph/Z RGB($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
								ModifyGraph/W=RT_EPSPGraph/Z marker($WaveStr)=(16+k)
								ModifyGraph/W=RT_EPSPGraph/Z mSize($WaveStr)=2
								k += 1
							endif
							j += 1
						while (j<4)
					endif
				endif
		
				i += 1
			while (i<4)
		
			// Modify appearance of input resistance and membrane potential / holding current from previous runs
			if (nPlotRepeatsAdjusted>0)
				k = 0
				countDownFromLastRun = nPriorRuns-1
				do
					currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
					currTimeStr = PM_DateTime2String(currTimeStamp)	
					i = 0
					do
						WaveStr = "RT_SealTestWave"+num2str(i+1)+"_"+currTimeStr
						if (Exists(WaveStr))
							ModifyGraph/W=RT_SealTestGraph/Z RGB($WaveStr)=(65535*(3-i)/3,0,65535*i/3),Marker($WaveStr)=19,mSize=2
						endif
						WaveStr = "RT_VmImWave"+num2str(i+1)+"_"+currTimeStr
						if (Exists(WaveStr))
							ModifyGraph/W=RT_VmGraph/Z RGB($WaveStr)=(65535*(3-i)/3,0,65535*i/3),Marker($WaveStr)=19,mSize=2
						endif
						i += 1
					while(i<4)
					countDownFromLastRun -= 1
					k += 1
				while(k<nPlotRepeatsAdjusted)
			endif
	
			// Modify appearance of responses from previous runs
			if (nPlotRepeatsAdjusted>0)
				k = 0
				countDownFromLastRun = nPriorRuns-1
				do
					currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
					currTimeStr = PM_DateTime2String(currTimeStamp)	
					SVAR	EPSPwaveList = $("PM_RT_EPSPwaveList_"+currTimeStr)
					nWaves = ItemsInList(EPSPwaveList)
					if (nWaves>0)
						i = 0
						kk = 0
						jj = -100
						do
							currEntry = StringFromList(i,EPSPwaveList)
							currTrace = StringFromList(0,currEntry,",")
							currMode = Str2Num(StringFromList(1,currEntry,","))
							if (StringMatch(currTrace[0,12],"RT_EPSPMatrix"))		// This is a connectivity matrix trace
								ii = str2num(currTrace[13,13])-1
								lastjj = jj
								jj = str2num(currTrace[14,14])-1
								if (jj==lastjj)
									kk += 1
								else
									kk = 0
								endif
								ModifyGraph/W=RT_EPSPGraph/Z RGB($currTrace)=(65535*(3-jj)/3,0,65535*jj/3)
								ModifyGraph/W=RT_EPSPGraph/Z marker($currTrace)=(16+kk)
								ModifyGraph/W=RT_EPSPGraph/Z mSize($currTrace)=2
							else																	// This is a manual grab trace
								ii = str2num(currTrace[11,11])-1
								ModifyGraph/W=RT_EPSPGraph/Z RGB($currTrace)=(65535*(3-ii)/3,0,65535*ii/3),Marker($currTrace)=19
								ModifyGraph/W=RT_EPSPGraph/Z mSize($currTrace)=2
							endif
							i += 1
						while(i<nWaves)
					endif
					countDownFromLastRun -= 1
					k += 1
				while(k<nPlotRepeatsAdjusted)
			endif

		else				// Appearance mode 0 here
		
			i = 0
			do
		
				DoWindow RT_SealTestGraph
				if (V_flag)
					WaveStr = "RT_SealtestWave"+num2str(i+1)
					ModifyGraph/W=RT_SealTestGraph/Z RGB=(0,0,0),Marker($WaveStr)=i,mSize=1
				endif
		
				DoWindow RT_VmGraph
				if (V_flag)
					WaveStr = "RT_VmImWave"+num2str(i+1)
					ModifyGraph/W=RT_VmGraph/Z RGB=(0,0,0),Marker($WaveStr)=i,mSize=1
				endif
		
				DoWindow RT_EPSPGraph
				if (V_flag)
					if (RT_EPSPUseGrab)
						WaveStr = "RT_EPSPWave"+num2str(i+1)
						ModifyGraph/W=RT_EPSPGraph/Z RGB($WaveStr)=(0,0,0),Marker($WaveStr)=i,mSize($WaveStr)=1
					endif
					if (RT_EPSPUseMatrix)
						j = 0
						k = 0
						do
							if (Conn_Matrix[j][i])
								WaveStr = "RT_EPSPMatrix"+num2str(j+1)+num2str(i+1)
								ModifyGraph/W=RT_EPSPGraph/Z RGB($WaveStr)=(0,0,0)
								ModifyGraph/W=RT_EPSPGraph/Z marker($WaveStr)=(16+k)
								ModifyGraph/W=RT_EPSPGraph/Z mSize($WaveStr)=1
								k += 1
							endif
							j += 1
						while (j<4)
					endif
				endif
		
				i += 1
			while (i<4)
		
			// Modify appearance of input resistance and membrane potential / holding current from previous runs
			if (nPlotRepeatsAdjusted>0)
				k = 0
				countDownFromLastRun = nPriorRuns-1
				do
					currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
					currTimeStr = PM_DateTime2String(currTimeStamp)	
					i = 0
					do
						WaveStr = "RT_SealTestWave"+num2str(i+1)+"_"+currTimeStr
						if (Exists(WaveStr))
							ModifyGraph/W=RT_SealTestGraph/Z RGB=(0,0,0),Marker($WaveStr)=i,mSize=1
						endif
						WaveStr = "RT_VmImWave"+num2str(i+1)+"_"+currTimeStr
						if (Exists(WaveStr))
							ModifyGraph/W=RT_VmGraph/Z RGB=(0,0,0),Marker($WaveStr)=i,mSize=1
						endif
						i += 1
					while(i<4)
					countDownFromLastRun -= 1
					k += 1
				while(k<nPlotRepeatsAdjusted)
			endif
	
			// Modify appearance of responses from previous runs
			if (nPlotRepeatsAdjusted>0)
				k = 0
				countDownFromLastRun = nPriorRuns-1
				do
					currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
					currTimeStr = PM_DateTime2String(currTimeStamp)	
					SVAR	EPSPwaveList = $("PM_RT_EPSPwaveList_"+currTimeStr)
					nWaves = ItemsInList(EPSPwaveList)
					if (nWaves>0)
						i = 0
						kk = 0
						jj = -100
						do
							currEntry = StringFromList(i,EPSPwaveList)
							currTrace = StringFromList(0,currEntry,",")
							currMode = Str2Num(StringFromList(1,currEntry,","))
							if (StringMatch(currTrace[0,12],"RT_EPSPMatrix"))		// This is a connectivity matrix trace
								ii = str2num(currTrace[13,13])-1
								lastjj = jj
								jj = str2num(currTrace[14,14])-1
								if (jj==lastjj)
									kk += 1
								else
									kk = 0
								endif
								ModifyGraph/W=RT_EPSPGraph/Z RGB($currTrace)=(0,0,0)
								ModifyGraph/W=RT_EPSPGraph/Z marker($currTrace)=(16+kk)
								ModifyGraph/W=RT_EPSPGraph/Z mSize($currTrace)=1
							else																	// This is a manual grab trace
								ii = str2num(currTrace[11,11])-1
								ModifyGraph/W=RT_EPSPGraph/Z RGB($currTrace)=(0,0,0),Marker($currTrace)=ii,mSize($currTrace)=1
							endif
							i += 1
						while(i<nWaves)
					endif
					countDownFromLastRun -= 1
					k += 1
				while(k<nPlotRepeatsAdjusted)
			endif

		endif

	endif

	DoXOPIdle

End

//////////////////////////////////////////////////////////////////////////////////
//// This procedure is used for the preparation of realtime analysis parameters, waves, etc

Function PM_RT_Prepare()

	Variable		i

	NVAR			RT_FirstHalfEnds =			root:MP:PM_Data:RT_FirstHalfEnds		// Keep track of where the first half of the first baseline ends
	NVAR			NRepeats1 =				root:MP:PM_Data:NRepeats1			// The number of repeats of the first step of the pattern (i.e. the baseline)
	
	//// To be used to estimate the stability of the baseline
	RT_FirstHalfEnds = ceil(NRepeats1/2)

	//// Make waves and graphs
	PM_RT_Prepare_Waves_n_Graphs(1)
	
End
	
//////////////////////////////////////////////////////////////////////////////////
//// List time stamps of prior pattern runs that have been stored
//// (only used for debugging purposes)

Function RT_ListPriorRuns()

	WAVE		RT_PatternSuffixWave

	Variable n = numpnts(RT_PatternSuffixWave)
	Variable i = n-1
	do
		print JT_num2digstr(3,i+1)+"\t-\t"+PM_DateTime2String(RT_PatternSuffixWave[i])
		i -= 1
	while (i>=0)

End

//////////////////////////////////////////////////////////////////////////////////
//// Make the waves and the graphs for the realtime analysis

Function PM_RT_Prepare_Waves_n_Graphs(MakeWaves)
	Variable		MakeWaves									// Boolean: Make new waves, otherwise assume they already exist

	String		LegendStr
	String		LegendStrInit = "\\Z08"
	String		WaveStr
	Variable		i,j,k
	Variable		First

	NVAR			RT_nPlotRepeats = root:MP:PM_Data:RT_nPlotRepeats
	WAVE			RT_PatternSuffixWave													// Keep track of all old pattern runs by remembering the timestamp
	Variable		nPlotRepeatsAdjusted = RT_nPlotRepeats
	Variable		nPriorRuns = numpnts(RT_PatternSuffixWave)					// This many prior runs have been stored
	if (RT_nPlotRepeats>nPriorRuns)													// Do not try to plot more prior runs than are available to plot
		nPlotRepeatsAdjusted = nPriorRuns
	endif

	Variable		NTotIter															// Total number of iterations in pattern
	
	Variable		WinX = 392
	Variable		WinY = 44+16
	Variable		WinYSp = 160
	Variable		WinHeight = WinYSp-32
	Variable		WinWidth = 415
	Variable		theLeftAxis = 0
	Variable		theRightAxis = 0
	
	NVAR			WorkVar =					root:MP:PM_Data:WorkVar
	NVAR			NSteps = 					root:MP:PM_Data:NSteps				// Number of steps in pattern
	WAVE			VClampWave =				root:MP:IO_Data:VClampWave			// Boolean: Channel is in voltage clamp or in current clamp?
	
	NVAR			RT_SealTestCheck =			root:MP:PM_Data:RT_SealTestOnOff		// Realtime sealtest analysis on or off?
	NVAR			RT_VmCheck =				root:MP:PM_Data:RT_VmOnOff			// Realtime membrane potential analysis on or off?
	NVAR			RT_EPSPCheck =			root:MP:PM_Data:RT_EPSPOnOff			// Realtime EPSP analysis on or off?
	NVAR			RT_EPSPUseGrab =			root:MP:PM_Data:RT_EPSPUseGrab	// Use manually positioned EPSPs?
	NVAR			RT_EPSPUseMatrix =			root:MP:PM_Data:RT_EPSPUseMatrix // Use automatically positioned EPSPs?
	WAVE			UseInputFlags =				root:MP:PM_Data:UseInputFlags			// These flags keep track of whether an input channel is being used during a pattern
	
	WAVE			ST_ChannelsChosen =		root:MP:ST_Data:ST_ChannelsChosen	// Channels chosen in ST creator

	WAVE			Conn_Matrix =			root:MP:PM_Data:Conn_Matrix			// Connectivity matrix describing which cells are connected to which
	NVAR			SizeMode = 				root:MP:PM_Data:SizeMode
	SizeMode = 1

	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	String	currTrace,currEntry,currTimeStr,currNote
	Variable	currMode,currTimeStamp
	Variable	nWaves,ii,jj,countDownFromLastRun
	Variable	xOffs

	//// Figure out the total number of iterations in the pattern
	NTotIter = 0
	i = 0
	do
		NVAR	NRepsInThisStep = $("root:MP:PM_Data:NRepeats"+num2str(i+1))
		NTotIter += NRepsInThisStep
		i += 1
	while (i<NSteps)
	
	//// Make the necessary waves and plots
	LegendStr = LegendStrInit
	//// Input resistance ////
	if (RT_SealTestCheck)
		DoWindow/K RT_SealTestGraph
		First = 1
		i = 0
		do
			if (UseInputFlags[i])
				WaveStr = "RT_SealTestWave"+num2str(i+1)
				WAVE	w = $WaveStr
				if (MakeWaves)
					make/O/N=(NTotIter) $WaveStr
					w = 0
				endif
				if (MakeWaves)
					ProduceUnitsOnYAxis(WaveStr,"Ohm")
				endif
				if (First)
					Display/W=(WinX,WinY,WinX+WinWidth,WinY+WinHeight) $WaveStr as "Input resistance"
					DoWindow/C RT_SealTestGraph
					ControlBar 22
					Button CloseThePlotsButton,pos={0,1},size={18,18},proc=PM_RT_CloseThePlotsProc,title="X",fSize=11,font="Arial"
					Button ResizeTheGraphsButton,pos={22,1},size={18,18},proc=PM_RT_ResizeThePlotsProc,title="R",fSize=11,font="Arial"
					Button Kill1Button,pos={22*2+28*0,1},size={24,18},proc=PM_RT_KillRTTracesProc_1,title="K1",fSize=11,font="Arial"//,fcolor=(ChannelColor_R[0],ChannelColor_G[0],ChannelColor_B[0])
					Button Kill2Button,pos={22*2+28*1,1},size={24,18},proc=PM_RT_KillRTTracesProc_1,title="K2",fSize=11,font="Arial"
					Button Kill3Button,pos={22*2+28*2,1},size={24,18},proc=PM_RT_KillRTTracesProc_1,title="K3",fSize=11,font="Arial"
					Button Kill4Button,pos={22*2+28*3,1},size={24,18},proc=PM_RT_KillRTTracesProc_1,title="K4",fSize=11,font="Arial"
					Button LineMarkerButton,pos={22*2+28*4,1},size={40,18},proc=PM_RT_LineMarkerProc,title="Mark",fSize=11,font="Arial"
					Button AutoYButton,pos={22*2+28*4+44,1},size={40,18},proc=PM_RT_AutoYProc,title="AutoY",fSize=11,font="Arial"
					ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
					ModifyGraph lstyle($WaveStr)=i
					ModifyGraph marker($WaveStr)=i
					First = 0
				else
					AppendToGraph $WaveStr
					ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
					ModifyGraph lstyle($WaveStr)=i
					ModifyGraph marker($WaveStr)=i
					LegendStr = LegendStr+"\r"
				endif
				LegendStr = LegendStr+"\\s("+WaveStr+")Ch#"+num2str(i+1)
			endif
			i += 1
		while (i<4)
		// Add input resistance plots from previous runs
		xOffs = 0
		if (nPlotRepeatsAdjusted>0)
			k = 0
			countDownFromLastRun = nPriorRuns-1
			do
				currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
				currTimeStr = PM_DateTime2String(currTimeStamp)	
				First = 1
				i = 0
				do
					SetDrawEnv xcoord=bottom,linethick= 1.00,dash=1
					WaveStr = "RT_SealTestWave"+num2str(i+1)+"_"+currTimeStr
					if (Exists(WaveStr))
						if (First)
							First = 0
							DrawLine xOffs-0.5,1,xOffs-0.5,0
							xOffs -= numpnts($(WaveStr))
						endif
						AppendToGraph $WaveStr
						ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
						ModifyGraph lstyle($WaveStr)=i
						ModifyGraph marker($WaveStr)=i
						ModifyGraph offset($WaveStr)={xOffs,0}
					endif
					i += 1
				while(i<4)
				countDownFromLastRun -= 1
				k += 1
			while(k<nPlotRepeatsAdjusted)
		endif
		// General
		if (!(First))
			ModifyGraph mode=3
			Label bottom "Iteration number"
			SetAxis/A/E=1 left
			ModifyGraph msize=1
			Textbox/N=Legend/A=LT LegendStr
		endif
	
	endif

	//// Membrane potential/current ////
	theLeftAxis = 0
	theRightAxis = 0
	LegendStr = LegendStrInit
	if (RT_VmCheck)
		DoWindow/K RT_VmGraph
		First = 1
		i = 0
		do
			if (UseInputFlags[i])
				WaveStr = "RT_VmImWave"+num2str(i+1)
				WAVE	w = $WaveStr
				if (MakeWaves)
					make/O/N=(NTotIter) $WaveStr
					w = 0
				endif
				if (VClampWave[i])														// Produce units on the y axis --> depends on v clamp or i clamp
					if (MakeWaves)
						ProduceUnitsOnYAxis(WaveStr,"A")
					endif
					theRightAxis = 1
				else
					if (MakeWaves)
						ProduceUnitsOnYAxis(WaveStr,"V")
					endif
					theLeftAxis = 1
				endif
				if (First)
					if (VClampWave[i])													// Use right axis if in voltage clamp, and left if in current clamp
						Display/W=(WinX,WinY+WinYSp*1,WinX+WinWidth,WinY+WinHeight+WinYSp*1)/R $WaveStr as "Membrane potential/current"
					else
						Display/W=(WinX,WinY+WinYSp*1,WinX+WinWidth,WinY+WinHeight+WinYSp*1)/L $WaveStr as "Membrane potential/current"
					endif
					DoWindow/C RT_VmGraph
					ControlBar 22
					Button CloseThePlotsButton,pos={0,1},size={18,18},proc=PM_RT_CloseThePlotsProc,title="X",fSize=11,font="Arial"
					Button ResizeTheGraphsButton,pos={22,1},size={18,18},proc=PM_RT_ResizeThePlotsProc,title="R",fSize=11,font="Arial"
					Button Kill1Button,pos={22*2+28*0,1},size={24,18},proc=PM_RT_KillRTTracesProc_2,title="K1",fSize=11,font="Arial"
					Button Kill2Button,pos={22*2+28*1,1},size={24,18},proc=PM_RT_KillRTTracesProc_2,title="K2",fSize=11,font="Arial"
					Button Kill3Button,pos={22*2+28*2,1},size={24,18},proc=PM_RT_KillRTTracesProc_2,title="K3",fSize=11,font="Arial"
					Button Kill4Button,pos={22*2+28*3,1},size={24,18},proc=PM_RT_KillRTTracesProc_2,title="K4",fSize=11,font="Arial"
					Button LineMarkerButton,pos={22*2+28*4,1},size={40,18},proc=PM_RT_LineMarkerProc,title="Mark",fSize=11,font="Arial"
					Button AutoYButton,pos={22*2+28*4+44,1},size={40,18},proc=PM_RT_AutoYProc,title="AutoY",fSize=11,font="Arial"
					ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
					ModifyGraph lstyle($WaveStr)=i
					ModifyGraph marker($WaveStr)=i
					First = 0
				else
					if (VClampWave[i])													// Use right axis if in voltage clamp, and left if in current clamp
						AppendToGraph/R $WaveStr
					else
						AppendToGraph/L $WaveStr
					endif
					ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
					ModifyGraph lstyle($WaveStr)=i
					ModifyGraph marker($WaveStr)=i
					LegendStr = LegendStr+"\r"
				endif
				LegendStr = LegendStr+"\\s("+WaveStr+")Ch#"+num2str(i+1)
			endif
			i += 1
		while (i<4)
		// Add membrane potential / holding current plots from previous runs
		xOffs = 0
		if (nPlotRepeatsAdjusted>0)
			k = 0
			countDownFromLastRun = nPriorRuns-1
			do
				currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
				currTimeStr = PM_DateTime2String(currTimeStamp)	
				First = 1
				i = 0
				do
					SetDrawEnv xcoord=bottom,linethick= 1.00,dash=1
					WaveStr = "RT_VmImWave"+num2str(i+1)+"_"+currTimeStr
					if (Exists(WaveStr))
						if (First)
							First = 0
							DrawLine xOffs-0.5,1,xOffs-0.5,0
							xOffs -= numpnts($(WaveStr))
						endif
						currNote = Note($(WaveStr))
						if (NumberByKey("vClamp",StringFromList(0,currNote),":"))
							AppendToGraph/R $WaveStr
						else
							AppendToGraph/L $WaveStr
						endif
						ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
						ModifyGraph lstyle($WaveStr)=i
						ModifyGraph marker($WaveStr)=i
						ModifyGraph offset($WaveStr)={xOffs,0}
					endif
					i += 1
				while(i<4)
				countDownFromLastRun -= 1
				k += 1
			while(k<nPlotRepeatsAdjusted)
		endif
		// General
		if (!(First))
			ModifyGraph mode=3
			Label bottom "Iteration number"
			ModifyGraph msize=1
			Textbox/N=Legend/A=LT LegendStr
			DoUpdate
			if (theRightAxis)
				SetAxis/A/N=1/E=0 right
			endif
			if (theLeftAxis)
				SetAxis/A/N=1/E=0 left
			endif
		endif
	endif

	//// Response Amplitude ////
	theLeftAxis = 0
	theRightAxis = 0
	LegendStr = LegendStrInit
	if (RT_EPSPCheck)
		// First make the graph
		DoWindow/K RT_EPSPGraph
		Make/O/N=(3) dummyEPSPWave,dummyTimeWave
		dummyEPSPWave = {0,nan,1e-18}
		dummyTimeWave = {0,nan,NTotIter}
		Display/W=(WinX,WinY+WinYSp*2,WinX+WinWidth,WinY+WinHeight+WinYSp*2) dummyEPSPWave vs dummyTimeWave as "EPSP amplitude"
		DoWindow/C RT_EPSPGraph
		ControlBar 22
		Button CloseThePlotsButton,pos={0,1},size={18,18},proc=PM_RT_CloseThePlotsProc,title="X",fSize=11,font="Arial"
		Button ResizeTheGraphsButton,pos={22,1},size={18,18},proc=PM_RT_ResizeThePlotsProc,title="R",fSize=11,font="Arial"
		Button SpreadTheTracesButton,pos={44,1},size={18,18},proc=PM_RT_SpreadTheTracesProc,title="S",fSize=11,font="Arial"
		Button CollectTheTracesButton,pos={66,1},size={18,18},proc=PM_RT_SpreadTheTracesProc,title="C",fSize=11,font="Arial"
		Button Kill1Button,pos={66+22+28*0,1},size={24,18},proc=PM_RT_KillRTTracesProc_3,title="K1",fSize=11,font="Arial"
		Button Kill2Button,pos={66+22+28*1,1},size={24,18},proc=PM_RT_KillRTTracesProc_3,title="K2",fSize=11,font="Arial"
		Button Kill3Button,pos={66+22+28*2,1},size={24,18},proc=PM_RT_KillRTTracesProc_3,title="K3",fSize=11,font="Arial"
		Button Kill4Button,pos={66+22+28*3,1},size={24,18},proc=PM_RT_KillRTTracesProc_3,title="K4",fSize=11,font="Arial"
		Button ChangeButton,pos={66+22+28*4,1},size={32,18},proc=PM_RT_ShowChangeProc,title="Chg",fSize=11,font="Arial"
		CheckBox Ch1Check pos={66+22+28*4+32+4+34*0,3},size={40,18},fsize=12,title="#1",value=ST_ChannelsChosen[0],fSize=11,font="Arial"
		CheckBox Ch2Check pos={66+22+28*4+32+4+34*1,3},size={40,18},fsize=12,title="#2",value=ST_ChannelsChosen[1],fSize=11,font="Arial"
		CheckBox Ch3Check pos={66+22+28*4+32+4+34*2,3},size={40,18},fsize=12,title="#3",value=ST_ChannelsChosen[2],fSize=11,font="Arial"
		CheckBox Ch4Check pos={66+22+28*4+32+4+34*3,3},size={40,18},fsize=12,title="#4",value=ST_ChannelsChosen[3],fSize=11,font="Arial"
		if (!(RT_EPSPUseGrab))
			Button Kill1Button,disable=2
			Button Kill2Button,disable=2
			Button Kill3Button,disable=2
			Button Kill4Button,disable=2
			CheckBox Ch1Check,disable=2
			CheckBox Ch2Check,disable=2
			CheckBox Ch3Check,disable=2
			CheckBox Ch4Check,disable=2
		endif
		Button LineMarkerButton,pos={66+22+28*4+32+4+34*4,1},size={40,18},proc=PM_RT_LineMarkerProc,title="Mark",fSize=11,font="Arial"
		Button AutoYButton,pos={66+22+28*4+32+4+34*4+44,1},size={40,18},proc=PM_RT_AutoYProc,title="AutoY",fSize=11,font="Arial"
		// Then make the waves for the manually positioned EPSP positions
		if (RT_EPSPUseGrab)
			i = 0
			do
				if (UseInputFlags[i])
					WaveStr = "RT_EPSPWave"+num2str(i+1)
					WAVE/z		w = $WaveStr
					if (MakeWaves)
						make/O/N=(NTotIter) $WaveStr
						w = 0
						if (VClampWave[i])														// Use right axis if in voltage clamp, and left if in current clamp
							ProduceUnitsOnYAxis(WaveStr,"A")
						else
							ProduceUnitsOnYAxis(WaveStr,"V")
						endif
					endif
					if (VClampWave[i])													// Produce units on the y axis --> depends on v clamp or i clamp
						AppendToGraph/R $WaveStr
					else
						AppendToGraph/L $WaveStr
					endif
					ModifyGraph rgb($WaveStr)=(65535*(3-i)/3,0,65535*i/3)
					ModifyGraph lstyle($WaveStr)=i
					ModifyGraph marker($WaveStr)=i
					LegendStr = LegendStr+"\\s("+WaveStr+")Ch#"+num2str(i+1)+"\r"
				endif
				i += 1
			while (i<4)
		endif
		// Then make the waves for the automatically positioned EPSP positions
		if (RT_EPSPUseMatrix)
			i = 0
			do
				j = 0
				do
					if (Conn_Matrix[i][j])
						WaveStr = "RT_EPSPMatrix"+num2str(i+1)+num2str(j+1)
						WAVE/Z		w = $WaveStr
						if (MakeWaves)
							make/O/N=(NTotIter) $WaveStr
							w = 0
							if (VClampWave[j])											// Use right axis if in voltage clamp, and left if in current clamp
								ProduceUnitsOnYAxis(WaveStr,"A")
							else
								ProduceUnitsOnYAxis(WaveStr,"V")
							endif
						endif
						if (VClampWave[j])											// Produce units on the y axis --> depends on v clamp or i clamp
							AppendToGraph/R $WaveStr
						else
							AppendToGraph/L $WaveStr
						endif
						ModifyGraph rgb($WaveStr)=(65535*(3-j)/3,0,65535*j/3)
						ModifyGraph lstyle($WaveStr)=j
						ModifyGraph marker($WaveStr)=j
						LegendStr = LegendStr+"\\s("+WaveStr+")"+num2str(i+1)+"->"+num2str(j+1)+"\r"
					endif
					j += 1
				while (j<4)
				i += 1
			while (i<4)
		endif
		// Add responses from previous runs
		xOffs = 0
		if (nPlotRepeatsAdjusted>0)
			k = 0
			countDownFromLastRun = nPriorRuns-1
			do
				currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
				currTimeStr = PM_DateTime2String(currTimeStamp)	
				SVAR	EPSPwaveList = $("PM_RT_EPSPwaveList_"+currTimeStr)
				nWaves = ItemsInList(EPSPwaveList)
				if (nWaves>0)
					i = 0
					do
						currEntry = StringFromList(i,EPSPwaveList)
						currTrace = StringFromList(0,currEntry,",")
						currMode = Str2Num(StringFromList(1,currEntry,","))
						SetDrawEnv xcoord=bottom,linethick= 1.00,dash=1
						if (i==0)
							DrawLine xOffs-0.5,1,xOffs-0.5,0
							xOffs -= numpnts($(currTrace))
						endif
						if (currMode)
							AppendToGraph/R $currTrace
						else
							AppendToGraph/L $currTrace
						endif
						ModifyGraph offset($currTrace)={xOffs,0}
						ModifyGraph rgb($currTrace)=(65535*(3-jj)/3,0,65535*jj/3)
						ModifyGraph lstyle($currTrace)=jj
						ModifyGraph marker($currTrace)=jj
						i += 1
					while(i<nWaves)
				endif
				countDownFromLastRun -= 1
				k += 1
			while(k<nPlotRepeatsAdjusted)
		endif
		// Final tweaks of the graph
		ModifyGraph mode=3
		Label bottom "Iteration number"
		if (NSteps>1)
			Variable	cumulSteps = 0
			i = 0
			do
				NVAR	currReps = $("root:MP:PM_Data:NRepeats"+num2str(i+1))
				cumulSteps += currReps
				SetDrawEnv xcoord= bottom,linethick= 1.00,dash= 11
				DrawLine cumulSteps-0.5,1,cumulSteps-0.5,0
				i += 1
			while(i<NSteps-1)
		endif
		ModifyGraph msize=1
		Variable LegendStrLen = StrLen(LegendStr)
		LegendStr = LegendStr[0,LegendStrLen-1-1]							// Remove last CR
		if (StrLen(LegendStr)>0)
			Textbox/N=Legend/A=LT LegendStr
		endif
		if (theRightAxis)
			SetAxis/A/N=1/E=0 right
		endif
		if (theLeftAxis)
			SetAxis/A/N=1/E=0 left
		endif
		ModifyGraph mode(dummyEPSPWave)=0
	endif
	
	//// Print out list of prior runs plotted ////
	// This has to be done outside of the plotting, since user may select or unselect specific types of plots
	xOffs = 0
	if (nPlotRepeatsAdjusted>0)
		k = 0
		countDownFromLastRun = nPriorRuns-1
		do
			currTimeStamp = RT_PatternSuffixWave[countDownFromLastRun]
			currTimeStr = PM_DateTime2String(currTimeStamp)	
			print "\t\tPlotting run "+JT_num2digstr(3,countDownFromLastRun+1)+" -- this is timestamp "+currTimeStr+"."
			countDownFromLastRun -= 1
			k += 1
		while(k<nPlotRepeatsAdjusted)
	endif

	//// Bath temperature ////
	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			if (MakeWaves)
				make/O/N=(NTotIter) RT_TempWave,RT_HeaterTempWave,RT_TargetTempWave
				RT_TempWave = NaN
				RT_HeaterTempWave = NaN
				RT_TargetTempWave = NaN
				ProduceUnitsOnYAxis("RT_TempWave","°C")
				ProduceUnitsOnYAxis("RT_HeaterTempWave","°C")
				ProduceUnitsOnYAxis("RT_TargetTempWave","°C")
			endif
			DoWindow/K RT_TempGraph
			Display/W=(WinX,WinY+WinYSp*3,WinX+WinWidth,WinY+WinHeight+WinYSp*3) as "Temperature"
			DoWindow/C RT_TempGraph
			ControlBar 22
			Button CloseThePlotsButton,pos={0,1},size={18,18},proc=PM_RT_CloseThePlotsProc,title="X",fSize=11,font="Arial"
			Button ResizeTheGraphsButton,pos={22,1},size={18,18},proc=PM_RT_ResizeThePlotsProc,title="R",fSize=11,font="Arial"
			Button LineMarkerButton,pos={44,1},size={40,18},proc=PM_RT_LineMarkerProc,title="Mark",fSize=11,font="Arial"
			Button ZoomLeftAxisButton,pos={88,1},size={44,18},proc=PM_RT_ZoomLeftAxisProc,title="ZoomY",fSize=11,font="Arial"
			AppendToGraph/R RT_TargetTempWave
			ModifyGraph mode(RT_TargetTempWave)=0,rgb(RT_TargetTempWave)=(65535/2,65535/2,65535/2)
			AppendToGraph/R RT_HeaterTempWave
			ModifyGraph mode(RT_HeaterTempWave)=0,rgb(RT_HeaterTempWave)=(0,0,0)
			AppendToGraph RT_TempWave
			
			ModifyGraph mode(RT_TempWave)=0
			ModifyGraph marker(RT_TempWave)=8,opaque(RT_TempWave)=1
			ModifyGraph lsize(RT_TempWave)=2
			SetAxis/A/N=1 left
			ModifyGraph grid(left)=2
			ModifyGraph manTick(left)={0,1,0,0},manMinor(left)={1,50}
			ModifyGraph nticks(right)=3//,manTick(right)=0
			ModifyGraph minor(right)=1
			Label left "\\s(RT_TempWave)\\U"
			Label right "\\s(RT_TargetTempWave)\\s(RT_HeaterTempWave)\\U"
			Label bottom "Iteration number"
			Legend/J/A=LT "\\Z08\\s(RT_TargetTempWave) Target\r\\s(RT_HeaterTempWave) Heater\r\\s(RT_TempWave) Bath"
		endif
	endif

	//// Bath temperature -- Warner Heater ////
	if (Exists("Warner_Temp"))
		if (MakeWaves)
			make/O/N=(NTotIter) RT_TempWave
			RT_TempWave = NaN
			ProduceUnitsOnYAxis("RT_TempWave","°C")
		endif
		DoWindow/K RT_TempGraph
		Display/W=(WinX,WinY+WinYSp*3,WinX+WinWidth,WinY+WinHeight+WinYSp*3) as "Temperature"
		DoWindow/C RT_TempGraph
		ControlBar 22
		Button CloseThePlotsButton,pos={0,1},size={18,18},proc=PM_RT_CloseThePlotsProc,title="X",fSize=11,font="Arial"
		Button ResizeTheGraphsButton,pos={22,1},size={18,18},proc=PM_RT_ResizeThePlotsProc,title="R",fSize=11,font="Arial"
		Button LineMarkerButton,pos={44,1},size={40,18},proc=PM_RT_LineMarkerProc,title="Mark",fSize=11,font="Arial"
		Button ZoomLeftAxisButton,pos={88,1},size={44,18},proc=PM_RT_ZoomLeftAxisProc,title="ZoomY",fSize=11,font="Arial"
		AppendToGraph RT_TempWave
		ModifyGraph mode(RT_TempWave)=0
		ModifyGraph marker(RT_TempWave)=8,opaque(RT_TempWave)=1
		ModifyGraph lsize(RT_TempWave)=2
		SetAxis/A/N=1 left
		ModifyGraph grid(left)=2
		ModifyGraph manTick(left)={0,1,0,0},manMinor(left)={1,50}
		Label left "\\s(RT_TempWave)\\U"
		Label bottom "Iteration number"
		Legend/J/A=LT "\\Z08\\s(RT_TempWave) Target"
	endif

	PM_RT_AppearanceModeProc("NoCountUp")

End

//////////////////////////////////////////////////////////////////////////////////
//// Kill traces in RT_SealTestGraph

Function PM_RT_KillRTTracesProc_1(ctrlName) : ButtonControl
	String		ctrlName

	Variable		ChNo = str2num(ctrlName[4,5])
	String		WaveStr = "RT_SealTestWave"+num2str(ChNo)
	
	RemoveFromGraph/Z $(WaveStr)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Kill traces in RT_VmGraph

Function PM_RT_KillRTTracesProc_2(ctrlName) : ButtonControl
	String		ctrlName

	Variable		ChNo = str2num(ctrlName[4,5])
	String		WaveStr = "RT_VmImWave"+num2str(ChNo)
	
	RemoveFromGraph/Z $(WaveStr)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Kill traces in RT_EPSPGraph

Function PM_RT_KillRTTracesProc_3(ctrlName) : ButtonControl
	String		ctrlName

	Variable		ChNo = str2num(ctrlName[4,5])
	String		WaveStr = "RT_EPSPWave"+num2str(ChNo)
	
	RemoveFromGraph/Z $(WaveStr)
	
End


//////////////////////////////////////////////////////////////////////////////////
//// Spread the traces in the EPSP wave graph

Function PM_RT_SpreadTheTracesProc(ctrlName) : ButtonControl
	String		ctrlName
	
	if (StringMatch(ctrlName,"SpreadTheTracesButton"))
		DoSpreadTracesInGraph ("RT_EPSPGraph",1)
	else
		DoSpreadTracesInGraph ("RT_EPSPGraph",0)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Make nice y axis range for top graph
//// Adopted this proc from J-Tools

Function PM_RT_AutoYProc(ctrlName) : ButtonControl
	String		ctrlName
	
	NVAR		TotalIterCounter =	 root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	
	String		Name = WinName(0,1)
	String		TraceList = TraceNameList("",";",1)		//WaveList("*",";","WIN:")
	Variable	nWaves = ItemsInList(TraceList)
	String		currWave
	String		AxisStr
	Variable	xMin
	Variable	xMax
	Variable	yMax
	Variable	yMin
	Variable	xOffset,yOffset
	Variable	i,j
	Variable	wHeight
	Variable	adj

	String		ListOfAxes = "left;right;"
	
	j = 0
	do
		AxisStr = StringFromList(j,ListOfAxes)
		xMin = 0
		xMax = TotalIterCounter-1
		yMax = -Inf
		yMin = Inf
		i = 0
		do
			currWave = StringFromList(i,TraceList)
			if (StringMatch(WhichYAxis(currWave),AxisStr))
				// print "\tWorking on:",currWave
				xOffset = ReadXOffset(currWave)
				yOffset = ReadYOffset(currWave)
				WaveStats/Q/R=(xMin-xOffset,xMax-xOffset)/Z $currWave
				if (yMax<V_max+yOffset)
					yMax = V_max+yOffset
				endif
				if (yMin>V_min+yOffset)
					yMin = V_min+yOffset
				endif
			endif
			i += 1
		while(i<nWaves)
		wHeight = 0
		adj = 0
		wHeight = yMax-yMin
		adj = 0.2*wHeight
		SetAxis/Z/W=$Name $AxisStr,yMin-adj,yMax+adj
		j += 1
	while (j<2)

End

//////////////////////////////////////////////////////////////////////////////////
//// Zoom left axis to target temperature range

Function PM_RT_ZoomLeftAxisProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable		yBottom = 31.5
	Variable		yTop = 34.5
	
	GetAxis/W=RT_TempGraph/Q left
	if (!((yTop==V_max) %& (yBottom==V_min)))
		SetAxis/W=RT_TempGraph left,yBottom,yTop
	else
		SetAxis/A/N=1 left
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Spread the traces in the EPSP wave graph

Function PM_RT_LineMarkerProc(ctrlName) : ButtonControl
	String		ctrlName
	
	NVAR		CurrentStep =			root:MP:PM_Data:CurrentStep
	NVAR		CurrISI =				root:MP:PM_Data:CurrISI
	NVAR		NSteps =				root:MP:PM_Data:NSteps
	NVAR		IterCounter =			root:MP:PM_Data:IterCounter				// Counts down the iterations in a particular step
	NVAR		DummyIterCounter = 	root:MP:PM_Data:DummyIterCounter		// Counts up the iterations in a particular step
	NVAR		TotalIterCounter =	 	root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning
	SVAR		PatternName = 			root:MP:PM_Data:PatternName

	NVAR		StartTicks =			root:MP:PM_Data:StartTicks				// The ticks counter when the pattern was started
	Variable	CurrTicks
	NVAR		ElapsedMins =			root:MP:PM_Data:ElapsedMins				// Number of minutes elapsed since the start of the recording
	NVAR		ElapsedSecs =			root:MP:PM_Data:ElapsedSecs				// Number of seconds (minus the above minutes) elapsed since the start of the recording

	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Adding marker lines to PatternMaker graphs\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\tTime is "+Time()+".\r"
	if (PatternRunning)
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern \""+PatternName+"\" is running at total iteration "+num2str(TotalIterCounter)+"\r"
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern is at step "+num2str(CurrentStep)+" (of "+num2str(NSteps)+") and at iteration "+num2str(DummyIterCounter)+" of that step.\r"
		CurrTicks = Ticks
		ElapsedMins = Floor((CurrTicks-StartTicks)/60.15/60)
		ElapsedSecs = Floor( ((CurrTicks-StartTicks)/60.15/60 - ElapsedMins )*60)
		Notebook Parameter_Log ruler=Normal, text="\t"+num2str(ElapsedMins)+" minutes and "+num2str(ElapsedSecs)+" seconds have elapsed since pattern begun.\r"
	endif
	Notebook Parameter_Log ruler=Normal, text="\r"

	AddLineMarker("RT_SealTestGraph")
	AddLineMarker("RT_VmGraph")
	AddLineMarker("RT_EPSPGraph")
	if (Exists("MM_HeaterExists"))
		NVAR/Z	MM_HeaterExists
		if (MM_HeaterExists)
			AddLineMarker("RT_TempGraph")
		endif
	endif

	if (Exists("Warner_Temp"))
		AddLineMarker("RT_TempGraph")
	endif

End

Function AddLineMarker(whichGraph)
	String		whichGraph

	NVAR		TotalIterCounter =	 root:MP:PM_Data:TotalIterCounter			// Counts up the total number of iterations for a pattern -- used for indexing data to be saved
	
	DoWindow/F $(whichGraph)
	
	SetDrawLayer UserBack
	SetDrawEnv xcoord= bottom,linefgc= (29524,0,58982),dash= 2
	DrawLine TotalIterCounter-0.5,0,TotalIterCounter-0.5,1
	SetDrawLayer UserFront

End

//////////////////////////////////////////////////////////////////////////////////
//// Grab the position of the peak of the EPSP based on the positions of the cursors

Function PM_RT_GrabEPSPProc(ctrlName) : ButtonControl
	String		ctrlName

	SVAR		WorkStr = 			root:MP:PM_Data:WorkStr
	WAVE		EPSPPosWave =		root:MP:PM_Data:EPSPPosWave			// EPSP start in trace

	String		TraceName
	Variable	BaseNameLength
	Variable	Found, Channel
	
	Variable	i
	
	TraceName = CsrWave(A)

	Found = 0
	i = 0
	do
		SVAR	sourceStr = $("root:MP:IO_Data:WaveNamesIn"+num2str(i+1))
		WorkStr = sourceStr
		BaseNameLength = StrLen(WorkStr)
		if ( (StringMatch(TraceName[0,BaseNameLength-1],WorkStr[0,BaseNameLength-1])) %| (StringMatch(TraceName,"Temp"+num2str(i+1))) )
			Channel = i+1
			print "--> EPSP was localized to channel #"+num2str(Channel)+" <--"
			i = Inf															// Found the channel to which the current EPSP position belongs!
			Found = 1
		endif
		i += 1
	while (i<4)
	if (!(Found))
		Beep;
		Print "Could not properly associate the EPSP position with an input channel! Are you sure you're operating on the right graph?"
		Print "You should be putting the ROUND cursor on one of the traces in the \"Acquired Waves\" plot."
	else
		print "\tStoring away EPSP position for use with real-time analysis. Position = "+num2str(xcsr(A))+" sec."
		EPSPPosWave[Channel-1] = xcsr(A)
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="New EPSP position\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r\tChannel #"+num2str(Channel)+" EPSP position at "+num2str(xcsr(A))+" seconds. Time is "+Time()+".\r\r"
	endif

End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Carry out the actual filtering
//// This function will filter any wave in the root that is passed as a string, but the assumption here is 
//// that only the Temp1-4 waves shown in the Acquired Waves window will be filtered. The data saved on 
//// the HD will thus not be filtered.

Function FilterThisWave(theWaveName)
	String		theWaveName
	
	WAVE			theWave = $theWaveName

	//// PARAMETERS FROM WAVECREATOR	
	NVAR			SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	//// Parameters for filtering postsynaptic sweeps before analysis
	NVAR			NotchFilterFlag = root:MP:PM_Data:PM_RT_NotchFilterFlag
	NVAR			LowPassFilterFlag = root:MP:PM_Data:PM_RT_LowPassFilterFlag
	NVAR			BoxFilterFlag = root:MP:PM_Data:PM_RT_BoxFilterFlag
	
	NVAR			BoxSize = root:MP:PM_Data:PM_RT_BoxSize
	NVAR			NotchFilter1 = root:MP:PM_Data:PM_RT_NotchFilter1
	NVAR			NotchFilter2 = root:MP:PM_Data:PM_RT_NotchFilter2
	NVAR			LowPassFilter = root:MP:PM_Data:PM_RT_LowPassFilter
	NVAR			LowPass_nPoles = root:MP:PM_Data:PM_RT_LowPass_nPoles

	Variable	initialCondition = theWave[0]

	if ((NotchFilterFlag) %| (LowPassFilterFlag))
		theWave -= initialCondition											// Adaptive filtering requires that starting point is at zero, roughly
	endif

	if (NotchFilterFlag)
		Variable	fNotch = (NotchFilter1+NotchFilter2)/2/SampleFreq
		Variable	notchQ = fNotch*SampleFreq/(NotchFilter2-NotchFilter1) // Large notchQ produces a filter that "rings" a lot.
		if (notchQ>75)
			print "WARNING! notchQ is larger than 75 --> you're notch filter settings are probably too tight."
		endif
		FilterIIR/N={fNotch,notchQ} theWave
	endif

	if (LowPassFilterFlag)
		FilterIIR/LO=(LowPassFilter/SampleFreq)/ORD=(LowPass_nPoles) theWave
	endif

	if ((NotchFilterFlag) %| (LowPassFilterFlag))
		theWave += initialCondition											// Set the baseline back to where it was
	endif

	if (BoxFilterFlag)
		Smooth/B BoxSize,theWave												// Simple box filtering does not care about initial conditions
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Set up real-time filtering of the temp waves

Function PM_RT_SetUpFilterProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			PM_RT_CreateFilterPanel()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the Filter Panel

Function PM_RT_CreateFilterPanel()

	NVAR			NotchFilterFlag = root:MP:PM_Data:PM_RT_NotchFilterFlag
	NVAR			LowPassFilterFlag = root:MP:PM_Data:PM_RT_LowPassFilterFlag
	NVAR			BoxFilterFlag = root:MP:PM_Data:PM_RT_BoxFilterFlag
	
	NVAR			BoxSize = root:MP:PM_Data:PM_RT_BoxSize
	NVAR			NotchFilter1 = root:MP:PM_Data:PM_RT_NotchFilter1
	NVAR			NotchFilter2 = root:MP:PM_Data:PM_RT_NotchFilter2
	NVAR			LowPassFilter = root:MP:PM_Data:PM_RT_LowPassFilter
	NVAR			LowPass_nPoles = root:MP:PM_Data:PM_RT_LowPass_nPoles

	Variable		ScSc = 72/ScreenResolution

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 420
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow PM_RT_FilterPanel
	if (V_flag)
		GetWindow PM_RT_FilterPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	else
		GetWindow MultiPatch_ShowInputs, wsize
		xPos = V_left/ScSc+150
		yPos = V_top/ScSc+70
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K PM_RT_FilterPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Filter Panel"
	DoWindow/C PM_RT_FilterPanel
	ModifyPanel/W=PM_RT_FilterPanel fixedSize=1
	
	xSkip = floor((Width-xMargin*2)/5)
	x = xMargin
	CheckBox NotchFilter,pos={x,y+4},size={xSkip-4,bHeight},title="Notch",value=NotchFilterFlag,fsize=fontSize,font="Arial",Proc=PM_RT_ToggleFilterProc
	x += xSkip
	SetVariable NotchFilter1SV,pos={x,y+3},size={xSkip*2-4,bHeight},title="fStart: ",value=NotchFilter1,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip*2
	SetVariable NotchFilter2SV,pos={x,y+3},size={xSkip*2-4,bHeight},title="fEnd: ",value=NotchFilter2,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip*2
	y += ySkip

	xSkip = floor((Width-xMargin*2)/5)
	x = xMargin
	CheckBox lowPassFilter,pos={x,y+4},size={xSkip-4,bHeight},title="Low-pass",value=LowPassFilterFlag,fsize=fontSize,font="Arial",Proc=PM_RT_ToggleFilterProc
	x += xSkip
	SetVariable LowPassFilterSV,pos={x,y+3},size={xSkip*2-4,bHeight},title="Freq: ",value=LowPassFilter,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip*2
	SetVariable LowPass_nPolesSV,pos={x,y+3},size={xSkip*2-4,bHeight},title="nPoles: ",value=LowPass_nPoles,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip*2
	y += ySkip
	
	xSkip = floor((Width-xMargin*2)/5)
	x = xMargin
	CheckBox BoxFilter,pos={x,y+4},size={xSkip-4,bHeight},title="Box",value=BoxFilterFlag,fsize=fontSize,font="Arial",Proc=PM_RT_ToggleFilterProc
	x += xSkip
	SetVariable BoxFilterSV,pos={x,y+3},size={xSkip*2-4,bHeight},title="Box size: ",value=BoxSize,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip*2
	Button CloseFilterPanelButton,pos={x,y},size={xSkip*2-4,bHeight},proc=PM_RT_CloseFilterPanel,title="Close this panel",fsize=fontSize,font="Arial"
	y += ySkip

	MoveWindow/W=PM_RT_FilterPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...

End

//////////////////////////////////////////////////////////////////////////////////
//// Silly toggle routine to keep the filter checkbox values up to date

Function PM_RT_ToggleFilterProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR			NotchFilterFlag = root:MP:PM_Data:PM_RT_NotchFilterFlag
	NVAR			LowPassFilterFlag = root:MP:PM_Data:PM_RT_LowPassFilterFlag
	NVAR			BoxFilterFlag = root:MP:PM_Data:PM_RT_BoxFilterFlag
	
	String		currState = ""
	
	currState += "Filter settings at "+time()+": "
	
	ControlInfo/W=PM_RT_FilterPanel NotchFilter
	NotchFilterFlag = V_Value
	currState += "Notch filter is "
	if (V_Value)
		currState += "ON; "
	else
		currState += "OFF; "
	endif

	ControlInfo/W=PM_RT_FilterPanel lowPassFilter
	LowPassFilterFlag = V_Value
	currState += "Low-pass filter is "
	if (V_Value)
		currState += "ON; "
	else
		currState += "OFF; "
	endif

	ControlInfo/W=PM_RT_FilterPanel BoxFilter
	BoxFilterFlag = V_Value
	currState += "Box filter is "
	if (V_Value)
		currState += "ON; "
	else
		currState += "OFF; "
	endif

	print currState

End

//////////////////////////////////////////////////////////////////////////////////
//// Close the Filter Panel

Function PM_RT_CloseFilterPanel(ctrlName) : ButtonControl
	String		ctrlName
	
	DoWindow/K PM_RT_FilterPanel

End


//////////////////////////////////////////////////////////////////////////////////
//// Show EPSP positions in MultiPatch_ShowInputs window

Function PM_RT_ShowEPSPPosProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	Variable	EraseInstead = 0
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
//		Print "\tYou pressed the Shift key."
		EraseInstead = 1
	endif

	switch( ba.eventCode )
		case 2: // mouse up
			if (EraseInstead)
				Button ShowEPSPPos,title="Clear",win=MultiPatch_ShowInputs//,fColor=(0,65535,0)
				SetDrawLayer/W=MultiPatch_ShowInputs/K UserBack
			else
				Button ShowEPSPPos,title="EPSP pos?",win=MultiPatch_ShowInputs//,fColor=(65535,65535,65535)
				PM_RT_DoShowEPSPPosProc()
			endif
			break
		case 5: // mouse enter
			if (EraseInstead)
				Button ShowEPSPPos,title="Clear",win=MultiPatch_ShowInputs//,fColor=(0,65535,0)
			else
				Button ShowEPSPPos,title="EPSP pos?",win=MultiPatch_ShowInputs//,fColor=(65535,65535,65535)
			endif
			break
		case 6: // mouse leave
			Button ShowEPSPPos,title="EPSP pos?",win=MultiPatch_ShowInputs//,fColor=(65535,65535,65535)
			break
	endswitch

	return 0
End

Function PM_RT_DoShowEPSPPosProc()

	NVAR		RT_EPSPOnOff =			root:MP:PM_Data:RT_EPSPOnOff		// Realtime EPSP analysis on or off?
	NVAR		RT_EPSPUseGrab =			root:MP:PM_Data:RT_EPSPUseGrab		// Use manual EPSPs?
	NVAR		RT_EPSPUseMatrix =			root:MP:PM_Data:RT_EPSPUseMatrix		// Use automatic EPSPs?

	WAVE		EPSPPosWave =			root:MP:PM_Data:EPSPPosWave			// EPSP start in trace
	NVAR		RT_EPSPLatency =	root:MP:PM_Data:RT_EPSPLatency			// EPSP peak latency [s]
	NVAR		RT_EPSPWidth =		root:MP:PM_Data:RT_EPSPWidth		// EPSP width in trace
	NVAR		RT_EPSPBaseStart =	root:MP:PM_Data:RT_EPSPBaseStart	// _Relative_ EPSP baseline start in trace
	NVAR		RT_EPSPBaseWidth =	root:MP:PM_Data:RT_EPSPBaseWidth	// EPSP baseline width in trace

	//// CONNECTIVITY
	WAVE		Conn_Matrix =			root:MP:PM_Data:Conn_Matrix			// Connectivity matrix describing which cells are connected to which
	WAVE		Pos_Matrix =			root:MP:PM_Data:Pos_Matrix				// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]

	WAVE		WaveWasAcq =			root:MP:FixAfterAcq:WaveWasAcq		// Flags that wave was used

	DoWindow/F MultiPatch_ShowInputs
	SetDrawLayer/W=MultiPatch_ShowInputs/K UserBack
	
	Variable	i,j
	
	if ( (RT_EPSPOnOff) %& (RT_EPSPUseGrab) )
		i = 0
		do
			if (EPSPPosWave[i]!=0)
				SetDrawLayer UserBack
				SetDrawEnv xcoord= bottom,ycoord= prel,dash= 11
				DrawRect EPSPPosWave[i],0,EPSPPosWave[i]+RT_EPSPWidth,1
				SetDrawEnv xcoord= bottom,ycoord= prel,dash= 11
				DrawRect EPSPPosWave[i]+RT_EPSPBaseStart,0.95,EPSPPosWave[i]+RT_EPSPBaseStart+RT_EPSPBaseWidth,0.90
			endif
			i += 1
		while(i<4)
	endif

	if ( (RT_EPSPOnOff) %& (RT_EPSPUseMatrix) )
		i = 0
		do
			j = 0
			do
				if (i!=j)
					if (Conn_Matrix[i][j])
						if (Pos_Matrix[i][j]!=-1)
							SetDrawLayer UserBack
							SetDrawEnv xcoord= bottom,ycoord= prel//,dash= 11
							DrawRect Pos_Matrix[i][j]+RT_EPSPLatency,0,Pos_Matrix[i][j]+RT_EPSPLatency+RT_EPSPWidth,1
							SetDrawEnv xcoord= bottom,ycoord= prel//,dash= 11
							DrawRect Pos_Matrix[i][j]+RT_EPSPBaseStart,1,Pos_Matrix[i][j]+RT_EPSPBaseStart+RT_EPSPBaseWidth,0.95
						endif
					endif
				endif
				j += 1
			while(j<4)
			i += 1
		while(i<4)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Take region of interest from the axes of the ShowInputs graph

Function PM_RT_TakeROIProc(ctrlName) : ButtonControl
	String		ctrlName

	WAVE		RT_ROI_x1 = root:MP:PM_Data:RT_ROI_x1
	WAVE		RT_ROI_x2 = root:MP:PM_Data:RT_ROI_x2
	WAVE		RT_ROI_y1 = root:MP:PM_Data:RT_ROI_y1
	WAVE		RT_ROI_y2 = root:MP:PM_Data:RT_ROI_y2
	WAVE		RT_ROI_yy1 = root:MP:PM_Data:RT_ROI_yy1	// KM 9/25/00
	WAVE		RT_ROI_yy2 = root:MP:PM_Data:RT_ROI_yy2

	Variable		ROI_No = str2num(ctrlName[3,3])
	Print "Grabbing ROI #",ROI_No
	
	DoWindow/F MultiPatch_ShowInputs
	if (V_Flag)
		GetAxis/Q bottom
		RT_ROI_x1[ROI_No-1] = V_min
		RT_ROI_x2[ROI_No-1] = V_max
//		print "\t -- ",V_min,V_max," -- "
		GetAxis/Q left
		if (V_flag==0)				// in case no left axis  KM 9/25/00
			RT_ROI_y1[ROI_No-1] = V_min
			RT_ROI_y2[ROI_No-1] = V_max
//			print " -- ",V_min,V_max," -- "
//		else
//			RT_ROI_y1[ROI_No-1] = NaN
//			RT_ROI_y2[ROI_No-1] = NaN
		endif
		GetAxis/Q right			// KM 9/25/00
		if (V_flag==0)
			RT_ROI_yy1[ROI_No-1] = V_min
			RT_ROI_yy2[ROI_No-1] = V_max
//			print " -- ",V_min,V_max," -- "
//		else
//			RT_ROI_yy1[ROI_No-1] = NaN
//			RT_ROI_yy2[ROI_No-1] = NaN
		endif
	else
		Abort "You must have the 'ShowInputs' plot open to invoke this command!"
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Automatic grab of regions of interest

Function PM_RT_AutoTakeROIProc(ctrlName) : ButtonControl
	String		ctrlName

	WAVE		RT_ROI_x1 = root:MP:PM_Data:RT_ROI_x1
	WAVE		RT_ROI_x2 = root:MP:PM_Data:RT_ROI_x2
	WAVE		RT_ROI_y1 = root:MP:PM_Data:RT_ROI_y1
	WAVE		RT_ROI_y2 = root:MP:PM_Data:RT_ROI_y2
	WAVE		RT_ROI_yy1 = root:MP:PM_Data:RT_ROI_yy1
	WAVE		RT_ROI_yy2 = root:MP:PM_Data:RT_ROI_yy2

	//// CONNECTIVITY
	WAVE		Conn_Matrix =			root:MP:PM_Data:Conn_Matrix			// Connectivity matrix describing which cells are connected to which
	WAVE		Pos_Matrix =			root:MP:PM_Data:Pos_Matrix				// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]
	
	Variable	winStart = 0.01
	Variable	winWid = 0.05
	
	Variable	i
	
	Print "Automatically generating Regions of Interest"
	Print "\t",Date(),Time()

	i = 0
	do
		if (Pos_Matrix[i][0]!=-1)
			RT_ROI_x1[i] = Pos_Matrix[i][0]-winStart
			RT_ROI_x2[i] = Pos_Matrix[i][0]+winWid-winStart
			RT_ROI_y1[i] = -0.071
			RT_ROI_y2[i] = -0.051
			RT_ROI_yy1[i] = -0.020
			RT_ROI_yy2[i] = 0.020
//		else
//			RT_ROI_x1[i] = NaN
//			RT_ROI_x2[i] = NaN
//			RT_ROI_y1[i] = NaN
//			RT_ROI_y2[i] = NaN
//			RT_ROI_yy1[i] = NaN
//			RT_ROI_yy2[i] = NaN
		endif
		i += 1
	while(i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle the Region-Of-Interest function on and off

Function PM_RT_GotoROIProc(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		PatternRunning = 			root:MP:PM_Data:PatternRunning	// Boolean: Is a pattern running?
	NVAR		RT_ROIOnOff = 				root:MP:PM_Data:RT_ROIOnOff	// Boolean: Use the Region-Of-Interest function?
	NVAR		RT_ROI_Slot = 				root:MP:PM_Data:RT_ROI_Slot	// Which ROI slot?

	WAVE		RT_ROI_x1 = 				root:MP:PM_Data:RT_ROI_x1		// Parameters that define the ROI
	WAVE		RT_ROI_x2 = 				root:MP:PM_Data:RT_ROI_x2
	WAVE		RT_ROI_y1 = 				root:MP:PM_Data:RT_ROI_y1
	WAVE		RT_ROI_y2 = 				root:MP:PM_Data:RT_ROI_y2
	WAVE		RT_ROI_yy1 = 				root:MP:PM_Data:RT_ROI_yy1		// KM 9/25/00
	WAVE		RT_ROI_yy2 = 				root:MP:PM_Data:RT_ROI_yy2
	
	Variable		ROI_No = str2num(ctrlName[3,3])
	RT_ROIOnOff  = (ROI_No>0)
	
//	if (StringMatch(ctrlName,"acqROI1Go"))
//		RT_ROIOnOff = 1
//		ROI_No = 1
//	endif

	if (RT_ROIOnOff)									// Zoom in to the region of interest, when a pattern is used, and when the user has chosen do to so
		DoWindow/F MultiPatch_ShowInputs
		SetAxis/Z left,RT_ROI_y1[ROI_No-1],RT_ROI_y2[ROI_No-1]
		SetAxis/Z right, RT_ROI_yy1[ROI_No-1], RT_ROI_yy2[ROI_No-1]
		SetAxis/Z bottom,RT_ROI_x1[ROI_No-1],RT_ROI_x2[ROI_No-1]
		RT_ROI_Slot = ROI_No
		Print "Goto ROI #",ROI_No
	else
		DoWindow/F MultiPatch_ShowInputs
		SetAxis/A
	endif
	
	// ROI1GoAcq
	if (!StringMatch(ctrlName[6,8],"Acq"))
		DoWindow/F MultiPatch_PatternMaker
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Silly toggle routine to keep the checkbox value up to date

Function PM_RT_RepeatPatternToggleProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR		RT_RepeatPattern =		root:MP:PM_Data:RT_RepeatPattern			// Boolean: Should the pattern be repeated?

	ControlInfo/W=MultiPatch_PatternMaker RT_RepeatPatternCheck
	RT_RepeatPattern = V_Value

End


//////////////////////////////////////////////////////////////////////////////////
//// The routine that manages the actual real-time averaging of the waves

Function PM_RT_AveragerManager()

	//// PARAMETERS FROM WAVECREATOR	
	NVAR		SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	//// PARAMETERS FOR THE AVERAGER
	WAVE		WantAverageOnThisChannel = 		root:MP:PM_Data:WantAverageOnThisChannel
	NVAR		PM_RT_nAverages =				root:MP:PM_Data:PM_RT_nAverages
	NVAR		PM_RT_AverageDuration =		root:MP:PM_Data:PM_RT_AverageDuration
	NVAR		PM_RT_AveragePosition =			root:MP:PM_Data:PM_RT_AveragePosition
	NVAR		PM_RT_AveragerSlotCounter =		root:MP:PM_Data:PM_RT_AveragerSlotCounter
	
	WAVE		PM_RT_AverageWaves = 			PM_RT_AverageWaves

	Variable	iCount,jCount
	
	// Ran out of slots?
	if (PM_RT_AveragerSlotCounter>PM_RT_nAverages-1)
		PM_RT_AveragerSlotCounter = 0
	endif

	// Store latest wave in memory in current slot
	iCount = 0
	do
		if (WantAverageOnThisChannel[iCount])
			WAVE	SourceWave = $("Temp"+num2str(iCount+1))
//			PM_RT_AverageWaves[0,PM_RT_AverageDuration*1e-3*SampleFreq-1][PM_RT_AveragerSlotCounter][i] = SourceWave[p+x2pnt(SourceWave, PM_RT_AveragePosition*1e-3)]
			PM_RT_AverageWaves[][PM_RT_AveragerSlotCounter][iCount] = SourceWave[p+x2pnt(SourceWave, PM_RT_AveragePosition*1e-3)]
		endif
		iCount += 1						// test
	while (iCount<4)

	// Make average

//	ImageTransform/METH=2 yProjection PM_RT_AverageWaves			// This approach gives the average of all four channels, whether used or not...
//	WAVE	M_yProjection = M_yProjection
//	i = 0
//	do
//		if (WantAverageOnThisChannel[i])									// Extract relevant wave for display
//			WAVE	AveWave = $("PM_RT_Ave_"+num2str(i+1))
//			AveWave[] = M_yProjection[p][i]
//		endif
//		i += 1
//	while (i<4)


	Make/O/N=(PM_RT_nAverages) DummyWave
	jCount = 0
	do
		iCount = 0
		do
			if (WantAverageOnThisChannel[iCount])
				WAVE	AveWave = $("PM_RT_Ave_"+num2str(iCount+1))
				DummyWave = PM_RT_AverageWaves[jCount][p][iCount]
				WaveStats/Q DummyWave
				AveWave[jCount] = V_avg // mean(DummyWave)
			endif
			iCount += 1
		while (iCount<4)
		jCount += 1
	while (jCount<PM_RT_AverageDuration*1e-3*SampleFreq)

	// Make sure average trace baseline is at zero
	PM_RT_Ave_AlignBase()
	
	// Go to next slot for the next step of the acquisition
	PM_RT_AveragerSlotCounter += 1

End


//////////////////////////////////////////////////////////////////////////////////
//// Make sure average trace baseline is at zero

Function PM_RT_Ave_AlignBase()

	//// PARAMETERS FOR THE AVERAGER
	WAVE		WantAverageOnThisChannel = 		root:MP:PM_Data:WantAverageOnThisChannel
	NVAR		PM_RT_AveBaseStart	 =			root:MP:PM_Data:PM_RT_AveBaseStart
	NVAR		PM_RT_AveBaseWidth =			root:MP:PM_Data:PM_RT_AveBaseWidth
	NVAR		PM_RT_AveAlignBase =			root:MP:PM_Data:PM_RT_AveAlignBase

//	Variable	baselineStart = 0
//	Variable	baselineWidth = 4
	Variable	baselineVal = 0
	
	Variable iCount = 0

	DoWindow PM_RT_AverageGraph
	if (V_flag)
		iCount = 0
		do
			if (WantAverageOnThisChannel[iCount])
				WAVE	AveWave = $("PM_RT_Ave_"+num2str(iCount+1))
				if (PM_RT_AveAlignBase)
					baselineVal = mean(AveWave,PM_RT_AveBaseStart/1e3,(PM_RT_AveBaseStart+PM_RT_AveBaseWidth)/1e3)
					ModifyGraph/W=PM_RT_AverageGraph offset($("PM_RT_Ave_"+num2str(iCount+1)))={0,-baselineVal}
				else
					ModifyGraph/W=PM_RT_AverageGraph offset($("PM_RT_Ave_"+num2str(iCount+1)))={0,0}
				endif
			endif
			iCount += 1
		while (iCount<4)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Produce the Online AveragerPanel

Function PM_RT_AveragerSettingsProc(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR		ScSc = root:MP:ScSc

	WAVE		WantAverageOnThisChannel = 	root:MP:PM_Data:WantAverageOnThisChannel
	NVAR		PM_RT_nAverages =			root:MP:PM_Data:PM_RT_nAverages
	NVAR		PM_RT_AveAlignBase = 		root:MP:PM_Data:PM_RT_AveAlignBase
	
	Variable	WinX = 600
	Variable	WinY = 48
	Variable	WinWidth = 400
	Variable	WinHeight = 132+22+22
	
	DoWindow	MultiPatch_AveragerSettings
	if (V_flag==0)

		DoWindow/K MultiPatch_AveragerSettings										// Create panel
		NewPanel /W=(WinX*ScSc,WinY*ScSc,WinX*ScSc+WinWidth,WinY*ScSc+WinHeight) as "Averager Settings"
		DoWindow/C MultiPatch_AveragerSettings
		
		SetDrawLayer UserBack
		SetDrawEnv linethick= 2,fillfgc= (65535/2,65535/2,65535/2),fillbgc= (1,1,1)
		DrawRect 4,2,WinWidth-4,36
		SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
		DrawText 70+(WinWidth-300)/2,29,"Averager Settings"
		
		Variable YShift = 40
		Variable SpChX = (WinWidth-16)/4
		CheckBox AveOn1Check pos={8+SpChX*0,YShift},size={SpChX-4,19},fsize=14,Proc=PM_RT_ToggleAveHereProc,title="Channel 1",value=WantAverageOnThisChannel[0]
		CheckBox AveOn2Check pos={8+SpChX*1,YShift},size={SpChX-4,19},fsize=14,Proc=PM_RT_ToggleAveHereProc,title="Channel 2",value=WantAverageOnThisChannel[1]
		CheckBox AveOn3Check pos={8+SpChX*2,YShift},size={SpChX-4,19},fsize=14,Proc=PM_RT_ToggleAveHereProc,title="Channel 3",value=WantAverageOnThisChannel[2]
		CheckBox AveOn4Check pos={8+SpChX*3,YShift},size={SpChX-4,19},fsize=14,Proc=PM_RT_ToggleAveHereProc,title="Channel 4",value=WantAverageOnThisChannel[3]
		
		SetVariable AveragePositionSetVar,pos={4,YShift+22*1},size={WinWidth/2-8,20},title="Average position [ms]: "
		SetVariable AveragePositionSetVar,limits={0,Inf,10},value=root:MP:PM_Data:PM_RT_AveragePosition
	
		SetVariable AverageDurationSetVar,pos={4+WinWidth/2,YShift+22*1},size={WinWidth/2-8,20},title="Duration [ms]: "
		SetVariable AverageDurationSetVar,limits={0,Inf,50},proc=UpdateAverageWavesProc,value=root:MP:PM_Data:PM_RT_AverageDuration
	
		SetVariable nAveragesSetVar,pos={4,YShift+22*2},size={WinWidth/2-8,20},title="# of averages: "
		SetVariable nAveragesSetVar,limits={0,Inf,1},proc=UpdateAverageWavesProc,value=root:MP:PM_Data:PM_RT_nAverages
	
		SetVariable AverageBaseStartSetVar,pos={4+WinWidth/2,YShift+22*2},size={WinWidth/2-8,20},title="Baseline start [ms]: "
		SetVariable AverageBaseStartSetVar,limits={0,Inf,1},proc=UpdateAverageWavesProc,value=root:MP:PM_Data:PM_RT_AveBaseStart
	
		SetVariable AverageBaseWidthSetVar,pos={4,YShift+22*3},size={WinWidth/2-8,20},title="Baseline width [ms]: "
		SetVariable AverageBaseWidthSetVar,limits={0,Inf,1},proc=UpdateAverageWavesProc,value=root:MP:PM_Data:PM_RT_AveBaseWidth
	
		CheckBox AverageAlignBaseCheck pos={4+WinWidth/2,YShift+22*3},size={WinWidth/2-8,20},fsize=14,Proc=PM_RT_AveAlignBaseProc,title="Align baseline?",value=PM_RT_AveAlignBase

		Button CloseAveragerSettingsButton,pos={4+WinWidth/2-4,YShift+22*4},size={WinWidth/2-8,18},proc=PM_RT_CloseAveragerSettingsProc,title="Close this panel"
		Button ShowAverageGraphButton,pos={4,YShift+22*4},size={WinWidth/2-8,18},proc=PM_RT_ShowAverageGraphProc,title="Show averages"

		Button ClearAveragingButton,pos={4,YShift+22*5},size={WinWidth/2-8,18},proc=PM_RT_ClearAveragingProc,title="Clear averaging buffer"

	else
		DoWindow/F MultiPatch_AveragerSettings										// Panel already exists, so just bring to front
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Show the averages graph

Function PM_RT_ClearAveragingProc(ctrlName) : ButtonControl
	String ctrlName
	
 	WAVE		PM_RT_AverageWaves = 			PM_RT_AverageWaves
 	
 	Print Time()+" - Clearing the averaging buffer."
 	
// 	PM_RT_AverageWaves = 0
	PM_RT_AverageWaves = NaN
	
End
	
//////////////////////////////////////////////////////////////////////////////////
//// Show the averages graph

Function PM_RT_ShowAverageGraphProc(ctrlName) : ButtonControl
	String ctrlName
	
	WAVE		WantAverageOnThisChannel = 		root:MP:PM_Data:WantAverageOnThisChannel
	NVAR		PM_RT_AtLeastOneAve = 			root:MP:PM_Data:PM_RT_AtLeastOneAve

	Variable	WinX = 500
	Variable	WinY = 48+200+20
	Variable	WinWidth = 400
	Variable	WinHeight = 200

	DoWindow PM_RT_AverageGraph
	if (V_flag==0)			// Create graph window
		DoWindow/K PM_RT_AverageGraph
		Display/W=(WinX,WinY,WinX+WinWidth,WinY+WinHeight) as "The averages"
		DoWindow/C PM_RT_AverageGraph
		
		Variable	i
		i = 0
		do
			if(WantAverageOnThisChannel[i])
				AppendToGraph $("PM_RT_Ave_"+num2str(i+1))
				ModifyGraph rgb($("PM_RT_Ave_"+num2str(i+1)))=(65535*(3-i)/3,0,65535*i/3)
			endif
			i += 1
		while(i<4)
		
		ModifyGraph grid(bottom)=1
		ModifyGraph nticks(bottom)=3
		
		PM_RT_Ave_AlignBase()
		
		Button CloseThePlotsButton,pos={0,0},size={18,18},proc=Averager_CloseThePlotsProc,title="X"
		Button SpreadTheTracesButton,pos={22,0},size={18,18},proc=Averager_SpreadTheTracesProc,title="S"
		Button CollectTheTracesButton,pos={44,0},size={18,18},proc=Averager_SpreadTheTracesProc,title="C"
	else						// Graph already exists, so just bring to front
		DoWindow/F PM_RT_AverageGraph
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Close the averager graph

Function Averager_CloseThePlotsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	DoWindow/K PM_RT_AverageGraph

End

//////////////////////////////////////////////////////////////////////////////////
//// Spread the traces in the make range graph

Function Averager_SpreadTheTracesProc(ctrlName) : ButtonControl
	String		ctrlName
	
	if (StringMatch(ctrlName,"SpreadTheTracesButton"))
		DoSpreadTracesInGraph ("PM_RT_AverageGraph",1)
	else
		DoSpreadTracesInGraph ("PM_RT_AverageGraph",0)
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Update the AverageWaves

Function UpdateAverageWavesProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	//// PARAMETERS FROM WAVECREATOR	
	NVAR		SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR		PM_RT_nAverages =				root:MP:PM_Data:PM_RT_nAverages
	NVAR		PM_RT_AverageDuration =			root:MP:PM_Data:PM_RT_AverageDuration
	
	Make/O/N=(PM_RT_AverageDuration*1e-3*SampleFreq,PM_RT_nAverages,4) PM_RT_AverageWaves
	PM_RT_AverageWaves = 0

	Make/O/N=(PM_RT_AverageDuration*1e-3*SampleFreq) PM_RT_Ave_1
	Make/O/N=(PM_RT_AverageDuration*1e-3*SampleFreq) PM_RT_Ave_2
	Make/O/N=(PM_RT_AverageDuration*1e-3*SampleFreq) PM_RT_Ave_3
	Make/O/N=(PM_RT_AverageDuration*1e-3*SampleFreq) PM_RT_Ave_4

	SetScale/I x 0,PM_RT_AverageDuration/1000,"s", PM_RT_Ave_1
	SetScale/I x 0,PM_RT_AverageDuration/1000,"s", PM_RT_Ave_2
	SetScale/I x 0,PM_RT_AverageDuration/1000,"s", PM_RT_Ave_3
	SetScale/I x 0,PM_RT_AverageDuration/1000,"s", PM_RT_Ave_4

End

//////////////////////////////////////////////////////////////////////////////////
//// Close the Online AveragerPanel

Function PM_RT_CloseAveragerSettingsProc(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/K MultiPatch_AveragerSettings	
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Read AveAlignBase checkbox and save state

Function PM_RT_AveAlignBaseProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable		checked
	
	NVAR	PM_RT_AveAlignBase = 	root:MP:PM_Data:PM_RT_AveAlignBase
	
	PM_RT_AveAlignBase = checked
	
//	Print "Toggle {PM_RT_AveAlignBaseProc}",PM_RT_AveAlignBase

End

//////////////////////////////////////////////////////////////////////////////////
//// Read checkboxes and save state

Function PM_RT_ToggleAveHereProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked

	WAVE		WantAverageOnThisChannel = 		root:MP:PM_Data:WantAverageOnThisChannel
	NVAR		PM_RT_AtLeastOneAve = 			root:MP:PM_Data:PM_RT_AtLeastOneAve
	
	WantAverageOnThisChannel[str2num(ctrlName[5,5])-1] = checked
	PM_RT_AtLeastOneAve = 0
	Variable	i = 0
	do	
		if (WantAverageOnThisChannel[i])
			PM_RT_AtLeastOneAve = 1
		endif
		i += 1
	while(i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Shift everything in the pattern up one step.

Macro PM_ShiftPatternUpProc(ctrlName) : ButtonControl
	String ctrlName

	Silent 1

	Variable	i
	Variable	j
	String		CommandStr1
	String		CommandStr2
	String		CommandStr3
	Variable	Handle

	if (root:MP:PM_Data:NSteps>1)																				// Need at least two steps to have something to shift!

		Handle = ShowInfoBox("Shifting up!")
		
		print "Shifting pattern up one step at time "+Time()+"."
		
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Shifting a pattern up one step\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r\tThe pattern \""+root:MP:PM_Data:PatternName+"\" was shifted up one step at time "+Time()+".\r\r"
			
		StorePatternMakerValues()																				// First read the values off the PatternMaker panel

		i = 0
		do
	
			j = 0
			do
		
				CommandStr1 = "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)			// Output checkboxes
				CommandStr2 = "root:MP:PM_Data:OutputCheck"+num2str(i+2)+"_"+num2str(j+1)
				CommandStr3= CommandStr1+"="+CommandStr2
				Execute CommandStr3
			
				CommandStr1 = "root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1)			// Output wave names
				CommandStr2 = "root:MP:PM_Data:OutputWave"+num2str(i+2)+"_"+num2str(j+1)
				CommandStr3= CommandStr1+"="+CommandStr2
				Execute CommandStr3
			
				CommandStr1 = "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1)			// Input check boxes
				CommandStr2 = "root:MP:PM_Data:InputCheck"+num2str(i+2)+"_"+num2str(j+1)
				CommandStr3= CommandStr1+"="+CommandStr2
				Execute CommandStr3
			
				j += 1
			while(j<4)
			
			CommandStr1 = "root:MP:PM_Data:NRepeats"+num2str(i+1)										// Number of repeats
			CommandStr2 = "root:MP:PM_Data:NRepeats"+num2str(i+2)
			CommandStr3= CommandStr1+"="+CommandStr2
			Execute CommandStr3
	
			CommandStr1 = "root:MP:PM_Data:ISI"+num2str(i+1)												// Inter-stimulus interval
			CommandStr2 = "root:MP:PM_Data:ISI"+num2str(i+2)
			CommandStr3= CommandStr1+"="+CommandStr2
			Execute CommandStr3
	
			i += 1
		while(i<root:MP:PM_Data:NSteps-1)
		
		root:MP:PM_Data:NSteps -= 1																			// Reduce the number of steps by one step
		root:MP:PM_Data:OldNSteps = root:MP:PM_Data:NSteps													// Update the "old" number of steps
	
		MakeMultiPatch_PatternMaker()																			// Recreate the PatternMaker panel

		RemoveInfoBox(Handle)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Bring up PatternManipulator panel
//// to be simplify the rapid alteration of the entire pattern

Function PM_PatternManipulator()

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	Variable	PanX = 540
	Variable	PanY = 200
	Variable	PanWidth = 360
	Variable	PanHeight = 200

	NVAR		ScSc = root:MP:ScSc
	
	Variable	xPos = 8
	Variable	yShift = 4+28
	Variable	controlHeight = 20
	Variable	fontSize = 14
	Variable	rowSpacing = 24
	
	Variable	i

	DoWindow/K PM_PatternManipulatorPanel
	NewPanel/K=1/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) as "Manipulate Pattern"
	DoWindow/C PM_PatternManipulatorPanel
	
	SetDrawLayer UserBack
	SetDrawEnv fsize=(fontSize+4),fstyle=5,textxjust=1,textyjust= 2
	DrawText PanWidth/2,4,"Manipulate Pattern"

	Button CopyOutputWavesfrom1stButton,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},proc=PM_CopyFirstOutWavesProc,title="Copy output waves from 1st step"
	yShift += rowSpacing

	i = 0
	do
		Button $("CopyOutputWavesfrom1stCh"+num2str(i+1)+"Button"),pos={xPos+(panWidth-xPos*1)/4*i,yShift},size={(panWidth-xPos*2)/4-6,controlHeight},proc=PM_CopyFirstOutWaves1ChProc,title="for Ch#"+num2str(i+1)
		Button $("CopyOutputWavesfrom1stCh"+num2str(i+1)+"Button"),fcolor=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
		i += 1
	while(i<4)
	yShift += rowSpacing

	Button CopyCheckboxesfrom1stButton,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},proc=PM_CopyFirstnCheckboxesProc,title="Copy checkboxes from 1st step"
	yShift += rowSpacing

	Button CopyNRepsfrom1stButton,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},proc=PM_CopyFirstnRepsProc,title="Copy nRepeats from 1st step"
	yShift += rowSpacing
	
	Button CopyISIfrom1stButton,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},proc=PM_CopyFirstISIProc,title="Copy ISI from 1st step"
	yShift += rowSpacing
	
	Button ShiftPatternUpButton,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},proc=PM_ShiftPatternUpProc,title="Shift pattern up one step"
	yShift += rowSpacing
	
	Button Repeat2TextWaveButton,pos={xPos,yShift},size={panWidth-xPos*2,controlHeight},proc=PM_Repeat2TextWaveProc,title="Convert repeating pattern to a wave list"
	yShift += rowSpacing
	
	Button CloseThisPanelButton,pos={xPos+16,yShift},size={panWidth-xPos*2-32,controlHeight},title="Close this panel"
	Button CloseThisPanelButton,proc=PM_ClosePatternManipulatorProc,fsize=(fontSize),fColor=(65535,0,0)
	yShift += rowSpacing
	PanHeight = yShift

	MoveWindow/W=PM_PatternManipulatorPanel PanX,PanY,PanX+PanWidth/ScSc,PanY+PanHeight/ScSc
	ModifyPanel/W=PM_PatternManipulatorPanel fixedSize=1

End

Function PM_ClosePatternManipulatorProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/K PM_PatternManipulatorPanel
			break
	endswitch

	return 0
End

Function PM_PatternManipulatorProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			PM_PatternManipulator()
			break
	endswitch

	return 0
End


//////////////////////////////////////////////////////////////////////////////////
//// Copy first-step ISI to all other steps

Function PM_CopyFirstISIProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		NSteps = root:MP:PM_Data:NSteps
	SVAR		PatternName = root:MP:PM_Data:PatternName

	Variable	i
	Variable	j
	Variable	Handle

	if (NSteps>1)																	// Need at least two steps to have something to work on!

		Handle = ShowInfoBox("Copying ISI!")
		
		NVAR		ISI1 =			root:MP:PM_Data:ISI1

		print "Copying ISI from first step (="+num2str(ISI1)+") to all other steps in pattern "+Time()+"."
		
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Copying ISI from first step\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal,text="\r\tISI in first step is: "+num2str(ISI1)+".\r"
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern \""+PatternName+"\" was manipulated at time "+Time()+".\r\r"

		i = 1
		do
			NVAR		currISI =			$("root:MP:PM_Data:ISI")+num2str(i+1)
			currISI = ISI1
			i += 1
		while(i<NSteps)
		
		Execute "MakeMultiPatch_PatternMaker()"									// Recreate the PatternMaker panel
		RemoveInfoBox(Handle)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Copy first-step Number of Repeats to all other steps

Function PM_CopyFirstnRepsProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		NSteps = root:MP:PM_Data:NSteps
	SVAR		PatternName = root:MP:PM_Data:PatternName

	Variable	i
	Variable	j
	Variable	Handle

	if (NSteps>1)																	// Need at least two steps to have something to work on!

		Handle = ShowInfoBox("Copying nRepeats!")
		
		Execute "StorePatternMakerValues()"										// First read the values off the PatternMaker panel
		
		NVAR		NRepeats1 =			root:MP:PM_Data:NRepeats1

		print "Copying nRepeats from first step (="+num2str(NRepeats1)+") to all other steps in pattern "+Time()+"."
		
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Copying nRepeats from first step\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal,text="\r\tNumber of repeats in first step is: "+num2str(NRepeats1)+".\r"
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern \""+PatternName+"\" was manipulated at time "+Time()+".\r\r"
			
		i = 1
		do
			NVAR		currNRepeats =			$("root:MP:PM_Data:NRepeats")+num2str(i+1)
			currNRepeats = NRepeats1
			i += 1
		while(i<NSteps)
		
		Execute "MakeMultiPatch_PatternMaker()"									// Recreate the PatternMaker panel
		RemoveInfoBox(Handle)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Copy first-step Checkbox settings to all other steps

Function PM_CopyFirstnCheckboxesProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		NSteps = root:MP:PM_Data:NSteps
	SVAR		PatternName = root:MP:PM_Data:PatternName

	Variable	i
	Variable	j
	Variable	Handle
	String		OutCheckStr = ""
	String		InCheckStr = ""
	String		SillyOnOffList = "[off];[on] ;"

	if (NSteps>1)																	// Need at least two steps to have something to work on!

		Handle = ShowInfoBox("Copying checkboxes!")
		
		Execute "StorePatternMakerValues()"										// First read the values off the PatternMaker panel

		print "Copying checkboxes from first step to all other steps in pattern "+Time()+"."

		j = 0
		do
	
			NVAR OutCheck1st = $("root:MP:PM_Data:OutputCheck1_"+num2str(j+1))
			OutCheckStr += StringFromList(OutCheck1st,SillyOnOffList)+"   "
			NVAR InCheck1st = $("root:MP:PM_Data:InputCheck1_"+num2str(j+1))
			InCheckStr += StringFromList(InCheck1st,SillyOnOffList)+"   "
		
			i = 1
			do
				NVAR		currOutputCheck =	$("root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1))
				currOutputCheck = OutCheck1st
				NVAR		currInputCheck =	$("root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1))
				currInputCheck = InCheck1st
				i += 1
			while(i<NSteps)

			j += 1
		while(j<4)

		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Copying checkboxes from first step\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal,text="\r\tOutput checkboxes in first step are: "+OutCheckStr+"\r"
		Notebook Parameter_Log ruler=Normal,text="\tInput checkboxes in first step are:   "+InCheckStr+"\r"
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern \""+PatternName+"\" was manipulated at time "+Time()+".\r\r"
		
		Execute "MakeMultiPatch_PatternMaker()"									// Recreate the PatternMaker panel
		RemoveInfoBox(Handle)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Convert a repeating pattern to a wavelist of text waves

Function PM_Repeat2TextWaveProc(ctrlName) : ButtonControl
	String ctrlName

	//// GENERAL
	SVAR	ST_BaseName = 		root:MP:ST_Data:ST_BaseName		// The base name for all waves

	//// CELL NUMBERS
	NVAR	Cell_1 =				root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =				root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =				root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =				root:MP:IO_Data:Cell_4

	NVAR	NSteps = 				root:MP:PM_Data:NSteps
	SVAR	PatternName = 			root:MP:PM_Data:PatternName
	
	NVAR	RT_RepeatNTimes =		root:MP:PM_Data:RT_RepeatNTimes

	Variable	i,j,k,m
	Variable	nChannelsChecked
	String		WorkStr,WorkStr2
	String		TheWave
	Variable	Handle
	Variable	NTotRepeats
	Variable	nListEntries
	Variable	ListEntryCounter
	
	String		WL_Suffix = "_list"

	Print "Converting a repeating pattern into a list of waves"
	Print "\t\t"+Date()
	Print "\t\t"+Time()

	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Converting repeating pattern into a wavelist\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\tThe source pattern \""+PatternName+"\" (see below) was manipulated at time "+Time()+".\r"
	Execute "DumpPatternToNoteBook()"

	Handle = ShowInfoBox("Converting pattern!")
		
	Execute "StorePatternMakerValues()"										// First read the values off the PatternMaker panel

	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) ThisChannelChecked
	nChannelsChecked = 0

	Print "Figuring out which channels are active..."
	j = 0
	do
		NVAR OutCheck1st = $("root:MP:PM_Data:OutputCheck1_"+num2str(j+1))
		ThisChannelChecked[j] = OutCheck1st
		if (OutCheck1st)
			nChannelsChecked += 1
		endif
		j += 1
	while (j<4)
	print "\t\t\t("+num2str(nChannelsChecked)+" channel(s) checked in first step.)"
	
	Print "Figuring out the total number of repeats in this pattern..."
	NTotRepeats = 0
	i = 0
	do
		NVAR		currNRepeats =			$("root:MP:PM_Data:NRepeats")+num2str(i+1)
		NTotRepeats += currNRepeats
		i += 1
	while (i<NSteps)
	print "\t\t\t"+num2str(NTotRepeats)+" repeats in total *in* this pattern"
	print "\t\t\t"+num2str(RT_RepeatNTimes)+" repeats *of* this pattern"
	nListEntries = NTotRepeats*RT_RepeatNTimes
	print "\t\t\tWe thus need "+num2str(nListEntries)+" list entries"

	print "\tLists of the generated waves are stored in the following text waves:"
	i = 0	// Go through each channel
	do
		if (ThisChannelChecked[i])
			TheWave = ST_BaseName+num2str(i+1)+WL_Suffix
			KillWaves/Z $TheWave
			Make/T/O/N=(nListEntries) $TheWave
			WAVE/T	wList = $TheWave
			print "\t\tChannel #"+num2str(i+1)+"/Cell #"+num2str(CellNumbers[i])+":\t\""+TheWave+"\""
			ListEntryCounter = 0
			j = 0	// Go through each repeat of entire pattern
			do
				k = 0	// Go through all steps of pattern
				do
					NVAR		currNRepeats =		$("root:MP:PM_Data:NRepeats")+num2str(k+1)
					SVAR		currOutputWave =	$("root:MP:PM_Data:OutputWave"+num2str(k+1)+"_"+num2str(i+1))
					m = 0	// Go through all repeats at this particular step of pattern
					do
						wList[ListEntryCounter] = currOutputWave
						ListEntryCounter += 1
						m += 1
					while(m<currNRepeats)
					k += 1
				while(k<NSteps)
				j += 1
			while(j<RT_RepeatNTimes)
			// Set first wave to be text wave with list
			SVAR OutputWave1st = $("root:MP:PM_Data:OutputWave1_"+num2str(i+1))
			OutputWave1st = TheWave
		endif
		i += 1
	while (i<4)
	
	Print "Update pattern..."
	NVAR		NRepeats1 =			root:MP:PM_Data:NRepeats1
	NRepeats1 = nListEntries
	NSteps = 1

	Notebook Parameter_Log ruler=Normal, text="\tThe resulting pattern:\r"
	Execute "DumpPatternToNoteBook()"

	Execute "MakeMultiPatch_PatternMaker()"									// Recreate the PatternMaker panel
	RemoveInfoBox(Handle)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Copy first-step output waves to all other steps

Function PM_CopyFirstOutWavesProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		NSteps = root:MP:PM_Data:NSteps
	SVAR		PatternName = root:MP:PM_Data:PatternName

	Variable	i
	Variable	j
	Variable	Handle
	String		OutwavesStr = ""

	if (NSteps>1)																	// Need at least two steps to have something to work on!

		Handle = ShowInfoBox("Copying waves!")
		
		Execute "StorePatternMakerValues()"										// First read the values off the PatternMaker panel

		print "Copying output waves from first step to all other steps in pattern "+Time()+"."

		j = 0
		do
	
			SVAR OutputWave1st = $("root:MP:PM_Data:OutputWave1_"+num2str(j+1))
			OutwavesStr += "\t\t"+OutputWave1st+"\r"
		
			i = 1
			do
				SVAR		currOutputWave =	$("root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j+1))
				currOutputWave = OutputWave1st
				i += 1
			while(i<NSteps)

			j += 1
		while(j<4)

		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Copying output waves from first step\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal,text="\r\tOutput waves in first step are:\r"+OutwavesStr
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern \""+PatternName+"\" was manipulated at time "+Time()+".\r\r"
		
		Execute "MakeMultiPatch_PatternMaker()"									// Recreate the PatternMaker panel
		RemoveInfoBox(Handle)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Copy first-step output waves to all other steps, but only for ONE channel

Function PM_CopyFirstOutWaves1ChProc(ctrlName) : ButtonControl
	String ctrlName

	NVAR		NSteps = root:MP:PM_Data:NSteps
	SVAR		PatternName = root:MP:PM_Data:PatternName

	Variable	i
	Variable	j = str2num(ctrlName[24]) // CopyOutputWavesfrom1stChX
	Variable	Handle
	String		OutwavesStr = ""

	if (NSteps>1)																	// Need at least two steps to have something to work on!

		Handle = ShowInfoBox("Copying waves!")
		
		Execute "StorePatternMakerValues()"										// First read the values off the PatternMaker panel

		print "For channel #"+num2str(j)+", copying output wave from first step to all other steps in pattern "+Time()+"."

		SVAR OutputWave1st = $("root:MP:PM_Data:OutputWave1_"+num2str(j))
		OutwavesStr += "\t\t"+OutputWave1st+"\r"
	
		i = 1
		do
			SVAR		currOutputWave =	$("root:MP:PM_Data:OutputWave"+num2str(i+1)+"_"+num2str(j))
			currOutputWave = OutputWave1st
			i += 1
		while(i<NSteps)

		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="For channel #"+num2str(j)+", copying output wave from first step\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal,text="\r\tOutput wave in first step is:\r"+OutwavesStr
		Notebook Parameter_Log ruler=Normal, text="\tThe pattern \""+PatternName+"\" was manipulated at time "+Time()+".\r\r"
		
		Execute "MakeMultiPatch_PatternMaker()"									// Recreate the PatternMaker panel
		RemoveInfoBox(Handle)
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Realtime analysis of sealtest and of membrane potential.

Function PM_RT_Analysis()

	Variable	i,j,k
	Variable	WorkVar1
	Variable	WorkVar2
	Variable	t1,t2,t3,t4

	String		CommandStr
	String		WaveStr

	NVAR		PatternRunning = 		root:MP:PM_Data:PatternRunning		// Boolean: Is a pattern running?
	NVAR		PatternReachedItsEnd = 	root:MP:PM_Data:PatternReachedItsEnd	// Boolean: Did pattern just reach its end?
	NVAR		SingleSendFlag =		root:MP:SingleSendFlag					// Boolean: Acquisition was initiated using the 'Single Send' button

	NVAR		RT_SealTestOnOff =		root:MP:PM_Data:RT_SealTestOnOff		// Sealtest analysis on or off
	NVAR		RT_VmOnOff =			root:MP:PM_Data:RT_VmOnOff			// Membrane potential analysis on or off
	NVAR		SealTestDur =			root:MP:SealTestDur					// Seal test duration [ms]
	NVAR		SealTestPad1 =			root:MP:SealTestPad1					// Seal test padding -- addition of time before seal test [ms]
	NVAR		SealTestPad2 =			root:MP:SealTestPad2					// Seal test padding -- addition of time after seal test [ms]
	NVAR		SealTestAmp_I =		root:MP:SealTestAmp_I					// Seal test amplitude in current clamp [nA]
	NVAR		SealTestAmp_V =		root:MP:SealTestAmp_V					// Seal test amplitude in voltage clamp [nA]

	NVAR		RT_SealTestWidth =		root:MP:PM_Data:RT_SealTestWidth		// Sealtest width of window for averaging
	NVAR		RT_VmWidth =			root:MP:PM_Data:RT_VmWidth			// Sealtest width of window for averaging

	NVAR		RT_EPSPOnOff =		root:MP:PM_Data:RT_EPSPOnOff		// EPSP amplitude analysis on or off
	NVAR		RT_EPSPUseGrab =		root:MP:PM_Data:RT_EPSPUseGrab		// Use manual position
	NVAR		RT_EPSPUseMatrix =		root:MP:PM_Data:RT_EPSPUseMatrix	// Use automatic position
	WAVE		EPSPPosWave =			root:MP:PM_Data:EPSPPosWave			// EPSP start in trace
	NVAR		RT_EPSPLatency =	root:MP:PM_Data:RT_EPSPLatency			// EPSP peak latency [s]
	NVAR		RT_EPSPWidth =		root:MP:PM_Data:RT_EPSPWidth		// EPSP width in trace
	NVAR		RT_EPSPBaseStart =	root:MP:PM_Data:RT_EPSPBaseStart	// _Relative_ EPSP baseline start in trace
	NVAR		RT_EPSPBaseWidth =	root:MP:PM_Data:RT_EPSPBaseWidth	// EPSP baseline width in trace

	NVAR		TotalIterCounter =	 	root:MP:PM_Data:TotalIterCounter		// Counts up the total number of iterations for a pattern -- used for indexing data to be saved

	WAVE		WaveWasAcq =			root:MP:FixAfterAcq:WaveWasAcq		// Flags that wave was used
	WAVE/T	WaveNames =			root:MP:FixAfterAcq:WaveNames			// Contains the names of the used waves
	
	NVAR		RT_StableBaseline	=	root:MP:PM_Data:RT_StableBaseline	// Boolean: Want to check the stability of the baseline?
	WAVE		RT_FirstHalfMean	=	root:MP:PM_Data:RT_FirstHalfMean		// The first and the second half of the baseline... if means are more than 10% different, then discard experiment
	WAVE		RT_SecondHalfMean	=	root:MP:PM_Data:RT_SecondHalfMean
	WAVE/Z	RT_FirstHalfMeanMatrix	=	root:MP:PM_Data:RT_FirstHalfMeanMatrix		// Matrix: The first and the second half of the baseline... if means are more than 10% different, then discard experiment
	WAVE/Z	RT_SecondHalfMeanMatrix	=	root:MP:PM_Data:RT_SecondHalfMeanMatrix
	NVAR		RT_FirstHalfEnds	=	root:MP:PM_Data:RT_FirstHalfEnds		// The iteration at which the first half of the first baseline ends (the second half ends when the baseline ends)
		
	NVAR		CurrentStep =			root:MP:PM_Data:CurrentStep
	NVAR		DummyIterCounter = 	root:MP:PM_Data:DummyIterCounter	// Counts up the iterations in a particular step -- for display purposes only
	NVAR		IterCounter =			root:MP:PM_Data:IterCounter			// Counts down the iterations in a particular step

	WAVE		VClampWave =			root:MP:IO_Data:VClampWave			// Boolean: Channel is in voltage clamp or in current clamp?

	NVAR		ST_SealTestAtEnd =		root:MP:ST_Data:ST_SealTestAtEnd		// Put sealtest at end of wave
	NVAR		ST_StartPad = 			root:MP:ST_Data:ST_StartPad			// The padding at the start of the waves [ms]

	NVAR		PM_RT_AtLeastOneAve = 	root:MP:PM_Data:PM_RT_AtLeastOneAve	// Boolean for Averager: Produce average on at least one channel

	//// CONNECTIVITY
	WAVE		Conn_Matrix =			root:MP:PM_Data:Conn_Matrix			// Connectivity matrix describing which cells are connected to which
	WAVE		Pos_Matrix =			root:MP:PM_Data:Pos_Matrix				// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]
	Variable	wDur

	if (!(SingleSendFlag))														// It is only meaningful to do the sealtest or the V_m analysis if a pattern is running
		
		//// AVERAGER
		if (PM_RT_AtLeastOneAve)												// Only call the AverageWaves routine if at least one channel was checked in the Averager panel
			PM_RT_AveragerManager()										// Average waves
		endif

		i = 0
		do																		// Go through all possible channels
		
	
			//// SEALTEST -- Assumes waves were generated with ST_Creator
			if (RT_SealTestOnOff)
				if (WaveWasAcq[i])
					if (ST_SealTestAtEnd)
						if (VClampWave[i])											// ... in v clamp
							WaveStr = WaveNames[i]
							WAVE	w = $WaveStr
							wDur = pnt2x(w,numpnts(w)-1)						// The duration of the wave
							t1 = wDur-(SealTestPad1+SealTestDur+RT_SealTestWidth)/1000 //(ST_StartPad+SealTestPad1-RT_SealTestWidth)/1000
							t2 = wDur-(SealTestPad1+SealTestDur)/1000// (ST_StartPad+SealTestPad1)/1000
							WorkVar1 = mean($WaveStr,t1,t2)									// WorkVar1 --> Baseline I_m before sealtest [A]
							t3 = wDur-(SealTestPad1+RT_SealTestWidth)/1000//(ST_StartPad+SealTestPad1+SealTestDur-RT_SealTestWidth)/1000
							t4 = wDur-SealTestPad1/1000//(ST_StartPad+SealTestPad1+SealTestDur)/1000
							WorkVar2 = mean($WaveStr,t3,t4)									// WorkVar2 --> I_m at peak value of sealtest [A]
							WaveStr = "RT_SealTestWave"+num2str(i+1)
							WAVE	w = $WaveStr
							w[TotalIterCounter-1] = (SealTestAmp_V)/(WorkVar2-WorkVar1)	// V = R*I --> R = V/I
						else															// ... in i clamp
							WaveStr = WaveNames[i]
							WAVE	w = $WaveStr
							wDur = pnt2x(w,numpnts(w)-1)						// The duration of the wave
							t1 = wDur-(SealTestPad1+SealTestDur+RT_SealTestWidth)/1000 //(ST_StartPad+SealTestPad1-RT_SealTestWidth)/1000
							t2 = wDur-(SealTestPad1+SealTestDur)/1000// (ST_StartPad+SealTestPad1)/1000
							WorkVar1 = mean($WaveStr,t1,t2)									// WorkVar1 --> Baseline V_m before sealtest [V]
							t3 = wDur-(SealTestPad1+RT_SealTestWidth)/1000//(ST_StartPad+SealTestPad1+SealTestDur-RT_SealTestWidth)/1000
							t4 = wDur-SealTestPad1/1000//(ST_StartPad+SealTestPad1+SealTestDur)/1000
							WorkVar2 = mean($WaveStr,t3,t4)									// WorkVar2 --> V_m at peak value of sealtest [V]
							WaveStr = "RT_SealTestWave"+num2str(i+1)
							WAVE	w = $WaveStr
							w[TotalIterCounter-1] = (WorkVar2-WorkVar1)/(SealTestAmp_I*1e-9)	// V = R*I --> R = V/I (also convert current step from nA to A)
						endif
					else
						if (VClampWave[i])											// ... in v clamp
							WaveStr = WaveNames[i]
							t1 = (SealTestPad1-RT_SealTestWidth)/1000
							t2 = (SealTestPad1)/1000
							WorkVar1 = mean($WaveStr,t1,t2)									// WorkVar1 --> Baseline I_m before sealtest [A]
							t3 = (SealTestPad1+SealTestDur-RT_SealTestWidth)/1000
							t4 = (SealTestPad1+SealTestDur)/1000
							WorkVar2 = mean($WaveStr,t3,t4)									// WorkVar2 --> I_m at peak value of sealtest [A]
							WaveStr = "RT_SealTestWave"+num2str(i+1)
							WAVE	w = $WaveStr
							w[TotalIterCounter-1] = (SealTestAmp_V)/(WorkVar2-WorkVar1)	// V = R*I --> R = V/I
						else															// ... in i clamp
							WaveStr = WaveNames[i]
							t1 = (SealTestPad1-RT_SealTestWidth)/1000
							t2 = (SealTestPad1)/1000
							WorkVar1 = mean($WaveStr,t1,t2)									// WorkVar1 --> Baseline V_m before sealtest [V]
							t3 = (SealTestPad1+SealTestDur-RT_SealTestWidth)/1000
							t4 = (SealTestPad1+SealTestDur)/1000
							WorkVar2 = mean($WaveStr,t3,t4)									// WorkVar2 --> V_m at peak value of sealtest [V]
							WaveStr = "RT_SealTestWave"+num2str(i+1)
							WAVE	w = $WaveStr
							w[TotalIterCounter-1] = (WorkVar2-WorkVar1)/(SealTestAmp_I*1e-9)	// V = R*I --> R = V/I (also convert current step from nA to A)
						endif
					endif
				endif
			endif
			
			//// MEMBRANE POTENTIAL OR CURRENT
			if (RT_VmOnOff)
				if (WaveWasAcq[i])
					WaveStr = WaveNames[i]
					t1 = 0
					t2 = RT_VmWidth/1000
					WorkVar1 = mean($WaveStr,t1,t2)
					WaveStr = "RT_VmImWave"+num2str(i+1)
					WAVE	w = $WaveStr
					w[TotalIterCounter-1] = WorkVar1
				endif
			endif
			
			//// MANUAL EPSP OR EPSC AMPLITUDE
			if ((RT_EPSPOnOff) %& (RT_EPSPUseGrab))
				if (WaveWasAcq[i])
					WaveStr = WaveNames[i]
					WorkVar1 = mean($WaveStr,EPSPPosWave[i]+RT_EPSPBaseStart,EPSPPosWave[i]+RT_EPSPBaseStart+RT_EPSPBaseWidth)	// WorkVar1 --> Baseline V_m before EPSP
					WorkVar2 = mean($WaveStr,EPSPPosWave[i],EPSPPosWave[i]+RT_EPSPWidth)												// WorkVar2 --> V_m at peak value of EPSP
					WaveStr = "RT_EPSPWave"+num2str(i+1)
					WAVE	w = $WaveStr
					w[TotalIterCounter-1] = (WorkVar2-WorkVar1)
				endif
			endif
			
			i += 1
		while (i<4) // End all possible channels loop
	
		//// AUTOMATIC EPSP OR EPSC AMPLITUDE
		if ((RT_EPSPOnOff) %& (RT_EPSPUseMatrix))
			i = 0	// Pre
			do
				j = 0	// Post
				do
					if (i!=j)	// All these "ifs" are totally overkill, but better safe than sorry
						if (Conn_Matrix[i][j])
							if (Pos_Matrix[i][j]!=-1)
								WaveStr = WaveNames[j]
								WorkVar1 = mean($WaveStr,Pos_Matrix[i][j]+RT_EPSPBaseStart,Pos_Matrix[i][j]+RT_EPSPBaseStart+RT_EPSPBaseWidth)	// WorkVar1 --> Baseline V_m before EPSP
								WorkVar2 = mean($WaveStr,Pos_Matrix[i][j]+RT_EPSPLatency,Pos_Matrix[i][j]+RT_EPSPLatency+RT_EPSPWidth)												// WorkVar2 --> V_m at peak value of EPSP
								WaveStr = "RT_EPSPMatrix"+num2str(i+1)+num2str(j+1)
								WAVE	w = $WaveStr
								w[TotalIterCounter-1] = (WorkVar2-WorkVar1)
							endif
						endif
					endif
					j += 1
				while (j<4)
				i += 1
			while (i<4)
		endif
		
		//// TEMPERATURE
		if (Exists("MM_HeaterExists"))
			NVAR/Z	MM_HeaterExists
			if (MM_HeaterExists)
				WAVE	RT_TempWave
				WAVE	RT_HeaterTempWave
				WAVE	RT_TargetTempWave
				NVAR MM_TempBath
				NVAR MM_TempHeater
				NVAR MM_TempTarget
				RT_TempWave[TotalIterCounter-1] = MM_TempBath
				RT_HeaterTempWave[TotalIterCounter-1] = MM_TempHeater
				RT_TargetTempWave[TotalIterCounter-1] = MM_TempTarget
			endif
		endif

		if (Exists("Warner_Temp"))
			NVAR/Z	Warner_Temp
			WAVE	RT_TempWave
			RT_TempWave[TotalIterCounter-1] = Warner_Temp
		endif


		if ((PatternReachedItsEnd)%&((RT_SealTestOnOff)%|(RT_VmOnOff)))					// Last step of a pattern was just executed

			Notebook Parameter_Log selection={endOfFile, endOfFile}
			Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="PatternMaker stats at end of pattern:\r",textRGB=(0,0,0)
			Notebook Parameter_Log ruler=Normal, text="\r\t\tTime: "+Time()+"\r\r"

			i = 0
			do																					// Go through all possible channels
		
				//// AVERAGE VALUE OF SEALTEST VALUES
				if (RT_SealTestOnOff)
					if (WaveWasAcq[i])
						WaveStr = "RT_SealTestWave"+num2str(i+1)
						WAVE	w = $WaveStr
						WorkVar1 = mean(w,-Inf,Inf)
						sprintf CommandStr, "%.0W1POhm",WorkVar1
						Notebook Parameter_Log ruler=TabRow, text="\t\tChannel "+num2str(i+1)+" mean sealtest value:\t"+CommandStr+"\r"
					endif
				endif
				
				//// AVERAGE VALUE OF MEMBRANE POTENTIALS
				if (RT_VmOnOff)
					if (WaveWasAcq[i])
						WaveStr = "RT_VmImWave"+num2str(i+1)
						WAVE	w = $WaveStr
						WorkVar2 = mean(w,-Inf,Inf)
						sprintf CommandStr, "%.1W1PV",WorkVar2
						Notebook Parameter_Log ruler=TabRow, text="\t\tChannel "+num2str(i+1)+" mean membrane potential:\t"+CommandStr+"\r"
					endif
				endif
				
				Notebook Parameter_Log ruler=Normal, text="\r"

				i += 1
			while (i<4) // End all possible channels loop

		endif // PatternReachedItsEnd
		
		if (PatternReachedItsEnd)
			BackupParameterLog()							// Save ParameterLog at end of pattern!
		endif
		
		//// FIGURE OUT THE STABILITY OF THE BASELINE
		if ( (RT_EPSPOnOff) %& (RT_StableBaseline) %& (CurrentStep == 1) %& (DummyIterCounter == RT_FirstHalfEnds) )
			i = 0
			do
				if (RT_EPSPUseGrab)
					if (WaveWasAcq[i])
						WaveStr = "RT_EPSPWave"+num2str(i+1)
						WAVE	w = $WaveStr
						RT_FirstHalfMean[i] = mean(w,0,RT_FirstHalfEnds)
					endif
				endif
				i += 1
			while (i<4)
			if (RT_EPSPUseMatrix)
				i = 0	// Pre
				do
					j = 0	// Post
					do
						if (i!=j)	// All these "ifs" are totally overkill, but better safe than sorry
							if (Conn_Matrix[i][j])
								if (Pos_Matrix[i][j]!=-1)
									WaveStr = "RT_EPSPMatrix"+num2str(i+1)+num2str(j+1)
									WAVE	w = $WaveStr
									RT_FirstHalfMeanMatrix[i][j] = mean(w,0,RT_FirstHalfEnds)
								endif
							endif
						endif
						j += 1
					while (j<4)
					i += 1
				while (i<4)
			endif
		endif
	
		if ( (RT_EPSPOnOff) %& (RT_StableBaseline) %& (CurrentStep == 1) %& (IterCounter == 1) )
			Notebook Parameter_Log selection={endOfFile, endOfFile}
			Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Baseline stability\r",textRGB=(0,0,0)
			Notebook Parameter_Log ruler=TabRow, text="\r\tTime:"+Time()+"\r\r"
			i = 0
			do
				if (RT_EPSPUseGrab)
					if (WaveWasAcq[i])
						WaveStr = "RT_EPSPWave"+num2str(i+1)
						WAVE	w = $WaveStr
						RT_SecondHalfMean[i] = mean(w,RT_FirstHalfEnds+1,TotalIterCounter-1)
						print "Baseline stability for channel #"+num2str(i+1)+" is:\t"+num2str(RT_SecondHalfMean[i]/RT_FirstHalfMean[i])
						Notebook Parameter_Log ruler=TabRow, text="\t\tPercent change for channel #"+num2str(i+1)+":\t"+num2str(RT_SecondHalfMean[i]/RT_FirstHalfMean[i]*100)+"%\r"
						if (abs(RT_SecondHalfMean[i]/RT_FirstHalfMean[i]-1)>0.1)
							print "\tWARNING! Baseline does not appear to be stable for this channel!"
							Notebook Parameter_Log ruler=TabRow, text="\t\t\tWARNING! This exceeds the threshold value of 10% change!\r"
						endif
					endif
				endif
				i += 1
			while (i<4)
			if (RT_EPSPUseMatrix)
				i = 0	// Pre
				do
					j = 0	// Post
					do
						if (i!=j)	// All these "ifs" are totally overkill, but better safe than sorry
							if (Conn_Matrix[i][j])
								if (Pos_Matrix[i][j]!=-1)
									WaveStr = "RT_EPSPMatrix"+num2str(i+1)+num2str(j+1)
									WAVE	w = $WaveStr
									RT_SecondHalfMeanMatrix[i][j] = mean(w,RT_FirstHalfEnds+1,TotalIterCounter-1)
									print "Baseline stability for channel #"+num2str(i+1)+" to channel #"+num2str(j+1)+"is:\t"+num2str(RT_SecondHalfMeanMatrix[i][j]/RT_FirstHalfMeanMatrix[i][j])
									Notebook Parameter_Log ruler=TabRow, text="\t\tPercent change for #"+num2str(i+1)+"->#"+num2str(j+1)+":\t"+num2str(RT_SecondHalfMeanMatrix[i][j]/RT_FirstHalfMeanMatrix[i][j]*100)+"%\r"
									if (abs(RT_SecondHalfMeanMatrix[i][j]/RT_FirstHalfMeanMatrix[i][j]-1)>0.1)
										print "\tWARNING! Baseline does not appear to be stable for this channel!"
										Notebook Parameter_Log ruler=TabRow, text="\t\t\tWARNING! This exceeds the threshold value of 10% change!\r"
									endif
								endif
							endif
						endif
						j += 1
					while (j<4)
					i += 1
				while (i<4)
			endif
			Notebook Parameter_Log ruler=TabRow, text="\r"
		endif
		
	else
	
		BackupParameterLog()									// Save ParameterLog after every Single Send
	
	endif // SingleSendFlag
	
	SingleSendFlag = 0												// Enable 'PM_RT_Analysis' next time around

End

//////////////////////////////////////////////////////////////////////////////////
//// Backup the ParameterLog window, so that we don't lose it in case the computer crashes!

Function BackupParameterLog()
	
	SaveNotebook/O/P=home/S=7 Parameter_Log as "Parameter_Log_BACKUP.ifn"
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Change the title of the pattern-related buttons in Switchboard and in PatternMaker to the
//// content of the passed string argument.

Function TogglePatternButtons(ButtonTitle)
	String		ButtonTitle

	Button PatternButton,pos={4,339},size={86,35},proc=PM_PatternProc,title=ButtonTitle,win=MultiPatch_Switchboard	
	Button PatternButton,pos={698,24},size={168,16},proc=PM_PatternProc,title=ButtonTitle,win=MultiPatch_PatternMaker

End

//////////////////////////////////////////////////////////////////////////////////
//// Positions the notebook to one of two favorite positions.

Macro RepositionNotebookProc(ctrlName) : ButtonControl
	String ctrlName

	variable		xl1		= 675-100-40
	variable		yt1		= 130
	variable		xr1		= 1022-100-40-50
	variable		yb1		= 180

	variable		xl2		= 10+400+122-100-40
	variable		yt2		= 50
	variable		xr2		= 500+400+122-100-40
	variable		yb2		= 700

	Variable	ShiftWasNotPressed
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
//		Print "\tYou pressed the Shift key."
		ShiftWasNotPressed = 0
	else
		ShiftWasNotPressed = 1
	endif

	DoWindow/F Parameter_Log		
	if (ShiftWasNotPressed)
		//	GetWindow kwTopWin, wsize
		if (root:MP:PM_Data:SizeModeNB)
			MoveWindow/W=Parameter_Log xl2,yt2,xr2,yb2							// Move parameter log to favorite position #2
			root:MP:PM_Data:SizeModeNB = 0
		else
			MoveWindow/W=Parameter_Log xl1,yt1,xr1,yb1							// Move parameter log to favorite position #1
			root:MP:PM_Data:SizeModeNB = 1
		endif
	endif
	DoWindow/F MultiPatch_Switchboard		
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Add to notebook the information that a new cell is being worked on.

Function NewCellProc(ctrlName) : ButtonControl
	String		ctrlName

	NVAR		CellNumber =			root:MP:CellNumber		// The number of the cell we're working on
	
	CellNumber += 1
	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="New cell\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\r\tCell number "+num2str(CellNumber)+" at time "+Time()+".\r\r"

End

//////////////////////////////////////////////////////////////////////////////////
//// Rename the input base name for the waves on the chosen channel according to the number
//// of the current cell

Function LabelChannelProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	ChosenChannel
	String		CommandStr
	String		BaseName =				"Cell_"
	NVAR		CellNumber =			root:MP:CellNumber		// The number of the cell we're working on
	SVAR		DummyStr =			root:MP:DummyStr

	if (CellNumber==0)
		Abort "Press \"New cell\" first!"
	else
		ChosenChannel = str2num(ctrlName[strlen(ctrlName)-1]);		// Figure out which button was pressed
		CommandStr = "root:MP:IO_Data:WaveNamesIn"+num2str(ChosenChannel)+" = \""+BaseName+JS_num2digstr(2,CellNumber)+"_\""
		Execute CommandStr
		CommandStr = "root:MP:DummyStr = root:MP:IO_Data:WaveNamesIn"+num2str(ChosenChannel)
		Execute CommandStr
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Changing input base name\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r\tCell number "+num2str(CellNumber)+" is on channel "+num2str(ChosenChannel)+".\r"
		Notebook Parameter_Log ruler=Normal, text="\tChannel "+num2str(ChosenChannel)+" input base name was changed to:\t"+DummyStr+"\r\r"
		CommandStr = "root:MP:IO_Data:Cell_"+num2str(ChosenChannel)+" = "+num2str(CellNumber)
		Execute CommandStr
	endif

end

//////////////////////////////////////////////////////////////////////////////////
//// Make sure user does not select no store but kill by mistake

Function NoStoreButKillProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	Variable	a,b

	ControlInfo/W=MultiPatch_Switchboard StoreCheck
	a = V_value
	ControlInfo/W=MultiPatch_Switchboard KillCheck
	b = V_value
	if ((!(a)) %& (b))									// User does not want to store, but does want to kill
		Abort "WARNING! You have now selected not to store the waves, but still you wish to have them killed after acquisition!"
	endif

End


//////////////////////////////////////////////////////////////////////////////////
//// Determine all the pipette resistances.

Function RpipProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR		BoardName =				root:BoardName								// ITC18 board? National Instruments?

	String		BaseNameOut =				"TestWaveOut"
	String		BaseNameIn =				"TestWaveIn"
	Variable	SampleFreq	=				10000
	Variable	WaveDuration =				800
	Variable	nPulses =					32
	Variable	PulseDur = 					8
	Variable	PulseFreq =					50
	Variable	PulseAmp =					1
	Variable	BeginTrainAt =				50
	Variable	MeasureWidth = 			5
	
	NVAR 		AcqGainSet =				root:MP:AcqGainSet
	NVAR		SingleSendFlag =			root:MP:SingleSendFlag
	NVAR		AcqInProgress = 			root:MP:AcqInProgress
	NVAR		RpipGenerated =			root:MP:RpipGenerated
	
	NVAR		DemoMode =				root:MP:DemoMode

	NVAR		PatternRunning = 			root:MP:PM_Data:PatternRunning			// Boolean: A pattern is currently running

	String		WaveNameIn
	String		WaveNameOut
	String		WaveListStr
	String		WorkStr
	Variable	i
	Variable	j
	Variable	PulseStartAt
	Variable	PulseStopAt
	Variable	BslStartAt
	Variable	BslStopAt
	Variable	Rpip,dV
	
	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	if (PatternRunning)
	
		print "This feature is blocked while running a pattern."

	else
	
		Make/O/N=(4,3) ChannelColors
		i = 0
		do
			ChannelColors[i][0] = ChannelColor_R[i]
			ChannelColors[i][1] = ChannelColor_G[i]
			ChannelColors[i][2] = ChannelColor_B[i]
			i += 1
		while(i<4)
	
		ControlInfo/W=MultiPatch_Switchboard ExternalTrigCheck
		if (V_Value)
			Print "Turn off external triggering to use the R_pip function."
			Abort "Turn off external triggering to use the R_pip function."
		endif
		
		Make/O/N=(nPulses)	MeasureWave
		Make/O/N=(4)			RpipXaxisWave
		Make/O/N=(4)			RpipMeanWave
		Make/O/N=(4)			RpipSdevWave
	
		print "Measuring pipette resistances at "+Time()+"."
	
		Notebook Parameter_Log selection={endOfFile, endOfFile}
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Pipette resistances\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r\tMeasuring pipette resistances at time "+Time()+".\r\r"
	
		i = 0
		do
	
			WorkStr = "Rpip"+num2str(i+1)+"Check"
			ControlInfo/W=MultiPatch_Switchboard $WorkStr
			if (V_value)
			
				WaveNameOut = BaseNameOut+JS_num2digstr(4,i+1)
				ProduceWave(WaveNameOut,SampleFreq,WaveDuration)
				ProducePulses(WaveNameOut,BeginTrainAt,nPulses,PulseDur,PulseFreq,PulseAmp,0,0,0,0)
				ProduceScaledWave(WaveNameOut,i+1,-1)
		
				WaveNameIn = BaseNameIn+JS_num2digstr(4,i+1)
				ProduceWave(WaveNameIn,SampleFreq,WaveDuration)
				DA_StoreWaveStats(WaveNameIn,i+1)
				WaveListStr = WaveNameIn+","+num2str(i)+","+num2str(AcqGainSet)+ ";"
		
				SingleSendFlag = 1;PatternRunning = 0;RpipGenerated = 1;		// This combination will tell ITC18 routines to _not_ simulate end-of-scan hook
				SendOneWave(WaveNameOut,i+1)
				BeginAcquisition(WaveListStr)
				
				if (!(StringMatch(BoardName,"ITC18")))
					// Important note: An interrupt from a standard Igor Background task will not interrupt a loop
					// in progress, but the NIDAQ EndOfScanHook *will*! Hence, with the ITC18, there is a workaround
					// in the MP_Board_ITC18 plug-in procedure.
					do
						DoXOPIdle
					while((AcqInProgress)%&(!(DemoMode)))
				endif
				
				j = 0
				do
					PulseStartAt = BeginTrainAt/1000+j/PulseFreq+PulseDur/1000-MeasureWidth/1000
					PulseStopAt = BeginTrainAt/1000+j/PulseFreq+PulseDur/1000
					BslStartAt = BeginTrainAt/1000+j/PulseFreq-MeasureWidth/1000
					BslStopAt = BeginTrainAt/1000+j/PulseFreq
					dV = mean($WaveNameIn,PulseStartAt,PulseStopAt)-mean($WaveNameIn,BslStartAt,BslStopAt)
					Rpip = dV/(PulseAmp*1e-9)										// V = RI --> R=V/I
					MeasureWave[j] = Rpip
					j += 1
				while(j<nPulses)
				WaveStats/Q MeasureWave
				RpipMeanWave[i] = V_avg
				RpipSdevWave[i] = V_sdev
				RpipXaxisWave[i] = i+1
				Notebook Parameter_Log ruler=TabRow, text="\t\tChannel #"+num2str(i+1)+":\t"+num2str(V_avg)+" Ohm\r"
				Killwaves/Z $WaveNameOut,$WaveNameIn
			else
				RpipMeanWave[i] = NaN
				RpipSdevWave[i] = NaN
				RpipXaxisWave[i] = i+1
				print "\tChannel #"+num2str(i+1)+": n/a"
				Notebook Parameter_Log ruler=TabRow, text="\t\tChannel #"+num2str(i+1)+":\tn/a\r"
			endif
			
			i += 1
		while(i<4)	
	
		Notebook Parameter_Log ruler=TabRow, text="\r"
	
		Killwaves/Z MeasureWave
	
		DoWindow/K RpipGraph
		ControlInfo/W=MultiPatch_Switchboard RpipGraphCheck
		if (V_value)
			Display/K=1/W=(133+368,342,368+368,678) RpipMeanWave vs RpipXaxisWave as "Pipette resistances"
			DoWindow/C RpipGraph
			ModifyGraph mode=8,marker=19
			ModifyGraph msize=6
			ModifyGraph mrkThick=1,lsize=2
			ModifyGraph nticks(bottom)=4
			Label left "\\U½"
			Label bottom "Channel #"
			SetAxis bottom 0.5,4.5 
			SetAxis/A/E=1 left
			ErrorBars RpipMeanWave Y,wave=(RpipSdevWave,RpipSdevWave)
			ModifyGraph zColor(RpipMeanWave)={ChannelColors,*,*,directRGB,0}
		endif
		
		Print "R_pip values:"
		i = 0
		do
			if (!(stringmatch(num2str(RpipMeanWave[i]),"NaN")))
				print "\tChannel #"+num2str(i+1)+":\t"+num2str(Round(RpipMeanWave[i]/1e6*10)/10)+"\tMOhm"
			else
				print "\tChannel #"+num2str(i+1)+":\tn/a"
			endif
			i += 1
		while (i<4)
		
		RpipGenerated = 0;
		
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Produce a blank wave

Function ProduceWave(Name,SampleFreq,WaveDuration)
	String		Name
	Variable	SampleFreq
	Variable	WaveDuration
	
	Make/O/N=(Ceil(SampleFreq*WaveDuration/1000)) $Name
	WAVE	w = $Name
	w = 0
	SetScale/P x,0, 1/SampleFreq, "s", $Name
	if (mod(numpnts(w),2))							// Odd number of samples in the output waves not allowed when using the NI6713 board
		w[numpnts(w)] = {0}						// Fix this by adding a single zero sample at the end of the wave when necessary...
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Starting with a wave that contains all zeros, this function _adds_ pulses to it.
//// N.B.! 'BeginTrainAt' and 'PulseDur' are given in [ms]!

Function ProducePulses(Name,BeginTrainAt,nPulses,PulseDur,PulseFreq,PulseAmp,DoAdd,Keep,BiExp,Ramp)
	String		Name
	Variable	BeginTrainAt				// Train begins at this position [ms]
	Variable	nPulses						// Number of pulses in train
	Variable	PulseDur					// Duration of each pulse [ms]
	Variable	PulseFreq					// Frequency of the pulse train
	Variable	PulseAmp					// Amplitude of the pulse train
	Variable	DoAdd						// Boolean: Should pulses be added to the wave?
	Variable	Keep						// Flag:		0 = keep all
											//			1 = keep first
											//			2 = keep last
											//			3 = keep none
	Variable	BiExp						// Flag:		0 = pulse
											//			1 = biexponential, synaptic-like, shape
	Variable	Ramp						// Flag:		0 = pulse
											//			1 = ramp

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	// Calculations and variables for biexponentials	
	NVAR		tau1 = root:MP:SynapseTau1	// Rising phase tau of biexponential [ms]
	NVAR		tau2 = root:MP:SynapseTau2	// Falling phase tau of biexponential [ms]
	Variable	analyticalMax = (tau2/tau1)^(tau1/(tau1-tau2))-(tau2/tau1)^(tau2/(tau1-tau2))
	Variable	SynapseAmp = PulseAmp/analyticalMax

	// Make pulses/biexponentials
	Variable	i1
	Variable	i2
	Variable	i

	if (!(Keep==3))
		i = 0
		do
			i1 = ceil(x2pnt($Name,BeginTrainAt/1000+i/PulseFreq))
			i2 = ceil(x2pnt($Name,BeginTrainAt/1000+i/PulseFreq+PulseDur/1000))
			if (i1<numpnts($Name))
				if (i2>numpnts($Name)-1)
					i2 = numpnts($Name)-1
				endif
			endif
			WAVE	w = $Name
			if ( (keep == 0) %| ( (keep == 1) %& (i == 0) ) %| ( (keep == 2) %& (i == nPulses-1) ) )
				if ( (PulseDur>=0) %& (i1<numpnts(w)) %& (i2<numpnts(w)) )
					if (DoAdd)
						if (BiExp)		//
							w[i1,i2] += (p<i1)? 0 : SynapseAmp*((1-exp(-((p-i1)/SampleFreq)/(tau1*1e-3)))-(1-exp(-((p-i1)/SampleFreq)/(tau2*1e-3))))
						else
							if (Ramp)
								// y = kx + m
								// k = (y2-y1)/(x2-x1)
								w[i1,i2] += (PulseAmp-0)/(i2-i1)*(p-i1)
							else
								w[i1,i2] += PulseAmp
							endif
						endif
					else
						if (BiExp)
							w[i1,i2] = (p<i1)? 0 : SynapseAmp*((1-exp(-((p-i1)/SampleFreq)/(tau1*1e-3)))-(1-exp(-((p-i1)/SampleFreq)/(tau2*1e-3))))
						else
							if (Ramp)
								w[i1,i2] = (PulseAmp-0)/(i2-i1)*(p-i1)
							else
								w[i1,i2] = PulseAmp
							endif
						endif
					endif
				endif
			endif
			i += 1
		while (i<nPulses)

		w[numpnts(w)-1]=0										// Correct for the nasty bug reported by Kate McLeod

	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Scale a wave according to which channel it is going to be sent to
//// Settings are read from the WaveCreator panel and not from the SwitchBoard. May want to change
//// this in the future.

Function ProduceScaledWave(Name,ChannelNumber,Mode)
	String		Name
	Variable	ChannelNumber
	Variable	Mode											// Mode = -1 --> read v or i clamp mode from SwitchBoard
																// Mode = 0 --> read v or i clamp mode from WaveCreator
																// Mode = 1 --> i clamp
																// Mode = 2 --> extracellular
																// Mode = 3 --> v clamp
	
	Variable	temp
	Variable	localMode
	
	WAVE		OutGainIClampWave =	root:MP:IO_Data:OutGainIClampWave
	WAVE		OutGainVClampWave =	root:MP:IO_Data:OutGainVClampWave
	WAVE		ChannelTypeWave = 		root:MP:IO_Data:ChannelType
	WAVE		VClampWave =			root:MP:IO_Data:VClampWave
	WAVE		w = $Name
	
	if (Mode == -1)
		localMode = ((VClampWave[ChannelNumber-1])*2+1)
	endif
	if (Mode == 0)
		localMode = ChannelTypeWave[ChannelNumber-1]
	endif
	if (Mode>0)
		localMode = Mode
	endif
	
	if (localMode==1)											// Current clamp
		temp = OutGainIClampWave[ChannelNumber-1]
		w /= temp
	endif
	if (localMode==3)											// Voltage clamp
		temp = OutGainVClampWave[ChannelNumber-1]
		w /= temp
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Scale the y axis of a wave according to its type

Function ProduceUnitsOnYAxis(Name,UnitsStr)
	String		Name
	String		UnitsStr
	
	Variable	temp
	
	WAVE		w = $Name
	
	SetScale d,-4,4,UnitsStr,w

End

//////////////////////////////////////////////////////////////////////////////////
//// Change the outgainwave when updating an output gain

Function OutGainSetProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	NVAR		WorkVar = 				root:MP:PM_Data:WorkVar
	WAVE		VClampWave =			root:MP:IO_Data:VClampWave
	WAVE		OutGainIClampWave =	root:MP:IO_Data:OutGainIClampWave
	WAVE		OutGainVClampWave =	root:MP:IO_Data:OutGainVClampWave
	
	Variable	i
	String		CommandStr
	
	i = 0
	do
		CommandStr = "root:MP:PM_Data:WorkVar = root:MP:IO_Data:OutGain"+num2str(i+1)
		Execute CommandStr
		if (VClampWave[i])
			OutGainVClampWave[i] = WorkVar
		else
			OutGainIClampWave[i] = WorkVar
		endif
		i += 1
	while (i<4)

	print "Updated the output gains at "+Time()

end

//////////////////////////////////////////////////////////////////////////////////
//// Change the ingainwaves when updating an input gain

Function InGainSetProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	NVAR		WorkVar =				root:MP:PM_Data:WorkVar
	WAVE		VClampWave =			root:MP:IO_Data:VClampWave
	WAVE		InGainIClampWave =	root:MP:IO_Data:InGainIClampWave
	WAVE		InGainVClampWave =	root:MP:IO_Data:InGainVClampWave
	
	Variable	i
	String		CommandStr
	
	i = 0
	do
		CommandStr = "root:MP:PM_Data:WorkVar = root:MP:IO_Data:InGain"+num2str(i+1)
		Execute CommandStr
		if (VClampWave[i])
			InGainVClampWave[i] = WorkVar
		else
			InGainIClampWave[i] = WorkVar
		endif
		i += 1
	while (i<4)

	print "Updated the input gains at "+Time()

end

//////////////////////////////////////////////////////////////////////////////////
//// Toggle between voltage clamp and current clamp on a particular channel
//// This means toggel the gains, in particular, as the user shouldn't have to remember the different
//// gain settings in voltage vs current clamp.

Function ToggleVClampProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	UpdateGainSetBoxes()

End

//////////////////////////////////////////////////////////////////////////////////
//// This is what does the actual updating -- used for ToggleVClampProc and for DoLoadSettings

Function UpdateGainSetBoxes()

	Variable	i
	
	String		CommandStr
	
	NVAR		WorkVar =				root:MP:PM_Data:WorkVar
	WAVE		VClampWave =			root:MP:IO_Data:VClampWave
	WAVE		OutGainIClampWave =	root:MP:IO_Data:OutGainIClampWave
	WAVE		OutGainVClampWave =	root:MP:IO_Data:OutGainVClampWave
	WAVE		InGainIClampWave =	root:MP:IO_Data:InGainIClampWave
	WAVE		InGainVClampWave =	root:MP:IO_Data:InGainVClampWave

	i = 0
	do
		CommandStr = "VClamp"+num2str(i+1)												// Read V clamp checkboxes
		ControlInfo/W=MultiPatch_Switchboard $CommandStr
		VClampWave[i] = V_value																// Store away read values

		//// Update SetVariable boxes according to the particular gains
		if (V_value)																			// Output gains
			WorkVar= OutGainVClampWave[i]
		else
			WorkVar= OutGainIClampWave[i]
		endif
		CommandStr = "root:MP:IO_Data:OutGain"+num2str(i+1)+"= root:MP:PM_Data:WorkVar" 
		Execute CommandStr
		if (V_value)																			// Input gains
			WorkVar= InGainVClampWave[i]
		else
			WorkVar= InGainIClampWave[i]
		endif
		CommandStr = "root:MP:IO_Data:InGain"+num2str(i+1)+"= root:MP:PM_Data:WorkVar" 
		Execute CommandStr

		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Calculate the access resistance based on the sealtest step in the top plot. Use the markers to
//// denote the initial step in voltage due to the series resistance.

Function CalcR_Access(ctrlName) : ButtonControl
	String		ctrlName

	Variable	V1,V2
	Variable	R_Access
	
	V1 = vcsr(A)
	V2 = vcsr(B)
	
	R_Access = abs(V1-V2)/0.025e-9							// V = R*I
	print "Access resistance:",R_Access

End

//////////////////////////////////////////////////////////////////////////////////
//// Stop all microsecond timers

Function StopAllMSTimers()

	print "\tStopping all MSTimers."
	Variable	i = 0;
	Variable	j = 0;
	do
		j = StopMSTimer(i)
		i += 1;
	while (i<10)

end

//////////////////////////////////////////////////////////////////////////////////
////  Create the ST_Creator panel

Function ST_GoToSpikeTimingCreator(ctrlName) : ButtonControl
	String		ctrlName
	
	String		CommandStr
	
	CommandStr = "ST_MakeST_CreatorPanel()"
	Execute CommandStr

End

//////////////////////////////////////////////////////////////////////////////////
//// Reset the percentages

Function ST_ResetRedPercProc(ctrlName) : ButtonControl
	String		ctrlName
	
	//// GENERAL
	NVAR	ST_RedPerc1 =		root:MP:ST_Data:ST_RedPerc1		// Scale current injection by this percentage for channel 1
	NVAR	ST_RedPerc2 =		root:MP:ST_Data:ST_RedPerc2		// Scale current injection by this percentage for channel 2
	NVAR	ST_RedPerc3 =		root:MP:ST_Data:ST_RedPerc3		// Scale current injection by this percentage for channel 3
	NVAR	ST_RedPerc4 =		root:MP:ST_Data:ST_RedPerc4		// Scale current injection by this percentage for channel 4
	
	ST_RedPerc1 = 100
	ST_RedPerc2 = 100
	ST_RedPerc3 = 100
	ST_RedPerc4 = 100

End

//////////////////////////////////////////////////////////////////////////////////
//// Close the ST_Creator panel & any graph windows that were produced

Function ST_CloseProc(ctrlName) : ButtonControl
	String		ctrlName

	if (StringMatch(ctrlName,"ClosePanelAndPlotsButton"))	
		ST_StoreCheckboxValues()
		DoWindow/K MultiPatch_ST_Creator
	endif
	
	ST_CloseAllGraphs()
	ST_MM_ClosePanelProc("")
	ST_MM2_ClosePanelProc("")
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Read the channel checkboxes of the ST_Creator panel and store away their values

Function ST_StoreCheckboxValues()

	Variable	i
	String		WorkStr

	NVAR		Ind_Sealtest =			root:MP:ST_Data:Ind_Sealtest
	NVAR		Ind_ConcatFlag =		root:MP:ST_Data:Ind_ConcatFlag
	NVAR		Base_Sealtest =			root:MP:ST_Data:Base_Sealtest
	NVAR		Base_RevOrder =		root:MP:ST_Data:Base_RevOrder
	NVAR		Base_vClampPulse =		root:MP:ST_Data:Base_vClampPulse
	NVAR		Base_Recovery =		root:MP:ST_Data:Base_Recovery
	NVAR		MMPooStyle =			root:MP:ST_Data:MMPooStyle
	
	WAVE		ST_NoSpikes =			root:MP:ST_Data:ST_NoSpikes
	WAVE		ST_NegPulse =			root:MP:ST_Data:ST_NegPulse
	WAVE 		ST_ChannelsChosen = 	root:MP:ST_Data:ST_ChannelsChosen
	WAVE 		ST_LightStim = 		root:MP:ST_Data:ST_LightStim
	WAVE 		ST_Extracellular = 		root:MP:ST_Data:ST_Extracellular
	WAVE 		ST_DendriticRec = 		root:MP:ST_Data:ST_DendriticRec
	WAVE 		ST_LongInj =	 		root:MP:ST_Data:ST_LongInj
	WAVE 		ST_ShortInj =	 		root:MP:ST_Data:ST_ShortInj
	WAVE 		ST_KeepLast =	 		root:MP:ST_Data:ST_KeepLast
	WAVE 		ST_KeepFirst =	 		root:MP:ST_Data:ST_KeepFirst
	
	NVAR		ST_Biphasic =			root:MP:ST_Data:ST_Biphasic
	
	NVAR		RandTrainsOff =			root:MP:ST_Data:RandTrainsOff
	NVAR		RandSpikesOff =			root:MP:ST_Data:RandSpikesOff

	i = 0
	do

		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
		ST_ChannelsChosen[i] = V_value

		WorkStr = "LightStim"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is this channel extracellular?
		ST_LightStim[i] = V_value

		WorkStr = "Extracellular"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is this channel extracellular?
		ST_Extracellular[i] = V_value

		WorkStr = "DendriticRec"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is this channel a dendritic recording?
		ST_DendriticRec[i] = V_value

		WorkStr = "NoSpikes"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// No spikes on this channel?
		ST_NoSpikes[i] = V_value

		WorkStr = "LongInj"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Does this channel have a long current injection?
		ST_LongInj[i] = V_value

		WorkStr = "ShortInj"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Does this channel have a short current injection?
		ST_ShortInj[i] = V_value

		WorkStr = "KeepLast"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Keep only last spike of spike train on this channel?
		ST_KeepLast[i] = V_value

		WorkStr = "KeepFirst"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Keep only first spike of spike train on this channel?
		ST_KeepFirst[i] = V_value

		WorkStr = "NegPulse"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Add negative pulse between spikes?
		ST_NegPulse[i] = V_value

		i += 1
	while (i<4)

	ControlInfo/W=MultiPatch_ST_Creator Ind_SealTestCheck
	Ind_SealTest = V_value

	ControlInfo/W=MultiPatch_ST_Creator Ind_ConcatCheck
	Ind_ConcatFlag = V_value

	ControlInfo/W=MultiPatch_ST_Creator Base_SealTestCheck
	Base_SealTest = V_value

	ControlInfo/W=MultiPatch_ST_Creator Base_RevOrderCheck
	Base_RevOrder = V_value

	ControlInfo/W=MultiPatch_ST_Creator Base_VClampPulseCheck
	Base_vClampPulse = V_value

	ControlInfo/W=MultiPatch_ST_Creator Base_RecoveryCheck
	Base_Recovery = V_value

	ControlInfo/W=MultiPatch_ST_Creator BiphasicCheck
	ST_Biphasic = V_value

	ControlInfo/W=MultiPatch_ST_Creator ST_MooMingPooStyleCheck
	MMPooStyle = V_value
	
	ControlInfo/W=MultiPatch_ST_Creator ST_RandTrainsOffCheck
	RandTrainsOff = V_value
	
	ControlInfo/W=MultiPatch_ST_Creator ST_RandSpikesOffCheck
	RandSpikesOff = V_value

End

//////////////////////////////////////////////////////////////////////////////////
//// Make the ST_Creator panel

Window ST_MakeST_CreatorPanel() : Panel
	PauseUpdate; Silent 1

	String		CommandStr
	Variable	i
	
	Variable	PanX = 328
	Variable	PanY = 56
	Variable	PanWidth = 520 // 420
	Variable/G	ST_PanHalfHeight = 40+18+18+6+20*18+2+4-2
	Variable/G	ST_PanFullHeight = 296+20+20+20+20+20+20+20+20-4+20+20+20+20+20*4+20*2+4+20*1+4+4+20
	
	ST_UpdateInd_WaveLength()
	ST_UpdateBase_WaveLength()

	Variable dd = 1.3
	Variable rr = 65535/dd
	Variable gg = 65535/dd
	Variable bb = 65535/dd
	
	if (!(Exists("ST_ShowTweaks")==2))
//		Print "Create ST_ShowTweaks"
		Variable/G	ST_ShowTweaks=0
	endif
	
	DoWindow MultiPatch_ST_Creator
	if (V_Flag)										// Panel already exists --> don't need to recreate it!

		DoWindow/F MultiPatch_ST_Creator

	else												// Recreate it!

		DoWindow/K MultiPatch_ST_Creator
		NewPanel/K=2/W=(PanX*root:MP:ScSc,PanY*root:MP:ScSc,PanX*root:MP:ScSc+PanWidth,PanY*root:MP:ScSc+ST_PanFullHeight) as "MultiPatch SpikeTiming Creator"
		DoWindow/C MultiPatch_ST_Creator
		ModifyPanel/W=MultiPatch_ST_Creator fixedSize=1
		DoUpdate
		
		SetDrawLayer UserBack
		SetDrawEnv linethick= 2,fillfgc= (0,0,65535),fillbgc= (1,1,1)
		DrawRect 4,2,PanWidth-4,36
		SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
		DrawText 55+(PanWidth-300)/2,29,"SpikeTiming Creator" //55
		
		Variable YShift = 40
		Variable xAdj = 20
		Variable SpChX = (PanWidth-16)/4
		CheckBox CellOn1Check pos={xAdj+8+SpChX*0,YShift},size={SpChX-4,19},fsize=14,Proc=ST_ToggleBase_SealTestProc,title="Channel 1",value=root:MP:ST_Data:ST_ChannelsChosen[0]
		CheckBox CellOn2Check pos={xAdj+8+SpChX*1,YShift},size={SpChX-4,19},fsize=14,Proc=ST_ToggleBase_SealTestProc,title="Channel 2",value=root:MP:ST_Data:ST_ChannelsChosen[1]
		CheckBox CellOn3Check pos={xAdj+8+SpChX*2,YShift},size={SpChX-4,19},fsize=14,Proc=ST_ToggleBase_SealTestProc,title="Channel 3",value=root:MP:ST_Data:ST_ChannelsChosen[2]
		CheckBox CellOn4Check pos={xAdj+8+SpChX*3,YShift},size={SpChX-4,19},fsize=14,Proc=ST_ToggleBase_SealTestProc,title="Channel 4",value=root:MP:ST_Data:ST_ChannelsChosen[3]
		
		YShift += 18-1
		xAdj -= 10
		i = 0
		do
			SetDrawEnv linethick = 1
			SetDrawEnv fillfgc=(root:MP:IO_Data:ChannelColor_R[i],root:MP:IO_Data:ChannelColor_G[i],root:MP:IO_Data:ChannelColor_B[i])
			SetDrawEnv linefgc=(root:MP:IO_Data:ChannelColor_R[i],root:MP:IO_Data:ChannelColor_G[i],root:MP:IO_Data:ChannelColor_B[i])
			SetDrawEnv linefgc=(0,0,0)
			DrawRRect xAdj+4+SpChX*i,YShift-18,xAdj+8+SpChX*i+SpChX-4-16,YShift
			i += 1
		while(i<4)
		
		YShift = 40+18+18+6
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText PanWidth/4-35,YShift,"Induction"
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText PanWidth*3/4-35,YShift,"Baseline"
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText PanWidth/2+4,YShift+20*7+2+18,"General"
		
		SetDrawEnv linethick = 2
		DrawLine 4,YShift-18,PanWidth-4,YShift-18								// Uppermost horizontal line
		SetDrawEnv linethick = 2
		DrawLine PanWidth/2,YShift-18+4,PanWidth/2,404+20+20				// Middle line going down
		SetDrawEnv linethick = 2
		DrawLine PanWidth/2+4,YShift+20*7+2,PanWidth-4,YShift+20*7+2	// Line separating baseline & general
		SetDrawEnv linethick = 2
		DrawLine 4,YShift+20*12+6,PanWidth/2-4,YShift+20*12+6				// Line separating induction & buttons
		SetDrawEnv linethick = 2
		DrawLine 4,YShift+20*18+2+4,PanWidth-4,YShift+20*18+2+4			// Line separating induction tweaks from rest
		SetDrawEnv linethick = 2
		DrawLine 4,YShift+20*23+8,PanWidth-4,YShift+20*23+8				// Horizontal line separating random firing from cycling through waves
		SetDrawEnv linethick = 2
		DrawLine 4,YShift+20*27+12,PanWidth-4,YShift+20*27+12			// Horizontal line separating Random from Cycle
		SetDrawEnv linethick = 2
		DrawLine 4,YShift+20*29+16,PanWidth-4,YShift+20*29+16			// Horizontal line separating Cycle from Export

		//// --- INDUCTION ---
		CheckBox Ind_SealTestCheck,pos={4,YShift+2},size={PanWidth/4-8,20},Proc=ST_ToggleInd_SealTestProc,title="Test pulse",value=root:MP:ST_Data:Ind_Sealtest
		CheckBox Ind_ConcatCheck,pos={4+PanWidth/4,YShift+2},size={PanWidth/4-8,20},Proc=ST_ToggleInd_SealTestProc,title="Concatenate",value=root:MP:ST_Data:Ind_ConcatFlag
		SetVariable Ind_OriginSetVar,pos={4,YShift+20},size={PanWidth/2-8,20},title="Origin [ms]: "
		SetVariable Ind_OriginSetVar,limits={0,Inf,5},proc=ST_ChangeInd_SetVar,value=root:MP:ST_Data:Ind_Origin

		SetVariable Ind_FreqSetVar,pos={4,YShift+20*2},size={(PanWidth/2-8)/2+4,20},title="Freq [Hz]:"
		SetVariable Ind_FreqSetVar,limits={0,Inf,5},proc=ST_ChangeInd_SetVar,value=root:MP:ST_Data:Ind_Freq
		SetVariable Ind_NPulsesSetVar,pos={4+(PanWidth/2-8)/2+8,YShift+20*2},size={(PanWidth/2-8)/2-8,20},title="# pulses:"
		SetVariable Ind_NPulsesSetVar,limits={0,Inf,1},proc=ST_ChangeInd_SetVar,value=root:MP:ST_Data:Ind_NPulses

		SetVariable Ind_DurationIClampSetVar,pos={4,YShift+20*3},size={PanWidth/2-8,20},title="I clamp pulse dur [ms]:"
		SetVariable Ind_DurationIClampSetVar,limits={0,Inf,1},value=root:MP:ST_Data:Ind_DurationIClamp
		SetVariable Ind_AmplitudeIClampSetVar,pos={4,YShift+20*4},size={PanWidth/2-8,20},title="I clamp pulse amp [nA]:"
		SetVariable Ind_AmplitudeIClampSetVar,limits={0,Inf,0.1},value=root:MP:ST_Data:Ind_AmplitudeIClamp

		SetVariable Ind_WaveLengthSetVar,pos={4,YShift+20*5},size={PanWidth/2-8,20},title="Wave length [ms]: "
		SetVariable Ind_WaveLengthSetVar,limits={0,Inf,100},value=root:MP:ST_Data:Ind_WaveLength

		SetDrawEnv fsize= 12,fstyle= 3,textrgb= (0,0,0)
		DrawText PanWidth*1/4-75,YShift+20*6+18+2,"Relative displacement"
		i = 0
		do

			CommandStr = "SetVariable Ind_RelDispl_"+num2str(i+1)+"SetVar,pos={4,"+num2str(YShift+20*(7+i)+4)+"},size={"+num2str(7/12*PanWidth/2-8)+",20},title=\"Ch #"+num2str(i+1)+": \""
			Execute CommandStr
			CommandStr = "SetVariable Ind_RelDispl_"+num2str(i+1)+"SetVar,limits={-Inf,Inf,5},proc=ST_ChangeInd_SetVar,value=root:MP:ST_Data:Ind_RelDispl_"+num2str(i+1)
			Execute CommandStr

			CommandStr = "SetVariable Cell_"+num2str(i+1)+"SetVar,pos={"+num2str(4+7/12*PanWidth/2)+","+num2str(YShift+20*(7+i)+4)+"},size={"+num2str(5/12*PanWidth/2-8)+",20},title=\"Cell: \""
			Execute CommandStr
			CommandStr = "SetVariable Cell_"+num2str(i+1)+"SetVar,noEdit=1,limits={0,Inf,0},frame = 0,proc=ST_ChangeInd_SetVar,value=root:MP:IO_Data:Cell_"+num2str(i+1)
			Execute CommandStr

			i += 1
		while (i<4)
		SetVariable Ind_rangeStartSetVar,pos={4,YShift+20*11+4},size={7/12*PanWidth/2-8,20},title="Range start [ms]:"
		SetVariable Ind_rangeStartSetVar,limits={-Inf,Inf,5},value=root:MP:ST_Data:Ind_rangeStart
		SetVariable Ind_rangeEndSetVar,pos={4+7/12*PanWidth/2,YShift+20*11+4},size={5/12*PanWidth/2-8,20},title="end:"
		SetVariable Ind_rangeEndSetVar,limits={-Inf,Inf,5},value=root:MP:ST_Data:Ind_rangeEnd

		//// --- BASELINE ---
		CheckBox Base_SealTestCheck,pos={PanWidth/2+4,YShift+2},size={86,20},Proc=ST_ToggleBase_SealTestProc,title="Test pulse",value=root:MP:ST_Data:Base_Sealtest
		CheckBox Base_RevOrderCheck,pos={PanWidth/2+PanWidth/4+4,YShift+2},size={86,20},Proc=ST_ToggleBase_SealTestProc,title="Reverse order",value=root:MP:ST_Data:Base_RevOrder

		SetVariable Base_SpacingSetVar,pos={PanWidth/2+4,YShift+20},size={PanWidth/4-8+20,20},title="Spacing [ms]: "
		SetVariable Base_SpacingSetVar,limits={0,Inf,5},proc=ST_ChangeBase_SetVar,value=root:MP:ST_Data:Base_Spacing
		CheckBox Base_VClampPulseCheck,pos={PanWidth/2+PanWidth/4+4+20,YShift+20},size={86,20},Proc=ST_ToggleBase_SealTestProc,title="vClamp pulse",value=root:MP:ST_Data:Base_VClampPulse

		SetVariable Base_FreqSetVar,pos={PanWidth/2+4,YShift+20*2},size={(PanWidth/2-8)/2+4,20},title="Freq [Hz]:"
		SetVariable Base_FreqSetVar,limits={0,Inf,5},proc=ST_ChangeBase_SetVar,value=root:MP:ST_Data:Base_Freq
		SetVariable Base_NPulsesSetVar,pos={PanWidth/2+4+(PanWidth/2-8)/2+8,YShift+20*2},size={(PanWidth/2-8)/2-8,20},title="# pulses:"
		SetVariable Base_NPulsesSetVar,limits={0,Inf,1},proc=ST_ChangeBase_SetVar,value=root:MP:ST_Data:Base_NPulses
		
		SetVariable Base_DurationIClampSetVar,pos={PanWidth/2+4,YShift+20*3},size={PanWidth/2-8,20},title="I clamp pulse dur [ms]:"
		SetVariable Base_DurationIClampSetVar,limits={0,Inf,1},value=root:MP:ST_Data:Base_DurationIClamp
		SetVariable Base_AmplitudeIClampSetVar,pos={PanWidth/2+4,YShift+20*4},size={PanWidth/2-8,20},title="I clamp pulse amp [nA]:"
		SetVariable Base_AmplitudeIClampSetVar,limits={0,Inf,0.1},value=root:MP:ST_Data:Base_AmplitudeIClamp

		SetVariable Base_WaveLengthSetVar,pos={PanWidth/2+4,YShift+20*5},size={PanWidth/2-8,20},title="Wave length [ms]: "
		SetVariable Base_WaveLengthSetVar,limits={0,Inf,100},value=root:MP:ST_Data:Base_WaveLength
		CheckBox Base_RecoveryCheck,pos={PanWidth/2+4,YShift+20*6},size={96,20},Proc=ST_ToggleBase_SealTestProc,title="Recovery pulse",value=root:MP:ST_Data:Base_Recovery
		SetVariable Base_RecoveryPosSetVar,pos={PanWidth/2+4+96,YShift+20*6},size={PanWidth/2-8-96,20},title="Pos [ms]:"
		SetVariable Base_RecoveryPosSetVar,limits={0,Inf,5},proc=ST_ChangeBase_SetVar,value=root:MP:ST_Data:Base_RecoveryPos
		
		//// --- GENERAL ---
		CheckBox ST_SealTestAtEndCheck,pos={PanWidth/2+PanWidth/4+4,YShift+20*7+5},size={86,20},Proc=WCST_ToggleSealTestAtEndProc,title="Test pulse at end",value=root:MP:ST_Data:ST_SealTestAtEnd
		// Potential bug alert: The above checkbox causes interaction between ST_Creator and WaveCreator

		SpChX = PanWidth/2/4 //30
		SetVariable ST_RedPerc1SetVar,pos={PanWidth/2+4+SpChX*0,YShift+20*8+4},size={SpChX-4,20},title="%1"
		SetVariable ST_RedPerc1SetVar,limits={0,Inf,5},value=root:MP:ST_Data:ST_RedPerc1
		SetVariable ST_RedPerc2SetVar,pos={PanWidth/2+4+SpChX*1,YShift+20*8+4},size={SpChX-4,20},title="%2"
		SetVariable ST_RedPerc2SetVar,limits={0,Inf,5},value=root:MP:ST_Data:ST_RedPerc2

		SetVariable ST_RedPerc3SetVar,pos={PanWidth/2+4+SpChX*2,YShift+20*8+4},size={SpChX-4,20},title="%3"
		SetVariable ST_RedPerc3SetVar,limits={0,Inf,5},value=root:MP:ST_Data:ST_RedPerc3
		SetVariable ST_RedPerc4SetVar,pos={PanWidth/2+4+SpChX*3,YShift+20*8+4},size={SpChX-4,20},title="%4"
		SetVariable ST_RedPerc4SetVar,limits={0,Inf,5},value=root:MP:ST_Data:ST_RedPerc4

		CheckBox ST_MooMingPooStyleCheck,pos={PanWidth/2+4,YShift+20*9+4},size={PanWidth/2-4,20},Proc=ST_ToggleMooMingPooStyleProc,title="MM Poo V clamp",value=root:MP:ST_Data:MMPooStyle
		Button ST_RedPercResetButton,pos={PanWidth/2+PanWidth/2*0.5,YShift+20*9+2},size={PanWidth/2*(1-0.5)-4,18},proc=ST_ResetRedPercProc,title="^ %Reset ^"
		SetVariable ST_DurationVClampSetVar,pos={PanWidth/2+4,YShift+20*10+4},size={PanWidth/2*0.6-4,20},title="V clamp dur [ms]:"
		SetVariable ST_DurationVClampSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_DurationVClamp
		SetVariable ST_AmplitudeVClampSetVar,pos={PanWidth/2+PanWidth/2*0.6,YShift+20*10+4},size={PanWidth/2*0.4-4,20},title="amp [V]:"
		SetVariable ST_AmplitudeVClampSetVar,limits={-Inf,Inf,0.01},value=root:MP:ST_Data:ST_AmplitudeVClamp
		SetVariable ST_StartPadSetVar,pos={PanWidth/2+4,YShift+20*11+4},size={PanWidth/4-4,20},title="Pad @ start:"
		SetVariable ST_StartPadSetVar,limits={0,Inf,10},proc=ST_ChangeBoth_SetVar,value=root:MP:ST_Data:ST_StartPad
		SetVariable ST_EndPadSetVar,pos={PanWidth/2+PanWidth/4+4,YShift+20*11+4},size={PanWidth/4-8,20},title="@ end [ms]:"
		SetVariable ST_EndPadSetVar,limits={0,Inf,10},proc=ST_ChangeBoth_SetVar,value=root:MP:ST_Data:ST_EndPad

		SetVariable ST_BaseNameSetVar,pos={PanWidth/2+4,YShift+20*12+4},size={PanWidth/4-4,20},title="Basename: "
		SetVariable ST_BaseNameSetVar,limits={0,Inf,100},value=root:MP:ST_Data:ST_BaseName
		SetVariable ST_SuffixSetVar,pos={PanWidth/2+4+PanWidth/4,YShift+20*12+4},size={PanWidth/4-8,20},title="Suffix: "
		SetVariable ST_SuffixSetVar,limits={0,Inf,100},value=root:MP:ST_Data:ST_Suffix

		// LIGHT STIM PARAMS
		SpChX = 30
		CheckBox LightStim1Check pos={PanWidth/2+4+SpChX*0,YShift+20*13+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_LightStim[0]
		CheckBox LightStim2Check pos={PanWidth/2+4+SpChX*1,YShift+20*13+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_LightStim[1]
		CheckBox LightStim3Check pos={PanWidth/2+4+SpChX*2,YShift+20*13+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_LightStim[2]
		CheckBox LightStim4Check pos={PanWidth/2+4+SpChX*3,YShift+20*13+4},size={Panwidth-8-(SpChX-4)*3,19},Proc=ST_ToggleTweaks,title="4 Light stim",value=root:MP:ST_Data:ST_LightStim[3]
		SetVariable ST_LightVoltageSetVar, pos={PanWidth/2+4,YShift+20*14+4},size={PanWidth/4-4,20},title="Light amp [V]:"
		SetVariable ST_LightVoltageSetVar, limits={-Inf,Inf,0.1},value=root:MP:ST_Data:ST_LightVoltage
		SetVariable ST_LightDurSetVar, pos={PanWidth/2+4+PanWidth/4,YShift+20*14+4},size={PanWidth/4-8,20},title="Light dur [ms]:"
		SetVariable ST_LightDurSetVar, limits={-Inf,Inf,0.1},value=root:MP:ST_Data:ST_LightDur

		// EXTRACELLULAR STIM PARAMS
		SpChX = 30
		CheckBox Extracellular1Check pos={PanWidth/2+4+SpChX*0,YShift+20*15+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_Extracellular[0]
		CheckBox Extracellular2Check pos={PanWidth/2+4+SpChX*1,YShift+20*15+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_Extracellular[1]
		CheckBox Extracellular3Check pos={PanWidth/2+4+SpChX*2,YShift+20*15+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_Extracellular[2]
		CheckBox Extracellular4Check pos={PanWidth/2+4+SpChX*3,YShift+20*15+4},size={Panwidth-8-(SpChX-4)*3,19},Proc=ST_ToggleTweaks,title="4 Extrac stim",value=root:MP:ST_Data:ST_Extracellular[3]
		CheckBox BiphasicCheck pos={PanWidth/2+4+(PanWidth/2-8)*8.5/12,YShift+20*15+4},size={(PanWidth/2-8)*7.5/12,19},Proc=ST_ToggleTweaks,title="Biphasic",value=root:MP:ST_Data:ST_Biphasic
		SetVariable ST_VoltageSetVar, pos={PanWidth/2+4,YShift+20*16+4},size={PanWidth/4-4,20},title="Voltage [V]:"
		SetVariable ST_VoltageSetVar, limits={-Inf,Inf,0.1},value=root:MP:ST_Data:ST_Voltage
		SetVariable ST_StimDurSetVar, pos={PanWidth/2+4+PanWidth/4,YShift+20*16+4},size={PanWidth/4-8,20},title="Dur [samples]:"
		SetVariable ST_StimDurSetVar, limits={1,Inf,1},value=root:MP:ST_Data:ST_StimDur

		// DENDRITIC RECORDING ON ANY CHANNEL?
		//// This means that the sealtest will not be produced at the beginning of the trace, but at
		//// the position where the spikes would have been. (Spikes are ommitted.)
		CheckBox DendriticRec1Check pos={PanWidth/2+4+SpChX*0,YShift+20*17+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_DendriticRec[0]
		CheckBox DendriticRec2Check pos={PanWidth/2+4+SpChX*1,YShift+20*17+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_DendriticRec[1]
		CheckBox DendriticRec3Check pos={PanWidth/2+4+SpChX*2,YShift+20*17+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_DendriticRec[2]
		CheckBox DendriticRec4Check pos={PanWidth/2+4+SpChX*3,YShift+20*17+4},size={Panwidth-8-(SpChX-4)*3,19},Proc=ST_ToggleTweaks,title="4 Dendritic rec.",value=root:MP:ST_Data:ST_DendriticRec[3]

		//// TOGGLE SHOW-TWEAKS
		Button ToggleShowTweaksButton,pos={PanWidth/2+4+PanWidth/2/4*3,YShift+20*17+4},size={PanWidth/2/4-8,18},proc=ST_ToggleShowTweaksProc,title="MORE",fColor=(65535/2,65535/5,65535),fSize=10,fStyle=1

		//// --- INDUCTION TWEAKS ---
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText 4,YShift+20*18+4+4+16,"Induction Tweaks"

		// REMOVE ALL SPIKES ON A CHANNEL
		SpChX = 30
		CheckBox NoSpikes1Check pos={PanWidth/2+4+SpChX*0,YShift+20*18+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_NoSpikes[0]
		CheckBox NoSpikes2Check pos={PanWidth/2+4+SpChX*1,YShift+20*18+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_NoSpikes[1]
		CheckBox NoSpikes3Check pos={PanWidth/2+4+SpChX*2,YShift+20*18+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_NoSpikes[2]
		CheckBox NoSpikes4Check pos={PanWidth/2+4+SpChX*3,YShift+20*18+4+4},size={Panwidth/2-8-SpChX*3,19},Proc=ST_ToggleTweaks,title="4 No spikes at all",value=root:MP:ST_Data:ST_NoSpikes[3]

		// PARAMS FOR USING ONLY SOME SPIKES IN A SPIKE TRAIN
		SpChX = 30
		CheckBox KeepLast1Check pos={PanWidth/2+4+SpChX*0,YShift+20*19+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_KeepLast[0]
		CheckBox KeepLast2Check pos={PanWidth/2+4+SpChX*1,YShift+20*19+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_KeepLast[1]
		CheckBox KeepLast3Check pos={PanWidth/2+4+SpChX*2,YShift+20*19+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_KeepLast[2]
		CheckBox KeepLast4Check pos={PanWidth/2+4+SpChX*3,YShift+20*19+4+4},size={Panwidth/2-8-SpChX*3,19},Proc=ST_ToggleTweaks,title="4 Keep last spike",value=root:MP:ST_Data:ST_KeepLast[3]

		CheckBox KeepFirst1Check pos={4+SpChX*0,YShift+20*19+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_KeepFirst[0]
		CheckBox KeepFirst2Check pos={4+SpChX*1,YShift+20*19+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_KeepFirst[1]
		CheckBox KeepFirst3Check pos={4+SpChX*2,YShift+20*19+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_KeepFirst[2]
		CheckBox KeepFirst4Check pos={4+SpChX*3,YShift+20*19+4+4},size={Panwidth/2-8-SpChX*3,19},Proc=ST_ToggleTweaks,title="4 Keep first spike",value=root:MP:ST_Data:ST_KeepFirst[3]

		// "LONG" CURRENT INJECTION PARAMS
		SpChX = 30
		CheckBox LongInj1Check pos={PanWidth/2+4+SpChX*0,YShift+20*20+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_LongInj[0]
		CheckBox LongInj2Check pos={PanWidth/2+4+SpChX*1,YShift+20*20+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_LongInj[1]
		CheckBox LongInj3Check pos={PanWidth/2+4+SpChX*2,YShift+20*20+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_LongInj[2]
		CheckBox LongInj4Check pos={PanWidth/2+4+SpChX*3,YShift+20*20+4+4},size={Panwidth/2-8-SpChX*3,19},Proc=ST_ToggleTweaks,title="4 Long I-step",value=root:MP:ST_Data:ST_LongInj[3]
		SetVariable ST_LongAmpISetVar,pos={PanWidth/2+4,YShift+20*21+4+4},size={(PanWidth/2-8)*1/2-4,20},title="I [nA]:"
		SetVariable ST_LongAmpISetVar,limits={-Inf,Inf,0.01},value=root:MP:ST_Data:ST_LongAmpI
		SetVariable ST_LongWidthSetVar,pos={PanWidth/2+(PanWidth/2-8)*1/2+4,YShift+20*21+4+4},size={(PanWidth/2-8)*1/2,20},title="W [ms]:"
		SetVariable ST_LongWidthSetVar,limits={0,Inf,50},value=root:MP:ST_Data:ST_LongWidth

		// PARAMS FOR ADDING NEGATIVE "SHORT" CURRENT STEP AFTER POSITIVE CURRENT STEP
		SpChX = 30
		CheckBox ShortInj1Check pos={4+SpChX*0,YShift+20*20+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_ShortInj[0]
		CheckBox ShortInj2Check pos={4+SpChX*1,YShift+20*20+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_ShortInj[1]
		CheckBox ShortInj3Check pos={4+SpChX*2,YShift+20*20+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_ShortInj[2]
		CheckBox ShortInj4Check pos={4+SpChX*3,YShift+20*20+4+4},size={Panwidth/2-8-SpChX*3,19},Proc=ST_ToggleTweaks,title="4 Short I-step",value=root:MP:ST_Data:ST_ShortInj[3]
		SetVariable ST_ShortAmpISetVar,pos={4,YShift+20*21+4+4},size={(PanWidth/2-8)*1/2-4,20},title="I [nA]:"
		SetVariable ST_ShortAmpISetVar,limits={-Inf,Inf,0.1},value=root:MP:ST_Data:ST_ShortAmpI
		SetVariable ST_ShortWidthSetVar,pos={(PanWidth/2-8)*1/2+4,YShift+20*21+4+4},size={(PanWidth/2-8)*1/2,20},title="W [ms]:"
		SetVariable ST_ShortWidthSetVar,limits={0,Inf,50},value=root:MP:ST_Data:ST_ShortWidth

		// PARAMS FOR NEGATIVE PULSES BETWEEN SPIKES
		SpChX = 30
		CheckBox NegPulse1Check pos={4+SpChX*0,YShift+20*22+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="1",value=root:MP:ST_Data:ST_NegPulse[0]
		CheckBox NegPulse2Check pos={4+SpChX*1,YShift+20*22+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="2",value=root:MP:ST_Data:ST_NegPulse[1]
		CheckBox NegPulse3Check pos={4+SpChX*2,YShift+20*22+4+4},size={SpChX-4,19},Proc=ST_ToggleTweaks,title="3",value=root:MP:ST_Data:ST_NegPulse[2]
		CheckBox NegPulse4Check pos={4+SpChX*3,YShift+20*22+4+4},size={Panwidth/2-8-SpChX*3+(PanWidth/2-8)/2,19},Proc=ST_ToggleTweaks,title="4 Neg pulse between spikes, of amplitude",value=root:MP:ST_Data:ST_NegPulse[3]
		SetVariable ST_NegPulseAmpISetVar,pos={PanWidth/2+4+PanWidth/4-4,YShift+20*22+4+4},size={(PanWidth/2-8)/2,20},title="I [nA]:"
		SetVariable ST_NegPulseAmpISetVar,limits={-Inf,Inf,0.01},value=root:MP:ST_Data:ST_NegPulseAmpI

		//// --- BUTTONS ---
		Button UpdatePatternMakerButton,pos={4,YShift+20*12+10},size={PanWidth/2-8,18},proc=ST_UpdatePatternMakerProc,title="Update PatternMaker"
		Button MakeExtracellularButton,pos={4,YShift+20*13+10},size={PanWidth/2-8,18},proc=ST_MakeExtracellularProc,title="-- Make extracellular wave --"
		Button ClosePanelAndPlotsButton,pos={4,YShift+20*14+10},size={PanWidth/4-8,18},proc=ST_CloseProc,title="Close panel & plots"
		Button ClosePlotsButton,pos={4+PanWidth/4,YShift+20*14+10},size={PanWidth/4-8,18},proc=ST_CloseProc,title="Close the plots"
		Button MakeButton,pos={4,YShift+20*15+10},size={PanWidth/2-8,18+10+4},proc=ST_MakeProc,title="*** Make the waves ***"
		Button MakeTRangeButton,pos={4,YShift+20*17+4},size={PanWidth/2-8,18},proc=ST_MakeTRangeProc,title="Make timing range"

		//// --- RANDOM SPIKING ---
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText 4,YShift+20*23+4+4+16+2,"Random Spiking"
		
		Button MakeRandomUniButton,pos={4+PanWidth/2*0.5,YShift+20*23+4+4+4},size={PanWidth/2*(1-0.5)-4,18},proc=ST_MakeRandomProc,title="Uniform"

		Button MakeRandomPoiButton,pos={PanWidth/2+4,YShift+20*23+4+4+4},size={PanWidth/4-8,18},proc=ST_MakeRandomProc2,title="Poisson"

		SetVariable ST_nWavesSetVar,pos={PanWidth/2+4+PanWidth/4,YShift+20*23+4+4+4},size={PanWidth/4-8,20},title="# of waves:"
		SetVariable ST_nWavesSetVar,limits={1,Inf,1},value=root:MP:ST_Data:ST_nWaves
		
		Variable xShift = 48

		SetVariable ST_RandWidTrainSetVar,pos={4,YShift+20*24+4+4+4},size={PanWidth/2+xShift-8,20},title="TRAIN: Distribution width [ms]:"
		SetVariable ST_RandWidTrainSetVar,limits={0,Inf,5},value=root:MP:ST_Data:ST_RandWidTrain
		SetVariable ST_nGrainsTrainSetVar,pos={PanWidth/2+4+xShift,YShift+20*24+4+4+4},size={PanWidth/2-xShift-8-40,20},title= "Graininess:"
		SetVariable ST_nGrainsTrainSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_nGrainsTrain
		CheckBox ST_RandTrainsOffCheck pos={PanWidth/2+4+PanWidth/2-8-40+4,YShift+20*24+4+4+4},size={32,20},title="off",value=root:MP:ST_Data:RandTrainsOff

		SetVariable ST_RandWidSpikesSetVar,pos={4,YShift+20*25+4+4+4},size={PanWidth/2+xShift-8,20},title="SPIKES: Distribution width [ms]:"
		SetVariable ST_RandWidSpikesSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_RandWidSpikes
		SetVariable ST_nGrainsSpikesSetVar,pos={PanWidth/2+4+xShift,YShift+20*25+4+4+4},size={PanWidth/2-xShift-8-40,20},title= "Graininess:"
		SetVariable ST_nGrainsSpikesSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_nGrainsSpikes
		CheckBox ST_RandSpikesOffCheck pos={PanWidth/2+4+PanWidth/2-8-40+4,YShift+20*25+4+4+4},size={32,20},title="off",value=root:MP:ST_Data:RandSpikesOff

		Button RedoCorrButton,pos={4,YShift+20*26+4+4+2},size={PanWidth/2*0.25-4,18},proc=ST_TheCorrelogramsProc,title="Redo"
		SetVariable ST_CorrWidSetVar,pos={4+PanWidth/2*0.25,YShift+20*26+4+4+4},size={PanWidth/2+xShift-8-PanWidth/2*0.25,20},title="CORRELOGRAM: Width [ms]:"
		SetVariable ST_CorrWidSetVar,limits={0,Inf,5},value=root:MP:ST_Data:ST_CorrWid
		SetVariable ST_CorrNBinsSetVar,pos={PanWidth/2+4+xShift,YShift+20*26+4+4+4},size={PanWidth/2-xShift-8,20},title= "Number of bins:"
		SetVariable ST_CorrNBinsSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_CorrNBins
		
		//// --- CYCLE THROUGH WAVES ---
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText 4,YShift+20*27+4+4+4+16+2,"Cycle through waves:"
		SetVariable ST_nTotIterSetVar,pos={4+PanWidth/2,YShift+20*27+4+4+4+4},size={PanWidth/2-8,20},title="Total number of iterations:"
		SetVariable ST_nTotIterSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_Cycle_TotIter
		Button MakeCycleButton,pos={4,YShift+20*28+4+4+4+2},size={PanWidth/2/3-8,18},proc=ST_MakeCycleProc,title="Make"
		SetVariable ST_CycleSuffixSetVar,pos={4+PanWidth/2/3-4,YShift+20*28+4+4+4+2},size={PanWidth/2-(PanWidth/2/3-8)-8,20},title="Suffix: "
		SetVariable ST_CycleSuffixSetVar,limits={0,Inf,100},value=root:MP:ST_Data:ST_Cycle_Suffix
		SetVariable ST_nCycleSetVar,pos={4+PanWidth/2,YShift+20*28+4+4+4+4},size={PanWidth/2-8,20},title="Number of waves in cycle:"
		SetVariable ST_nCycleSetVar,limits={0,Inf,1},value=root:MP:ST_Data:ST_Cycle_nCycle

		//// --- EXPORT WAVES AS TEXT FILES ---
		SetDrawEnv fsize= 14,fstyle= 5,textrgb= (0,0,0)
		DrawText 4,YShift+20*28+4+4+4+4+20+20+2,"Various"
		Button ST_ExportButton,pos={4+60,YShift+20*29+4+4+4+4+4},size={48,18},proc=ST_ExportProc,title="Export"
		
		//// --- CONVERT SPIKE TIME WAVES TO OUTPUT WAVES ---
		Button ST_SpTm2WavesButton,pos={4+60+48+4,YShift+20*29+4+4+4+4+4},size={66,18},proc=SpTm2WavesSetupProc,title="SpTm2Wv"

		
		//// --- PRODUCE COINCIDENCE DETECTION/MULTIMAKE PANEL ---
		SpChX = 24
		xShift = 60
		SetDrawEnv fsize= 12,fstyle= 1,textrgb= (0,0,0)
		Button ST_MultiMakePanelButton,pos={4+60+48+4+66+4+SpChX*0,YShift+20*29+4+4+4+4+4},size={SpChX-4+xShift,18},proc=ST_MultiMakePanelProc,title="MultiMake 1"
		Button ST_MultiMakePanel2Button,pos={4+60+48+4+66+4+SpChX*1+xShift,YShift+20*29+4+4+4+4+4},size={SpChX-4,18},proc=ST_MultiMakePanel2Proc,title="2"
		Button ST_MultiMakePanel3Button,pos={4+60+48+4+66+4+SpChX*2+xShift,YShift+20*29+4+4+4+4+4},size={SpChX-4,18},proc=ST_MultiMakePanel3Proc,title="3"
		Button ST_MultiMakePanel4Button,pos={4+60+48+4+66+4+SpChX*3+xShift,YShift+20*29+4+4+4+4+4},size={SpChX-4,18},proc=ST_MultiMakePanel4Proc,title="4"

		ST_ToggleShowTweaksProc("NoToggle")
		
	endif
		
End

//////////////////////////////////////////////////////////////////////////////////
//// Produce MultiMake panel
	
Function ST_MultiMakePanelProc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable	PanX = 590
	Variable	PanY = 500
	Variable	PanWidth = 360
	Variable	PanHeight = 200-18
	
	NVAR		ST_MM_Voltage1 = root:MP:ST_Data:ST_MM_Voltage1
	NVAR		ScSc = root:MP:ScSc

	DoWindow/K MultiPatch_ST_MultiMake
	NewPanel/K=2/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) as "MM1 - EPSPs & APs"
	DoWindow/C MultiPatch_ST_MultiMake
	ModifyPanel/W=MultiPatch_ST_MultiMake fixedSize=1
	DoUpdate
	
	Button ST_MM_MakeButton,pos={4,4},size={PanWidth/2-8,18},proc=ST_MM_MakeProc,fColor=(0,65535,0),title="+++ Make +++"
	Button ST_MM_CloseButton,pos={4+PanWidth/2,4},size={PanWidth/2-8,18},proc=ST_MM_ClosePanelProc,fColor=(65535,0,0),title="--- Close ---"

	SetDrawEnv fsize= 12,fstyle=5,textrgb= (0,0,0)
	DrawText 4,20*1+20,"Condition names:"

	SetVariable ST_MM_Cond1_SetVar,pos={4,20*2+4},size={PanWidth/2-8,20},title="1 Both 1:      ",font="Geneva"
	SetVariable ST_MM_Cond1_SetVar,value=root:MP:ST_Data:ST_MM_Name1
	SetVariable ST_MM_Cond2_SetVar,pos={4,20*3+4},size={PanWidth/2-8,20},title="2 Both 2:      ",font="Geneva"
	SetVariable ST_MM_Cond2_SetVar,value=root:MP:ST_Data:ST_MM_Name2
	SetVariable ST_MM_Cond3_SetVar,pos={4,20*4+4},size={PanWidth/2-8,20},title="3 No EPSP: ",font="Geneva"
	SetVariable ST_MM_Cond3_SetVar,value=root:MP:ST_Data:ST_MM_Name3
	SetVariable ST_MM_Cond4_SetVar,pos={4,20*5+4},size={PanWidth/2-8,20},title="4 No AP 1:   ",font="Geneva"
	SetVariable ST_MM_Cond4_SetVar,value=root:MP:ST_Data:ST_MM_Name4
	SetVariable ST_MM_Cond5_SetVar,pos={4,20*6+4},size={PanWidth/2-8,20},title="5 No AP 2:   ",font="Geneva"
	SetVariable ST_MM_Cond5_SetVar,value=root:MP:ST_Data:ST_MM_Name5

	SetDrawEnv fsize= 12,fstyle=5,textrgb= (0,0,0)
	DrawText 4+PanWidth/2,20*1+20,"Parameters:"

	SetVariable ST_MM_LowVoltage_SetVar,pos={4+PanWidth/2,20*2+4},size={PanWidth/2-8,20},title="Voltage 1 [V]: "
	SetVariable ST_MM_LowVoltage_SetVar,limits={0,Inf,0.1},value=root:MP:ST_Data:ST_MM_Voltage1

	SetVariable ST_MM_HighVoltage_SetVar,pos={4+PanWidth/2,20*3+4},size={PanWidth/2-8,20},title="Voltage 2 [V]: "
	SetVariable ST_MM_HighVoltage_SetVar,limits={0,Inf,0.1},value=root:MP:ST_Data:ST_MM_Voltage2

	// EPSPS ON THIS CHANNEL
	Variable	SpChX = 30
	Variable	YShift = 4
	Variable	Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	CheckBox Both1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	CheckBox Both2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	CheckBox Both3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	CheckBox Both4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Both",value=Temp

	// EPSPS ON THIS CHANNEL
	SpChX = 30
	YShift = 4+20
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular1Check
		Temp = Temp %& V_Value
	endif
	CheckBox NoEPSPs1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular2Check
		Temp = Temp %& V_Value
	endif
	CheckBox NoEPSPs2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular3Check
		Temp = Temp %& V_Value
	endif
	CheckBox NoEPSPs3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular4Check
		Temp = Temp %& V_Value
	endif
	CheckBox NoEPSPs4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - EPSPs",value=Temp

	// SPIKES ON THIS CHANNEL
	SpChX = 30
	YShift = 4+20+20

	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular1Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox NoAPs1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular2Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox NoAPs2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular3Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox NoAPs3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator Extracellular4Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox NoAPs4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - APs",value=Temp

	// Additional buttons
	Button ST_MM_UpdateButton,pos={4,20*7+4},size={PanWidth/2-8,18},proc=ST_MultiMakePanelProc,title="Update"
	Button ST_MM_KillGraphsButton,pos={4+PanWidth/2,20*7+4},size={PanWidth/2-8,18},proc=ST_MM_KillGraphsProc,title="Kill graphs"
	Button ST_MM_GraphsToFrontButton,pos={4,20*8+4},size={PanWidth/2-8,18},proc=ST_MM_GraphsToFrontProc,title="Graphs to front"
	Button ST_MM_GraphsToBackButton,pos={4+PanWidth/2,20*8+4},size={PanWidth/2-8,18},proc=ST_MM_GraphsToBackProc,title="Graphs to back"

End



//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 2 stupid fix for iontophoresis experiments
	
Function ST_MultiMakeFixProc(ctrlName) : ButtonControl
	String		ctrlName
	
	FixStart()
	
end

Function FixStart()

	NVAR	Ind_freq = root:MP:ST_Data:Ind_freq
	NVAR	Ind_nPulses = root:MP:ST_Data:Ind_nPulses
	NVAR	Ind_RelDispl_4 = root:MP:ST_Data:Ind_RelDispl_4
	NVAR	ST_LongWidth = root:MP:ST_Data:ST_LongWidth
	
	Ind_RelDispl_4 = (ST_LongWidth/2-(Ind_NPulses-1)/2*1/Ind_Freq*1000)
	
	print "Ind rel displ for Ch4:",Ind_RelDispl_4
	
	// (Ind_NPulses-1)/2*1/Ind_Freq*1000-ST_LongWidth/2

End

	
//////////////////////////////////////////////////////////////////////////////////
//// Produce MultiMake panel 2
	
Function ST_MultiMakePanel2Proc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable	PanX = 590+20
	Variable	PanY = 500
	Variable	PanWidth = 360
	Variable	PanHeight = 184
	
	NVAR		ST_MM_Voltage1 = root:MP:ST_Data:ST_MM_Voltage1
	NVAR		ST_MM_PercReduc = root:MP:ST_Data:ST_MM_PercReduc
	NVAR		ScSc = root:MP:ScSc

	DoWindow/K MultiPatch_ST_MultiMake2
	NewPanel/K=2/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) as "MM2 - Dendr Depol & APs"
	DoWindow/C MultiPatch_ST_MultiMake2
	ModifyPanel/W=MultiPatch_ST_MultiMake2 fixedSize=1
	DoUpdate
	
	Button ST_MM_MakeButton,pos={4,4},size={PanWidth/2-8,18},proc=ST_MM2_MakeProc,fColor=(0,65535,0),title="+++ Make +++"
	Button ST_MM_CloseButton,pos={4+PanWidth/2,4},size={PanWidth/2-8,18},proc=ST_MM2_ClosePanelProc,fColor=(65535,0,0),title="--- Close ---"

	SetDrawEnv fsize= 12,fstyle=5,textrgb= (0,0,0)
	DrawText 4,20*1+20,"Condition names:"

	SetVariable ST_MM_Cond1_SetVar,pos={4,20*3+4},size={PanWidth/2-8,20},title="1: "
	SetVariable ST_MM_Cond1_SetVar,value=root:MP:ST_Data:ST_MM2_Name1
	SetVariable ST_MM_Cond2_SetVar,pos={4,20*4+4},size={PanWidth/2-8,20},title="2: "
	SetVariable ST_MM_Cond2_SetVar,value=root:MP:ST_Data:ST_MM2_Name2
	SetVariable ST_MM_Cond3_SetVar,pos={4,20*5+4},size={PanWidth/2-8,20},title="3: "
	SetVariable ST_MM_Cond3_SetVar,value=root:MP:ST_Data:ST_MM2_Name3

	SetDrawEnv fsize= 12,fstyle=5,textrgb= (0,0,0)
	DrawText 4+PanWidth/2,20*1+20,"Parameters:"

	SetVariable ST_MM_PercRed_SetVar,pos={4,20*2+4},size={PanWidth/2-8,20},title="Reduce current [%]: "
	SetVariable ST_MM_PercRed_SetVar,limits={1,Inf,5},value=root:MP:ST_Data:ST_MM_PercReduc

	SetVariable ST_MM_LongIStep_SetVar,pos={4+PanWidth/2,20*2+4},size={PanWidth/2-8,20},title="Long I-step [nA]: "
	SetVariable ST_MM_LongIStep_SetVar,limits={-Inf,Inf,0.1},value=root:MP:ST_Data:ST_MM_LongIStep

	// BOTH ON THIS CHANNEL
	Variable	SpChX = 30
	Variable	YShift = 4-20
	Variable	Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	CheckBox Both1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	CheckBox Both2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	CheckBox Both3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	CheckBox Both4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Both",value=Temp

	// DEPOL ONLY ON THIS CHANNEL
	SpChX = 30
	YShift += 20
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec1Check
		Temp = Temp %& V_Value
	endif
	CheckBox DepolOnly1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec2Check
		Temp = Temp %& V_Value
	endif
	CheckBox DepolOnly2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec3Check
		Temp = Temp %& V_Value
	endif
	CheckBox DepolOnly3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec4Check
		Temp = Temp %& V_Value
	endif
	CheckBox DepolOnly4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Depol",value=Temp

	// APS ONLY ON THIS CHANNEL
	SpChX = 30
	YShift += 20

	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec1Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec2Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec3Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator DendriticRec4Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - APs",value=Temp

	// THIS CHANNEL IS PASSIVE (example: 2nd dendritic recording)
	SpChX = 30
	YShift += 20

	CheckBox Passive1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=0
	CheckBox Passive2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=0
	CheckBox Passive3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=0
	CheckBox Passive4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Passive",value=0

	// Additional buttons
	Button ST_MM_FixButton,pos={4,20*6+4},size={PanWidth/2-8,18},proc=ST_MultiMakeFixProc,title="Goofy fix"
	Button ST_MM_UpdateButton,pos={4,20*7+4},size={PanWidth/2-8,18},proc=ST_MultiMakePanel2Proc,title="Update"
	Button ST_MM_KillGraphsButton,pos={4+PanWidth/2,20*7+4},size={PanWidth/2-8,18},proc=ST_MM2_KillGraphsProc,title="Kill graphs"
	Button ST_MM_GraphsToFrontButton,pos={4,20*8+4},size={PanWidth/2-8,18},proc=ST_MM2_GraphsToFrontProc,title="Graphs to front"
	Button ST_MM_GraphsToBackButton,pos={4+PanWidth/2,20*8+4},size={PanWidth/2-8,18},proc=ST_MM2_GraphsToBackProc,title="Graphs to back"

End

//////////////////////////////////////////////////////////////////////////////////
//// Do the MultiMake 2
	
Function ST_MM2_MakeProc(ctrlName) : ButtonControl
	String		ctrlName

	NVAR		ST_LongAmpI = root:MP:ST_Data:ST_LongAmpI
		
	NVAR		ST_MM_LongIStep = 		root:MP:ST_Data:ST_MM_LongIStep
	NVAR		ST_MM_PercReduc = 	root:MP:ST_Data:ST_MM_PercReduc
	NVAR		Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]

	SVAR		ST_MM2_Name1 = root:MP:ST_Data:ST_MM2_Name1
	SVAR		ST_MM2_Name2 = root:MP:ST_Data:ST_MM2_Name2
	SVAR		ST_MM2_Name3 = root:MP:ST_Data:ST_MM2_Name3
	
	SVAR		ST_Suffix = root:MP:ST_Data:ST_Suffix
	
	Variable		TempLongIStep									// Remember Long I-step value
	Variable		TempInd_AmplitudeIClamp							// Remember current injection for spikes
	Variable		i
	Make/O/N=(4) TempNoSpikes									// Remember which channels have "no spikes" set
	Make/O/N=(4) TempLongInj									// Remember which channels have "LongInj1Check" set (or not)
	Make/O/N=(4) TempChannelsSelected							// Remember which channels are selected
	String		TempSuffix										// Remember suffix string
	
	Print "*** ST MultiMake 2:\tStarting"
	Print "*** ST MultiMake 2:\tStoring values"

	TempLongIStep = ST_LongAmpI
	TempSuffix = ST_Suffix
	TempInd_AmplitudeIClamp = Ind_AmplitudeIClamp

	ControlInfo/W=MultiPatch_ST_Creator NoSpikes1Check
	TempNoSpikes[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes2Check
	TempNoSpikes[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes3Check
	TempNoSpikes[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes4Check
	TempNoSpikes[3] = V_value

	ControlInfo/W=MultiPatch_ST_Creator LongInj1Check
	TempLongInj[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator LongInj2Check
	TempLongInj[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator LongInj3Check
	TempLongInj[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator LongInj4Check
	TempLongInj[3] = V_value
	
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	TempChannelsSelected[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	TempChannelsSelected[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	TempChannelsSelected[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	TempChannelsSelected[3] = V_value
	
	///////////////// 1 BOTH
	// Transfer Suffix string
	ST_Suffix = ST_MM2_Name1
	Print "*** ST MultiMake 2:\tDoing condition "+"BOTH"
	Ind_AmplitudeIClamp *= (ST_MM_PercReduc/100)
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=0
	// Transfer Long I-Step selected
	Variable	DepolOnly,Passive
	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly1Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive1Check
	Passive = V_Value
	CheckBox/Z LongInj1Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly2Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive2Check
	Passive = V_Value
	CheckBox/Z LongInj2Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly3Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive3Check
	Passive = V_Value
	CheckBox/Z LongInj3Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly4Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive4Check
	Passive = V_Value
	CheckBox/Z LongInj4Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	// Transfer Long I-Step value
	ST_LongAmpI = ST_MM_LongIStep
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)
	Ind_AmplitudeIClamp = TempInd_AmplitudeIClamp		// NOTE: Restore spike current injection during depolarization already here!

	///////////////// 2 DEPOL (NO APS)
	// Transfer Suffix string
	ST_Suffix = ST_MM2_Name2
	Print "*** ST MultiMake 2:\tDoing condition "+"DEPOL"
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=1
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=1
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=1
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=1
	// Transfer Long I-Step selected
	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly1Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive1Check
	Passive = V_Value
	CheckBox/Z LongInj1Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly2Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive2Check
	Passive = V_Value
	CheckBox/Z LongInj2Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly3Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive3Check
	Passive = V_Value
	CheckBox/Z LongInj3Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly4Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive4Check
	Passive = V_Value
	CheckBox/Z LongInj4Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %& (!(Passive)) )

	// Transfer Long I-Step value
	ST_LongAmpI = ST_MM_LongIStep
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// 3 APS (NO DEPOL)
	// Transfer Suffix string
	ST_Suffix = ST_MM2_Name3
	Print "*** ST MultiMake 2:\tDoing condition "+"APs"
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=0
	// Transfer Long I-Step selected
	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly1Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive1Check
	Passive = V_Value
	CheckBox/Z LongInj1Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly2Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive2Check
	Passive = V_Value
	CheckBox/Z LongInj2Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly3Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive3Check
	Passive = V_Value
	CheckBox/Z LongInj3Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	ControlInfo/W=MultiPatch_ST_MultiMake2 DepolOnly4Check
	DepolOnly = V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake2 Passive4Check
	Passive = V_Value
	CheckBox/Z LongInj4Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=( (DepolOnly) %| (Passive) )

	// Transfer Long I-Step value
	ST_LongAmpI = 0
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	Print "*** ST MultiMake 2:\tRestoring values"
	// Restore Long I-Step value
	ST_LongAmpI = TempLongIStep
	// Restore Suffix string
	ST_Suffix = TempSuffix
	// Restore Channels selected
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[0]
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[1]
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[2]
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[3]
	// Restore NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[0]
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[1]
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[2]
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[3]
	// Restore LongInj selected
	CheckBox/Z LongInj1Check,win=MultiPatch_ST_Creator,Value=TempLongInj[0]
	CheckBox/Z LongInj2Check,win=MultiPatch_ST_Creator,Value=TempLongInj[1]
	CheckBox/Z LongInj3Check,win=MultiPatch_ST_Creator,Value=TempLongInj[2]
	CheckBox/Z LongInj4Check,win=MultiPatch_ST_Creator,Value=TempLongInj[3]
	
	// Do the restore
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	// Close all ST_CreatorWindows
	ST_CloseAllGraphs()						// Should be superfluous, keeping it, though
	
	// Producing graphs
	Print "*** ST MultiMake 2:\tProducing graphs"
	Variable	nChannelsSelected = 0
	i = 0
	do
		ControlInfo/W=MultiPatch_ST_MultiMake2 $("Both"+num2str(i+1)+"Check")
		if (V_Value)
			nChannelsSelected += 1
		endif
		i += 1
	while (i<4)

	Variable	winXSp= 12
	Variable	winXSize = 880-winXSp*nChannelsSelected
	Variable	winX = 4
	Variable	winY = 64
	Variable	winWidth = winXSize/nChannelsSelected //240
	Variable	winHeight = 400
 	Variable	nChannelCounter = 0
	
	SVAR		ST_BaseName = root:MP:ST_Data:ST_BaseName

	i = 0
	do
		ControlInfo/W=MultiPatch_ST_MultiMake2 $("Both"+num2str(i+1)+"Check")
		if (V_Value)
			DoWindow/K $("ST_MM2_"+num2str(i+1))
			Display/W=(winX+(winWidth+winXSp)*nChannelCounter,winY,winX+(winWidth+winXSp)*nChannelCounter+winWidth,winY+winHeight) as "Channel #"+num2str(i+1)
			DoWindow/C $("ST_MM2_"+num2str(i+1))
			nChannelCounter += 1
			AppendToGraph/W=$("ST_MM2_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM2_Name1)
			AppendToGraph/W=$("ST_MM2_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM2_Name2)
			AppendToGraph/W=$("ST_MM2_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM2_Name3)
			DoUpdate
			DoSpreadTracesInGraph("ST_MM2_"+num2str(i+1),1)
			CallColorizeTraces2()
		endif
		i += 1
	while (i<4)
	

	Print "*** ST MultiMake 2:\tDone"
	
End


//////////////////////////////////////////////////////////////////////////////////
//// Do the MultiMake
	
Function ST_MM_MakeProc(ctrlName) : ButtonControl
	String		ctrlName
		
	NVAR		ST_Voltage = root:MP:ST_Data:ST_Voltage
	
	NVAR		ST_MM_Voltage1 = root:MP:ST_Data:ST_MM_Voltage1
	NVAR		ST_MM_Voltage2 = root:MP:ST_Data:ST_MM_Voltage2

	SVAR		ST_MM_Name1 = root:MP:ST_Data:ST_MM_Name1
	SVAR		ST_MM_Name2 = root:MP:ST_Data:ST_MM_Name2
	SVAR		ST_MM_Name3 = root:MP:ST_Data:ST_MM_Name3
	SVAR		ST_MM_Name4 = root:MP:ST_Data:ST_MM_Name4
	SVAR		ST_MM_Name5 = root:MP:ST_Data:ST_MM_Name5
	
	SVAR		ST_Suffix = root:MP:ST_Data:ST_Suffix
	
	Variable	TempVoltage										// Remember voltage
	Make/O/N=(4) TempNoSpikes									// Remember which channels have "no spikes" set
	Make/O/N=(4) TempChannelsSelected							// Remember which channels are selected
	String		TempSuffix											// Remember suffix string
	
	Print "*** ST MultiMake:\tStarting"
	Print "*** ST MultiMake:\tStoring values"

	TempVoltage = ST_Voltage
	TempSuffix = ST_Suffix

	ControlInfo/W=MultiPatch_ST_Creator NoSpikes1Check
	TempNoSpikes[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes2Check
	TempNoSpikes[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes3Check
	TempNoSpikes[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes4Check
	TempNoSpikes[3] = V_value
	
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	TempChannelsSelected[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	TempChannelsSelected[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	TempChannelsSelected[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	TempChannelsSelected[3] = V_value
	
	///////////////// Both 1
	// Transfer Suffix string
	ST_Suffix = ST_MM_Name1
	Print "*** ST MultiMake:\tDoing condition "+ST_Suffix
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected - NoEPSPs1Check
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=0
	// Transfer Voltage value
	ST_Voltage = ST_MM_Voltage1
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// Both 2
	// Transfer Suffix string
	ST_Suffix = ST_MM_Name2
	Print "*** ST MultiMake:\tDoing condition "+ST_Suffix
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=0
	// Transfer Voltage value
	ST_Voltage = ST_MM_Voltage2
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// No EPSPs
	// Transfer Suffix string
	ST_Suffix = ST_MM_Name3
	Print "*** ST MultiMake:\tDoing condition "+ST_Suffix
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	ControlInfo/W=MultiPatch_ST_MultiMake NoEPSPs1Check
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoEPSPs2Check
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoEPSPs3Check
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoEPSPs4Check
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer Voltage value
	ST_Voltage = 0
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// No APs 1
	// Transfer Suffix string
	ST_Suffix = ST_MM_Name4
	Print "*** ST MultiMake:\tDoing condition "+ST_Suffix
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs1Check
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs2Check
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs3Check
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs4Check
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer Voltage value
	ST_Voltage = ST_MM_Voltage1
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// No APs 2
	// Transfer Suffix string
	ST_Suffix = ST_MM_Name5
	Print "*** ST MultiMake:\tDoing condition "+ST_Suffix
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs1Check
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs2Check
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs3Check
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake NoAPs4Check
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer Voltage value
	ST_Voltage = ST_MM_Voltage2
	// Make
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	Print "*** ST MultiMake:\tRestoring values"
	// Restore Voltage value
	ST_Voltage = TempVoltage
	// Restore Suffix string
	ST_Suffix = TempSuffix
	// Restore Channels selected
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[0]
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[1]
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[2]
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[3]
	// Restore NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[0]
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[1]
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[2]
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[3]
	// Do the restore
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	// Close all ST_CreatorWindows
	ST_CloseAllGraphs()						// Should be superfluous, keeping it, though
	
	// Producing graphs
	Print "*** ST MultiMake:\tProducing graphs"
	Variable	i
	Variable	nChannelsSelected = 0
	i = 0
	do
		ControlInfo/W=MultiPatch_ST_MultiMake $("Both"+num2str(i+1)+"Check")
		if (V_Value)
			nChannelsSelected += 1
		endif
		i += 1
	while (i<4)

	Variable	winXSp= 12
	Variable	winXSize = 960-winXSp*nChannelsSelected
	Variable	winX = 4
	Variable	winY = 64
	Variable	winWidth = winXSize/nChannelsSelected //240
	Variable	winHeight = 400
 	Variable	nChannelCounter = 0
	
	SVAR		ST_BaseName = root:MP:ST_Data:ST_BaseName

	i = 0
	do
		ControlInfo/W=MultiPatch_ST_MultiMake $("Both"+num2str(i+1)+"Check")
		if (V_Value)
			DoWindow/K $("ST_MM_"+num2str(i+1))
			Display/W=(winX+(winWidth+winXSp)*nChannelCounter,winY,winX+(winWidth+winXSp)*nChannelCounter+winWidth,winY+winHeight) as "Channel #"+num2str(i+1)
			DoWindow/C $("ST_MM_"+num2str(i+1))
			nChannelCounter += 1
			AppendToGraph/W=$("ST_MM_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM_Name1)
			AppendToGraph/W=$("ST_MM_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM_Name2)
			AppendToGraph/W=$("ST_MM_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM_Name3)
			AppendToGraph/W=$("ST_MM_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM_Name4)
			AppendToGraph/W=$("ST_MM_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM_Name5)
			DoSpreadTracesInGraph("ST_MM_"+num2str(i+1),1)
		endif
		i += 1
	while (i<4)
	

	Print "*** ST MultiMake:\tDone"
	
End

//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 2 graphs to back
	
Function ST_MM2_GraphsToBackProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/B $("ST_MM2_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 2 graphs to front
	
Function ST_MM2_GraphsToFrontProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/F $("ST_MM2_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Kill MultiMake 2 graphs
	
Function ST_MM2_KillGraphsProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/K $("ST_MM2_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 1 graphs to back
	
Function ST_MM_GraphsToBackProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/B $("ST_MM_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 1 graphs to front
	
Function ST_MM_GraphsToFrontProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/F $("ST_MM_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Kill MultiMake 1 graphs
	
Function ST_MM_KillGraphsProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/K $("ST_MM_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Kill MultiMake panel 1
	
Function ST_MM_ClosePanelProc(ctrlName) : ButtonControl
	String		ctrlName

	DoWindow/K MultiPatch_ST_MultiMake
	ST_MM_KillGraphsProc("")

end

//////////////////////////////////////////////////////////////////////////////////
//// Kill MultiMake panel 2
	
Function ST_MM2_ClosePanelProc(ctrlName) : ButtonControl
	String		ctrlName

	DoWindow/K MultiPatch_ST_MultiMake2
	ST_MM2_KillGraphsProc("")

end

//////////////////////////////////////////////////////////////////////////////////
//// Kill MultiMake panel 4
	
Function ST_MM4_ClosePanelProc(ctrlName) : ButtonControl
	String		ctrlName

	DoWindow/K MultiPatch_ST_MultiMake4
	ST_MM4_KillGraphsProc("")

end

//////////////////////////////////////////////////////////////////////////////////
//// Kill MultiMake 4 graphs
	
Function ST_MM4_KillGraphsProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/K $("ST_MM4_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 4 graphs to back
	
Function ST_MM4_GraphsToBackProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/B $("ST_MM4_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// MultiMake 4 graphs to front
	
Function ST_MM4_GraphsToFrontProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	
	i = 0
	do
		DoWindow/F $("ST_MM4_"+num2str(i+1))
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Do the MultiMake 4
	
Function ST_MM4_MakeProc(ctrlName) : ButtonControl
	String		ctrlName

	SVAR		ST_MM4_Name1 = root:MP:ST_Data:ST_MM4_Name1
	SVAR		ST_MM4_Name2 = root:MP:ST_Data:ST_MM4_Name2
	SVAR		ST_MM4_Name3 = root:MP:ST_Data:ST_MM4_Name3
	
	SVAR		ST_Suffix = root:MP:ST_Data:ST_Suffix
	
	Variable		i
	Make/O/N=(4) TempNoSpikes									// Remember which channels have "no spikes" set
	Make/O/N=(4) TempChannelsSelected							// Remember which channels are selected
	String		TempSuffix											// Remember suffix string
	
	Print "*** ST MultiMake 4:\tStarting"
	Print "*** ST MultiMake 4:\tStoring values"

	TempSuffix = ST_Suffix

	ControlInfo/W=MultiPatch_ST_Creator NoSpikes1Check
	TempNoSpikes[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes2Check
	TempNoSpikes[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes3Check
	TempNoSpikes[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator NoSpikes4Check
	TempNoSpikes[3] = V_value

	
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	TempChannelsSelected[0] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	TempChannelsSelected[1] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	TempChannelsSelected[2] = V_value
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	TempChannelsSelected[3] = V_value
	
	///////////////// 1 BOTH
	// Transfer Suffix string
	ST_Suffix = ST_MM4_Name1
	Print "*** ST MultiMake 4:\tDoing condition "+"BOTH"
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=0
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=0
	// Any passive channel? --- NOTE TO SELF: To implement, use as template, copy three times
//	Variable	Passive
//	ControlInfo/W=MultiPatch_ST_MultiMake4 Passive1Check
//	Passive = V_Value
//	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=(Passive)

	// Make
	doUpdate
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// 2 LIGHT (NO APS)
	// Transfer Suffix string
	ST_Suffix = ST_MM4_Name2
	Print "*** ST MultiMake 4:\tDoing condition "+"LIGHT"
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	ControlInfo/W=MultiPatch_ST_MultiMake4 APsOnly1Check
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	ControlInfo/W=MultiPatch_ST_MultiMake4 APsOnly2Check
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	ControlInfo/W=MultiPatch_ST_MultiMake4 APsOnly3Check
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	ControlInfo/W=MultiPatch_ST_MultiMake4 APsOnly4Check
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	// Any passive channel? --- NOTE TO SELF: To implement, use as template, copy three times
//	Variable	Passive
//	ControlInfo/W=MultiPatch_ST_MultiMake4 Passive1Check
//	Passive = V_Value
//	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=(Passive)

	// Make
	doUpdate
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	///////////////// 3 APS (NO LIGHT)
	// Transfer Suffix string
	ST_Suffix = ST_MM4_Name3
	Print "*** ST MultiMake 4:\tDoing condition "+"APs"
	// Transfer Channels selected
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both1Check
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both2Check
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both3Check
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=V_Value
	ControlInfo/W=MultiPatch_ST_MultiMake4 Both4Check
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=V_Value
	// Transfer NoSpikes selected
	ControlInfo/W=MultiPatch_ST_MultiMake4 LightOnly1Check
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	ControlInfo/W=MultiPatch_ST_MultiMake4 LightOnly2Check
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	ControlInfo/W=MultiPatch_ST_MultiMake4 LightOnly3Check
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	ControlInfo/W=MultiPatch_ST_MultiMake4 LightOnly4Check
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=(V_Value)
	// Any passive channel? --- NOTE TO SELF: To implement, use as template, copy three times
//	Variable	Passive
//	ControlInfo/W=MultiPatch_ST_MultiMake4 Passive1Check
//	Passive = V_Value
//	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=(Passive)

	// Make
	doUpdate
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	ST_DoTheMake(2)

	Print "*** ST MultiMake 4:\tRestoring values"
	// Restore Suffix string
	ST_Suffix = TempSuffix
	// Restore Channels selected
	CheckBox/Z CellOn1Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[0]
	CheckBox/Z CellOn2Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[1]
	CheckBox/Z CellOn3Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[2]
	CheckBox/Z CellOn4Check,win=MultiPatch_ST_Creator,Value=TempChannelsSelected[3]
	// Restore NoSpikes selected
	CheckBox/Z NoSpikes1Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[0]
	CheckBox/Z NoSpikes2Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[1]
	CheckBox/Z NoSpikes3Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[2]
	CheckBox/Z NoSpikes4Check,win=MultiPatch_ST_Creator,Value=TempNoSpikes[3]
	
	// Do the restore
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()
	// Close all ST_CreatorWindows
	ST_CloseAllGraphs()						// Should be superfluous, keeping it, though
	
	// Producing graphs
	Print "*** ST MultiMake 4:\tProducing graphs"
	Variable	nChannelsSelected = 0
	i = 0
	do
		ControlInfo/W=MultiPatch_ST_MultiMake4 $("Both"+num2str(i+1)+"Check")
		if (V_Value)
			nChannelsSelected += 1
		endif
		i += 1
	while (i<4)

	Variable	winXSp= 12
	Variable	winXSize = 880-winXSp*nChannelsSelected
	Variable	winX = 4
	Variable	winY = 64
	Variable	winWidth = winXSize/nChannelsSelected //240
	Variable	winHeight = 400
 	Variable	nChannelCounter = 0
	
	SVAR		ST_BaseName = root:MP:ST_Data:ST_BaseName

	i = 0
	do
		ControlInfo/W=MultiPatch_ST_MultiMake4 $("Both"+num2str(i+1)+"Check")
		if (V_Value)
			DoWindow/K $("ST_MM4_"+num2str(i+1))
			Display/W=(winX+(winWidth+winXSp)*nChannelCounter,winY,winX+(winWidth+winXSp)*nChannelCounter+winWidth,winY+winHeight) as "Channel #"+num2str(i+1)
			DoWindow/C $("ST_MM4_"+num2str(i+1))
			nChannelCounter += 1
			AppendToGraph/W=$("ST_MM4_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM4_Name1)
			AppendToGraph/W=$("ST_MM4_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM4_Name2)
			AppendToGraph/W=$("ST_MM4_"+num2str(i+1)) $(ST_BaseName+num2str(i+1)+ST_MM4_Name3)
			DoUpdate
			DoSpreadTracesInGraph("ST_MM4_"+num2str(i+1),1)
			CallColorizeTraces2()
		endif
		i += 1
	while (i<4)
	

	Print "*** ST MultiMake 4:\tDone"
	
End
//////////////////////////////////////////////////////////////////////////////////
//// Produce MultiMake panel 4
	
Function ST_MultiMakePanel4Proc(ctrlName) : ButtonControl
	String		ctrlName
	
	Variable	PanX = 590+20+20
	Variable	PanY = 300
	Variable	PanWidth = 360
	Variable	PanHeight = 184-20
	
	NVAR		ScSc = root:MP:ScSc

	DoWindow/K MultiPatch_ST_MultiMake4
	NewPanel/K=2/W=(PanX*ScSc,PanY*ScSc,PanX*ScSc+PanWidth,PanY*ScSc+PanHeight) as "MM4 - APs & Light Pulses"
	DoWindow/C MultiPatch_ST_MultiMake4
	ModifyPanel/W=MultiPatch_ST_MultiMake4 fixedSize=1
	DoUpdate
	
	Button ST_MM_MakeButton,pos={4,4},size={PanWidth/2-8,18+20},proc=ST_MM4_MakeProc,fColor=(0,65535,0),title="+++ Make +++"
	Button ST_MM_CloseButton,pos={4+PanWidth/2,4},size={PanWidth/2-8,18+20},proc=ST_MM4_ClosePanelProc,fColor=(65535,0,0),title="--- Close ---"

	SetDrawEnv fsize= 12,fstyle=5,textrgb= (0,0,0)
	DrawText 4,20*1+20+20,"Condition names:"

	SetVariable ST_MM_Cond1_SetVar,pos={4,20*3+4},size={PanWidth/2-8,20},title="1: "
	SetVariable ST_MM_Cond1_SetVar,value=root:MP:ST_Data:ST_MM4_Name1
	SetVariable ST_MM_Cond2_SetVar,pos={4,20*4+4},size={PanWidth/2-8,20},title="2: "
	SetVariable ST_MM_Cond2_SetVar,value=root:MP:ST_Data:ST_MM4_Name2
	SetVariable ST_MM_Cond3_SetVar,pos={4,20*5+4},size={PanWidth/2-8,20},title="3: "
	SetVariable ST_MM_Cond3_SetVar,value=root:MP:ST_Data:ST_MM4_Name3

	SetDrawEnv fsize= 12,fstyle=5,textrgb= (0,0,0)
	DrawText 4+PanWidth/2,20*1+20+20,"Parameters:"

	// BOTH ON THIS CHANNEL
	Variable	SpChX = 30
	Variable	YShift = 4-20
	Variable	Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	CheckBox Both1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	CheckBox Both2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	CheckBox Both3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	CheckBox Both4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Both",value=Temp

	// LIGHT ONLY ON THIS CHANNEL
	SpChX = 30
	YShift += 20
	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim1Check
		Temp = Temp %& V_Value
	endif
	CheckBox LightOnly1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim2Check
		Temp = Temp %& V_Value
	endif
	CheckBox LightOnly2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim3Check
		Temp = Temp %& V_Value
	endif
	CheckBox LightOnly3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp
	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim4Check
		Temp = Temp %& V_Value
	endif
	CheckBox LightOnly4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Light",value=Temp

	// APS ONLY ON THIS CHANNEL
	SpChX = 30
	YShift += 20

	ControlInfo/W=MultiPatch_ST_Creator CellOn1Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim1Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn2Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim2Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn3Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim3Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=Temp

	ControlInfo/W=MultiPatch_ST_Creator CellOn4Check
	Temp = V_Value
	if (Temp)
		ControlInfo/W=MultiPatch_ST_Creator LightStim4Check
		Temp = Temp %& (!V_Value)
	endif
	CheckBox APsOnly4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - APs",value=Temp

	// THIS CHANNEL IS PASSIVE (example: 2nd dendritic recording)
//	SpChX = 30
//	YShift += 20
//
//	CheckBox Passive1Check pos={PanWidth/2+4+SpChX*0,20*4+YShift},size={SpChX-4,19},title="1",value=0
//	CheckBox Passive2Check pos={PanWidth/2+4+SpChX*1,20*4+YShift},size={SpChX-4,19},title="2",value=0
//	CheckBox Passive3Check pos={PanWidth/2+4+SpChX*2,20*4+YShift},size={SpChX-4,19},title="3",value=0
//	CheckBox Passive4Check pos={PanWidth/2+4+SpChX*3,20*4+YShift},size={Panwidth/2-8-SpChX*3,19},title="4 - Passive",value=0

	// Additional buttons
//	Button ST_MM_FixButton,pos={4,20*6+4},size={PanWidth/2-8,18},proc=ST_MultiMakeFixProc,title="Goofy fix"
	Button ST_MM_UpdateButton,pos={4,20*6+4},size={PanWidth/2-8,18},proc=ST_MultiMakePanel4Proc,title="Update"
	Button ST_MM_KillGraphsButton,pos={4+PanWidth/2,20*6+4},size={PanWidth/2-8,18},proc=ST_MM4_KillGraphsProc,title="Kill graphs"
	Button ST_MM_GraphsToFrontButton,pos={4,20*7+4},size={PanWidth/2-8,18},proc=ST_MM4_GraphsToFrontProc,title="Graphs to front"
	Button ST_MM_GraphsToBackButton,pos={4+PanWidth/2,20*7+4},size={PanWidth/2-8,18},proc=ST_MM4_GraphsToBackProc,title="Graphs to back"

End

//////////////////////////////////////////////////////////////////////////////////
//// Make extracellular stim wave only
	
Function ST_MakeExtracellularProc(ctrlName) : ButtonControl
	String		ctrlName
	
	ST_DoTheMake(1)

End

//////////////////////////////////////////////////////////////////////////////////
//// Make the waves to be used in the spike timing pattern -- RANDOM TRAINS
	
Function ST_MakeRandomProc(ctrlName) : ButtonControl
	String		ctrlName
	
	print "----------- Making random spike trains -----------"
	print "\tTime:",Time()
	
	ST_DoTheMakeRandom()
	print "--------- Done making random spike trains ---------"

End

//////////////////////////////////////////////////////////////////////////////////
//// Take notes -- RANDOM TRAINS

Function ST_TakeNotesForMakeRandom(AveRates)
	WAVE	AveRates

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V
	
	//// PARAMETERS FOR THE RANDOM SPIKE TRAINS
	NVAR	ST_nWaves = 			root:MP:ST_Data:ST_nWaves		// Number of waves to be generated
	NVAR	ST_RandWidTrain = 	root:MP:ST_Data:ST_RandWidTrain	// Width of uniform distribution in [ms] for the whole spike train
	NVAR	ST_nGrainsTrain =		root:MP:ST_Data:ST_nGrainsTrain	// Granularity or graininess of the above width
	NVAR	ST_RandWidSpikes =	root:MP:ST_Data:ST_RandWidSpikes	// Width of uniform distribution in [ms] for the individual spikes of a spike train
	NVAR	ST_nGrainsSpikes = 	root:MP:ST_Data:ST_nGrainsSpikes	// Granularity for the above width, as described for the spike train above
	NVAR	ST_CorrWid =			root:MP:ST_Data:ST_CorrWid		// Width of correlograms
	NVAR	ST_CorrNBins = 		root:MP:ST_Data:ST_CorrNBins		// Number of bins for the correlograms

	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4

	//// GENERAL
	NVAR	ST_AmplitudeVClamp = 	root:MP:ST_Data:ST_AmplitudeVClamp	// The pulse amplitude for _all_ voltage clamp pulses [nA]
	NVAR	ST_DurationVClamp =	root:MP:ST_Data:ST_DurationVClamp	// The pulse duration for _all_  voltage clamp pulses [ms]
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves

	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	NVAR	MMPooStyle =		root:MP:ST_Data:MMPooStyle		// Boolean: Is the protocol of the Bi&Poo, J.Neurosci, 1998 type?
																	// (Otherwise a LTP pairing protocol is assumed, with postsynaptic depolarization coincident with EPSP.)
	//// INDUCTION TWEAKS
	WAVE	ST_NoSpikes =		root:MP:ST_Data:ST_NoSpikes		// Used to store away the checkbox values -- No spikes at all on checked channel

	WAVE	ST_NegPulse =		root:MP:ST_Data:ST_NegPulse		// Used to store away the checkbox values -- Add negative pulses between spikes?
	NVAR	ST_NegPulseAmpI = root:MP:ST_Data:ST_NegPulseAmpI	// The size of the negative pulse

	WAVE	ST_LongInj =		root:MP:ST_Data:ST_LongInj		// Long current injection on this channel?
	NVAR	ST_LongAmpI = 		root:MP:ST_Data:ST_LongAmpI		// The amplitude of the long current injection step [nA]
	NVAR	ST_LongWidth = 	root:MP:ST_Data:ST_LongWidth		// The width of the long current injection step [ms] (centered around spike, or just before spike if short inj is also checked)

	WAVE	ST_ShortInj =		root:MP:ST_Data:ST_ShortInj		// Long current injection on this channel?
	NVAR	ST_ShortAmpI = 	root:MP:ST_Data:ST_ShortAmpI		// The amplitude of the short current injection step [nA]
	NVAR	ST_ShortWidth = 	root:MP:ST_Data:ST_ShortWidth	// The width of the short current injection step [ms] (occurs just before spike)

	WAVE	ST_KeepLast =		root:MP:ST_Data:ST_KeepLast		// Keep only last spike in spike train during induction on this channel?
	WAVE	ST_KeepFirst =		root:MP:ST_Data:ST_KeepFirst		// Keep only first spike in spike train during induction on this channel?

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I = 	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V = 	root:MP:SealTestAmp_V

	//// INDUCTION
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1	// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// GAINS USED FOR SCALING
	WAVE	OutGainIClampWave = root:MP:IO_Data:OutGainIClampWave
	WAVE	OutGainVClampWave = root:MP:IO_Data:OutGainVClampWave

	//// CHANNELS IN VOLTAGE CLAMP
	WAVE	VClampWave =		root:MP:IO_Data:VClampWave		// Boolean: Which channels are in voltage clamp? (otherwise current clamp)

	Variable	nDigs = 4												// Number of digits in the suffix number appended at the end of the waves
	Variable	i
	String		WorkStr
	
	print "\tDumping stats to notebook"
	
	ControlInfo/W=MultiPatch_ST_Creator ST_RandTrainsOffCheck
	Variable FlagRandTrainsOff = V_value
	
	ControlInfo/W=MultiPatch_ST_Creator ST_RandSpikesOffCheck
	Variable FlagRandSpikesOff = V_value

	Make/O/N=(4) Ind_RelDispl										// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}
	
	Make/O/N=(4) ThisChannelChecked

	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}
	
	i = 0
	do
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr				// This channel checked?
		ThisChannelChecked[i] = V_value
		i += 1
	while (i<4)
	
	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="RandomSpiker is producing waves\r\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+"\r\r"
	
	Notebook Parameter_Log ruler=Normal, text="\tGeneral parameters for the induction\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSample frequency:\t"+num2str(SampleFreq)+"\tHz\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPadding at the end of the last pulse of all waves:\t"+num2str(ST_EndPad)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tVoltage amplitude (extracellular):\t"+num2str(ST_Voltage)+"\tV\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude (Induction I clamp):\t"+num2str(Ind_AmplitudeIClamp)+"\tnA\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration (Induction I clamp):\t"+num2str(Ind_DurationIClamp)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tOrigin:\t"+num2str(Ind_Origin)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tFrequency of spike trains:\t"+num2str(Ind_Freq)+"\tHz\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tNumber of pulses in spike train:\t"+num2str(Ind_NPulses)+"\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tWave length of all baseline waves:\t"+num2str(Ind_WaveLength)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tNumber of waves generated:\t"+num2str(ST_nWaves)+"\r"

	if (ST_Biphasic)
		Notebook Parameter_Log ruler=TextRow, text="\t\tBiphasic extracellular pulse:\tYes\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tBiphasic extracellular pulse:\tNo\r"
	endif
	WorkStr = ""
	i = 0
	do
		if (ST_Extracellular[i])
			WorkStr += "ch #"+num2str(i+1)+" "
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tExtracellular channel(s):\t"+WorkStr+"\r"

	ControlInfo/W=MultiPatch_ST_Creator Ind_SealTestCheck
	if (V_value)
		Notebook Parameter_Log ruler=Normal, text="\t\tSealtest:\t\tYes\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tSealtest:\t\tNo\r"
	endif

	Notebook Parameter_Log ruler=Normal, text="\r\tTRAIN ‹ Parameters for random spiking:\r"
	if (FlagRandTrainsOff)
		Notebook Parameter_Log ruler=Normal, text="\t\tThis feature is OFF.\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tThis feature is ON.\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tWidth of random spiking:\t"+num2str(ST_RandWidTrain)+"\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tGraininess:\t"+num2str(ST_nGrainsTrain)+"\r"
	endif
	
	Notebook Parameter_Log ruler=Normal, text="\r\tSPIKES ‹ Parameters for random spiking:\r"
	if (FlagRandSpikesOff)
		Notebook Parameter_Log ruler=Normal, text="\t\tThis feature is OFF.\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tThis feature is ON.\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tWidth of random spiking:\t"+num2str(ST_RandWidSpikes)+"\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tGraininess:\t"+num2str(ST_nGrainsSpikes)+"\r"
	endif
	
	Notebook Parameter_Log ruler=SlotTabRow, text="\r"

	i = 0
	do
		if (ThisChannelChecked[i])
			Notebook Parameter_Log ruler=SlotTabRow, text="\tFor channel#"+num2str(i+1)+"/cell#"+num2str(CellNumbers[i])+", the gain:\t"+num2str(OutGainIClampWave[i])+",\tthe average rate:\t"+num2str(AveRates[i])+" Hz\r"
		endif
		i += 1
	while (i<4)
	
	Notebook Parameter_Log ruler=SlotTabRow, text="\r"

	KillWaves/Z Ind_RelDispl,ThisChannelChecked,CellNumbers			// Avoid potential tricky bug by scrapping these waves
	
End
	
//////////////////////////////////////////////////////////////////////////////////
//// Make the textwave for the Cycle Generator

Function ST_MakeCycleProc(ctrlName) : ButtonControl
	String		ctrlName

	//// GENERAL
	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves

	//// CycleGenerator
	NVAR	ST_Cycle_TotIter = 		root:MP:ST_Data:ST_Cycle_TotIter		// Total number of iterations, i.e. total number of steps in induction, or total number of waves listed in textwave
	NVAR	ST_Cycle_nCycle = 		root:MP:ST_Data:ST_Cycle_nCycle		// Number of waves per cycle
	SVAR	ST_Cycle_Suffix = 		root:MP:ST_Data:ST_Cycle_Suffix		// The suffix for the cycling text wave
	
	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4

	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}
	
	Make/T/O/N=(1) RemWaves
	Variable	RemWavesCounter = 0

	Variable	nDigs = 4												// Number of digits in the suffix number appended at the end of the waves
	
	Variable	i,j,k
	String		TheWave
	String		WorkStr,WorkStr2
	
	Print "-- START: MAKE LIST OF CYCLING WAVES --"

	Make/O/N=(4) ThisChannelChecked
	Variable	nChannelsChecked = 0
	print "\tFinding checked channels:"
	j = 0
	do
		WorkStr = "CellOn"+num2str(j+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr				// This channel checked?
		ThisChannelChecked[j] = V_value
		if (ThisChannelChecked[j])
			nChannelsChecked += 1
		endif
		j += 1
	while (j<4)
	print "\t\t("+num2str(nChannelsChecked)+" channel(s) checked.)"

	print "\tLists of the waves stored in the following text waves:"
	i = 0
	do
		if (ThisChannelChecked[i])
			TheWave = ST_BaseName+num2str(i+1)+ST_Cycle_Suffix
			KillWaves/Z $TheWave
			Make/T/O/N=(ST_Cycle_TotIter) $TheWave
			print "\t\tChannel #"+num2str(i+1)+"/Cell #"+num2str(CellNumbers[i])+":\t\""+TheWave+"\""
			WorkStr = ST_BaseName+num2str(i+1)+ST_Cycle_Suffix
			WAVE/T	ListOfWaves = $WorkStr
			k = 0	// Wave counter
			j = 0
			do
				TheWave = ST_BaseName+num2str(i+1)+ST_Cycle_Suffix+"_"+num2str(k+1)//JS_num2digstr(nDigs,k+1)
				if (!(Exists(TheWave)==1) %& (j==k))
					Print "\t\t\tProblem: The wave \""+TheWave+"\" does not seem to exist!"
					Abort "Problem! Check command window for further info!"
				else
					if (j==k)
						RemWaves[RemWavesCounter] = {TheWave}
						RemWavesCounter += 1
					endif
				endif
				ListOfWaves[j] = TheWave										// Store away the wave name
				k += 1
				if (k>=ST_Cycle_nCycle)
					k = 0
				endif
				j += 1
			while (j<ST_Cycle_TotIter)
		endif
		i += 1
	while (i<4)

	//// Take notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Making textwave describing cycling through waves\r\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+"\r\r"
	
	Notebook Parameter_Log ruler=Normal, text="\t\tNumber of waves in cycle:\t"+num2str(ST_Cycle_nCycle)+"\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tThese are:\r"
	i = 0
	do
		if (i==0)
			Notebook Parameter_Log ruler=Normal, text="\t\t\t"
		else
			Notebook Parameter_Log ruler=Normal, text=", "
		endif
		Notebook Parameter_Log ruler=Normal, text=RemWaves[i]
		i += 1
	while (i<RemWavesCounter)
	Notebook Parameter_Log ruler=Normal, text="\r\r"

	Print "-- END: MAKE LIST OF CYCLING WAVES --"

End

//////////////////////////////////////////////////////////////////////////////////
//// Generate Poisson Distributed Spikes
//// WARNING! This function thinks in terms of seconds, not milliseconds

Function ST_poissonSpikes(rate,nSpikes,pulseDur,firstSpikeAtZero)
	Variable	rate
	Variable	nSpikes
//	Variable	wDur
	Variable	pulseDur
	Variable	firstSpikeAtZero

	Variable	t = 0
	
	Variable	currISI
	Variable	ISIthres = pulseDur*2
	
	Make/O/N=(0) ST_spTimes
	Make/O/N=(0) ST_spISIs

	Variable	n = 1000
	Variable	i,j
	if (firstSpikeAtZero)
		i = 1
		ST_spTimes[numpnts(ST_spTimes)] = {0}
		ST_spISIs[numpnts(ST_spISIs)] = {0}
	else
		i = 0
	endif
	do
		j = 0
		do
			currISI = expNoise(1/rate)
			j += 1
		while((currISI<ISIthres) %& (j<n))
		
		t += currISI
		ST_spTimes[numpnts(ST_spTimes)] = {t}
		ST_spISIs[numpnts(ST_spISIs)] = {currISI}

		i += 1
	while(i<nSpikes)

	WaveStats/Q ST_spISIs
	if (ST_spISIs[0]==0)					// This if-clause is a terrible kludge to account for when the first spike time is fixed, so that ST_spISIs[0] = 0, which has to be kept for backward compatibility
		Duplicate/O ST_spISIs,ST_spISIs_temp
		DeletePoints 0,1,ST_spISIs_temp
		WaveStats/Q ST_spISIs_temp
		KillWaves ST_spISIs_temp
	endif
	print "nSpikes:"+num2str(numpnts(ST_spTimes))+", rate: "+num2str(1/V_avg)+", max freq: "+num2str(1/V_min)+" Hz, min freq: "+num2str(1/V_max)+" Hz"
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Make the waves to be used in the spike timing pattern -- RANDOM POISSON TRAINS
	
Function ST_MakeRandomProc2(ctrlName) : ButtonControl
	String		ctrlName
	
	print "----------- Making Poisson spike trains -----------"
	print "\tTime:",Time()
	
	ST_DoTheMakePoisson()
	print "--------- Done making Poisson spike trains ---------"

End

//////////////////////////////////////////////////////////////////////////////////
//// Do the actual making of random waves -- Poisson TRAINS

Function ST_DoTheMakePoisson()

	//// INDUCTION
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1	// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// GENERAL
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves
	
	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_StimDur =		root:MP:ST_Data:ST_StimDur			// Extrac stim pulse duration [samples]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V
	
	//// PARAMETERS FROM ST PANEL
	WAVE	ST_NoSpikes =		root:MP:ST_Data:ST_NoSpikes		// Used to store away the checkbox values -- No spikes at all on checked channel

	//// PARAMETERS FOR THE RANDOM SPIKE TRAINS
	NVAR	ST_nWaves = 			root:MP:ST_Data:ST_nWaves		// Number of waves to be generated
	NVAR	ST_RandWidTrain = 	root:MP:ST_Data:ST_RandWidTrain	// Width of uniform distribution in [ms] for the whole spike train
	NVAR	ST_nGrainsTrain =		root:MP:ST_Data:ST_nGrainsTrain	// Granularity or graininess of the above width
	NVAR	ST_RandWidSpikes =	root:MP:ST_Data:ST_RandWidSpikes	// Width of uniform distribution in [ms] for the individual spikes of a spike train
	NVAR	ST_nGrainsSpikes = 	root:MP:ST_Data:ST_nGrainsSpikes	// Granularity for the above width, as described for the spike train above
	NVAR	ST_CorrWid =			root:MP:ST_Data:ST_CorrWid		// Width of correlograms
	NVAR	ST_CorrNBins = 		root:MP:ST_Data:ST_CorrNBins		// Number of bins for the correlograms

	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4

	Variable	nDigs = 4												// Number of digits in the suffix number appended at the end of the waves
	
	Variable	TotalHeight = 768
	Variable	WinHeight
	Variable	WinWidth = 320
	Variable	WinSpacing = 30
	Variable	WinXPos = 10
	Variable	WinYPos = 50
	
	Variable	TracePercentSeparation = 10							// In graphs showing the traces, displace the waves by this many percent

	Variable	nChannelsChecked

	Variable	t_train,t_pulse											// The random time variables for the train and for the pulse, respectively
	Variable	BeginTrainAt											// Account for sealtest (or not)
	String		TheWave
	String		WorkStr,WorkStr2
	
	Variable	i,j,k,t,p,q
	
	Variable	spCounter = 0

	ST_CloseAllGraphs()

	Make/O/N=(4) Ind_RelDispl										// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}
	
	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) AveRates,AveISI
	AveRates = 0
	AveISI = 0

	Make/O/N=(4) ThisChannelChecked
	nChannelsChecked = 0
	print "\tStoring away spike times in the following waves:"
	j = 0
	do
		WorkStr = "CellOn"+num2str(j+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr				// This channel checked?
		ThisChannelChecked[j] = V_value
		if (ThisChannelChecked[j])
			nChannelsChecked += 1
			i = 0
			make/O/N=(ST_nWaves,Ind_NPulses) $("RND_SpikeTimes_"+num2str(CellNumbers[j]))
			print "\t\tChannel #"+num2str(j+1)+":\t\"RND_SpikeTimes_"+num2str(CellNumbers[j])+"\""
//			print "\t\tChannel #"+num2str(j+1)+":\t\"RND_SpikeTimes_"+num2str(CellNumbers[j])+"_xxxx\""
//			do
//				make/O/N=(0) $("RND_SpikeTimes_"+num2str(CellNumbers[j])+"_"+JS_num2digstr(nDigs,i+1))
//				i += 1
//			while (i<ST_nWaves)
		endif
		j += 1
	while (j<4)
	print "\t\t\t("+num2str(nChannelsChecked)+" channel(s) checked.)"

	WinHeight = TotalHeight/nChannelsChecked-WinSpacing

	PauseUpdate
	print "\tMaking graphs:"
	i = 0
	j = 0
	do
		DoWindow/K $("RND_"+num2str(j+1))
		if (ThisChannelChecked[j])
			Display/W=(WinXPos,WinYPos+(WinHeight+WinSpacing)*i,WinXPos+WinWidth,WinYPos+(WinHeight+WinSpacing)*i+WinHeight)/K=1 as "Channel #"+num2str(j+1)
			DoWindow/C $("RND_"+num2str(j+1))
			i += 1
		endif
		j += 1
	while (j<4)
	
	print "\tLists of the generated waves stored in the following text waves:"
	i = 0
	do
		if (ThisChannelChecked[i])
			TheWave = ST_BaseName+num2str(i+1)+ST_Suffix
			KillWaves/Z $TheWave
			Make/T/O/N=(ST_nWaves) $TheWave
			print "\t\tChannel #"+num2str(i+1)+"/Cell #"+num2str(CellNumbers[i])+":\t\""+TheWave+"\""
		endif
		i += 1
	while (i<4)

	ControlInfo/W=MultiPatch_ST_Creator Ind_SealTestCheck			// Add a sealtest to the induction waves?
	Variable	AddSealTest = V_value

	print "\tMaking the waves:"
	i = 0																		// == Go through waves ==
	do
		print "\t\tWorking on wave#"+num2str(i+1)
		
		j = 0
		do																		// == Go through channels ==

			if (ThisChannelChecked[j])											// Produce waves for this channel?

				TheWave = ST_BaseName+num2str(j+1)+ST_Suffix+"_"+JS_num2digstr(nDigs,i+1)
				WorkStr = ST_BaseName+num2str(j+1)+ST_Suffix
				WAVE/T	ListOfWaves = $WorkStr
				ListOfWaves[i] = TheWave										// Store away the wave name
				ProduceWave(TheWave,SampleFreq,Ind_WaveLength)
	
				//// Add sealtest
				if (AddSealTest)
					BeginTrainAt = SealTestPad1+SealTestDur+SealTestPad2+Ind_Origin+Ind_RelDispl[j]
					if (!(ST_Extracellular[j]))	
						ProducePulses(TheWave,SealTestPad1,1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
					endif
				else
					BeginTrainAt = Ind_Origin+Ind_RelDispl[j]
				endif
				
				//// Produce the pulses
//				ST_poissonSpikes(Ind_Freq,1.1*Ind_WaveLength*1e-3,Ind_DurationIClamp*1e-3)	// Add some slop to wave length
				ST_poissonSpikes(Ind_Freq,Ind_NPulses,Ind_DurationIClamp*1e-3,1)
				WAVE	ST_spTimes
				WAVE	ST_spISIs
				spCounter = 0
				WAVE	w1 = $("RND_SpikeTimes_"+num2str(CellNumbers[j]))//+"_"+JS_num2digstr(nDigs,i+1))
				k = 0
				do 
					t = ST_spTimes[k]*1e3+BeginTrainAt
					if (t>Ind_WaveLength)
						print "Outside..."
						k = Inf
					else
						WAVE	w1 = $("RND_SpikeTimes_"+num2str(CellNumbers[j]))
						w1[i][k] = t													// Store away spike times {wave,pulse}
//						w1[numpnts(w1)] = {t}										// Store away spike times {pulse number}
//						spCounter += 1

						if (ST_NoSpikes[j]==0)
							if (!(ST_Extracellular[j]))	
								ProducePulses(TheWave,t,1,Ind_DurationIClamp,1,Ind_AmplitudeIClamp,0,0,0,0)
							else
								ProducePulses(TheWave,t,1,(ST_StimDur-1)/SampleFreq*1000,1,ST_Voltage,0,0,0,0)
								if (ST_Biphasic)
									ProducePulses(TheWave,t+ST_StimDur/SampleFreq*1e3,1,(ST_StimDur-1)/SampleFreq*1000,1,-ST_Voltage,0,0,0,0)
								endif
							endif
						endif
						if (k!=0)
							AveISI[j] += ST_spISIs[k]
						endif
					endif
					k += 1
				while (k<Ind_NPulses)

				if (Ind_NPulses>1)
					AveISI[j] /= (Ind_NPulses-1)
				endif

				if (ST_NoSpikes[j]==0)
					if (!(ST_Extracellular[j]))	
						ProduceScaledWave(TheWave,j+1,1)								// Mode = 1 --> current clamp
					endif
				endif

				WAVE	w2 = $TheWave
				AppendToGraph/W=$("RND_"+num2str(j+1)) w2
				WaveStats/Q w2
				ModifyGraph/W=$("RND_"+num2str(j+1)) offset($TheWave)={0,-(V_max-V_min)*(100+TracePercentSeparation)/100*i}
				
			endif

			j += 1
		while (j<4)

		i += 1
	while (i<ST_nWaves)
	
	if (Ind_NPulses!=1)
		AveRates = 1/AveISI		// Want rate in Hz
		AveISI *= 1e3				// Want ISIs in ms
		WorkStr = ""
		WorkStr2 = "AveRates"
		i = 0
		do
			if (!(ThisChannelChecked[i]))
				AveRates[i] = NaN
			else
				WorkStr2 += ("_"+num2str(CellNumbers[i]))
			endif
			WorkStr += ("\t\t"+num2str(AveRates[i])+" Hz ")
			i += 1
		while (i<4)
		Duplicate/O AveRates,$WorkStr2
		print "\t\tAverage rates for each channel:"+WorkStr+"\t(copied to wave \""+WorkStr2+"\")"
	endif

	print "\tModifying graphs"
	Variable	MinStartAxis = Inf
	Variable	MaxEndAxis = -Inf
	j = 0
	do
		if (ThisChannelChecked[j])
			if (AddSealTest)
				BeginTrainAt = SealTestPad1+SealTestDur+SealTestPad2+Ind_Origin+Ind_RelDispl[j]
			else
				BeginTrainAt = Ind_Origin+Ind_RelDispl[j]
			endif
			if (MinStartAxis>BeginTrainAt/1000)
				MinStartAxis = BeginTrainAt/1000
			endif
			if (MaxEndAxis<(BeginTrainAt+1/Ind_Freq*1000*(Ind_NPulses-1)+ST_RandWidTrain+ST_RandWidSpikes+Ind_DurationIClamp)/1000)
				MaxEndAxis = (BeginTrainAt+1/Ind_Freq*1000*(Ind_NPulses-1)+ST_RandWidTrain+ST_RandWidSpikes+Ind_DurationIClamp)/1000
			endif
		endif
		j += 1
	while (j<4)
	MinStartAxis -= (ST_RandWidTrain/2000)
	j = 0
	do
		if (ThisChannelChecked[j])
			DoWindow/F $("RND_"+num2str(j+1))
			SetAxis bottom,MinStartAxis,MaxEndAxis
		endif
		j += 1
	while (j<4)
	DoUpdate
	
	KillWaves/Z Ind_RelDispl,ThisChannelChecked,CellNumbers					// Avoid potential tricky bug by scrapping these waves
	
	ST_DoTheCorrelogramsProc()
	ST_TakeNotesForMakeRandom(AveRates)

End

//////////////////////////////////////////////////////////////////////////////////
//// Do the actual making of waves -- RANDOM TRAINS

Function ST_DoTheMakeRandom()
	
	//// INDUCTION
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1	// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// GENERAL
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves
	
	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_StimDur = 		root:MP:ST_Data:ST_StimDur			// Stim pulse duration [samples]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V
	
	//// PARAMETERS FOR THE RANDOM SPIKE TRAINS
	NVAR	ST_nWaves = 			root:MP:ST_Data:ST_nWaves		// Number of waves to be generated
	NVAR	ST_RandWidTrain = 	root:MP:ST_Data:ST_RandWidTrain	// Width of uniform distribution in [ms] for the whole spike train
	NVAR	ST_nGrainsTrain =		root:MP:ST_Data:ST_nGrainsTrain	// Granularity or graininess of the above width
	NVAR	ST_RandWidSpikes =	root:MP:ST_Data:ST_RandWidSpikes	// Width of uniform distribution in [ms] for the individual spikes of a spike train
	NVAR	ST_nGrainsSpikes = 	root:MP:ST_Data:ST_nGrainsSpikes	// Granularity for the above width, as described for the spike train above
	NVAR	ST_CorrWid =			root:MP:ST_Data:ST_CorrWid		// Width of correlograms
	NVAR	ST_CorrNBins = 		root:MP:ST_Data:ST_CorrNBins		// Number of bins for the correlograms

	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4

	Variable	nDigs = 4												// Number of digits in the suffix number appended at the end of the waves
	
	Variable	i,j,k,t,p,q
	Variable	Counter
	Variable	t_train,t_pulse											// The random time variables for the train and for the pulse, respectively
	Variable	BeginTrainAt											// Account for sealtest (or not)
	Variable	nChannelsChecked
	String		TheWave
	String		WorkStr,WorkStr2
	
	Variable	TotalHeight = 768
	Variable	WinHeight
	Variable	WinWidth = 320
	Variable	WinSpacing = 30
	Variable	WinXPos = 10
	Variable	WinYPos = 50
	
	Variable	TracePercentSeparation = 10							// In graphs showing the traces, displace the waves by this many percent
	
	Variable	First = 1												// Boolean: True if currently working on the first selected channel
	Variable	FirstTime = Nan										// The time of the first pulse on the first channel
	
	ST_CloseAllGraphs()

	ControlInfo/W=MultiPatch_ST_Creator ST_RandTrainsOffCheck
	Variable FlagRandTrainsOff = V_value
	
	ControlInfo/W=MultiPatch_ST_Creator ST_RandSpikesOffCheck
	Variable FlagRandSpikesOff = V_value

	Make/O/N=(4) Ind_RelDispl										// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}
	
	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) AveRates,AveISI
	AveRates = 0
	AveISI = 0

	Make/O/N=(4) ThisChannelChecked
	nChannelsChecked = 0
	print "\tStoring away spike times in the following waves:"
	j = 0
	do
		WorkStr = "CellOn"+num2str(j+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr				// This channel checked?
		ThisChannelChecked[j] = V_value
		if (ThisChannelChecked[j])
			nChannelsChecked += 1
			make/O/N=(ST_nWaves,Ind_NPulses) $("RND_SpikeTimes_"+num2str(CellNumbers[j]))
			print "\t\tChannel #"+num2str(j+1)+":\t\"RND_SpikeTimes_"+num2str(CellNumbers[j])+"\""
		endif
		j += 1
	while (j<4)
	print "\t\t\t("+num2str(nChannelsChecked)+" channel(s) checked.)"

	WinHeight = TotalHeight/nChannelsChecked-WinSpacing

	PauseUpdate
	print "\tMaking graphs:"
	i = 0
	j = 0
	do
		DoWindow/K $("RND_"+num2str(j+1))
		if (ThisChannelChecked[j])
			Display/W=(WinXPos,WinYPos+(WinHeight+WinSpacing)*i,WinXPos+WinWidth,WinYPos+(WinHeight+WinSpacing)*i+WinHeight)/K=1 as "Channel #"+num2str(j+1)
			DoWindow/C $("RND_"+num2str(j+1))
			i += 1
		endif
		j += 1
	while (j<4)
	
	print "\tLists of the generated waves stored in the following text waves:"
	i = 0
	do
		if (ThisChannelChecked[i])
			TheWave = ST_BaseName+num2str(i+1)+ST_Suffix
			KillWaves/Z $TheWave
			Make/T/O/N=(ST_nWaves) $TheWave
			print "\t\tChannel #"+num2str(i+1)+"/Cell #"+num2str(CellNumbers[i])+":\t\""+TheWave+"\""
		endif
		i += 1
	while (i<4)

	ControlInfo/W=MultiPatch_ST_Creator Ind_SealTestCheck			// Add a sealtest to the induction waves?
	Variable	AddSealTest = V_value

	print "\tMaking the waves:"
	i = 0																		// == Go through waves ==
	do
		print "\t\tWorking on wave#"+num2str(i+1)
		
		First = 1
		j = 0
		do																		// == Go through channels ==

			if (ThisChannelChecked[j])											// Produce waves for this channel?

				TheWave = ST_BaseName+num2str(j+1)+ST_Suffix+"_"+JS_num2digstr(nDigs,i+1)
				WorkStr = ST_BaseName+num2str(j+1)+ST_Suffix
				WAVE/T	ListOfWaves = $WorkStr
				ListOfWaves[i] = TheWave										// Store away the wave name
				ProduceWave(TheWave,SampleFreq,Ind_WaveLength)
	
				//// Add sealtest
				if (AddSealTest)
					BeginTrainAt = SealTestPad1+SealTestDur+SealTestPad2+Ind_Origin+Ind_RelDispl[j]
					if (!(ST_Extracellular[j]))	
						ProducePulses(TheWave,SealTestPad1,1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
					endif
				else
					BeginTrainAt = Ind_Origin+Ind_RelDispl[j]
				endif
				
				//// Produce the pulses
				
				if (First)																// -- Pulse _position_ on first encountered channel should just be picked from a uniform distribution...
					if (ST_nGrainsTrain==0)
						t_train = (enoise(0.5)+0.5)*ST_RandWidTrain				// Produce an "infinite" number of values within the width ST_RandWidTrain [ms]
					else
						if (ST_nGrainsTrain==1)
							t_train = 0
						else
							t_train = floor((enoise(0.5)+0.5)*ST_nGrainsTrain)/(ST_nGrainsTrain-1)*ST_RandWidTrain		// Produce ST_nGrainsTrain number of values within the width ST_RandWidTrain [ms]
						endif
					endif
//					t_train = 0
					FirstTime = t_train
					First = 0
				else																		// -- ...all subsequent channels should be _displaced_ relative to the first channel as picked from a uniform distribution
					if (ST_nGrainsTrain==0)
						t_train = (enoise(0.5)+0.5)*ST_RandWidTrain				// Produce an "infinite" number of values within the width ST_RandWidTrain [ms]
					else
						if (ST_nGrainsTrain==1)
							t_train = 0
						else
							t_train = floor((enoise(0.5)+0.5)*ST_nGrainsTrain)/(ST_nGrainsTrain-1)*ST_RandWidTrain		// Produce ST_nGrainsTrain number of values within the width ST_RandWidTrain [ms]
						endif
					endif
					t_train = FirstTime+t_train-ST_RandWidTrain/2
				endif
				
				if (FlagRandTrainsOff)
					t_train = 0
				endif
				
				k = 0
				do																	// == Go through pulses ==
					if (ST_nGrainsSpikes==0)
						t_pulse = (enoise(0.5)+0.5)*ST_RandWidSpikes			// Produce an "infinite" number of values within the width ST_RandWidSpikes [ms]
					else
						if (ST_nGrainsSpikes==1)
							t_pulse = 0
						else
							t_pulse = floor((enoise(0.5)+0.5)*ST_nGrainsSpikes)/(ST_nGrainsSpikes-1)*ST_RandWidSpikes		// Produce ST_nGrainsTrain number of values within the width ST_RandWidSpikes [ms]
						endif
					endif
					if (FlagRandSpikesOff)
						t_pulse = 0
					endif
					t = BeginTrainAt+1/Ind_Freq*1000*k+t_train+t_pulse
					WAVE	w1 = $("RND_SpikeTimes_"+num2str(CellNumbers[j]))
					w1[i][k] = t													// Store away spike times {wave,pulse}
					if (!(ST_Extracellular[j]))	
						ProducePulses(TheWave,t,1,Ind_DurationIClamp,1,Ind_AmplitudeIClamp,0,0,0,0)
					else
						ProducePulses(TheWave,t,1,(ST_StimDur-1)/SampleFreq*1000,1,ST_Voltage,0,0,0,0)
						if (ST_Biphasic)
							ProducePulses(TheWave,t+ST_StimDur/SampleFreq*1000,1,(ST_StimDur-1)/SampleFreq*1000,1,-ST_Voltage,0,0,0,0)
						endif
					endif
					if (k!=0)
						AveISI[j] += (w1[i][k]-w1[i][k-1])
//						AveRates[j] += 1000/(w1[i][k]-w1[i][k-1])
					endif
					k += 1
				while (k<Ind_NPulses)
				
				ProduceScaledWave(TheWave,j+1,1)								// Mode = 1 --> current clamp
				
				WAVE	w2 = $TheWave
				AppendToGraph/W=$("RND_"+num2str(j+1)) w2
				WaveStats/Q w2
				ModifyGraph/W=$("RND_"+num2str(j+1)) offset($TheWave)={0,-(V_max-V_min)*(100+TracePercentSeparation)/100*i}
				
			endif

			j += 1
		while (j<4)

		i += 1
	while (i<ST_nWaves)
	if (Ind_NPulses!=1)
		AveISI /= ((Ind_NPulses-1)*ST_nWaves)
		AveRates = 1000/AveISI
//		AveRates /= ((Ind_NPulses-1)*ST_nWaves)
		WorkStr = ""
		WorkStr2 = "AveRates"
		i = 0
		do
			if (!(ThisChannelChecked[i]))
				AveRates[i] = NaN
			else
				WorkStr2 += ("_"+num2str(CellNumbers[i]))
			endif
			WorkStr += ("\t\t"+num2str(AveRates[i])+" Hz ")
			i += 1
		while (i<4)
		Duplicate/O AveRates,$WorkStr2
		print "\t\tAverage rates for each channel:"+WorkStr+"\t(copied to wave \""+WorkStr2+"\")"
	endif

	print "\tModifying graphs"
	Variable	MinStartAxis = Inf
	Variable	MaxEndAxis = -Inf
	j = 0
	do
		if (ThisChannelChecked[j])
			if (AddSealTest)
				BeginTrainAt = SealTestPad1+SealTestDur+SealTestPad2+Ind_Origin+Ind_RelDispl[j]
			else
				BeginTrainAt = Ind_Origin+Ind_RelDispl[j]
			endif
			if (MinStartAxis>BeginTrainAt/1000)
				MinStartAxis = BeginTrainAt/1000
			endif
			if (MaxEndAxis<(BeginTrainAt+1/Ind_Freq*1000*(Ind_NPulses-1)+ST_RandWidTrain+ST_RandWidSpikes+Ind_DurationIClamp)/1000)
				MaxEndAxis = (BeginTrainAt+1/Ind_Freq*1000*(Ind_NPulses-1)+ST_RandWidTrain+ST_RandWidSpikes+Ind_DurationIClamp)/1000
			endif
		endif
		j += 1
	while (j<4)
	MinStartAxis -= (ST_RandWidTrain/2000)
	j = 0
	do
		if (ThisChannelChecked[j])
			DoWindow/F $("RND_"+num2str(j+1))
			SetAxis bottom,MinStartAxis,MaxEndAxis
		endif
		j += 1
	while (j<4)
	DoUpdate
	
	KillWaves/Z Ind_RelDispl,ThisChannelChecked,CellNumbers					// Avoid potential tricky bug by scrapping these waves
	
	ST_DoTheCorrelogramsProc()
	ST_TakeNotesForMakeRandom(AveRates)

End

//////////////////////////////////////////////////////////////////////////////////
//// Do the correlogram analysis (must have run Make Random at least once before this)
	
Function ST_TheCorrelogramsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	ST_DoTheCorrelogramsProc()
	
End

Function ST_DoTheCorrelogramsProc()

	//// INDUCTION
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1	// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// GENERAL
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves
	
	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V
	
	//// PARAMETERS FOR THE RANDOM SPIKE TRAINS
	NVAR	ST_nWaves = 			root:MP:ST_Data:ST_nWaves		// Number of waves to be generated
	NVAR	ST_RandWidTrain = 	root:MP:ST_Data:ST_RandWidTrain	// Width of uniform distribution in [ms] for the whole spike train
	NVAR	ST_nGrainsTrain =		root:MP:ST_Data:ST_nGrainsTrain	// Granularity or graininess of the above width
	NVAR	ST_RandWidSpikes =	root:MP:ST_Data:ST_RandWidSpikes	// Width of uniform distribution in [ms] for the individual spikes of a spike train
	NVAR	ST_nGrainsSpikes = 	root:MP:ST_Data:ST_nGrainsSpikes	// Granularity for the above width, as described for the spike train above
	NVAR	ST_CorrWid =			root:MP:ST_Data:ST_CorrWid		// Width of correlograms
	NVAR	ST_CorrNBins = 		root:MP:ST_Data:ST_CorrNBins		// Number of bins for the correlograms

	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4

	Variable	nDigs = 4												// Number of digits in the suffix number appended at the end of the waves
	
	Variable	i,j,k,t,p,q												// loop variables
	variable	ii,jj													// Take care of spacing of graphs
	Variable	Counter
	Variable	t_train,t_pulse											// The random time variables for the train and for the pulse, respectively
	Variable	BeginTrainAt											// Account for sealtest (or not)
	Variable	nChannelsChecked
	String		TheWave
	String		WorkStr

	Variable	WinCorrHeight = NaN
	Variable	WinCorrWid = NaN
	Variable	WinCorrXSpacing = 15
	Variable	WinCorrYSpacing = 30
	Variable	WinCorrXPos = 10+320+WinCorrXSpacing
	Variable	WinCorrYPos = 50
	
	Variable	TotWinCorrHeight = (100+WinCorrXSpacing)*4
	Variable	TotWinCorrWid = (150+WinCorrYSpacing)*4

	Variable	TheMean
	
	Make/O/N=(4) Ind_RelDispl										// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}
	
	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) ThisChannelChecked
	nChannelsChecked = 0
	j = 0
	do
		WorkStr = "CellOn"+num2str(j+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr				// This channel checked?
		ThisChannelChecked[j] = V_value
		if (ThisChannelChecked[j])
			nChannelsChecked += 1
		endif
		j += 1
	while (j<4)
	WinCorrHeight = TotWinCorrHeight/nChannelsChecked-WinCorrXSpacing
	WinCorrWid = TotWinCorrWid/nChannelsChecked-WinCorrYSpacing

	print "\tProducing correlogram data"
	i = 0
	do
		j = i+1
		if (j<4)
			do
				if ((ThisChannelChecked[i]) %& (ThisChannelChecked[j]))
					print "\t\tWorking on channels "+num2str(i+1)+" and "+num2str(j+1)+""
					WorkStr = "RND_RelativeTimes_"+num2str(CellNumbers[i])+"_to_"+num2str(CellNumbers[j])
					Make/O/N=(1) $WorkStr
					WAVE	w3 = $WorkStr
					Counter = 0
					k = 0
					do
						WAVE	w1 = $("RND_SpikeTimes_"+num2str(CellNumbers[i]))
						WAVE	w2 = $("RND_SpikeTimes_"+num2str(CellNumbers[j]))
						p = 0
						do
							q = 0
							do
								w3[Counter] = {w2[k][q]-w1[k][p]}					// w3{element} = w2{wave,pulse}-w1{wave,pulse}
								Counter += 1
								q += 1
							while (q<Ind_NPulses)
							p += 1
						while (p<Ind_NPulses)
						k += 1
					while (k<ST_nWaves)
				endif
				j += 1
			while (j<4)
		endif
		i += 1
	while (i<4)
	
	print "\tProducing the correlogram graphs"
	ST_CloseCorrGraphs()
	i = 0
	do
		jj = 0
		j = i+1
		if (j<4)
			do
				if ((ThisChannelChecked[i]) %& (ThisChannelChecked[j]))
					ii += 1
					jj += 1
					print "\t\tWorking on channels "+num2str(i+1)+" and "+num2str(j+1)
					WorkStr = "RND_RelativeTimes_"+num2str(CellNumbers[i])+"_to_"+num2str(CellNumbers[j])
					WAVE	w1 = $WorkStr
					WorkStr = "RND_Correlogram_"+num2str(CellNumbers[i])+"_to_"+num2str(CellNumbers[j])
					Make/O/N=(ST_CorrNBins) $WorkStr
					WAVE	w2 = $WorkStr
					Histogram/B={-ST_CorrWid/2,ST_CorrWid/ST_CorrNBins,ST_CorrNBins} w1,w2
					WaveStats/Q w1
					w2 /= V_npnts
					TheMean = V_avg
					Display/W=(WinCorrXPos+(WinCorrWid+WinCorrXSpacing)*jj,WinCorrYPos+(WinCorrHeight+WinCorrYSpacing)*i,WinCorrXPos+(WinCorrWid+WinCorrXSpacing)*jj+WinCorrWid,WinCorrYPos+(WinCorrHeight+WinCorrYSpacing)*i+WinCorrHeight) w2 as "#"+num2str(CellNumbers[i])+" to #"+num2str(CellNumbers[j])
//					Display/W=(WinCorrXPos+(WinCorrWid+WinCorrXSpacing)*jj,WinCorrYPos+(WinCorrHeight+WinCorrYSpacing)*ii,WinCorrXPos+(WinCorrWid+WinCorrXSpacing)*jj+WinCorrWid,WinCorrYPos+(WinCorrHeight+WinCorrYSpacing)*ii+WinCorrHeight) w2 as "#"+num2str(CellNumbers[i])+" to #"+num2str(CellNumbers[j])
//					Display/W=(WinCorrXPos+(WinCorrWid+WinCorrXSpacing)*j,WinCorrYPos+(WinCorrHeight+WinCorrYSpacing)*i,WinCorrXPos+(WinCorrWid+WinCorrXSpacing)*j+WinCorrWid,WinCorrYPos+(WinCorrHeight+WinCorrYSpacing)*i+WinCorrHeight) w2 as "#"+num2str(CellNumbers[i])+" to #"+num2str(CellNumbers[j])
					DoWindow/C $("Corr_"+num2str(i+1)+"_"+num2str(j+1))
					ModifyGraph mode=5
					SetAxis/A/R bottom
					DoUpdate
					GetAxis/Q left
					SetDrawLayer UserFront
					SetDrawEnv xcoord= bottom,ycoord= left,dash= 2
					DrawLine TheMean,V_min,TheMean,V_max
				endif
				j += 1
			while (j<4)
		endif
		i += 1
	while (i<4)

	KillWaves/Z Ind_RelDispl,ThisChannelChecked									// Avoid potential tricky bug by scrapping these waves

end

//////////////////////////////////////////////////////////////////////////////////
//// Export waves as text files so that they can be loaded into VClamp
	
Function ST_ExportProc(ctrlName) : ButtonControl
	String		ctrlName
	
	SVAR	MasterName =	root:MP:MasterName					// Name of HD

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq				// Sampling frequency [Hz]

	//// INDUCTION
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]

	//// BASELINE
	NVAR	Base_WaveLength =	root:MP:ST_Data:Base_WaveLength	// The length of the waves for the ST_Creator [ms]

	//// GENERAL
	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves
	
	ST_CloseAllGraphs()
	
	Print Time()+":\t--- Exporting the waves as text files ---"
	
	String	ExportPathStr = MasterName+":MP_WaveExport:"
	
	PathInfo/S ExportPath
	if (!(V_flag))
		Print "\tExportPath does not exist -- creating it now..."
		NewPath/C/O/Q ExportPath,ExportPathStr
		Print "\tExportPath is:",ExportPathStr
	else
		Print "\tExportPath is:",S_path
	endif
	
	String	wName_Induction
	String	wName_Baseline
	String	WorkStr
	
	Variable	nSamples_Induction
	Variable	nSamples_Baseline
	
	Variable	i
	
	i = 0
	do
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr						// Is there a connected cell on this channel?
		if (V_Value)
			wName_Induction = ST_BaseName+num2str(i+1)+ST_Suffix
			wName_Baseline = ST_BaseName+num2str(i+1)
			WAVE	w1 = $(wName_Baseline)
			WAVE	w2 = $(wName_Induction)
			nSamples_Baseline = numpnts(w1)
			nSamples_Induction = numpnts(w2)
			Print "\tChannel #"+num2str(i+1)+":\tExporting waves \""+wName_Baseline+"\" ("+num2str(Base_WaveLength)+" ms) and \""+wName_Induction+"\" ("+num2str(Ind_WaveLength)+" ms)"
			Save/G/M="\r\n"/O/P=ExportPath w1 as wName_Baseline+".txt"
			Save/G/M="\r\n"/O/P=ExportPath w2 as wName_Induction+".txt"
		else
			Print "\tChannel #"+num2str(i+1)+":\tNothing to export"
		endif
		i += 1
	while(i<4)
	
	Print Time()+":\t--- Done exporting waves ---"
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Make a range of timings to be used with jScan uncaging panel
//// NOTE! This only operates in current clamp and it always adds a test pulse
//// at the end of the sweep.
	
Function ST_MakeTRangeProc(ctrlName) : ButtonControl
	String		ctrlName
	
	//// INDUCTION
	NVAR	Ind_ConcatFlag =	root:MP:ST_Data:Ind_ConcatFlag			// Boolean: Concatenate induction wave with a previously existing induction wave
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq				// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses			// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength			// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1		// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]
	
	NVAR	Ind_rangeStart = 	root:MP:ST_Data:Ind_rangeStart		// timing range start [ms]
	NVAR	Ind_rangeEnd = 		root:MP:ST_Data:Ind_rangeEnd			// timing range end [ms]

	//// INDUCTION TWEAKS
	WAVE	ST_NoSpikes =		root:MP:ST_Data:ST_NoSpikes			// Used to store away the checkbox values -- No spikes at all on checked channel

	WAVE	ST_NegPulse =		root:MP:ST_Data:ST_NegPulse			// Used to store away the checkbox values -- Add negative pulses between spikes?
	NVAR	ST_NegPulseAmpI = 	root:MP:ST_Data:ST_NegPulseAmpI		// The size of the negative pulse

	WAVE	ST_KeepLast =		root:MP:ST_Data:ST_KeepLast			// Keep only last spike on this channel?
	WAVE	ST_KeepFirst =		root:MP:ST_Data:ST_KeepFirst			// Keep only first spike on this channel?

	WAVE	ST_LongInj =			root:MP:ST_Data:ST_LongInj			// Long current injection on this channel?
	NVAR	ST_LongAmpI = 		root:MP:ST_Data:ST_LongAmpI			// The amplitude of the long current step for _all_ checked channels [nA]
	NVAR	ST_LongWidth = 		root:MP:ST_Data:ST_LongWidth			// The width of the long current step for _all_ checked channels [ms] (centered around spike, or before if short is also checked)

	WAVE	ST_ShortInj =		root:MP:ST_Data:ST_ShortInj			// Short current injection on this channel?
	NVAR	ST_ShortAmpI = 		root:MP:ST_Data:ST_ShortAmpI			// The amplitude of the short current step for _all_ checked channels [nA]
	NVAR	ST_ShortWidth = 		root:MP:ST_Data:ST_ShortWidth			// The width of the short current step for _all_ checked channels [ms] (just before spike)

	//// GENERAL
	NVAR	ST_RedPerc1 =		root:MP:ST_Data:ST_RedPerc1			// Scale current injection by this percentage for channel 1
	NVAR	ST_RedPerc2 =		root:MP:ST_Data:ST_RedPerc2			// Scale current injection by this percentage for channel 2
	NVAR	ST_RedPerc3 =		root:MP:ST_Data:ST_RedPerc3			// Scale current injection by this percentage for channel 3
	NVAR	ST_RedPerc4 =		root:MP:ST_Data:ST_RedPerc4			// Scale current injection by this percentage for channel 4
	
	NVAR	ST_StartPad = 		root:MP:ST_Data:ST_StartPad			// The padding at the start of the waves [ms]
	NVAR	ST_EndPad = 			root:MP:ST_Data:ST_EndPad				// The padding at the end of the waves [ms]
	NVAR	ST_SealTestAtEnd =	root:MP:ST_Data:ST_SealTestAtEnd		// Put the sealtest at the end of the wave instead of at the beginning

	SVAR	ST_BaseName = 		root:MP:ST_Data:ST_BaseName			// The base name for all waves
	SVAR	ST_Suffix = 			root:MP:ST_Data:ST_Suffix				// The suffix to be added to the spiketiming waves
	
	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =			root:MP:SampleFreq						// Sampling frequency [Hz]
	NVAR	SealTestPad1 = 		root:MP:SealTestPad1					// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =		root:MP:SealTestAmp_I

	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	//// CELL NUMBERS
	NVAR	Cell_1 =				root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =				root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =				root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =				root:MP:IO_Data:Cell_4

	DoWindow jScanPanel
	if (V_flag==0)
		print "jScan Main Panel does not exist -- you cannot use this button now."
		Abort "jScan Main Panel does not exist -- you cannot use this button now."
	endif
	
	print "--- Making range of timings ---"
	print "\tfrom ",Ind_rangeStart,"to",Ind_rangeEnd
	print "\tat",Time(),Date()
	
	NVAR/Z		xSpots = jSc_unc_xSize
	NVAR/Z		ySpots = jSc_unc_ySize
	
	Variable	nPoints = xSpots*ySpots

	// Convert the uncaging pattern to voltage values
	NVAR/Z		jSc_mspl
	NVAR/Z		jSc_flyback
	NVAR/Z		jSc_pxpl
	NVAR/Z		jSc_lnpf
	NVAR/Z		jSc_xAmp
	NVAR/Z		jSc_yAmp
	NVAR/Z		jSc_xPad
	
	NVAR/Z		jSc_unc_sampFreq
	NVAR/Z		jSc_unc_flyTime
	NVAR/Z		jSc_unc_dwellTime
	NVAR/Z		jSc_unc_shutterTime
	NVAR/Z		jSc_unc_nPulses
	NVAR/Z		jSc_unc_PulsePrePad
	NVAR/Z		jSc_unc_freq
	
	NVAR/Z		jSc_VerboseMode

	// NB! Sample points below refer to the uncaging sampling frequency, which may be different from that of the ePhys sampling frequency!
	Variable	prePadPoints = jSc_unc_PulsePrePad*1e-3*jSc_unc_sampFreq
	Variable	dwellPoints = jSc_unc_dwellTime*1e-3*jSc_unc_sampFreq						// Number of sample points for each dwell time
	Variable	flyPoints = jSc_unc_flyTime*1e-3*jSc_unc_sampFreq							// Number of sample points for each fly time
	Variable	totDwellPoints = dwellPoints+flyPoints											// Total number of sample points for each uncaging location
	Variable	nSamplePoints = totDwellPoints*nPoints+prePadPoints							// Total number of sample points for entire uncaing sweep
	Variable	wDur = nSamplePoints/jSc_unc_sampFreq											// Uncaging sweep duration from points (s)
	Variable	calc_wDur = (jSc_unc_dwellTime+jSc_unc_flyTime)*1e-3*nPoints				// Uncaging sweep duration from time (s)
	Variable	uncPoints = jSc_unc_shutterTime*1e-3*jSc_unc_sampFreq
	Variable	freqInPoints = Round(jSc_unc_sampFreq/jSc_unc_freq)
	
	Variable		G_X_Base										// Graph position, X, Baseline 
	Variable		G_X_Ind = 20									// Graph position, X, Induction
	Variable		G_Y = 140										// Graph position, Y	
	Variable		G_Width										// Width of graph windows
	Variable		G_Height = 120									// Height of graph windows
	Variable		G_X_Grout = 10								// X spacing for graph windows
	Variable		G_Y_Grout = 30								// Y spacing for graph windows
	
	JT_GetScreenSize()
	NVAR		JT_ScreenWidth
	NVAR		JT_ScreenHeight
	if (JT_ScreenWidth>JT_ScreenHeight)
		G_Width = 480
		G_X_Base = G_X_Ind+G_X_Grout+G_Width
	else
		G_Width = 280
		G_X_Base = G_X_Ind+G_X_Grout+G_Width
	endif
	
	String			WinNameStr = ""								// Title of window
	String			LegendStr = ""								// Text in legend
	String			TitleStr = ""								// Text in title
	
	Variable		ConcatAppend = 0								// Boolean: True means concatenate function is enabled and a previously existing wave should be appended at end

	ST_CloseAllGraphs()

	String		WorkStr
	String		theWaveName_Ind
	String		theWaveName_Base
	
	Variable	ePhys_wDur = wDur*1e3+SealTestDur												// For ephys, we think in (ms), for uncaging, in (s)
	Variable	tSpike
	
	Make/O/N=(4) ST_KeepWave
	ST_KeepWave = 0
	Variable	i = 0
	do
		if (ST_KeepFirst[i])
			ST_KeepWave[i] = 1									// Keep first overrides keep last
		else
			if (ST_KeepLast[i])
				ST_KeepWave[i] = 2
			endif
		endif
		if (ST_NoSpikes[i])										// Keep none overrides both keep last and keep first
			ST_KeepWave[i] = 3
		endif
		i += 1
	while (i<4)

	Make/O/N=(4) Ind_RelDispl									// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}

	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) ST_RedPercWave
	ST_RedPercWave = {ST_RedPerc1,ST_RedPerc2,ST_RedPerc3,ST_RedPerc4}
	
	Variable	tStep = (Ind_rangeStart-Ind_rangeEnd)/(nPoints-1)

	Variable	j,k				// i - channels, j - uncaging pulses
	i = 0
	do
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr												// Is there a cell on this channel?
		if (V_value)
			theWaveName_Ind = ST_BaseName+num2str(i+1)+ST_Suffix
			theWaveName_Base = ST_BaseName+num2str(i+1)
			print "\tMaking "+theWaveName_Base+" and "+theWaveName_Ind+"."
			ProduceWave(theWaveName_Ind,SampleFreq,ePhys_wDur)						// Induction wave
			ProduceWave(theWaveName_Base,SampleFreq,ePhys_wDur)						// Baseline wave
			j = 0
			do
				tSpike = (j*totDwellPoints+prePadPoints)/jSc_unc_sampFreq*1e3 + Ind_rangeStart-tStep*j		// Time of first spike (ms)
				if ( (ST_LongInj[i]) %& (ST_ShortInj[i]) )
					ProducePulses(theWaveName_Ind,tSpike-ST_LongWidth-ST_ShortWidth,1,ST_LongWidth,1,ST_LongAmpI*ST_RedPercWave[i]/100,0,0,0,0)
					ProducePulses(theWaveName_Ind,tSpike-ST_ShortWidth,1,ST_ShortWidth,1,ST_ShortAmpI*ST_RedPercWave[i]/100,0,0,0,0)
				else
					if (ST_LongInj[i])													// Adding centered long current injection on top of which the spikes will ride
						ProducePulses(theWaveName_Ind,tSpike+(Ind_NPulses-1)/2*1/Ind_Freq*1000-ST_LongWidth/2,1,ST_LongWidth,1,ST_LongAmpI*ST_RedPercWave[i]/100,0,0,0,0)
					endif
				endif
				ProducePulses(theWaveName_Ind,tSpike,Ind_NPulses,Ind_DurationIClamp,Ind_Freq,Ind_AmplitudeIClamp*ST_RedPercWave[i]/100,0,ST_KeepWave[i],0,0)	// The current injections producing the spike(s)
				if (ST_NegPulse[i])
					ProducePulses(theWaveName_Ind,tSpike+Ind_DurationIClamp,Ind_NPulses,(1/Ind_Freq*1000)-Ind_DurationIClamp,Ind_Freq,ST_NegPulseAmpI*ST_RedPercWave[i]/100,0,ST_KeepWave[i],0,0)	// The current injectionsin between the spikes
				endif
				j += 1
			while(j<nPoints)
			ProducePulses(theWaveName_Ind,ePhys_wDur-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_I,0,0,0,0)	// Add test pulse at end of induction wave
			ProducePulses(theWaveName_Base,ePhys_wDur-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_I,0,0,0,0)	// Add test pulse at end of baseline wave
			ProduceScaledWave(theWaveName_Ind,i+1,1)				// Mode = 1 --> current clamp
			ProduceScaledWave(theWaveName_Base,i+1,1)				// Mode = 1 --> current clamp
			Note $theWaveName_Ind,num2str(Ind_rangeStart)+";"+num2str(Ind_rangeEnd)+";"
			// Make induction wave graphs
			WinNameStr = "Win"+num2str(i+1)
			TitleStr = "Induction -- Channel #"+num2str(i+1)+" -- Cell #"+num2str(CellNumbers[i])
			LegendStr = "Ch #"+num2str(i+1)
			DisplayOneWave(theWaveName_Ind,WinNameStr,TitleStr,LegendStr,G_X_Ind,G_Y+i*(G_Height+G_Y_Grout),G_Width,G_Height)
			print theWaveName_Ind,WinNameStr,TitleStr,LegendStr,G_X_Ind,G_Y+j*(G_Height+G_Y_Grout),G_Width,G_Height
			ModifyGraph rgb($theWaveName_Ind)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
			Button ClosePlotsButton,pos={0,0},size={18,18},proc=ST_CloseProc,title="X"
			// Make baseline wave graphs
			WinNameStr = "Win"+num2str(i+5)
			TitleStr = "Baseline -- Channel #"+num2str(i+1)+" -- Cell #"+num2str(CellNumbers[i])
			LegendStr = "Ch #"+num2str(i+1)
			DisplayOneWave(theWaveName_Base,WinNameStr,TitleStr,LegendStr,G_X_Base,G_Y+i*(G_Height+G_Y_Grout),G_Width,G_Height)
			ModifyGraph rgb($theWaveName_Base)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
			Button ClosePlotsButton,pos={0,0},size={18,18},proc=ST_CloseProc,title="X"
		endif
		i += 1
	while(i<4)
	
	ST_TakeNotes(3)
	
	if (Exists("jSc_shutterWave"))
		// Modification of Out_shutterWave and Out_blankWave is needed because of possibly different wavelengths and sampling frequencies on the two boards
		// This below kludge is necessary because MultiPatch and jScan should be possible to run independently of each other.
		// The creation of Out_shutterWave thus has to be done independently in jScan, while the modification of its
		// duration must be done here.
		ProduceWave("Out_shutterWave",SampleFreq,ePhys_wDur)
		WAVE	Out_shutterWave
		Out_shutterWave = 0
		WAVE/Z	jSc_shutterWave
		Out_shutterWave = jSc_shutterWave[floor(p*DimDelta(Out_shutterWave,0)/DimDelta(jSc_shutterWave,0))]		// Assumes there is no difference in origin!
		Duplicate/O Out_shutterWave,Out_blankWave
		Out_blankWave = 0
//		Killwaves/Z ST_shutterWave
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Make the waves to be used in the spike timing pattern
	
Function ST_MakeProc(ctrlName) : ButtonControl
	String		ctrlName
	
	ST_DoTheMake(0)
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Do the actual making of waves

Function ST_DoTheMake(ExtracellularOnly)
	Variable	ExtracellularOnly									// Boolean: Make only the extracellular waves and dump little text to notebook
																	// Addition 2004-04-24: ExtracellularOnly not just boolean, ExtracellularOnly == 2 --> suppress graphs
	
	Variable	SuppressGraphs
	If (ExtracellularOnly==2)
		SuppressGraphs = 1
		ExtracellularOnly = 0
	else
		SuppressGraphs = 0
	endif
	
	//// INDUCTION
	NVAR	Ind_ConcatFlag =	root:MP:ST_Data:Ind_ConcatFlag			// Boolean: Concatenate induction wave with a previously existing induction wave
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq				// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses			// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength			// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1		// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// BASELINE
	NVAR	Base_Spacing =	 	root:MP:ST_Data:Base_Spacing				// The spacing between the pulses in the baseline [ms]
	NVAR	Base_Freq = 		root:MP:ST_Data:Base_Freq						// The frequency of the pulses [Hz]
	NVAR	Base_NPulses = 	root:MP:ST_Data:Base_NPulses					// The number of pulses for each channel during the baseline
	NVAR	Base_WaveLength =	root:MP:ST_Data:Base_WaveLength			// The length of the waves for the ST_Creator [ms]
	NVAR	Base_Recovery =	root:MP:ST_Data:Base_Recovery					// Boolean: Recovery pulse?
	NVAR	Base_RecoveryPos =root:MP:ST_Data:Base_RecoveryPos			// Position of recovery pulse relative to end of train [ms]
	NVAR	Base_AmplitudeIClamp = root:MP:ST_Data:Base_AmplitudeIClamp	// The pulse amplitude for baseline current clamp pulses [nA]
	NVAR	Base_DurationIClamp = 	root:MP:ST_Data:Base_DurationIClamp		// The pulse duration for baseline current clamp pulses [ms]

	//// GENERAL
	NVAR	ST_RedPerc1 =		root:MP:ST_Data:ST_RedPerc1		// Scale current injection by this percentage for channel 1
	NVAR	ST_RedPerc2 =		root:MP:ST_Data:ST_RedPerc2		// Scale current injection by this percentage for channel 2
	NVAR	ST_RedPerc3 =		root:MP:ST_Data:ST_RedPerc3		// Scale current injection by this percentage for channel 3
	NVAR	ST_RedPerc4 =		root:MP:ST_Data:ST_RedPerc4		// Scale current injection by this percentage for channel 4
	
	NVAR	ST_AmplitudeVClamp = 	root:MP:ST_Data:ST_AmplitudeVClamp	// The pulse amplitude for _all_ voltage clamp pulses [nA]
	NVAR	ST_DurationVClamp = 	root:MP:ST_Data:ST_DurationVClamp	// The pulse duration for _all_ voltage clamp pulses [ms]
	NVAR	ST_StartPad = 			root:MP:ST_Data:ST_StartPad			// The padding at the start of the waves [ms]
	NVAR	ST_EndPad = 			root:MP:ST_Data:ST_EndPad					// The padding at the end of the waves [ms]
	NVAR	ST_SealTestAtEnd =		root:MP:ST_Data:ST_SealTestAtEnd		// Put the sealtest at the end of the wave instead of at the beginning

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves
	
	WAVE 	ST_LightStim = 		root:MP:ST_Data:ST_LightStim		// Is this channel a light stim channel?
	NVAR	ST_LightVoltage = 		root:MP:ST_Data:ST_LightVoltage	// The voltage amplitude for _all_ light stim pulses [V]
	NVAR	ST_LightDur = 			root:MP:ST_Data:ST_LightDur		// The voltage amplitude for _all_ light stim pulses [V]

	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_StimDur = 		root:MP:ST_Data:ST_StimDur			// The pulse duration for _all_ (extracellular) pulses [samples]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	WAVE 	ST_DendriticRec = 		root:MP:ST_Data:ST_DendriticRec		// Boolean: Is this channel a dendritic recording?

	NVAR	MMPooStyle =		root:MP:ST_Data:MMPooStyle		// Boolean: Is the protocol of the Bi&Poo, J.Neurosci, 1998 type?
																	// (Otherwise a LTP pairing protocol is assumed, with postsynaptic depolarization coincident with EPSP.)
	//// INDUCTION TWEAKS
	WAVE	ST_NoSpikes =		root:MP:ST_Data:ST_NoSpikes		// Used to store away the checkbox values -- No spikes at all on checked channel

	WAVE	ST_NegPulse =		root:MP:ST_Data:ST_NegPulse		// Used to store away the checkbox values -- Add negative pulses between spikes?
	NVAR	ST_NegPulseAmpI = root:MP:ST_Data:ST_NegPulseAmpI	// The size of the negative pulse

	WAVE	ST_KeepLast =		root:MP:ST_Data:ST_KeepLast		// Keep only last spike on this channel?
	WAVE	ST_KeepFirst =		root:MP:ST_Data:ST_KeepFirst		// Keep only first spike on this channel?

	WAVE	ST_LongInj =		root:MP:ST_Data:ST_LongInj		// Long current injection on this channel?
	NVAR	ST_LongAmpI = 		root:MP:ST_Data:ST_LongAmpI		// The amplitude of the long current step for _all_ checked channels [nA]
	NVAR	ST_LongWidth = 	root:MP:ST_Data:ST_LongWidth		// The width of the long current step for _all_ checked channels [ms] (centered around spike, or before if short is also checked)

	WAVE	ST_ShortInj =		root:MP:ST_Data:ST_ShortInj		// Short current injection on this channel?
	NVAR	ST_ShortAmpI = 	root:MP:ST_Data:ST_ShortAmpI		// The amplitude of the short current step for _all_ checked channels [nA]
	NVAR	ST_ShortWidth = 	root:MP:ST_Data:ST_ShortWidth	// The width of the short current step for _all_ checked channels [ms] (just before spike)

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V
	
	//// PARAMETERS FROM SWITCHBOARD
	WAVE	VClampWave =		root:MP:IO_Data:VClampWave		// Boolean: Which channels are in voltage clamp? (otherwise current clamp)

	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4
	
	//// FROM PATTERNHANDLER
	NVAR		DummyIterCounter = 	root:MP:PM_Data:DummyIterCounter		// Counts up the iterations in a particular step
	NVAR		CurrentStep =			root:MP:PM_Data:CurrentStep
	WAVE		Pos_Matrix =			root:MP:PM_Data:Pos_Matrix				// Positions of EPSPs in a quadruple recording, from channel r to channel k [s]
	Pos_Matrix = -1																	// Negative value means presynaptic cell not active during analysis
//	NVAR		RT_EPSPLatency =	root:MP:PM_Data:RT_EPSPLatency			// EPSP peak latency [s]
	
	// Use colors that match the traces on the 4-channel Tektronix TDS2004B oscilloscope	
	WAVE		ChannelColor_R = root:MP:IO_Data:ChannelColor_R
	WAVE		ChannelColor_G = root:MP:IO_Data:ChannelColor_G
	WAVE		ChannelColor_B = root:MP:IO_Data:ChannelColor_B

	String		WaveName
	String		WorkStr
	Variable	i,j
	Variable	BeginTrainAt
	Variable	PulsePosCount										// Counts the position of the pulse(train) in the induction waves
	Variable	NoExtracellular = 1									// Boolean: No extracellular channels were found
	Variable	TempVar
	
	Variable		G_X_Base										// Graph position, X, Baseline 
	Variable		G_X_Ind = 20									// Graph position, X, Induction
	Variable		G_Y = 140										// Graph position, Y	
	Variable		G_Width										// Width of graph windows
	Variable		G_Height = 120									// Height of graph windows
	Variable		G_X_Grout = 10								// X spacing for graph windows
	Variable		G_Y_Grout = 30								// Y spacing for graph windows
	
	JT_GetScreenSize()
	NVAR		JT_ScreenWidth
	NVAR		JT_ScreenHeight
	if (JT_ScreenWidth>JT_ScreenHeight)
		G_Width = 480
		G_X_Base = G_X_Ind+G_X_Grout+G_Width
	else
		G_Width = 280
		G_X_Base = G_X_Ind+G_X_Grout+G_Width
	endif
	
	String			WinNameStr = ""								// Title of window
	String			LegendStr = ""								// Text in legend
	String			TitleStr = ""								// Text in title
	
	Variable		ExistsAsTextWave = 0						// Boolean: May not want to overwrite a textwave with the same name...
	Variable		AlertResponse = 1

	Variable		ConcatAppend = 0								// Boolean: True means concatenate function is enabled and a previously existing wave should be appended at end

	ST_CloseAllGraphs()
	
	i = 0
	do
		WaveName = ST_BaseName+num2str(i+1)+ST_Suffix
		WAVE/Z	w = $WaveName
		if (WaveExists(w))
			if (WaveType(w)==0)
				ExistsAsTextWave = 1
			endif
		endif
		i += 1
	while (i<4)
	if (ExistsAsTextWave)
		DoAlert 1,"Overwrite induction text waves?"
		AlertResponse = V_Flag											// 1==Yes,2==No
		if (AlertResponse == 1)
			i = 0
			do
				WaveName = ST_BaseName+num2str(i+1)+ST_Suffix
				KillWaves/Z $WaveName
				i += 1
			while (i<4)
		endif
	endif
	
	Make/O/N=(4) ST_KeepWave
	ST_KeepWave = 0
	i = 0
	do
		if (ST_KeepFirst[i])
			ST_KeepWave[i] = 1									// Keep first overrides keep last
		else
			if (ST_KeepLast[i])
				ST_KeepWave[i] = 2
			endif
		endif
		if (ST_NoSpikes[i])										// Keep none overrides both keep last and keep first
			ST_KeepWave[i] = 3
		endif
		i += 1
	while (i<4)

	if (ExtracellularOnly)
		print "SpikeTiming Creator is making new extracellular waves at time "+Time()+". This is iteration "+num2str(DummyIterCounter)+" of step "+num2str(CurrentStep)+"."
	else
		print "SpikeTiming Creator is making new waves at time "+Time()+"."
	endif
	
	Make/O/N=(4) Ind_RelDispl									// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}

	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) ST_RedPercWave
	ST_RedPercWave = {ST_RedPerc1,ST_RedPerc2,ST_RedPerc3,ST_RedPerc4}

	//// MAKE THE INDUCTION WAVES
	if (!(AlertResponse==2))
		if (!(ExtracellularOnly))
			print "\tMaking the induction waves."
		endif
		i = 0			// i counts the channel (like expected)
		j = 0			// j counts the pulse position (used when updating the extracellular wave)
		do
	
			if ( (!(ExtracellularOnly)) %| (ST_Extracellular[i]))
	
				WorkStr = "CellOn"+num2str(i+1)+"Check"
				ControlInfo/W=MultiPatch_ST_Creator $WorkStr								// Is there a connected cell on this channel?
				if (V_value)
					if (!(ExtracellularOnly))
						print "\t\tWave for channel #"+num2str(i+1)+" is produced."
					endif
					WaveName = ST_BaseName+num2str(i+1)+ST_Suffix
					if ((Ind_ConcatFlag) %& (Exists(WaveName)==1) %& (!(ExtracellularOnly)) )
						ConcatAppend = 1
						Duplicate/O $WaveName,ConcatTempWave
					else
						ConcatAppend = 0
					endif
					ProduceWave(WaveName,SampleFreq,Ind_WaveLength)
					ControlInfo/W=MultiPatch_ST_Creator Ind_SealTestCheck					// Add a sealtest to the induction waves
					if (V_value)
						if (ST_SealTestAtEnd)
							BeginTrainAt = ST_StartPad+Ind_Origin+Ind_RelDispl[i]
						else
							BeginTrainAt = ST_StartPad+SealTestPad1+SealTestDur+SealTestPad2+Ind_Origin+Ind_RelDispl[i]
						endif
						if ( (!(ST_Extracellular[i])) %& (!(ST_DendriticRec[i])) %& (!(ST_LightStim[i])) )				// Don't add sealtest if extracellular stim, dendritic rec, or light stim
							if (ST_SealTestAtEnd)
								if ( (VClampWave[i]) %& (!(MMPooStyle)) )
									ProducePulses(WaveName,Ind_WaveLength-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
								else
									ProducePulses(WaveName,Ind_WaveLength-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
								endif
							else
								if ( (VClampWave[i]) %& (!(MMPooStyle)) )
									ProducePulses(WaveName,SealTestPad1,1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
								else
									ProducePulses(WaveName,SealTestPad1,1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
								endif
							endif
						endif
					else
						BeginTrainAt = ST_StartPad+Ind_Origin+Ind_RelDispl[i]
					endif
					if ( (!(ST_Extracellular[i])) %& (!(ST_LightStim[i])) )
						if ( (VClampWave[i]) %& (!(MMPooStyle)) )
							ProducePulses(WaveName,BeginTrainAt,1,ST_DurationVClamp,Ind_Freq,ST_AmplitudeVClamp*ST_RedPercWave[i]/100,0,0,0,0)			// Expecting only one long pulse in voltage clamp
						else
							if ( (ST_LongInj[i]) %& (ST_ShortInj[i]) )
								ProducePulses(WaveName,BeginTrainAt-ST_LongWidth-ST_ShortWidth,1,ST_LongWidth,1,ST_LongAmpI*ST_RedPercWave[i]/100,0,0,0,0)
								ProducePulses(WaveName,BeginTrainAt-ST_ShortWidth,1,ST_ShortWidth,1,ST_ShortAmpI*ST_RedPercWave[i]/100,0,0,0,0)
							else
								if (ST_LongInj[i])													// Adding centered long current injection on top of which the spikes will ride
									ProducePulses(WaveName,BeginTrainAt+(Ind_NPulses-1)/2*1/Ind_Freq*1000-ST_LongWidth/2,1,ST_LongWidth,1,ST_LongAmpI*ST_RedPercWave[i]/100,0,0,0,0)
								endif
							endif
							ProducePulses(WaveName,BeginTrainAt,Ind_NPulses,Ind_DurationIClamp,Ind_Freq,Ind_AmplitudeIClamp*ST_RedPercWave[i]/100,0,ST_KeepWave[i],0,0)	// The current injections producing the spike(s)
							if (ST_NegPulse[i])
								ProducePulses(WaveName,BeginTrainAt+Ind_DurationIClamp,Ind_NPulses,(1/Ind_Freq*1000)-Ind_DurationIClamp,Ind_Freq,ST_NegPulseAmpI*ST_RedPercWave[i]/100,0,ST_KeepWave[i],0,0)	// The current injectionsin between the spikes
							endif
						endif
						if (MMPooStyle)
							ProduceScaledWave(WaveName,i+1,1)								// Mode = 1 --> current clamp
						else
							ProduceScaledWave(WaveName,i+1,-1)							// Read mode from SwitchBoard
						endif
					else
						if (ST_Extracellular[i])
							NoExtracellular = 0
							ProducePulses(WaveName,BeginTrainAt,Ind_NPulses,(ST_StimDur-1)/SampleFreq*1000,Ind_Freq,ST_Voltage*ST_RedPercWave[i]/100,0,ST_KeepWave[i],0,0)
							if (ST_Biphasic)
								ProducePulses(WaveName,BeginTrainAt+ST_StimDur/SampleFreq*1000,Ind_NPulses,(ST_StimDur-1)/SampleFreq*1000,Ind_Freq,-ST_Voltage*ST_RedPercWave[i]/100,0,ST_KeepWave[i],0,0)
							endif
						else
							if (ST_LightStim[i])
								ProducePulses(WaveName,BeginTrainAt,Ind_NPulses,ST_LightDur,Ind_Freq,ST_LightVoltage,0,ST_KeepWave[i],0,0)
							endif
						endif
					endif
					// Make Graphs
					if ( (!(ExtracellularOnly)) %& (!(SuppressGraphs)) )
						WinNameStr = "Win"+num2str(i+1)
						TitleStr = "Induction -- Channel #"+num2str(i+1)+" -- Cell #"+num2str(CellNumbers[i])
						LegendStr = "Ch #"+num2str(i+1)
						DisplayOneWave(WaveName,WinNameStr,TitleStr,LegendStr,G_X_Ind,G_Y+j*(G_Height+G_Y_Grout),G_Width,G_Height)
						ModifyGraph rgb($WaveName)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
						Button ClosePlotsButton,pos={0,0},size={18,18},proc=ST_CloseProc,title="X"
					endif
					if (ConcatAppend)
						WAVE	CurrWave = $WaveName
						InsertPoints 0,numpnts(ConcatTempWave),CurrWave
						CurrWave[0,numpnts(ConcatTempWave)-1] = ConcatTempWave[p]
					endif
					j += 1
				endif
				
			endif
			
			i += 1
		while (i<4)
	endif
	
	//// MAKE THE BASELINE WAVES
	ControlInfo/W=MultiPatch_ST_Creator Base_RevOrderCheck					// Reverse ordering of spikes during the baseline
	Variable	Base_RevOrder = V_value
	ControlInfo/W=MultiPatch_ST_Creator Base_VClampPulseCheck				// Add pulses if channel is in voltage clamp too?
	Variable	Base_VClampPulse = V_value
	if (!(ExtracellularOnly))
		print "\tMaking the baseline waves."
		if (Base_RevOrder)
			print "\t\tSpikes are ordered reversely."
		endif
	endif
	i = 0			// i counts the channel (like expected)
	j = 0			// j counts the number of channels that are used
	do
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr							// Is there a connected cell on this channel?
		if (V_value)
			j += 1
		endif
		i += 1
	while (i<4)
	if (Base_RevOrder)
		PulsePosCount = j-1														// NB! Use variable j from induction to count number of channels selected
	else
		PulsePosCount = 0
	endif
	i = 0
	j = 0
	do

		if ( (!(ExtracellularOnly)) %| (ST_Extracellular[i]))

			WorkStr = "CellOn"+num2str(i+1)+"Check"
			ControlInfo/W=MultiPatch_ST_Creator $WorkStr								// Is there a connected cell on this channel?
			if (V_value)
				if (!(ExtracellularOnly))
					print "\t\tWave for channel #"+num2str(i+1)+" is produced."
				endif
				WaveName = ST_BaseName+num2str(i+1)
				ProduceWave(WaveName,SampleFreq,Base_WaveLength)
				ControlInfo/W=MultiPatch_ST_Creator Base_SealTestCheck					// Add a sealtest to the baseline waves
				if (V_value)
					if (ST_SealTestAtEnd)
						BeginTrainAt = ST_StartPad+PulsePosCount*((Base_NPulses-1)*1/Base_Freq*1000+Base_Spacing)
					else
						BeginTrainAt = ST_StartPad+SealTestPad1+SealTestDur+SealTestPad2+PulsePosCount*((Base_NPulses-1)*1/Base_Freq*1000+Base_Spacing)
					endif
					if ( (!(ST_Extracellular[i])) %& (!(ST_DendriticRec[i])) )						// Don't add sealtest if it is an extracellular stim or dendritic rec channel
						if (ST_SealTestAtEnd)
							if ( (VClampWave[i]) %| (MMPooStyle) )
								ProducePulses(WaveName,Base_WaveLength-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
							else
								ProducePulses(WaveName,Base_WaveLength-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
							endif
						else
							if ( (VClampWave[i]) %| (MMPooStyle) )
								ProducePulses(WaveName,SealTestPad1,1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
							else
								ProducePulses(WaveName,SealTestPad1,1,SealTestDur,1,SealTestAmp_I,0,0,0,0)
							endif
						endif
					endif
				else
					BeginTrainAt = ST_StartPad+PulsePosCount*((Base_NPulses-1)*1/Base_Freq*1000+Base_Spacing)
				endif
				if (Base_Recovery)
					TempVar = PulsePosCount*Base_RecoveryPos
					BeginTrainAt += TempVar
				endif
				if (Base_RevOrder)
					PulsePosCount -= 1
				else
					PulsePosCount += 1
				endif
				if ( (!(ST_Extracellular[i])) %& (!(ST_LightStim[i])) )
					if ((MMPooStyle) %| ( (Base_VClampPulse) %& (VClampWave[i]) ) )
						if (!(ST_DendriticRec[i]))
							ProducePulses(WaveName,BeginTrainAt,Base_NPulses,ST_DurationVClamp,Base_Freq,ST_AmplitudeVClamp*ST_RedPercWave[i]/100,0,0,0,0)
							Pos_Matrix[i][] = BeginTrainAt/1000//+RT_EPSPLatency
							if (Base_Recovery)
								TempVar = BeginTrainAt+Base_NPulses*1/Base_Freq*1000+Base_RecoveryPos
								ProducePulses(WaveName,TempVar,1,ST_DurationVClamp,1,ST_AmplitudeVClamp*ST_RedPercWave[i]/100,0,0,0,0)
							endif
						else
							ProducePulses(WaveName,BeginTrainAt,1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
						endif
					else
						if (!(VClampWave[i]))													// Don't add any pulses in V clamp during the baseline!
							if (!(ST_DendriticRec[i]))
								ProducePulses(WaveName,BeginTrainAt,Base_NPulses,Base_DurationIClamp,Base_Freq,Base_AmplitudeIClamp*ST_RedPercWave[i]/100,0,0,0,0)
								Pos_Matrix[i][] = BeginTrainAt/1000//+RT_EPSPLatency
								if (Base_Recovery)
									TempVar = BeginTrainAt+Base_NPulses*1/Base_Freq*1000+Base_RecoveryPos
									ProducePulses(WaveName,TempVar,1,Base_DurationIClamp,1,Base_AmplitudeIClamp*ST_RedPercWave[i]/100,0,0,0,0)
								endif
							else
								ProducePulses(WaveName,BeginTrainAt,1,SealTestDur,1,SealTestAmp_I,0,0,0,0) // If dendritic rec, put sealtest pulse where spikes would have been
							endif
						else
							if (ST_DendriticRec[i])
								ProducePulses(WaveName,BeginTrainAt,1,SealTestDur,1,SealTestAmp_V,0,0,0,0)
							endif
						endif
					endif
					if (MMPooStyle)
						ProduceScaledWave(WaveName,i+1,3)								// Mode = 3 --> voltage clamp
					else
						ProduceScaledWave(WaveName,i+1,-1)							// Read mode from SwitchBoard
					endif
				else
					if (ST_Extracellular[i])
						ProducePulses(WaveName,BeginTrainAt,Base_NPulses,(ST_StimDur-1)/SampleFreq*1000,Base_Freq,ST_Voltage*ST_RedPercWave[i]/100,0,0,0,0)
						Pos_Matrix[i][] = BeginTrainAt/1000//+RT_EPSPLatency
						if (Base_Recovery)
							TempVar = BeginTrainAt+Base_NPulses*1/Base_Freq*1000+Base_RecoveryPos
							ProducePulses(WaveName,TempVar,1,(ST_StimDur-1)/SampleFreq*1000,1,ST_Voltage*ST_RedPercWave[i]/100,0,0,0,0)
						endif
						if (ST_Biphasic)
							ProducePulses(WaveName,BeginTrainAt+ST_StimDur/SampleFreq*1000,Base_NPulses,(ST_StimDur-1)/SampleFreq*1000,Base_Freq,-ST_Voltage*ST_RedPercWave[i]/100,0,0,0,0)
							if (Base_Recovery)
								TempVar = BeginTrainAt+Base_NPulses*1/Base_Freq*1000+Base_RecoveryPos
								ProducePulses(WaveName,TempVar+ST_StimDur/SampleFreq*1000,1,(ST_StimDur-1)/SampleFreq*1000,1,-ST_Voltage*ST_RedPercWave[i]/100,0,0,0,0)
							endif
						endif
					else
						if (ST_LightStim[i])
							ProducePulses(WaveName,BeginTrainAt,Base_NPulses,ST_LightDur,Base_Freq,ST_LightVoltage*ST_RedPercWave[i]/100,0,0,0,0)
							Pos_Matrix[i][] = BeginTrainAt/1000//+RT_EPSPLatency
							if (Base_Recovery)
								TempVar = BeginTrainAt+Base_NPulses*1/Base_Freq*1000+Base_RecoveryPos
								ProducePulses(WaveName,TempVar,1,ST_LightDur,1,ST_LightVoltage*ST_RedPercWave[i]/100,0,0,0,0)
							endif
						endif
					endif
				endif
				// Make Graphs
				if ( (!(ExtracellularOnly)) %& (!(SuppressGraphs)) )
					WinNameStr = "Win"+num2str(i+5)
					TitleStr = "Baseline -- Channel #"+num2str(i+1)+" -- Cell #"+num2str(CellNumbers[i])
					LegendStr = "Ch #"+num2str(i+1)
					DisplayOneWave(WaveName,WinNameStr,TitleStr,LegendStr,G_X_Base,G_Y+j*(G_Height+G_Y_Grout),G_Width,G_Height)
					ModifyGraph rgb($WaveName)=(ChannelColor_R[i],ChannelColor_G[i],ChannelColor_B[i])
					Button ClosePlotsButton,pos={0,0},size={18,18},proc=ST_CloseProc,title="X"
				endif
				j += 1
			endif
			
		else
		
			WorkStr = "CellOn"+num2str(i+1)+"Check"
			ControlInfo/W=MultiPatch_ST_Creator $WorkStr				// Is there a connected cell on this channel?
			if (V_value)
				if (Base_RevOrder)											// Must still count the cell, even if only creating extracellular waves
					PulsePosCount -= 1
				else
					PulsePosCount += 1
				endif
			endif

		endif
		i += 1
	while (i<4)

	if (ExtracellularOnly)
		if (!(NoExtracellular))
			Notebook Parameter_Log selection={endOfFile, endOfFile}
			Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="SpikeTiming Creator is producing new extracellular wave\r\r",textRGB=(0,0,0)
			Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+" -- This is iteration "+num2str(DummyIterCounter)+" of step "+num2str(CurrentStep)+".\r"
			Notebook Parameter_Log ruler=Normal, text="\t\tVoltage:   "+num2str(ST_Voltage)+" V (not including percentage scaling)\r"
			print "\tVoltage: "+num2str(ST_Voltage)+" V (not including percentage scaling)"
			Notebook Parameter_Log ruler=Normal, text="\t\tStim dur:   "+num2str(ST_StimDur)+" samples\r"
			print "\tStim duration: "+num2str(ST_StimDur)+" samples"
			i = 0
			do
				if (ST_Extracellular[i])
					Notebook Parameter_Log ruler=Normal, text="\t\tPercentage scaling channel #"+num2str(i+1)+":   "+num2str(ST_RedPercWave[i])+" %\r"
					print "\tPercentage scaling channel #"+num2str(i+1)+":   "+num2str(ST_RedPercWave[i])+" %"
				endif
				i += 1
		 	while (i<4)
			Notebook Parameter_Log ruler=Normal, text="\r"
		else
			print "\t(No channel was marked as extracellular. Nothing was changed.)"
		endif
	else
		print "\tDumping parameters to the log file."
		ST_TakeNotes(AlertResponse)										// Produce some notes for the Parameter Log
	endif

	KillWaves/Z Ind_RelDispl,CellNumbers
	KillWaves/Z ST_KeepWave,ST_RedPercWave

	print "SpikeTiming Creator finished at "+Time()+"."

End

//////////////////////////////////////////////////////////////////////////////////
//// Produce some notes in the Parameter log about the waves that are being produced

Function ST_TakeNotes(AlertResponse)
	Variable	AlertResponse										// 1 = induction waves were made, 2 = induction waves were not made, but baseline waves were still made
																		// 3 = called from Making timing range

	//// BASELINE
	NVAR	Base_Spacing =	 	root:MP:ST_Data:Base_Spacing		// The spacing between the pulses in the baseline [ms]
	NVAR	Base_Freq = 		root:MP:ST_Data:Base_Freq			// The frequency of the pulses [Hz]
	NVAR	Base_NPulses = 	root:MP:ST_Data:Base_NPulses		// The number of pulses for each channel during the baseline
	NVAR	Base_WaveLength =	root:MP:ST_Data:Base_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Base_Recovery =	root:MP:ST_Data:Base_Recovery		// Boolean: Recovery test pulse?
	NVAR	Base_RecoveryPos =root:MP:ST_Data:Base_RecoveryPos	// Position of recovery test pulse relative to end of train [ms]
	NVAR	Base_AmplitudeIClamp = root:MP:ST_Data:Base_AmplitudeIClamp	// The pulse amplitude for baseline current clamp pulses [nA]
	NVAR	Base_DurationIClamp = 	root:MP:ST_Data:Base_DurationIClamp		// The pulse duration for baseline current clamp pulses [ms]

	//// GENERAL
	WAVE	ST_RedPercWave =	ST_RedPercWave					// The percentage scaling -- this wave will be killed by parent process
	
	NVAR	ST_AmplitudeVClamp = 	root:MP:ST_Data:ST_AmplitudeVClamp	// The pulse amplitude for _all_ voltage clamp pulses [nA]
	NVAR	ST_DurationVClamp =	root:MP:ST_Data:ST_DurationVClamp	// The pulse duration for _all_  voltage clamp pulses [ms]
	NVAR	ST_StartPad = 		root:MP:ST_Data:ST_StartPad			// The padding at the start of the waves [ms]
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves

	WAVE 	ST_LightStim = 		root:MP:ST_Data:ST_LightStim		// Is this channel a light stim channel?
	NVAR	ST_LightVoltage = 		root:MP:ST_Data:ST_LightVoltage	// The voltage amplitude for _all_ light stim pulses [V]
	NVAR	ST_LightDur = 			root:MP:ST_Data:ST_LightDur		// The voltage amplitude for _all_ light stim pulses [V]

	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_StimDur = 		root:MP:ST_Data:ST_StimDur			// The stim pulse duration [samples]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	WAVE 	ST_DendriticRec = 		root:MP:ST_Data:ST_DendriticRec		// Boolean: Is this channel a dendritic recording?

	NVAR	MMPooStyle =		root:MP:ST_Data:MMPooStyle		// Boolean: Is the protocol of the Bi&Poo, J.Neurosci, 1998 type?
																	// (Otherwise a LTP pairing protocol is assumed, with postsynaptic depolarization coincident with EPSP.)
	//// INDUCTION TWEAKS
	WAVE	ST_NoSpikes =		root:MP:ST_Data:ST_NoSpikes		// Used to store away the checkbox values -- No spikes at all on checked channel

	WAVE	ST_NegPulse =		root:MP:ST_Data:ST_NegPulse		// Used to store away the checkbox values -- Add negative pulses between spikes?
	NVAR	ST_NegPulseAmpI = root:MP:ST_Data:ST_NegPulseAmpI	// The size of the negative pulse

	WAVE	ST_LongInj =		root:MP:ST_Data:ST_LongInj		// Long current injection on this channel?
	NVAR	ST_LongAmpI = 		root:MP:ST_Data:ST_LongAmpI		// The amplitude of the long current injection step [nA]
	NVAR	ST_LongWidth = 	root:MP:ST_Data:ST_LongWidth		// The width of the long current injection step [ms] (centered around spike, or just before spike if short inj is also checked)

	WAVE	ST_ShortInj =		root:MP:ST_Data:ST_ShortInj		// Long current injection on this channel?
	NVAR	ST_ShortAmpI = 	root:MP:ST_Data:ST_ShortAmpI		// The amplitude of the short current injection step [nA]
	NVAR	ST_ShortWidth = 	root:MP:ST_Data:ST_ShortWidth	// The width of the short current injection step [ms] (occurs just before spike)

	WAVE	ST_KeepLast =		root:MP:ST_Data:ST_KeepLast		// Keep only last spike in spike train during induction on this channel?
	WAVE	ST_KeepFirst =		root:MP:ST_Data:ST_KeepFirst		// Keep only first spike in spike train during induction on this channel?

	NVAR	Ind_rangeStart = 	root:MP:ST_Data:Ind_rangeStart		// timing range start [ms]
	NVAR	Ind_rangeEnd = 		root:MP:ST_Data:Ind_rangeEnd			// timing range end [ms]

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I = 	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V = 	root:MP:SealTestAmp_V

	//// INDUCTION
	NVAR	Ind_ConcatFlag =	root:MP:ST_Data:Ind_ConcatFlag		// Boolean: Concatenate induction wave with a previously existing induction wave
	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Ind_RelDispl_1 = 	root:MP:ST_Data:Ind_RelDispl_1	// The relative displacement for the four channels [ms]
	NVAR	Ind_RelDispl_2 = 	root:MP:ST_Data:Ind_RelDispl_2
	NVAR	Ind_RelDispl_3 = 	root:MP:ST_Data:Ind_RelDispl_3
	NVAR	Ind_RelDispl_4 = 	root:MP:ST_Data:Ind_RelDispl_4
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix =			root:MP:ST_Data:ST_Suffix			// Suffix for the induction waves
	

	//// GAINS USED FOR SCALING
	WAVE	OutGainIClampWave = root:MP:IO_Data:OutGainIClampWave
	WAVE	OutGainVClampWave = root:MP:IO_Data:OutGainVClampWave

	//// CHANNELS IN VOLTAGE CLAMP
	WAVE	VClampWave =		root:MP:IO_Data:VClampWave		// Boolean: Which channels are in voltage clamp? (otherwise current clamp)

	
	Make/O/N=(4) Ind_RelDispl									// Make a wave of the relative displacements for each of the channels
	Ind_RelDispl = {Ind_RelDispl_1,Ind_RelDispl_2,Ind_RelDispl_3,Ind_RelDispl_4}

	Variable	i,j
	Variable	NChosen,Last
	String		WorkStr
	String		ChannelStr
	Variable	localGain

	ControlInfo/W=MultiPatch_ST_Creator Base_VClampPulseCheck				// Add pulses if channel is in voltage clamp too?
	Variable	Base_VClampPulse = V_value

	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	if (AlertResponse==3)
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="SpikeTiming Creator is producing new timing range waves\r",textRGB=(0,0,0)
	else
		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="SpikeTiming Creator is producing new waves\r",textRGB=(0,0,0)
	endif
	Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+"\r\r"
	
	Notebook Parameter_Log ruler=Normal, text="\tGeneral parameters\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tWave naming:\t\t"+ST_BaseName+"#"+ST_Suffix+"\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSample frequency:\t"+num2str(SampleFreq)+"\tHz\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude (V clamp):\t"+num2str(ST_AmplitudeVClamp)+"\tV\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration (V clamp):\t"+num2str(ST_DurationVClamp)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPadding at the start of all waves:\t"+num2str(ST_StartPad)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPadding at the end of the last pulse of all waves:\t"+num2str(ST_EndPad)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tVoltage amplitude (extracellular):\t"+num2str(ST_Voltage)+"\tV\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tStim duration (extracellular):\t"+num2str(ST_StimDur)+"\tsamples\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tLight pulse voltage:\t"+num2str(ST_LightVoltage)+"\tV\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tLight pulse duration:\t"+num2str(ST_LightDur)+"\tms\r"

	NChosen = 0													// Count number of channels chosen
	i = 0
	do
		
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
		If (V_value)
			NChosen += 1
		endif
		i += 1
	while (i<4)

	ChannelStr = ""
	i = 0
	j = 0
	do
		
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
		if (V_value)
			if ((j == NChosen-2) %& (NChosen == 2))
				WorkStr = (num2str(i+1)+" ")
				ChannelStr += WorkStr
			endif
			if ((j < NChosen-1) %& (!(NChosen == 2)) )
				WorkStr = num2str(i+1)+",  "
				ChannelStr += WorkStr
			endif
			if (j == NChosen-1)
				WorkStr = "and "+num2str(i+1)
				ChannelStr += WorkStr
			endif
			j += 1
		endif

		i += 1
	while (i<4)

	Notebook Parameter_Log ruler=TextRow, text="\t\tChannels selected:\t"+ChannelStr+"\r"

	ChannelStr = ""
	i = 0
	j = 0
	do
		
		if (VClampWave[i])
			localGain = OutGainVClampWave[i]
		else
			localGain = OutGainIClampWave[i]
		endif
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
		if (V_value)
			if ((j == NChosen-2) %& (NChosen == 2))
				WorkStr = (num2str(localGain)+" ")
				ChannelStr += WorkStr
			endif
			if ((j < NChosen-1) %& (!(NChosen == 2)) )
				WorkStr = num2str(localGain)+",  "
				ChannelStr += WorkStr
			endif
			if (j == NChosen-1)
				WorkStr = "and "+num2str(localGain)+", respectively."
				ChannelStr += WorkStr
			endif
			j += 1
		endif

		i += 1
	while (i<4)

	Notebook Parameter_Log ruler=TextRow, text="\t\tWave scaling by output gains:\t"+ChannelStr+"\r"
	ChannelStr = ""
	i = 0
	j = 0
	do
		
		if (VClampWave[i])
			localGain = OutGainVClampWave[i]
		else
			localGain = OutGainIClampWave[i]
		endif
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
		if (V_value)
			if ((j == NChosen-2) %& (NChosen == 2))
				WorkStr = (num2str(ST_RedPercWave[i])+" ")
				ChannelStr += WorkStr
			endif
			if ((j < NChosen-1) %& (!(NChosen == 2)) )
				WorkStr = num2str(ST_RedPercWave[i])+",  "
				ChannelStr += WorkStr
			endif
			if (j == NChosen-1)
				WorkStr = "and "+num2str(ST_RedPercWave[i])+", respectively."
				ChannelStr += WorkStr
			endif
			j += 1
		endif

		i += 1
	while (i<4)

	Notebook Parameter_Log ruler=TextRow, text="\t\tPercentage scaling [%]:\t"+ChannelStr+"\r"

	WorkStr = ""
	i = 0
	do
		if (ST_LightStim[i])
			WorkStr += "ch #"+num2str(i+1)+" "
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tLight stim channel(s):\t"+WorkStr+"\r"

	if (ST_Biphasic)
		Notebook Parameter_Log ruler=TextRow, text="\t\tBiphasic extracellular pulse:\tYes\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tBiphasic extracellular pulse:\tNo\r"
	endif
	WorkStr = ""
	i = 0
	do
		if (ST_Extracellular[i])
			WorkStr += "ch #"+num2str(i+1)+" "
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tExtracellular channel(s):\t"+WorkStr+"\r"

	WorkStr = ""
	i = 0
	do
		if (ST_DendriticRec[i] %& (!(ST_Extracellular[i])) )
			WorkStr += "ch #"+num2str(i+1)+" "
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tDendritic recording channel(s):\t"+WorkStr+"\r"

	WorkStr = ""
	Variable	AnyLongCurrent = 0
	i = 0
	do
		if ( (ST_LongInj[i]) %& (!(ST_Extracellular[i])) )
			WorkStr += "ch #"+num2str(i+1)+" "
			AnyLongCurrent = 1
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	
	Notebook Parameter_Log ruler=TextRow, text="\t\tChannel(s) with long current injection:\t"+WorkStr+"\r"

	WorkStr = ""
	Variable	AnyShortCurrent = 0
	i = 0
	do
		if ( (ST_ShortInj[i]) %& (ST_LongInj[i]) %& (!(ST_Extracellular[i])) )
			WorkStr += "ch #"+num2str(i+1)+" "
			AnyShortCurrent = 1
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tChannel(s) with short current injection:\t"+WorkStr+"\r"

	WorkStr = ""
	Variable	AnyKeepFirst = 0
	i = 0
	do
		if ( (ST_KeepFirst[i]) %& (!(ST_NoSpikes[i])) )
			WorkStr += "ch #"+num2str(i+1)+" "
			AnyKeepFirst = 1
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tChannel(s) with only _first_ spike kept:\t"+WorkStr+"\r"

	WorkStr = ""
	Variable	AnyKeepLast = 0
	i = 0
	do
		if ( (ST_KeepLast[i]) %& (!(ST_KeepFirst[i])) %& (!(ST_NoSpikes[i])) )
			WorkStr += "ch #"+num2str(i+1)+" "
			AnyKeepLast = 1
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tChannel(s) with only _last_ spike kept:\t"+WorkStr+"\r"

	WorkStr = ""
	Variable	AnyNoSpikes = 0
	i = 0
	do
		if (ST_NoSpikes[i])
			WorkStr += "ch #"+num2str(i+1)+" "
			AnyNoSpikes = 1
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tChannel(s) with no spikes kept:\t"+WorkStr+"\r"

	WorkStr = ""
	Variable	AnyNegPulse = 0
	i = 0
	do
		if (ST_NegPulse[i])
			WorkStr += "ch #"+num2str(i+1)+" "
			AnyNegPulse = 1
		endif
		i += 1
	while (i<4)
	if (StringMatch(WorkStr,""))
		WorkStr = "None"
	endif
	Notebook Parameter_Log ruler=TextRow, text="\t\tChannel(s) with negative pulses between spikes:\t"+WorkStr+"\r"

	WorkStr = ""
	i = 0
	do
		WorkStr = "CellOn"+num2str(i+1)+"Check"
		ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
		if (V_value)
			if (VClampWave[i])
				Notebook Parameter_Log ruler=TextRow, text="\t\tChannel #"+num2str(i+1)+" is in voltage clamp mode.\r"
			else
				Notebook Parameter_Log ruler=TextRow, text="\t\tChannel #"+num2str(i+1)+" is in current clamp mode.\r"
			endif
		endif
		i += 1
	while (i<4)
	
	if (MMPooStyle)
		Notebook Parameter_Log ruler=TextRow, text="\t\tProtocol is of the MM Poo-style.\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tClassical LTP pairing protocol is assumed. (Only applies when using V clamp.)\r"
	endif

	Notebook Parameter_Log ruler=TextRow, text="\r\tSealtest parameters are taken from the WaveCreator panel\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSeal test duration:\t"+num2str(SealTestDur)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSeal test pad before:\t"+num2str(SealTestPad1)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSeal test pad after:\t"+num2str(SealTestPad2)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSeal test amplitude (I clamp):\t"+num2str(SealTestAmp_I)+"\tnA\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tSeal test amplitude (V clamp):\t"+num2str(SealTestAmp_V)+"\tV\r"

	// Baseline
	Notebook Parameter_Log ruler=Normal, text="\r\tBaseline parameters\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude (Baseline I clamp):\t"+num2str(Base_AmplitudeIClamp)+"\tnA\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration (Baseline I clamp):\t"+num2str(Base_DurationIClamp)+"\tms\r"
	ControlInfo/W=MultiPatch_ST_Creator Base_SealTestCheck
	if (V_value)
		Notebook Parameter_Log ruler=TextRow, text="\t\tSealtest:\tYes\r"
	else
		Notebook Parameter_Log ruler=TextRow, text="\t\tSealtest:\tNo\r"
	endif
	if (Base_Recovery)
		Notebook Parameter_Log ruler=Normal, text="\t\tRecovery test pulse position [ms]:\t"+num2str(Base_RecoveryPos)+"\tms\r"
	endif
	if ( (Base_VClampPulse) %& (MMPooStyle) )
		Notebook Parameter_Log ruler=Normal, text="\t\tAdding pulses during baseline for channels in voltage clamp.\r"
	else
		Notebook Parameter_Log ruler=Normal, text="\t\tNot adding pulses during baseline for channels that are in voltage clamp.\r"
	endif
	Notebook Parameter_Log ruler=Normal, text="\t\tSpacing between pulses on different channels:\t"+num2str(Base_Spacing)+"\tms\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tFrequency of spike trains:\t"+num2str(Base_Freq)+"\tHz\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tNumber of pulses in spike train:\t"+num2str(Base_NPulses)+"\r"
	Notebook Parameter_Log ruler=Normal, text="\t\tWave length of all baseline waves:\t"+num2str(Base_WaveLength)+"\tms\r"

	if (AlertResponse==2)
		Notebook Parameter_Log ruler=Normal, text="\r\tInduction waves were not created\r\t\tWaves already exist as text waves that describe random spike trains.\r"
	else
		// Induction
		Notebook Parameter_Log ruler=Normal, text="\r\tInduction parameters\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse amplitude (Induction I clamp):\t"+num2str(Ind_AmplitudeIClamp)+"\tnA\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tPulse duration (Induction I clamp):\t"+num2str(Ind_DurationIClamp)+"\tms\r"
		ControlInfo/W=MultiPatch_ST_Creator Ind_SealTestCheck
		if (V_value)
			Notebook Parameter_Log ruler=TextRow, text="\t\tSealtest:\tYes\r"
		else
			Notebook Parameter_Log ruler=TextRow, text="\t\tSealtest:\tNo\r"
		endif
		if (Ind_ConcatFlag)
			Notebook Parameter_Log ruler=TextRow, text="\t\tConcatenate new waves with previously existing:\tYes\r"
		else
			Notebook Parameter_Log ruler=TextRow, text="\t\tConcatenate new waves with previously existing:\tNo\r"
		endif
		Notebook Parameter_Log ruler=Normal, text="\t\tOrigin:\t"+num2str(Ind_Origin)+"\tms\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tFrequency of spike trains:\t"+num2str(Ind_Freq)+"\tHz\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tNumber of pulses in spike train:\t"+num2str(Ind_NPulses)+"\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tWave length of all baseline waves:\t"+num2str(Ind_WaveLength)+"\tms\r"
		if (AnyLongCurrent)
			Notebook Parameter_Log ruler=Normal, text="\t\tAmplitude of long current injection:\t"+num2str(ST_LongAmpI)+"\tnA\r"
			Notebook Parameter_Log ruler=Normal, text="\t\tWidth of long current injection:\t"+num2str(ST_LongWidth)+"\tms\r"
		endif
		if (AnyShortCurrent)
			Notebook Parameter_Log ruler=Normal, text="\t\tAmplitude of short current injection:\t"+num2str(ST_ShortAmpI)+"\tnA\r"
			Notebook Parameter_Log ruler=Normal, text="\t\tWidth of short current injection:\t"+num2str(ST_ShortWidth)+"\tms\r"
		endif
		if (AnyNegPulse)
			Notebook Parameter_Log ruler=Normal, text="\t\tAmplitude of neg pulses between spikes:\t"+num2str(ST_NegPulseAmpI)+"\tnA\r"
		endif
		
		i = 0
		WAVE	www = Ind_RelDispl
		do
			
			WorkStr = "CellOn"+num2str(i+1)+"Check"
			ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
			If (V_value)
				Notebook Parameter_Log ruler=Normal, text="\t\tChannel number "+num2str(i+1)+" relative displacement:\t"+num2str(www[i])+"\tms\r"
			endif
	
			i += 1
		while (i<4)
	endif
	
	if (AlertResponse==3)
		Notebook Parameter_Log ruler=Normal, text="\t\tTiming range start:\t"+num2str(Ind_rangeStart)+"\tms\r"
		Notebook Parameter_Log ruler=Normal, text="\t\tTiming range end:\t"+num2str(Ind_rangeEnd)+"\tms\r"
	endif
	
	Notebook Parameter_Log ruler=Normal, text="\r"

	KillWaves/Z Ind_RelDispl

End

//////////////////////////////////////////////////////////////////////////////////
//// Close all the graphs that have anything to do with the ST_Creator panel

Function ST_CloseAllGraphs()

	Variable	i,j
	String		WinName
	
	i = 0
	do
		WinName = "Win"+num2str(i+1)
		DoWindow/K $WinName
		i += 1
	while (i<8)	
	
	j = 0
	do
		DoWindow/K $("RND_"+num2str(j+1))
		j += 1
	while (j<4)

	ST_CloseCorrGraphs()

End

Function ST_CloseCorrGraphs()

	Variable	i,j

	i = 0
	do
		j = 0
		do
			DoWindow/K $("Corr_"+num2str(i+1)+"_"+num2str(j+1))
			j += 1
		while (j<4)
		i += 1
	while (i<4)

End

//////////////////////////////////////////////////////////////////////////////////
//// Toggle the checkbox values for the MM Poo style protocol

Function ST_ToggleMooMingPooStyleProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	ST_StoreCheckboxValues()

End

//////////////////////////////////////////////////////////////////////////////////
//// Show the tweaks or not

Function ST_ToggleShowTweaksProc(ctrlName) : ButtonControl
	String		ctrlName
	
	NVAR		ST_ShowTweaks
	Variable		ScSc = 72/ScreenResolution				// Screen resolution
	NVAR		ST_PanFullHeight
	NVAR		ST_PanHalfHeight
	
	String		coordList = JT_GetWinPos("MultiPatch_ST_Creator")
	
	Variable	PanX = Str2num(StringFromList(0,coordList))
	Variable	PanY = Str2num(StringFromList(1,coordList))
	Variable	Width = Str2num(StringFromList(2,coordList))
	Variable	Height = Str2num(StringFromList(3,coordList))
	
	if (!(StringMatch(ctrlName,"NoToggle")))
		ST_ShowTweaks = ST_ShowTweaks == 1 ? 0 : 1
	endif

	if (ST_ShowTweaks)
		MoveWindow/W=MultiPatch_ST_Creator PanX*ScSc,PanY*ScSc,PanX*ScSc+Width*ScSc,PanY*ScSc+ST_PanFullHeight*ScSc
		Button ToggleShowTweaksButton,title="LESS",win=MultiPatch_ST_Creator
	else
		MoveWindow/W=MultiPatch_ST_Creator PanX*ScSc,PanY*ScSc,PanX*ScSc+Width*ScSc,PanY*ScSc+ST_PanHalfHeight*ScSc
		Button ToggleShowTweaksButton,title="MORE",win=MultiPatch_ST_Creator
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Update the checkbox values for the extracelluluar boolean variables

Function ST_ToggleTweaks(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	ST_StoreCheckboxValues()

End

//////////////////////////////////////////////////////////////////////////////////
//// Update the wavelength according to changes in the parameters -- BOTH INDUCTION AND BASE-
//// LINE

Function ST_ChangeBoth_SetVar(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	ST_UpdateInd_WaveLength()
	ST_UpdateBase_WaveLength()


End

//////////////////////////////////////////////////////////////////////////////////
//// Update the wavelength according to changes in the parameters -- INDUCTION

Function ST_ToggleInd_SealTestProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	ST_StoreCheckboxValues()	
	ST_UpdateInd_WaveLength()

End

Function ST_ChangeInd_SetVar(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	ST_UpdateInd_WaveLength()

End

Function ST_UpdateInd_WaveLength()

	NVAR	Ind_Origin = 		root:MP:ST_Data:Ind_Origin			// The origin for the spiketiming waves during induction (shift in [ms] relative to end of sealtest, if used)
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_WaveLength =	root:MP:ST_Data:Ind_WaveLength	// The length of the waves for the ST_Creator [ms]

	NVAR	ST_StartPad = 		root:MP:ST_Data:ST_StartPad		// The padding at the start of the waves [ms]
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I = 	root:MP:SealTestAmp_I

	NVAR	Ind_Sealtest =		root:MP:ST_Data:Ind_Sealtest
	
	NVAR	Ind_RelDispl_1 =	root:MP:ST_Data:Ind_RelDispl_1	// Relative displacement channel 1
	NVAR	Ind_RelDispl_2 =	root:MP:ST_Data:Ind_RelDispl_2	// Relative displacement channel 2
	NVAR	Ind_RelDispl_3 =	root:MP:ST_Data:Ind_RelDispl_3	// Relative displacement channel 3
	NVAR	Ind_RelDispl_4 =	root:MP:ST_Data:Ind_RelDispl_4	// Relative displacement channel 4

	Variable	MaxInd_RelDispl = 0
	
	MaxInd_RelDispl = max(MaxInd_RelDispl,Ind_RelDispl_1)
	MaxInd_RelDispl = max(MaxInd_RelDispl,Ind_RelDispl_2)
	MaxInd_RelDispl = max(MaxInd_RelDispl,Ind_RelDispl_3)
	MaxInd_RelDispl = max(MaxInd_RelDispl,Ind_RelDispl_4)

	Ind_WaveLength = Ind_Origin+1/Ind_Freq*(Ind_NPulses-1)*1000+ST_StartPad+ST_EndPad+MaxInd_RelDispl
	
	if (Ind_Sealtest)
		Ind_WaveLength += (SealTestPad1+SealTestPad2+SealTestDur+SealTestAmp_I)
	endif
	
	DoWindow MultiPatch_ST_Creator
	if (V_flag)
		ControlUpdate/W=MultiPatch_ST_Creator Ind_WaveLengthSetVar
	endif
		
End

//////////////////////////////////////////////////////////////////////////////////
//// Update the wavelength according to changes in the parameters -- BOTH WAVE CREATOR AND ST CREATOR
//// Note that these checkboxes are linked!

Function WCST_ToggleSealTestAtEndProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR		ST_SealTestAtEnd =		root:MP:ST_Data:ST_SealTestAtEnd
	ST_SealTestAtEnd = checked

	CheckBox/Z WC_SealTestAtEndCheck,win=MultiPatch_WaveCreator,value=ST_SealTestAtEnd

	DoWindow MultiPatch_ST_Creator
	if (V_flag)	
		CheckBox ST_SealTestAtEndCheck,win=MultiPatch_ST_Creator,value=ST_SealTestAtEnd
		ST_StoreCheckboxValues()
//		ST_UpdateBase_WaveLength()			// why should this be called here? Superfluous, no?
	endif

End

//////////////////////////////////////////////////////////////////////////////////
//// Update the wavelength according to changes in the parameters -- BASELINE

Function ST_ToggleBase_SealTestProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	ST_StoreCheckboxValues()	
	ST_UpdateBase_WaveLength()

End

Function ST_ChangeBase_SetVar(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	ST_UpdateBase_WaveLength()

End

Function ST_UpdateBase_WaveLength()

	NVAR	Base_Spacing =	 	root:MP:ST_Data:Base_Spacing		// The spacing between the pulses in the baseline [ms]
	NVAR	Base_Freq = 		root:MP:ST_Data:Base_Freq			// The frequency of the pulses [Hz]
	NVAR	Base_NPulses = 	root:MP:ST_Data:Base_NPulses		// The number of pulses for each channel during the baseline
	NVAR	Base_WaveLength =	root:MP:ST_Data:Base_WaveLength	// The length of the waves for the ST_Creator [ms]
	NVAR	Base_RecoveryPos =root:MP:ST_Data:Base_RecoveryPos	// Position of recovery pulse {if checked} relative to end of train [ms]
		
	NVAR	ST_StartPad = 		root:MP:ST_Data:ST_StartPad		// The padding at the start of the waves [ms]
	NVAR	ST_EndPad = 		root:MP:ST_Data:ST_EndPad			// The padding at the end of the waves [ms]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I = 	root:MP:SealTestAmp_I
	
	NVAR	Base_Sealtest =		root:MP:ST_Data:Base_Sealtest
	NVAR	Base_Recovery =	root:MP:ST_Data:Base_Recovery		// Boolean: Recovery test pulse?

	WAVE 	ST_ChannelsChosen = root:MP:ST_Data:ST_ChannelsChosen

	Variable	i
	Variable	NChecks
	
	NChecks = 0													// Count the number of channels to be used in the spike timing pattern
	i = 0
	do
		if (ST_ChannelsChosen[i])
			NChecks += 1
		endif
		i += 1
	while (i<4)

	Base_WaveLength = (1/Base_Freq*(Base_NPulses-1)*1000+Base_Spacing)*NChecks-Base_Spacing+ST_StartPad+ST_EndPad
	if (Base_Recovery)
		Base_WaveLength += Base_RecoveryPos*NChecks
	endif
	
	if (Base_Sealtest)
		Base_WaveLength += (SealTestPad1+SealTestPad2+SealTestDur+SealTestAmp_I)
	endif
	
	DoWindow MultiPatch_ST_Creator
	if (V_flag)
		ControlUpdate/W=MultiPatch_ST_Creator Base_WaveLengthSetVar
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Update the checkboxes in the pattern maker according to what channels are selected in the
//// ST_Creator panel.

Function ST_UpdatePatternMakerProc(ctrlName) : ButtonControl
	String		ctrlName

	Variable	i
	Variable	j
	
	String		CommandStr
	String		WorkStr
	String		NoteStr
	
	NVAR		WorkVar =		root:MP:PM_Data:WorkVar
	NVAR		NSteps =		root:MP:PM_Data:NSteps				// Number of steps in the pattern
	

	Print "SpikeTiming Creator is updating the PatternMaker at time "+Time()+"."

	//// Take automatic notes
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Updating the pattern\r\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\t\t...based on settings in the SpikeTiming CreatorTime. Time is "+Time()+".\r\r"

	NoteStr = ""
	i = 0
	do																	// Change the first three steps in the pattern maker
	
		print "\tStep #"+num2str(i+1)

		j = 0
		do																// Perform changes on all channels that are selected in the ST_Creator panel
		
			WorkStr = "CellOn"+num2str(j+1)+"Check"
			ControlInfo/W=MultiPatch_ST_Creator $WorkStr			// Is there a connected cell on this channel?
			WorkVar = V_value
			if ( (WorkVar) %& (i == 0) )
				NoteStr += (num2str(j+1)+"    ")
			endif

			CommandStr = "root:MP:PM_Data:OutputCheck"+num2str(i+1)+"_"+num2str(j+1)+"="				// Output checkbox values
			CommandStr += "root:MP:PM_Data:WorkVar"
			Execute CommandStr

			CommandStr = "root:MP:PM_Data:InputCheck"+num2str(i+1)+"_"+num2str(j+1)+"="				// Input checkbox values
			CommandStr += "root:MP:PM_Data:WorkVar"
			Execute CommandStr
			
			j += 1
		while (j<4)
		
		i += 1
	while (i<NSteps)
	
	Notebook Parameter_Log ruler=Normal, text="\t\tChannels that were selected:    "+NoteStr+"\r\r"

	print "\tUpdating PatternMaker panel."
	CommandStr = "MakeMultiPatch_PatternMaker()"						// Redraw the PatternMaker panel
	Execute CommandStr
	DoUpdate
	Print "SpikeTiming Creator finished updating the PatternMaker at time "+Time()+"."

End

//////////////////////////////////////////////////////////////////////////////////
//// Show the waves that are being made

Function DisplayOneWave(WaveName,WinName,TitleStr,LegendStr,PosX,PosY,Width,Height)
	String		WaveName
	String		WinName
	String		TitleStr
	String		LegendStr
	Variable	PosX
	Variable	PosY
	Variable	Width
	Variable	Height
	
	Wave	w = $WaveName
	DoWindow/K $WinName
	if (StringMatch(TitleStr,""))	
		Display/W=(PosX, PosY, PosX+Width, PosY+Height) w
	else
		Display/W=(PosX, PosY, PosX+Width, PosY+Height) w as TitleStr
	endif
	Label left "\\u"
	DoWindow/C $WinName
	Legend	LegendStr
	ModifyGraph/W=$WinName margin(left)=40,margin(right)=4
	ModifyGraph/W=$WinName margin(bottom)=28,margin(top)=8
	Button CloseThePlotsButton,pos={0,0},size={18,18},proc=WC_CloseThePlotsProc,title="X"

End

//////////////////////////////////////////////////////////////////////////////////
//// Save the general settings as an Igor text file

Function SaveSettingsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	SVAR		ChannelNote1 = root:MP:IO_Data:ChannelNote1
	SVAR		ChannelNote2 = root:MP:IO_Data:ChannelNote2
	SVAR		ChannelNote3 = root:MP:IO_Data:ChannelNote3
	SVAR		ChannelNote4 = root:MP:IO_Data:ChannelNote4

	WAVE		OutGainIClampWave = root:MP:IO_Data:OutGainIClampWave
	WAVE		OutGainVClampWave = root:MP:IO_Data:OutGainVClampWave

	WAVE		InGainIClampWave = root:MP:IO_Data:InGainIClampWave
	WAVE		InGainVClampWave = root:MP:IO_Data:InGainVClampWave
	
	NVAR		pAUnits = root:MP:IO_Data:pAUnits									// Boolean: Convert to [pA] in v clamp (otherwise [A])
	NVAR		mVUnits = root:MP:IO_Data:mVUnits									// Boolean: Convert to [mV] in i clamp (otherwise [V])
	NVAR		AcqGainSet = root:MP:AcqGainSet

	//// 	PARAMETERS FROM WAVECREATOR	
	NVAR		SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	Make/T/O/N=(4) ChannelNoteWave
	WAVE/T	ChannelNoteWave = ChannelNoteWave
	ChannelNoteWave = {ChannelNote1,ChannelNote2,ChannelNote3,ChannelNote4}

	Make/O/N=(2) ParameterWave
	ParameterWave = {pAUnits,mVUnits,AcqGainSet,SampleFreq}

	Save/T/O/I/P=Settings ChannelNoteWave,OutGainIClampWave,OutGainVClampWave,InGainIClampWave,InGainVClampWave,ParameterWave as "Default_Settings.itx"
	Print "Saving the settings at time "+Time()+"."
	
	Killwaves/Z ChannelNoteWave,ParameterWave

End

//////////////////////////////////////////////////////////////////////////////////
//// Save the general settings as an Igor text file

Function LoadSettingsProc(ctrlName) : ButtonControl
	String		ctrlName
	
	DoLoadSettings(1)
	
End

Function DoLoadSettings(InterActive)
	Variable	InterActive													// Boolean: Load interactively (or load default filename --> starting up)?

	SVAR		ChannelNote1 = root:MP:IO_Data:ChannelNote1
	SVAR		ChannelNote2 = root:MP:IO_Data:ChannelNote2
	SVAR		ChannelNote3 = root:MP:IO_Data:ChannelNote3
	SVAR		ChannelNote4 = root:MP:IO_Data:ChannelNote4

	WAVE		OutGainIClampWave = root:MP:IO_Data:OutGainIClampWave
	WAVE		OutGainVClampWave = root:MP:IO_Data:OutGainVClampWave

	WAVE		InGainIClampWave = root:MP:IO_Data:InGainIClampWave
	WAVE		InGainVClampWave = root:MP:IO_Data:InGainVClampWave
	
	NVAR		pAUnits = root:MP:IO_Data:pAUnits									// Boolean: Convert to [pA] in v clamp (otherwise [A])
	NVAR		mVUnits = root:MP:IO_Data:mVUnits									// Boolean: Convert to [mV] in i clamp (otherwise [V])
	NVAR		AcqGainSet = root:MP:AcqGainSet										// The per-channel gain
	
	//// 	PARAMETERS FROM WAVECREATOR	
	NVAR		SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	Variable	i

	String	OldDataFolder = GetDataFolder(1)
	SetDataFolder root:
	
	Killwaves/Z ChannelNoteWave
	
	Print "--- Loading settings at "+Time()+" ---"

	if (InterActive)
		LoadWave/Q/T/O/I/P=Settings "Default_Settings"
	else
		LoadWave/Q/T/O/P=Settings "Default_Settings"
	endif
	Print "\tLoaded file \""+S_fileName+"\" from this path: "+S_path
	if (Exists("ChannelNoteWave"))

		Notebook Parameter_Log selection={endOfFile, endOfFile}

		WAVE/T		ChannelNoteWave = root:ChannelNoteWave
		WAVE		LocalOutGainIClampWave = root:OutGainIClampWave
		WAVE		LocalOutGainVClampWave = root:OutGainVClampWave
		WAVE		LocalInGainIClampWave = root:InGainIClampWave
		WAVE		LocalInGainVClampWave = root:InGainVClampWave
		WAVE		ParameterWave = root:ParameterWave

		Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Default settings\r",textRGB=(0,0,0)
		Notebook Parameter_Log ruler=Normal, text="\r\tDate: "+Date()+"\r"
		Notebook Parameter_Log text="\tTime: "+Time()+"\r"
		Notebook Parameter_Log text="\tSettings file: \""+S_fileName+"\"\r"
		Notebook Parameter_Log text="\tSettings path: \""+S_path+"\"\r"
		Print "\tTransferring information from loaded info waves."
		OutGainIClampWave = LocalOutGainIClampWave
		OutGainVClampWave = LocalOutGainVClampWave
		InGainIClampWave = LocalInGainIClampWave
		InGainVClampWave = LocalInGainVClampWave
		ChannelNote1 = ChannelNoteWave[0]
		ChannelNote2 = ChannelNoteWave[1]
		ChannelNote3 = ChannelNoteWave[2]
		ChannelNote4 = ChannelNoteWave[3]
		i = 0
		do
			Print "\t\tFor Ch#"+num2str(i+1)+": "+ChannelNoteWave[i]+", OutGain IC="+num2str(OutGainIClampWave[i])+", OutGain VC="+num2str(OutGainVClampWave[i])+", InGain IC="+num2str(InGainIClampWave[i])+", InGain VC="+num2str(InGainVClampWave[i])
			Notebook Parameter_Log text="\tFor Ch#"+num2str(i+1)+":\r\t"+ChannelNoteWave[i]+", OutGain IC="+num2str(OutGainIClampWave[i])+", OutGain VC="+num2str(OutGainVClampWave[i])+", InGain IC="+num2str(InGainIClampWave[i])+", InGain VC="+num2str(InGainVClampWave[i])+"\r"
			i += 1
		while (i<4)
		pAUnits = ParameterWave[0]
		if (pAUnits)
			Print "\t\t* Working with [pA]."
			Notebook Parameter_Log text="\t\t* Working with [pA].\r"
		else
			Print "\t\t* Working with [A]."
			Notebook Parameter_Log text="\t\t* Working with [A].\r"
		endif
		mVUnits = ParameterWave[1]
		if (mVUnits)
			Print "\t\t* Working with [mV]."
			Notebook Parameter_Log text="\t\t* Working with [mV].\r"
		else
			Print "\t\t* Working with [V]."
			Notebook Parameter_Log text="\t\t* Working with [V].\r"
		endif
		AcqGainSet = ParameterWave[2]
		print "\t\t* {AcqGainSet} = "+num2str(AcqGainSet)
		
		if (numpnts(ParameterWave)>3)
			SampleFreq = ParameterWave[3]			// Load sample frequency, if stored
			print "\t\t* {SampleFreq} = "+num2str(SampleFreq)
			Notebook Parameter_Log text="\t\t* Sample frequency is "+num2str(SampleFreq)+" Hz.\r"
		else
			print "\t\t* {SampleFreq} = "+num2str(SampleFreq)+" -- not updated."
		endif
		DoWindow MultiPatch_Switchboard
		if (V_Flag)
			UpdateGainSetBoxes()
			RedrawUnitsCheckboxes()
		endif
		Notebook Parameter_Log text="\r"
		Print "\tKilling info waves (no longer needed)."
		KillWaves/Z ChannelNoteWave,LocalOutGainIClampWave,LocalOutGainVClampWave,LocalInGainIClampWave,LocalInGainVClampWave
		Print "--- Done loading settings ---"

	else
		
		print "\r"
		Print "\t\t************ Loading settings did not work! ************"
		print "\r"

	endif
	
	SetDataFolder OldDataFolder

End

//////////////////////////////////////////////////////////////////////////////////
//// Checkboxes aren't update automatically, so the "Inputs units" checkboxes must be updated by
//// hand below.

Function RedrawUnitsCheckboxes()

	NVAR		pAUnits = root:MP:IO_Data:pAUnits									// Boolean: Convert to [pA] in v clamp (otherwise [A])
	NVAR		mVUnits = root:MP:IO_Data:mVUnits									// Boolean: Convert to [mV] in i clamp (otherwise [V])

	CheckBox pAConvCheck pos={4+64+12,522+19},size={55-12,19},proc=DA_ToggleUnitsProc,title="pA",value=pAUnits,win=MultiPatch_SwitchBoard
	CheckBox mVConvCheck pos={4+64+55+4+8,522+19},size={55-8,19},proc=DA_ToggleUnitsProc,title="mV",value=mVUnits,win=MultiPatch_SwitchBoard

End

//////////////////////////////////////////////////////////////////////////////////
//// This function takes a string as an argument, looks for bad characters that would not work for
//// a wave name, for example, and replaces them with an underscore, etc

Function/S EliminateBadChars(Str)
	String		Str
	Variable	i
	Variable	Length
	Length = strlen(Str)
	i = 0
	do
		if (StringMatch(Str[i,i],".")) // work in progress... add more "bad chars" in the future...
			Str[i,i] = "_"
		endif
		if (StringMatch(Str[i,i],"-"))
			Str[i,i] = "n"
		endif
		if (StringMatch(Str[i,i],"+"))
			Str[i,i] = "p"
		endif
		i += 1
	while (i<Length)
	
	Return Str

End

//////////////////////////////////////////////////////////////////////////////////
//// Need to clear the t_vectors before running a pattern

Function Clear_tVectors()

	WAVE/T	t_vector =				root:MP:PM_Data:t_vector
	WAVE		dt_vector =				root:MP:PM_Data:dt_vector

	t_vector = "------------"
	dt_vector = 0
		
end

//////////////////////////////////////////////////////////////////////////////////
//// Produce a table of the timing vectors

Macro t_vectors()
	Silent 1

	Edit root:MP:PM_Data:t_vector,root:MP:PM_Data:dt_vector

End

//////////////////////////////////////////////////////////////////////////////////
//	This function returns a string representing a number padded with zeros, so that the number of character
//	= digits. If num occupies more digits than requested, the excess low digits of the number are truncated. 
// 	e.g. calling JS_num2digstr (3,1234) returns "123", while  calling JS_num2digstr (6,1234) returns "001234"
// Borrowed from SNUtilities2.3 on 2004-03-08, Jesper Sjostrom

Function /S JS_num2digstr(digits,num)
	variable digits, num

	String outstr, zerostr="000000000000", numstr = num2istr(num)
	variable i=1
	
	if (strlen(numstr) <= digits) 
		outstr = zerostr[0,digits-1]		
		outstr[digits-strlen(numstr),digits-1] = numstr
	else
		outstr = numstr[0,digits-1]
	endif
	
	return outstr
End

//// --- THE LOADWAVES PANEL WAS DEPRECATED ON 26 MAR 2021, JSJ --- ////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////// Make LoadWavesPanel so that user can quickly load & display recently
////// acquired waves
//
//Function MakeLoadWavesPanel()
//
//	NVAR		ScSc = root:MP:ScSc
//	
//	NVAR		nRepsToLoad = root:MP:nRepsToLoad
//	WAVE		LoadDataFromThisChannel = root:MP:LoadDataFromThisChannel
//
//	Variable	WinX = 300
//	Variable	WinY = 45
//	Variable	WinWidth = 360
//	Variable	WinHeight = 126+22+22*6+2
//
//	DoWindow/K MultiPatch_LoadWavesPanel
//	NewPanel /W=(WinX*ScSc,WinY*ScSc,WinX*ScSc+WinWidth,WinY*ScSc+WinHeight) as "MP Load Waves"
//	DoWindow/C MultiPatch_LoadWavesPanel
//	
//	SetDrawLayer UserBack
//	SetDrawEnv linethick= 2,fillbgc= (1,1,1),fillfgc= (65535/2,65535/10,65535/2)//,fillfgc= (65535/2,65535/2,65535/2)
//	DrawRect 4,2,WinWidth-4,36
//	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
//	SetDrawEnv textxjust= 1
//	DrawText WinWidth/2,29,"MultiPatch Load Waves"
//
//	Variable YShift = 40
//	Variable SpChX = (WinWidth-16)/4
//	CheckBox LoadFrom1Check pos={8+SpChX*0,YShift},size={SpChX-4,19},Proc=MP_ToggleLoadFromProc,title="Channel 1",value=LoadDataFromThisChannel[0],font="Arial",fSize=12
//	CheckBox LoadFrom2Check pos={8+SpChX*1,YShift},size={SpChX-4,19},Proc=MP_ToggleLoadFromProc,title="Channel 2",value=LoadDataFromThisChannel[1],font="Arial",fSize=12
//	CheckBox LoadFrom3Check pos={8+SpChX*2,YShift},size={SpChX-4,19},Proc=MP_ToggleLoadFromProc,title="Channel 3",value=LoadDataFromThisChannel[2],font="Arial",fSize=12
//	CheckBox LoadFrom4Check pos={8+SpChX*3,YShift},size={SpChX-4,19},Proc=MP_ToggleLoadFromProc,title="Channel 4",value=LoadDataFromThisChannel[3],font="Arial",fSize=12
//
//	Variable	firstWid = WinWidth/2-8-20
//	Variable	otherWid = (WinWidth-firstWid-4)/3-4
//	SetVariable Start1SuffSetVar,pos={4,YShift+22*1},size={firstWid-4,20},title="Start loading at: "
//	SetVariable Start1SuffSetVar,limits={1,Inf,1},value=root:MP:LoadData_Suff1Start
//	SetVariable Start2SuffSetVar,pos={4+firstWid+(otherWid+4)*0,YShift+22*1},size={otherWid,20},title=" "
//	SetVariable Start2SuffSetVar,limits={1,Inf,1},value=root:MP:LoadData_Suff2Start
//	SetVariable Start3SuffSetVar,pos={4+firstWid+(otherWid+4)*1,YShift+22*1},size={otherWid,20},title=" "
//	SetVariable Start3SuffSetVar,limits={1,Inf,1},value=root:MP:LoadData_Suff3Start
//	SetVariable Start4SuffSetVar,pos={4+firstWid+(otherWid+4)*2,YShift+22*1},size={otherWid,20},title=" "
//	SetVariable Start4SuffSetVar,limits={1,Inf,1},value=root:MP:LoadData_Suff4Start
//
//	Variable ColorDiv=10
//	Button GrabDataButton,pos={4,YShift+22*2},size={WinWidth/2-8,20},proc=MP_LoadDataGrabDataProc,title="Grab data from MultiPatch",fColor=(0,0,0),font="Arial",fSize=11
//	SetVariable nWavesSetVar,pos={4+WinWidth/2,YShift+22*2},size={WinWidth/2-8,20},title="Number of waves: "
//	SetVariable nWavesSetVar,limits={1,Inf,1},value=root:MP:nRepsToLoad
//
//	Button LoadTheDataButton1,pos={4,YShift+22*3},size={WinWidth/2-8,20},proc=MP_LoadDataProc,title="Load the data",fColor=(0,65535/ColorDiv,0),font="Arial",fSize=11
//	SetVariable StepSetVar,pos={4+WinWidth/2,YShift+22*3},size={WinWidth/2-8,18},title="Step between waves: "
//	SetVariable StepSetVar,limits={1,Inf,1},value=root:MP:LoadData_Step
//
//	Button CloseThisPanelButton,pos={4,YShift+22*4},size={WinWidth/2-8,20},proc=MP_LoadDataClosePanelProc,title="Close this panel",fColor=(65535/ColorDiv,0,0),font="Arial",fSize=11
//	CheckBox plotMeanTraceCheck pos={4+WinWidth/2,YShift+22*4},size={WinWidth/2-8,19},title="Plot mean trace",value=1,font="Arial",fSize=11
//
//	// Zoom in parameters
//
//	SetVariable xStartSV,pos={4,YShift+22*5},size={WinWidth/2-8,20},title="Zoom start (ms)"
//	SetVariable xStartSV,limits={0,Inf,1},value=root:MP:LD_xStart
//	SetVariable xSpacingSV,pos={4+WinWidth/2,YShift+22*5},size={WinWidth/2-8,20},title="Zoom spacing (ms)"
//	SetVariable xSpacingSV,limits={0,Inf,100},value=root:MP:LD_xSpacing
//	
//	SetVariable nRespSV,pos={4,YShift+22*6},size={WinWidth/2-8,20},title="Number of Zooms"
//	SetVariable nRespSV,limits={1,Inf,1},value=root:MP:LD_nResponses
//	SetVariable winWidSV,pos={4+WinWidth/2,YShift+22*6},size={WinWidth/2-8,20},title="Zoom duration (ms)"
//	SetVariable winWidSV,limits={10,Inf,5},value=root:MP:LD_winWidth
//	
//	SetVariable xPadSV,pos={4,YShift+22*7},size={WinWidth/2-8,20},title="Pad before (ms)"
//	SetVariable xPadSV,limits={1,Inf,1},value=root:MP:LD_xPad
//	SetVariable respWinSV,pos={4+WinWidth/2,YShift+22*7},size={WinWidth/2-8,20},title="Response window (ms)"
//	SetVariable respWinSV,limits={0,Inf,100},value=root:MP:LD_RespWin
//	
//	SetVariable latencySV,pos={4,YShift+22*8},size={WinWidth/2-8,20},title="Response latency (ms)"
//	SetVariable latencySV,limits={1,Inf,1},value=root:MP:LD_latency
//	SetVariable freqSV,pos={4+WinWidth/2,YShift+22*8},size={WinWidth/2-8,20},title="Response frequency (Hz)"
//	SetVariable freqSV,limits={5,Inf,5},value=root:MP:LD_pulseFreq
//
//	SetVariable nPulsesSV,pos={4,YShift+22*9},size={WinWidth/2-8,20},title="Number of responses"
//	SetVariable nPulsesSV,limits={1,Inf,1},value=root:MP:LD_nPulses
//	Button LoadTheDataButton2,pos={4+WinWidth/2,YShift+22*9},size={WinWidth/2-8,20},proc=MP_LoadDataProc,title="Load & zoom in",fColor=(0,65535/ColorDiv,0),font="Arial",fSize=11
//
//	Button PlotsToFrontButton,pos={4,YShift+22*10},size={WinWidth/2-8,20},proc=MP_LoadData_ToFrontProc,title="Plots to front",font="Arial",fsize=11
//	Button PlotsToBackButton,pos={4+WinWidth/2,YShift+22*10},size={WinWidth/2-8,20},proc=MP_LoadData_ToBackProc,title="Plots to back",font="Arial",fsize=11
//
//End
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////// Grab data from the MultiPatch SwitchBoard
//
//Function MP_LoadDataGrabDataProc(ctrlName) : ButtonControl
//	String ctrlName
//
//	// Parameters from the MultiPatch_SwitchBoard
//	NVAR		StartAt1 = 				root:MP:IO_Data:StartAt1
//	NVAR		StartAt2 = 				root:MP:IO_Data:StartAt2
//	NVAR		StartAt3 = 				root:MP:IO_Data:StartAt3
//	NVAR		StartAt4 = 				root:MP:IO_Data:StartAt4
//	
//	// Parameters from the LoadDataPanel
//	NVAR	nRepsToLoad = root:MP:nRepsToLoad
//	NVAR	LoadData_Suff1Start = root:MP:LoadData_Suff1Start
//	NVAR	LoadData_Suff2Start = root:MP:LoadData_Suff2Start
//	NVAR	LoadData_Suff3Start = root:MP:LoadData_Suff3Start
//	NVAR	LoadData_Suff4Start = root:MP:LoadData_Suff4Start
//	NVAR	LoadData_Step = root:MP:LoadData_Step
//	
//	LoadData_Suff1Start = StartAt1-nRepsToLoad*LoadData_Step
//	if (LoadData_Suff1Start<1)
//		LoadData_Suff1Start = 1
//	endif
//	
//	LoadData_Suff2Start = StartAt2-nRepsToLoad*LoadData_Step
//	if (LoadData_Suff2Start<1)
//		LoadData_Suff2Start = 1
//	endif
//	
//	LoadData_Suff3Start = StartAt3-nRepsToLoad*LoadData_Step
//	if (LoadData_Suff3Start<1)
//		LoadData_Suff3Start = 1
//	endif
//	
//	LoadData_Suff4Start = StartAt4-nRepsToLoad*LoadData_Step
//	if (LoadData_Suff4Start<1)
//		LoadData_Suff4Start = 1
//	endif
//	
//End
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////// Load the data!!!
//
//Function MP_LoadDataProc(ctrlName) : ButtonControl
//	String ctrlName
//	
//	Variable zoomIn = stringMatch(ctrlName,"LoadTheDataButton2")
//
//	// Parameters from the MultiPatch_SwitchBoard
//	SVAR		WaveNamesIn1 = 		root:MP:IO_Data:WaveNamesIn1
//	SVAR		WaveNamesIn2 = 		root:MP:IO_Data:WaveNamesIn2
//	SVAR		WaveNamesIn3 = 		root:MP:IO_Data:WaveNamesIn3
//	SVAR		WaveNamesIn4 = 		root:MP:IO_Data:WaveNamesIn4
//	
//	// Parameters from the LoadDataPanel
//	NVAR	nRepsToLoad = root:MP:nRepsToLoad
//	NVAR	LoadData_Suff1Start = root:MP:LoadData_Suff1Start
//	NVAR	LoadData_Suff2Start = root:MP:LoadData_Suff2Start
//	NVAR	LoadData_Suff3Start = root:MP:LoadData_Suff3Start
//	NVAR	LoadData_Suff4Start = root:MP:LoadData_Suff4Start
//	NVAR	LoadData_Step = root:MP:LoadData_Step
//	WAVE	LoadDataFromThisChannel = root:MP:LoadDataFromThisChannel
//	
//	// Parameters for zooming in
//	NVAR	LD_xStart = root:MP:LD_xStart					// Start of first response (ms)
//	NVAR	LD_xSpacing = root:MP:LD_xSpacing			// Separation of responses (ms)
//	NVAR	LD_nResponses = root:MP:LD_nResponses		// Number of responses to display
//	NVAR	LD_winWidth = root:MP:LD_winWidth			// Window width (ms)
//	NVAR	LD_xPad = root:MP:LD_xPad						// Padding before response (ms)
//	NVAR	LD_RespWin = root:MP:LD_RespWin				// Response window (ms)
//	NVAR	LD_latency = root:MP:LD_latency				// Latency to peak (ms)
//	NVAR	LD_pulseFreq = root:MP:LD_pulseFreq			// Pulse frequency (Hz)
//	NVAR	LD_nPulses = root:MP:LD_nPulses				// Number of pulse
//
//	Variable	nDigs = 4					// Number of digits in the suffix number appended at the end of the waves
//
//	ControlInfo/W=MultiPatch_LoadWavesPanel plotMeanTraceCheck
//	Variable	plotMeanTrace = V_Value
//
//	Variable	i,j,k
//	String	Name
//	Variable	nChannelsSelected = 0
//	
//	Print "--- Loading previously acquired waves ---"
//	Print "\tTime: "+Time()
//	i = 0
//	do
//		if (LoadDataFromThisChannel[i])
//			nChannelsSelected += 1
//			Print "Loading from channel "+num2str(i+1)+"."
//			printf "\tLoading waves: "
//			SVAR	baseName = $("root:MP:IO_Data:WaveNamesIn"+num2str(i+1))
//			NVAR	suffix = $("root:MP:LoadData_Suff"+num2str(i+1)+"Start")
//			j = 0
//			do
//				Name = baseName+JS_num2digstr(nDigs,j*LoadData_Step+suffix)
//				Printf Name
//				LoadWave/Q/P=home/O Name
//				if (V_flag==0)
//					Printf " (fail), "
//				else
//					if (j+1<nRepsToLoad)
//						Printf ", "
//					else
//						print "\r"
//					endif
//				endif
//				j += 1
//			while(j<nRepsToLoad)
//		endif
//		i += 1
//	while(i<4)
//	//print nChannelsSelected
//	
//	// Make the graphs
//	NVAR	ScSc = root:MP:ScSc
//	Variable	WinX = 300+290
//	Variable	WinY = 45
//	Variable	WinWidth = 360
//	Variable	Skip = 24
//	Variable	TotHeight = 120*4+Skip*4
//	
//	Variable	WinHeight = TotHeight/nChannelsSelected-Skip			// Scale graph height according to number of channels selected
//	Variable	MaxHeight = 250
//	if (WinHeight>MaxHeight)
//		WinHeight = MaxHeight
//	endif
//	Variable	currWinY = WinY
//	
//	MP_LoadData_CloseProc("")
//
//	Make/O		colWaveR = {59136,26880,65280,00000, 65535,00000,29952,36873}
//	Make/O		colWaveG = {54784,43776,29952,65535, 00000,00000,29952,14755}
//	Make/O		colWaveB = {01280,64512,65280,00000, 00000,00000,29952,58982}
//	
//	Variable		theFirst = 1
//
//	i = 0
//	do
//		if (LoadDataFromThisChannel[i])
//			theFirst = 1
//			Print "Making graph for channel "+num2str(i+1)+"."
//			DoWindow/K $("LoadDataGr_"+num2str(i+1))
//			Display /W=(WinX,currWinY,WinX+WinWidth,currWinY+WinHeight) as "Channel #"+num2str(i+1)
//			DoWindow/C $("LoadDataGr_"+num2str(i+1))
//			Button ClosePlotsButton,pos={0,0},size={18,18},proc=MP_LoadData_CloseProc,title="X",font="Arial",fsize=12,fstyle=1
//			SVAR	baseName = $("root:MP:IO_Data:WaveNamesIn"+num2str(i+1))
//			NVAR	suffix = $("root:MP:LoadData_Suff"+num2str(i+1)+"Start")
//			j = 0
//			do
//				Name = baseName+JS_num2digstr(nDigs,j*LoadData_Step+suffix)
//				if (Exists(Name)==1)
//					AppendToGraph/W=$("LoadDataGr_"+num2str(i+1)) $Name
//					ModifyGraph/W=$("LoadDataGr_"+num2str(i+1)) rgb($Name)=(colWaveR[i],colWaveG[i],colWaveB[i])
//					if (theFirst)
//						Duplicate/O $Name,$("avgWave_"+num2str(i+1))
//						WAVE	avgWave = $("avgWave_"+num2str(i+1))
//						theFirst = 0
//					else
//						WAVE	sourceWave = $Name
//						avgWave += sourceWave
//					endif
//				endif
//				j += 1
//			while(j<nRepsToLoad)
//			avgWave /= nRepsToLoad
//			if (plotMeanTrace)
//				AppendToGraph/W=$("LoadDataGr_"+num2str(i+1)) $("avgWave_"+num2str(i+1))
//				ModifyGraph/W=$("LoadDataGr_"+num2str(i+1)) rgb($("avgWave_"+num2str(i+1)))=(0,0,0)
//			endif
//			currWinY += WinHeight+Skip
//		endif
//		i += 1
//	while(i<4)
//	
//	if (zoomIn)
//		Variable	respAmp = 0
//		Variable	pVal
//		Variable	checkVal
//		String/G	LD_GraphList = ""
//		Variable yCenter
//		Variable yRange
//		Variable yZoomOut
//		Variable yNewRange
//		Variable yMax
//		Variable	yMin
//		i = 0
//		do
//			if (LoadDataFromThisChannel[i])
//				pauseUpdate
//				Make/O/N=(LD_nResponses) $("LD_responseWave"+num2str(i+1))
//				WAVE LD_responseWave = $("LD_responseWave"+num2str(i+1))
//				Print "Zooming in for channel "+num2str(i+1)+"."
//				k = 0
//				do
//					DoWindow/K $("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))
//					Display as "Ch"+num2str(i+1)+", R"+num2str(k+1)
//					DoWindow/C $("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))
//					LD_GraphList += "LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)+";"
//					Button ClosePlotsButton,pos={0,0},size={17,17},proc=MP_LoadData_CloseProc,title="X",font="Arial",fsize=10,fstyle=1
//					SVAR	baseName = $("root:MP:IO_Data:WaveNamesIn"+num2str(i+1))
//					NVAR	suffix = $("root:MP:LoadData_Suff"+num2str(i+1)+"Start")
//					Make/O/N=(0) workWave,workWave2
//					j = 0
//					do
//						Name = baseName+JS_num2digstr(nDigs,j*LoadData_Step+suffix)
//						if (Exists(Name)==1)
//							AppendToGraph/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) $Name
//							ModifyGraph/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) rgb($Name)=(colWaveR[i],colWaveG[i],colWaveB[i]),lsize($Name)=0.1
//							WAVE	w = $Name
//							respAmp = Mean(w,(LD_xStart+LD_xSpacing*k+LD_latency)*1e-3,(LD_xStart+LD_xSpacing*k+LD_latency+LD_RespWin)*1e-3) - Mean(w,(LD_xStart+LD_xSpacing*k-LD_RespWin)*1e-3,(LD_xStart+LD_xSpacing*k)*1e-3)
//							workWave[numpnts(workWave)] = {respAmp}
//						endif
//						j += 1
//					while(j<nRepsToLoad)
//					pVal = JT_oneSampleTTest(workWave,0)
//					checkVal = pVal < 0.05
//					LD_responseWave[k] = checkVal
//					CheckBox $("hasResponseCheck")+num2str(i+1)+JT_num2digstr(4,k+1) pos={1,16},size={16,19},title=" ",proc=LD_RespWinCheckProc,value=checkVal,font="Arial",fSize=12
//					Button JT_WinResizeButton,pos={1,32},size={17,17},proc=JT_WinResizeProc,title="R",fSize=10,font="Arial",fsize=10,fstyle=1
//					Button PlotsToBackButton,pos={1,48},size={17,17},proc=MP_LoadData_ToBackProc,title="B",font="Arial",fsize=10,fstyle=1
//					if (plotMeanTrace)
//						AppendToGraph/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) $("avgWave_"+num2str(i+1))
//						ModifyGraph/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) rgb($("avgWave_"+num2str(i+1)))=(0,0,0),lsize($("avgWave_"+num2str(i+1)))=2
//					endif
//					ModifyGraph/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) margin(top) = 2, margin(right) = 10, margin(left) = 18, margin(bottom) = 12
//					ModifyGraph/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) font="Arial",fSize=7, tick=2,  standoff=0, nticks(left)=3, tkLblRot(left)=90
//					Label/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) left "\\u#2"
//					Label/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) bottom "\\u#2"
//					// Calculate y-axis range
//					if (plotMeanTrace)
//						WAVE	meanTrace = $("avgWave_"+num2str(i+1))
//						WaveStats/Q/R=((LD_xStart+LD_xSpacing*k-LD_xPad)*1e-3,(LD_xStart+LD_xSpacing*k+LD_winWidth-LD_xPad)*1e-3) meanTrace
//						yCenter = (V_min+V_max)/2
//						yRange = V_max-V_min
//						yZoomOut = 1.6
//						yNewRange = yRange*yZoomOut
//						yMax = yCenter+yNewRange/2
//						yMin = yCenter-yNewRange/2
//						SetAxis/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) left,yMin,yMax
//					else
//						SetAxis/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))/A=2 left
//					endif
//					SetAxis/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1)) Bottom,(LD_xStart+LD_xSpacing*k-LD_xPad)*1e-3,(LD_xStart+LD_xSpacing*k+LD_winWidth-LD_xPad)*1e-3
//					MP_AlignBaseline(2,"left",(LD_xStart+LD_xSpacing*k-LD_RespWin)*1e-3,(LD_xStart+LD_xSpacing*k)*1e-3)
//					Cursor/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))/K A
//					Cursor/W=$("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))/K B
//					LD_DrawBars(k+1,checkVal)
//					k += 1
//				while(k<LD_nResponses)
//				resumeUpdate
//			endif
//			i += 1
//		while(i<4)
//		Variable LD_nGraphs = LD_nResponses*sum(LoadDataFromThisChannel)
//		Variable	LD_nGraphCols = 5
//		Variable	LD_nGraphRows = LD_nGraphCols-1
//		if (LD_nGraphs>LD_nGraphRows*LD_nGraphCols)
//			do
//				if (LD_nGraphRows<LD_nGraphCols)
//					LD_nGraphRows += 1
//				else
//					LD_nGraphCols += 1
//				endif
//			while (LD_nGraphs>LD_nGraphRows*LD_nGraphCols)
//		endif
//		JT_ArrangeGraphs2(LD_GraphList,LD_nGraphRows,LD_nGraphCols)
//	endif
//
//	Print "--- Done ---"
//
//End
//
//
////////////////////////////////////////////////////////////////////////////////////
////// Response window checkbox proc
//
//Function LD_RespWinCheckProc(ctrlName,checked) : CheckBoxControl
//	String	ctrlName
//	Variable	checked
//	
//	Variable	winNumber = str2num(ctrlName[strLen(ctrlName)-4,strLen(ctrlName)-1])
//	Variable channel = str2num(ctrlName[strLen(ctrlName)-5,strLen(ctrlName)-5])
//
//	WAVE LD_responseWave = $("LD_responseWave")+num2str(channel)
//	LD_responseWave[winNumber-1]=checked
//
//	LD_DrawBars(winNumber,checked)
//
//End
//
//
////////////////////////////////////////////////////////////////////////////////////
////// Plot bars indicating position of response windows
//
//Function LD_DrawBars(responseNumber,checkVal)
//	Variable	responseNumber
//	Variable	checkVal
//
//	// Parameters for zooming in
//	NVAR	LD_xStart = root:MP:LD_xStart					// Start of first response (ms)
//	NVAR	LD_xSpacing = root:MP:LD_xSpacing			// Separation of responses (ms)
//	NVAR	LD_nResponses = root:MP:LD_nResponses		// Number of responses to display
//	NVAR	LD_winWidth = root:MP:LD_winWidth			// Window width (ms)
//	NVAR	LD_xPad = root:MP:LD_xPad						// Padding before response (ms)
//	NVAR	LD_RespWin = root:MP:LD_RespWin				// Response window (ms)
//	NVAR	LD_latency = root:MP:LD_latency				// Latency to peak (ms)
//
//	NVAR	LD_pulseFreq = root:MP:LD_pulseFreq			// Pulse frequency (Hz)
//	NVAR	LD_nPulses = root:MP:LD_nPulses				// Number of pulse
//
//	SetDrawLayer/K UserBack
//	SetDrawLayer UserBack
//	// Baseline window
//	SetDrawEnv xcoord= bottom,dash= 1,fillfgc= (56797,56797,56797),linethick= 0.00
//	if (checkVal)
//		SetDrawEnv fillfgc=(0,0,0)
//	endif
//	DrawRect (LD_xStart+LD_xSpacing*(responseNumber-1)-LD_RespWin)*1e-3,0,(LD_xStart+LD_xSpacing*(responseNumber-1))*1e-3,1
//	// Peak window
//	SetDrawEnv xcoord= bottom,dash= 1,fillfgc= (56797,56797,56797),linethick= 0.00
//	if (checkVal)
//		SetDrawEnv fillfgc=(0,0,0)
//	endif
//	DrawRect (LD_xStart+LD_xSpacing*(responseNumber-1)+LD_latency)*1e-3,0,(LD_xStart+LD_xSpacing*(responseNumber-1)+LD_latency+LD_RespWin)*1e-3,1
//	
//	// Tag second peak, if there is one
//	if (LD_nPulses>1)
//		// Baseline window
//		SetDrawEnv xcoord= bottom,dash= 1,fillfgc= (56797,56797,56797),linethick= 0.00
//		if (checkVal)
//			SetDrawEnv fillfgc=(0,0,0)
//		endif
//		DrawRect 1/LD_pulseFreq+(LD_xStart+LD_xSpacing*(responseNumber-1)-LD_RespWin)*1e-3,0,1/LD_pulseFreq+(LD_xStart+LD_xSpacing*(responseNumber-1))*1e-3,1
//		// Peak window
//		SetDrawEnv xcoord= bottom,dash= 1,fillfgc= (56797,56797,56797),linethick= 0.00
//		if (checkVal)
//			SetDrawEnv fillfgc=(0,0,0)
//		endif
//		DrawRect 1/LD_pulseFreq+(LD_xStart+LD_xSpacing*(responseNumber-1)+LD_latency)*1e-3,0,1/LD_pulseFreq+(LD_xStart+LD_xSpacing*(responseNumber-1)+LD_latency+LD_RespWin)*1e-3,1
//	endif
//	
//	if (checkVal)
//		ModifyGraph mirror=2,axThick=2,axRGB=(65535,0,0)
//	else
//		ModifyGraph mirror=0,axThick=1,axRGB=(0,0,0)
//	endif
//
//End
//
////////////////////////////////////////////////////////////////////////////////////
////// Align all sweeps in top graph to baseline
//
//Function MP_AlignBaseline(mode,AxisStr,x1,x2)
//	Variable	mode
//	String	AxisStr
//	Variable	x1
//	Variable	x2
//
//	String		ListOfWaves = TraceNameList("",";",1)
//	Variable		nItems = ItemsInList(ListOfWaves)
//	String		CurrWave
//	
//	Variable	i
//	Variable	theMean
//	Variable	MeanOfMeans = 0
//	Variable	nItemsAveraged = 0
//	
//	if (mode==2)
//		i = 0
//		do
//			CurrWave = StringFromList(i,ListOfWaves)
//			if (StringMatch(WhichYAxis(currWave),AxisStr))
//				WAVE	w = $CurrWave
//				MeanOfMeans += Mean(w,x1,x2)
//				nItemsAveraged += 1
//			endif
//			i += 1
//		while (i<nItems)
//		MeanOfMeans /= nItemsAveraged
//	endif
//
//	i = 0
//	do
//		CurrWave = StringFromList(i,ListOfWaves)
//		if (StringMatch(WhichYAxis(currWave),AxisStr))
//			WAVE	w = $CurrWave
//			theMean = Mean(w,x1,x2)
//			ModifyGraph offset($CurrWave)={0,MeanOfMeans-theMean}
//		endif
//		i += 1
//	while (i<nItems)
//
//End
//
////////////////////////////////////////////////////////////////////////////////////
////// Move LoadData Plots to Back
//
//Function MP_LoadData_ToFrontProc(ctrlName) : ButtonControl
//	String		ctrlName
//
//	NVAR	LD_nResponses = root:MP:LD_nResponses		// Number of responses to display
//
//	DoWindow/F LoadDataGr_1
//	DoWindow/F LoadDataGr_2
//	DoWindow/F LoadDataGr_3
//	DoWindow/F LoadDataGr_4
//
//	Variable i,k
//
//	i = 0
//	do
//		k = 0
//		do
//			DoWindow/F $("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))
//			k += 1
//		while(k<LD_nResponses)	
//		i += 1
//	while(i<4)
//
//End
//
////////////////////////////////////////////////////////////////////////////////////
////// Move LoadData Plots to Back
//
//Function MP_LoadData_ToBackProc(ctrlName) : ButtonControl
//	String		ctrlName
//
//	NVAR	LD_nResponses = root:MP:LD_nResponses		// Number of responses to display
//
//	DoWindow/B LoadDataGr_1
//	DoWindow/B LoadDataGr_2
//	DoWindow/B LoadDataGr_3
//	DoWindow/B LoadDataGr_4
//
//	Variable i,k
//
//	i = 0
//	do
//		k = 0
//		do
//			DoWindow/B $("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))
//			k += 1
//		while(k<LD_nResponses)	
//		i += 1
//	while(i<4)
//
//End
//
////////////////////////////////////////////////////////////////////////////////////
////// Close LoadData Plots
//
//Function MP_LoadData_CloseProc(ctrlName) : ButtonControl
//	String		ctrlName
//
//	NVAR	LD_nResponses = root:MP:LD_nResponses		// Number of responses to display
//
//	DoWindow/K LoadDataGr_1
//	DoWindow/K LoadDataGr_2
//	DoWindow/K LoadDataGr_3
//	DoWindow/K LoadDataGr_4
//
//	Variable i,k
//
//	i = 0
//	do
//		k = 0
//		do
//			DoWindow/K $("LD_ZoomGr_"+num2str(i+1)+"_"+num2str(k+1))
//			k += 1
//		while(k<LD_nResponses)	
//		i += 1
//	while(i<4)
//
//End
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////// Close the panel
//
//Function MP_LoadDataClosePanelProc(ctrlName) : ButtonControl
//	String ctrlName
//	
//	DoWindow/K MultiPatch_LoadWavesPanel
//	MP_LoadData_CloseProc("")
//
//End
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////// Read checkboxes from MultiPatch_LoadWavesPanel and save state
//
//Function MP_ToggleLoadFromProc(ctrlName,checked) : CheckBoxControl
//	String	ctrlName
//	Variable	checked
//
//	WAVE		LoadDataFromThisChannel = root:MP:LoadDataFromThisChannel
//	NVAR		MP_AtLeastOneLoad = root:MP:MP_AtLeastOneLoad
//	
//	Variable		index = str2num(ctrlName[8,8])-1
//	
//	LoadDataFromThisChannel[index] = checked
//	MP_AtLeastOneLoad = 0
//	Variable	i = 0
//	do	
//		if (LoadDataFromThisChannel[i])
//			MP_AtLeastOneLoad = 1
//		endif
//		i += 1
//	while(i<4)
//	if (MP_AtLeastOneLoad==0)
//		LoadDataFromThisChannel[index] = 1
//		CheckBox $("LoadFrom"+num2str(index+1)+"Check") value = 1
//		Print "Leave at least one channel checked!"
//	endif
//
//End

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// MultiMake 3 Ñ routines for Alanna's PCPC paper, to simplify the Calcium imaging of boutons
//// These simple routines operate on the WaveCreator panel

Function ST_MultiMakePanel3Proc(ctrlName) : ButtonControl
	String		ctrlName
	
	MM3_Init_MM3()
	
End

Function MM3_Init_MM3()

	if (exists("MM3_WaveDur"))								// Make sure not to overwrite previously defined settings
		Print "Not setting up MM3 variables -- they already exist..."
	else
		Print "Setting up MM3 variables"
		Variable/G	MM3_WaveDur = 2400
		Variable/G	MM3_Hyp_dur = 1300
		Variable/G	MM3_Hyp_start = 0
	
		Variable/G	MM3_AP_start = 1180
		Variable/G	MM3_AP_dur = 5
	
		Variable/G	MM3_Channel = 1
	
		Variable/G	MM3_AP_freq = 50
		Variable/G	MM3_AP_n = 5
	
		String/G	MM3_Suffix_Control = "_ST_1"
		Variable/G	MM3_i_AP_Control = 0.5
	
		String/G	MM3_Suffix_Hyp = "_ST_2"
		Variable/G	MM3_i_AP_Hyp = 1
		Variable/G	MM3_i_Hyp = -0.4
		
		Variable/G	MM3_multiN = 5
	endif
	
	MM3_Make_MM3_Panel()									// Always redraw panel, though

End

Function MM3_Make_MM3_Panel()

	NVAR		ScSc = root:MP:ScSc

	Variable	WinX = 450
	Variable	WinY = 45
	Variable	WinWidth = 360
	Variable	WinHeight = 126+22*5

	DoWindow/K MM3_Panel
	NewPanel /W=(WinX*ScSc,WinY*ScSc,WinX*ScSc+WinWidth,WinY*ScSc+WinHeight) as "MM3 - APs & Hyperpol"
	DoWindow/C MM3_Panel
	ModifyPanel/W=MM3_Panel fixedSize=1
	DoUpdate

	SetDrawLayer UserBack
	SetDrawEnv linethick= 2,fillbgc= (1,1,1),fillfgc= (65535/2,65535/10,65535/2)//,fillfgc= (65535/2,65535/2,65535/2)
	DrawRect 4,2,WinWidth-4,36
	SetDrawEnv fsize= 18,fstyle= 1,textrgb= (65535,65535,65535)
	SetDrawEnv textxjust= 1
	DrawText WinWidth/2,29,"MultiMake 3"

	Variable YShift = 40

	Button MakeButton,pos={4,YShift+22*0},size={WinWidth/2-8,18},proc=MM3_MakeProc,title="--- Make ---",fColor=(0,65535,0)
	Button CloseButton,pos={4+WinWidth/2,YShift+22*0},size={WinWidth/2-8,18},proc=MM3_KillMM3_Panel,title="--- Close ---",fColor=(65535,0,0)

	SetVariable ChannelSetVar,pos={4+WinWidth/2*0,YShift+22*1},size={WinWidth/2-8,20},title="Channel:"
	SetVariable ChannelSetVar,limits={1,4,1},value=MM3_Channel
	SetVariable WaveDurSetVar,pos={4+WinWidth/2*1,YShift+22*1},size={WinWidth/2-8,20},title="Wave duration [ms]:"
	SetVariable WaveDurSetVar,limits={800,Inf,100},value=MM3_WaveDur

	SetVariable Hyp_startSetVar,pos={4+WinWidth/2*0,YShift+22*2},size={WinWidth/2-8,20},title="Hyp, start [ms]:"
	SetVariable Hyp_startSetVar,limits={0,Inf,100},value=MM3_Hyp_start
	SetVariable Hyp_durSetVar,pos={4+WinWidth/2*1,YShift+22*2},size={WinWidth/2-8,20},title="Hyp, duration [ms]: "
	SetVariable Hyp_durSetVar,limits={10,Inf,50},value=MM3_Hyp_dur

	SetVariable AP_startSetVar,pos={4+WinWidth/2*0,YShift+22*3},size={WinWidth/2-8,20},title="AP start [ms]: "
	SetVariable AP_startSetVar,limits={10,Inf,5},value=MM3_AP_start
	SetVariable AP_durSetVar,pos={4+WinWidth/2*1,YShift+22*3},size={WinWidth/2-8,20},title="AP dur [ms]: "
	SetVariable AP_durSetVar,limits={1,Inf,1},value=MM3_AP_dur

	SetVariable AP_freqSetVar,pos={4+WinWidth/2*0,YShift+22*4},size={WinWidth/2-8,20},title="AP freq [Hz]: "
	SetVariable AP_freqSetVar,limits={1,Inf,5},value=MM3_AP_freq
	SetVariable AP_nSetVar,pos={4+WinWidth/2*1,YShift+22*4},size={WinWidth/2-8,20},title="# of APs: "
	SetVariable AP_nSetVar,limits={1,Inf,1},value=MM3_AP_n

	SetVariable Suffix_ControlSetVar,pos={4+WinWidth/2*0,YShift+22*5},size={WinWidth/2-8,20},title="Suffix, Control: "
	SetVariable Suffix_ControlSetVar,value=MM3_Suffix_Control
	SetVariable i_AP_ControlSetVar,pos={4+WinWidth/2*1,YShift+22*5},size={WinWidth/2-8,20},title="AP, current [nA]: "
	SetVariable i_AP_ControlSetVar,limits={0.1,Inf,0.1},value=MM3_i_AP_Control

	SetVariable Suffix_HypSetVar,pos={4+WinWidth/2*0,YShift+22*6},size={WinWidth/2-8,20},title="Suffix, Hyp: "
	SetVariable Suffix_HypSetVar,value=MM3_Suffix_Hyp
	SetVariable i_AP_HypSetVar,pos={4+WinWidth/2*1,YShift+22*6},size={WinWidth/2-8,20},title="AP, current [nA]: "
	SetVariable i_AP_HypSetVar,limits={0.1,Inf,0.1},value=MM3_i_AP_Hyp

	SetVariable i_HypSetVar,pos={4+WinWidth/2*0,YShift+22*7},size={WinWidth/2-8,20},title="Hyp, current [nA]: "
	SetVariable i_HypSetVar,limits={-Inf,Inf,0.02},value=MM3_i_Hyp
	Button ClosePlotsButton,pos={4+WinWidth/2*1,YShift+22*7},size={WinWidth/2-8,18},proc=MM3_KillMM3_Graph,title="Close plots"

	SetVariable MultiSetVar,pos={4+WinWidth/2*0,YShift+22*8},size={WinWidth/2-8,20},title="# of steps in range: "
	SetVariable MultiSetVar,limits={2,Inf,1},value=MM3_multiN
	Button MakeRangeButton,pos={4+WinWidth/2*1,YShift+22*8},size={WinWidth/2-8,18},proc=MM3_MakeRange,title="Make range",fColor=(0,65535,0)

End

Function MM3_KillMM3_Panel(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/K MM3_Panel
	MM3_KillMM3_Graph("")
	
end

Function MM3_KillMM3_Graph(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/K MM3_graph
	
end

Function MM3_MakeProc(ctrlName) : ButtonControl
	String ctrlName
	
	MM3(2)
	
end

Function MM3_MakeRange(ctrlName) : ButtonControl
	String ctrlName

	NVAR	MM3_multiN	

	MM3(MM3_multiN)
	
end


Function MM3(nSteps)
	Variable	nSteps
	
	DoWindow/F MultiPatch_WaveCreator						// This routine operates on the MultiPatch_WaveCreator panel
	if (V_flag==0)
		Print "MultiPatch_WaveCreator is not open!"
		Abort "MultiPatch_WaveCreator is not open!"
	endif
	
	Print "=== MM3 is running ==="
	print Date()
	Print Time()

	NVAR		MM3_WaveDur
	NVAR		MM3_Hyp_dur
	NVAR		MM3_Hyp_start

	NVAR		MM3_AP_start
	NVAR		MM3_AP_dur

	NVAR		MM3_Channel

	NVAR		MM3_AP_freq
	NVAR		MM3_AP_n

	SVAR		MM3_Suffix_Control
	NVAR		MM3_i_AP_Control

	SVAR		MM3_Suffix_Hyp
	NVAR		MM3_i_AP_Hyp
	NVAR		MM3_i_Hyp
	
//	NVAR		MM3_multiN
	
	Variable	i
	Variable	AP_amp_step = (MM3_i_AP_Hyp-MM3_i_AP_Control)/(nSteps-1)
	Variable	Hyp_amp_step = (MM3_i_Hyp-0)/(nSteps-1)
	Variable	curr_AP_amp
	Variable	curr_Hyp_amp
	
	String		SuffixBase = MM3_Suffix_Control[0,StrLen(MM3_Suffix_Control)-2]
	String		currSuffix
	String		listOfWaves = ""

// Also set:
// ======
// Use & Add checkboxes

	SVAR		CurrWaveNameOut = root:MP:CurrWaveNameOut
	SVAR		STSuffix =root:MP:IO_Data:STSuffix
	NVAR		TotalDur = root:MP:TotalDur

	NVAR NPulses = 			root:MP:NPulses				// Number of pulses
	NVAR PulseAmp = 			root:MP:PulseAmp				// Pulse amplitude
	NVAR PulseDur = 			root:MP:PulseDur				// Pulse duration
	NVAR PulseFreq = 			root:MP:PulseFreq				// Pulse frequency
	NVAR PulseDispl = 			root:MP:PulseDispl				// Pulse displacement

	// Basic settings first
	TotalDur = MM3_WaveDur
	WC_ToggleShow("",0)

	// Make the waves
	i = 0
	do
		// Calculate current current values etc
		curr_AP_amp = MM3_i_AP_Control+AP_amp_step*i
		curr_Hyp_amp = 0+Hyp_amp_step*i
		currSuffix = SuffixBase+num2str(i+1)
		// Do the make
		WC_ToggleDest("",MM3_Channel,"")
		WC_ToggleSlot("",1,"")										// Slot 1
		WC_ToggleUseSlot("",1)
		PulseAmp = curr_Hyp_amp
		PulseDur = MM3_Hyp_dur
		PulseFreq = MM3_AP_freq
		NPulses = 1
		PulseDispl = MM3_Hyp_start
		WC_DoUpdateAfterSetVarChange()
		WC_ToggleSlot("",2,"")										// Slot 2
		WC_ToggleUseSlot("",1)
		WC_ToggleAddSlot("",1)
		PulseAmp = curr_AP_amp
		PulseDur = MM3_AP_dur
		PulseFreq = MM3_AP_freq
		NPulses = MM3_AP_n
		PulseDispl = MM3_AP_start
		WC_DoUpdateAfterSetVarChange()
		STSuffix = currSuffix
		CheckBox STCheck,value=1,win=MultiPatch_WaveCreator
		WC_CreateOneWave("")										// Make the wave
		listOfWaves += CurrWaveNameOut+currSuffix+","
		i += 1
	while(i<nSteps)
	
	// Display waves
	DoWindow/K MM3_graph
	JT_ListToGraph(ListOfWaves)
	JT_NameWin("MM3_graph","MM3 output waves for channel "+num2str(MM3_Channel))
	CallColorizeTraces4()
	DoUpdate
	JT_SpreadTracesInGraph()
	SmartYAxisRange()

	// Clean up
	DoWindow/F MultiPatch_WaveCreator
	WC_ToggleSlotOnDisplay()
	NVAR ShowFlag = 			root:MP:ShowFlag
	ShowFlag = 1
	ControlUpdate/A/W=MultiPatch_WaveCreator
	DoWindow/F MM3_graph
	
	Print "These waves were created:"
	Print ListOfWaves[0,StrLen(ListOfWaves)-2]
	
	Print "=== MM3 is done ==="

End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set up SpTm2Wave

Function SpTm2WavesSetupProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SpTm2WavesSetup()
			break
	endswitch

	return 0
End

Function SpTm2WavesSetup()

	Print "Setting up SpTm2Waves at "+Time()+"."
	JT_GlobalVariable("SpTm_wDur",30,"",0)					// Wave duration [s]
	JT_GlobalVariable("SpTm_Suffix",1,"",0)					// Suffix [s]
	Print " "		// JT_GlobalVariable uses printf

	String/G	SpTmWaveList = "SpikeTimes_1;SpikeTimes_2;SpikeTimes_3;SpikeTimes_4;"
	DoWindow/K	SpTmTable
	Edit	/W=(520,64,938,556) as "Spike time table"
	DoWindow/C	SpTmTable
	Variable	n = ItemsInList(SpTmWaveList)
	String		currStr
	Variable	i
	i = 0
	do
		currStr = StringFromList(i,SpTmWaveList)
		if (!(Exists(currStr)))
			Make/O/N=(0) $(currStr)
		endif
		AppendToTable $(currStr)
		i += 1
	while(i<n)

	Create_SpTm2WavesPanel()
	AutoPositionWindow/M=0/R=SpTm2WavesPanel SpTmTable
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create SpTm2Wave Panel

Function Create_SpTm2WavesPanel()
	
	Variable		ScSc = 72/ScreenResolution

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 420
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow SpTm2WavesPanel
	if (V_flag)
		GetWindow SpTm2WavesPanel, wsize
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

	DoWindow/K SpTm2WavesPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Spike times to waves"
	DoWindow/C SpTm2WavesPanel
	ModifyPanel/W=SpTm2WavesPanel fixedSize=1
	
	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable wDurSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Duration [s]: ",value=SpTm_wDur,limits={5,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable SuffixSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Suffix: ",value=SpTm_Suffix,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	Button ReInitButton,pos={x,y},size={xSkip-4,bHeight},proc=SpTm2WavesSetupProc,title="Re-initialize",fsize=fontSize,font="Arial"	
	x += xSkip
	Button RunButton,pos={x,y},size={xSkip-4,bHeight},proc=RunSpTm2WavesProc,title="Run",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button Graphs2FrontButton,pos={x,y},size={xSkip-4,bHeight},proc=SpTm2Wave_2FrontProc,title="Move to front",fsize=fontSize,font="Arial"	
	x += xSkip
	Button KillGraphsButton,pos={x,y},size={xSkip-4,bHeight},proc=SpTm2Wave_KillGraphsProc,title="Kill graphs & table",fsize=fontSize,font="Arial"	
	x += xSkip
	Button CloseAllButton,pos={x,y},size={xSkip-4,bHeight},proc=SpTm2WaveCloseAllProc,title="Close everything",fsize=fontSize,font="Arial"	,fColor=(65535,0,0)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button GoSTCreatorButton,pos={x,y},size={xSkip-4,bHeight},proc=ST_GoToSpikeTimingCreator,title="Go to ST Creator",fsize=fontSize,font="Arial"	
	x += xSkip
	Button GoSwitchboardButton,pos={x,y},size={xSkip-4,bHeight},proc=GoToSwitchboard,title="Go to Switchboard",fsize=fontSize,font="Arial"	
	x += xSkip
	Button GoPatternMakerButton,pos={x,y},size={xSkip-4,bHeight},proc=GoToPatternMaker,title="Go to PatternMaker",fsize=fontSize,font="Arial"	
	x += xSkip
	y += ySkip

	MoveWindow/W=SpTm2WavesPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...
	DoWindow/F SpTm2WavesPanel

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Close SpTm2Wave completely

Function SpTm2WaveCloseAllProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/K SpTm2WavesPanel
			DoWindow/K SpTmTable
			DoWindow/K SpTm2WavesGraph
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move SpTm2Wave to front

Function SpTm2Wave_2FrontProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/F SpTmTable
			DoWindow/F SpTm2WavesGraph
			DoWindow/F SpTm2WavesPanel
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move SpTm2Wave to front

Function SpTm2Wave_KillGraphsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/K SpTmTable
			DoWindow/K SpTm2WavesGraph
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Run SpTm2Wave

Function RunSpTm2WavesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			RunSpTm2Waves()
			break
	endswitch

	return 0
End

Function RunSpTm2Waves()

	SVAR		SpTmWaveList
	NVAR		SpTm_wDur
	NVAR		SpTm_Suffix
	
	String		theWaveName

	//// INDUCTION
	NVAR	Ind_Freq = 			root:MP:ST_Data:Ind_Freq			// The frequency of the spike timing during the induction [Hz]
	NVAR	Ind_NPulses = 		root:MP:ST_Data:Ind_NPulses		// The number of pulses for the same waves
	NVAR	Ind_AmplitudeIClamp = 	root:MP:ST_Data:Ind_AmplitudeIClamp	// The pulse amplitude for induction current clamp pulses [nA]
	NVAR	Ind_DurationIClamp = 	root:MP:ST_Data:Ind_DurationIClamp	// The pulse duration for induction current clamp pulses [ms]

	//// GENERAL
	NVAR	ST_RedPerc1 =		root:MP:ST_Data:ST_RedPerc1		// Scale current injection by this percentage for channel 1
	NVAR	ST_RedPerc2 =		root:MP:ST_Data:ST_RedPerc2		// Scale current injection by this percentage for channel 2
	NVAR	ST_RedPerc3 =		root:MP:ST_Data:ST_RedPerc3		// Scale current injection by this percentage for channel 3
	NVAR	ST_RedPerc4 =		root:MP:ST_Data:ST_RedPerc4		// Scale current injection by this percentage for channel 4

	NVAR	ST_SealTestAtEnd =		root:MP:ST_Data:ST_SealTestAtEnd		// Put the sealtest at the end of the wave instead of at the beginning

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves

	WAVE	ST_Extracellular =	root:MP:ST_Data:ST_Extracellular	// Is this channel an extracellular channel?
	NVAR	ST_StimDur =		root:MP:ST_Data:ST_StimDur			// Extrac stim pulse duration [samples]
	NVAR	ST_Voltage = 		root:MP:ST_Data:ST_Voltage			// The voltage amplitude for _all_ (extracellular) pulses [V]
	NVAR	ST_Biphasic = 		root:MP:ST_Data:ST_Biphasic		// Is extracellular wave biphasic?

	//// PARAMETERS FROM WAVECREATOR	
	NVAR	SampleFreq =		root:MP:SampleFreq					// Sampling frequency [Hz]

	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	NVAR	SealTestAmp_I =	root:MP:SealTestAmp_I
	NVAR	SealTestAmp_V =	root:MP:SealTestAmp_V

	//// CELL NUMBERS
	NVAR	Cell_1 =			root:MP:IO_Data:Cell_1
	NVAR	Cell_2 =			root:MP:IO_Data:Cell_2
	NVAR	Cell_3 =			root:MP:IO_Data:Cell_3
	NVAR	Cell_4 =			root:MP:IO_Data:Cell_4

	// Test pulse HAS to be at the end, so update ST Creator and WaveCreator accordingly, since Pattern Maker uses this checkbox to figure out where the test pulse is
	NVAR		ST_SealTestAtEnd =		root:MP:ST_Data:ST_SealTestAtEnd
	ST_SealTestAtEnd = 1
	WCST_ToggleSealTestAtEndProc("",ST_SealTestAtEnd)

	Make/O/N=(4) CellNumbers
	CellNumbers = {Cell_1,Cell_2,Cell_3,Cell_4}

	Make/O/N=(4) ST_RedPercWave
	ST_RedPercWave = {ST_RedPerc1,ST_RedPerc2,ST_RedPerc3,ST_RedPerc4}

	Variable	totWDur = SpTm_wDur*1e3+SealTestDur+SealTestPad1+SealTestPad2		// Output wave duration [ms]
	
	Print "--- Converting spike times to output waves  ---"
	Print " ",Date(),Time()
	
	
	Variable		i,j
	Variable		n = ItemsInList(SpTmWaveList)
	String		currStr
	
	Variable		currSpTm
	Variable		nSpikes = NaN
	Variable		SpikesOutsideWDur = 0
	i = 0					// Channel counter
	do
		currStr = StringFromList(i,SpTmWaveList,";")
		WAVE	w = $currStr
		Duplicate/O $(currStr),$(currStr+"_"+JT_num2digstr(4,SpTm_Suffix))
		if (JT_waveHasNaNs(w))
			print "\tWARNING! Found NaNs in \""+currStr+"\", which are now being removed."
			JT_RemoveNaNs(w)
		endif
		nSpikes = numpnts(w)
		Print "Working on spike-time wave \""+currStr+"\", which has "+num2str(nSpikes)+" spikes."
		theWaveName = ST_BaseName+num2str(i+1)+ST_Suffix
		Print "\tOutput wave is\""+theWaveName+"\".\r\tThis is for Cell #"+num2str(CellNumbers[i])+"."
		ProduceWave(theWaveName,SampleFreq,totWDur)
		if (!(ST_Extracellular[i]))
			ProducePulses(theWaveName,totWDur-(SealTestDur+SealTestPad1),1,SealTestDur,1,SealTestAmp_I,0,0,0,0)	// Test pulse at end, but not if extrac stim wave
		endif
		if (nSpikes>0)		// There may be zero spikes on this channel, e.g. for presynaptic Poisson stimulation but a postsynaptic non-spiking recording
			j = 0				// Spike counter
			do
				currSpTm = w[j]*1e3
				if ((w[j]>SpTm_wDur) %| (w[j]<0))
					SpikesOutsideWDur = 1
				endif
				// ProducePulses(Name,BeginTrainAt,nPulses,PulseDur,PulseFreq,PulseAmp,DoAdd,Keep,BiExp,Ramp)
				if (ST_Extracellular[i])
					ProducePulses(theWaveName,currSpTm,Ind_NPulses,(ST_StimDur-1)/SampleFreq*1000,Ind_Freq,ST_Voltage*ST_RedPercWave[i]/100,0,0,0,0)
					if (ST_Biphasic)
						ProducePulses(theWaveName,currSpTm+ST_StimDur/SampleFreq*1000,Ind_NPulses,(ST_StimDur-1)/SampleFreq*1000,Ind_Freq,-ST_Voltage*ST_RedPercWave[i]/100,0,0,0,0)
					endif
				else
					ProducePulses(theWaveName,currSpTm,Ind_NPulses,Ind_DurationIClamp,Ind_Freq,Ind_AmplitudeIClamp*ST_RedPercWave[i]/100,0,0,0,0)
				endif
				j += 1
			while(j<nSpikes)
		endif
		ProduceScaledWave(theWaveName,i+1,1)			// Gain-scale the waves, JSj 2016-02-09
		i += 1
	while(i<n)

	// Take notes	
	Notebook Parameter_Log selection={endOfFile, endOfFile}
	Notebook Parameter_Log ruler=Title,textRGB=(0,0,65535), text="Spike Time 2 Wave Panel is producing new waves\r\r",textRGB=(0,0,0)
	Notebook Parameter_Log ruler=Normal, text="\t\tTime: "+Time()+" \r\r"
	Notebook Parameter_Log ruler=Normal, text="\tOutput waves are called "+ ST_BaseName+"X"+ST_Suffix+".\r"
	Notebook Parameter_Log ruler=Normal, text="\tOutput waves are "+num2str(SpTm_wDur+(SealTestDur+SealTestPad1+SealTestPad2)/1e3)+" seconds long.\r"
	Notebook Parameter_Log ruler=Normal, text="\tSpike time source waves are stored away with suffix "+JT_num2digstr(4,SpTm_Suffix)+".\r\r"
	SpTm_Suffix += 1

	SpTm2WavesMakeGraph()
	
	if (SpikesOutsideWDur)
		DoAlert/T="Warning!" 0,"WARNING! Some spikes are outside the wave range!"
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create SpTm2Wave graph

Function SpTm2WavesMakeGraph()

	SVAR	ST_BaseName = 	root:MP:ST_Data:ST_BaseName		// The base name for all waves
	SVAR	ST_Suffix = 		root:MP:ST_Data:ST_Suffix			// The suffix to be added to the spiketiming waves

//	WAVE		Out_1,Out_2,Out_3,Out_4				// POTENTIAL BUG! Hardwired wave names!

	DoWindow/K SpTm2WavesGraph
	Display as "Spike Time Output Waves"
	DoWindow/C SpTm2WavesGraph
	Variable	n = 4
	Variable	i
	i = 0
	do
		AppendToGraph $(ST_BaseName+num2str(i+1)+ST_Suffix)
		i += 1
	while(i<n)
	doUpdate
	JT_SpreadTracesInGraph()
	CallColorizeTraces1()
	JT_ArrangeGraphs2("SpTm2WavesGraph;",2,3)
	JT_AddCloseButton()
	Legend/A=RB
	doWindow SpTm2WavesPanel
	if (V_flag)
		AutoPositionWindow/M=1/R=SpTm2WavesPanel SpTm2WavesGraph
	endif

End

