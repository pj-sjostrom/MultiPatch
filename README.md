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
