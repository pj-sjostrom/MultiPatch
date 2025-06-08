# MultiPatch
IGOR PRO script for quadruple whole-cell recordings
Create a folder somewhere in your user directory called /Igor Stuff/.
Put all these files in /Igor Stuff/.

You also need "Jesper's tools", which is found here:
https://github.com/pj-sjostrom/qMorph/blob/653053f24b4fd660f12791354bdcaa1a01fcd36f/JespersTools_v03.ipf

To communicate with NI boards, MultiPatch requires the NIDAQ Tools MX XOP. See the WaveMetrics website:
https://www.wavemetrics.com/products/nidaqtools

The NI board you use has to have four inputs and four outputs. Other than that, its properties does not matter much; it can run via PCI, PCIe, or USB, presumably also PXI, although I never tested that.
If do not have the NIDAQ Tools MX XOP installed, the software will run in demo mode.

There is currently no manual for this software.

# Update 7 June 2025: Procedure files used for data analysis were added

- MP_DatAn 20.ipf
- MP_DatAn 20.ipn
- MP_CompileExperiments v28.ipf

MP_DatAn (MultiPatch Data Analysis) is used to analyze individual ephys experiments, e.g., a paired recording of long-term potentiation or depression. The corresponding ipn file provides help for setting up the analysis. Once analysis is done, the data should be exported to a folder named according to the condition at hand, e.g., "LTP" or "control".

Once all individual experiments have been exported with MP_DatAn into the relevant folders, MP_CompileExperiments is used for cross-condition meta analysis. The user indicates to the software where the relevant folders are located (e.g., "LTP" and "control") using the Compile button, top right. For each condition, use Macros > Store condition to save. Once all conditions have been loaded, use Macros > Reanalyze all slots. 

The PDF files 'MP_DatAn_20_loadTraces_V01.pdf' and 'MP_DatAn_20_StdpAnalysis_V02.pdf' provide guidance for how to load files and how to analyze an STDP experiment, respectively, with MP_DatAn.

There is currently no manual for the MP_CompileExperiments software.
