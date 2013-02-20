The RawDataViewer tool arose from the need to quickly view large files consistent of multiple channels of neuro-physiological data. It should work on systems ≥ Mac OS 10.6.
The data needs to be formatted in a way that the program understands. Currently, this means that the data file needs to have the following structure:

A 90 byte header consisting of the following fields
	the size of the header, encoded as a single unsigned 32 bit integer
	the sampling rate of the signal, encoded as a single 32 bit integer
	the number of recording channels, encoded as a single unsigned 8 bit integer 
the data itself, encoded as 16 bit integers. This needs to ordered by time, i.e. the first timepoint for all channels, followed by the second time points for each channel, etc.
In order words, when after reading in all the data, the resulting matrix would have dimensions of [number of time points] X [number of channels]
