The RawDataViewer tool arose from the need to quickly view large files consistent of multiple channels of neuro-physiological data. It should work on systems ≥ Mac OS 10.6.
The data needs to be formatted in a way that the program understands. Currently, this means that the data file needs to have the following structure:

A 90 byte header consisting of the following fields
	the size of the header, encoded as a single unsigned 32 bit integer
	the sampling rate of the signal, encoded as a single 32 bit integer
	the number of recording channels, encoded as a single unsigned 8 bit integer 
the data itself, encoded as 16 bit integers. This needs to ordered by time, i.e. the first timepoint for all channels, followed by the second time points for each channel, etc.
In order words, when after reading in all the data, the resulting matrix would have dimensions of [number of time points] X [number of channels]

Once the data have been organized in this way, the data files can be opened by simple dragging and dropping them onto the Application Icon using Finder. Alternatively, from the command line, you can type the following:

open data.bin -a /Applications/RawDataViewer.app

assuming that your data file is named data.bin and the viewer is located under /Applications. For most data files, it is not feasible to try and load the entire file onto the GPU in one go. There is a setting under Preferences deciding how much data to draw at a time. The default is set at 20 MB, meaning that when you open the file, a data 20 MB data buffer is read from the fie and displayed. To advance to the next 20 MB chunk, press the 'up' key. To display the previous chunk, press the 'down' key.

The interface works as follows:
Zooming is done by left-draggin the mouse around the region of interest. The application mantains a zoom stack, which can be traversed using the 'right' (go down the stack) and 'left' (go up the stack) keys.
To get info for a given data point, left click it while holding down the 'Options' key. This will display the time in milliseconds, the ampltide and the channel number. 
To select a particular channel (useful for tracking a channel across data chunks), left click its trace while holding down the 'Shift' key.




