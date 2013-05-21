//
//  fileReader.h
//  RawDataViewer
//
//  Created by Roger Herikstad on 3/4/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#ifndef RawDataViewer_fileReader_h
#define RawDataViewer_fileReader_h



#endif

#include <hdf5.h>
#include <hdf5_hl.h>
#include <matio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int readHMMFromMatfile(const char *fname, float **spikeforms, uint32_t *nspikes, uint32_t *nchs, uint32_t *nstates, float **spikes, uint32_t **cids, uint32_t *nSpikeForms, int16_t **data,uint32_t *npoints,float samplingRate);
int readHMMFromHDF5file(const char *fname, float **spikeforms, uint32_t *nspikes, uint32_t *nchs, uint32_t *nstates, float **spikes, uint32_t **cids, uint32_t *nSpikeForms, int16_t **data, uint32_t *npoints,float samplingRate);
int readDataFromHDF5File(const char *fname, float *data, uint32_t *nchs, uint32_t *npts);
void readNptDataFile(const char *fname, size_t offset, double **data, uint32_t *nchannels, uint64_t *npoints, double *samplingRate );

