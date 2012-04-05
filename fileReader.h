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

int readHMMFromMatfile(const char *fname, double **spikeforms, uint32_t *nspikes, uint32_t *nchs, uint32_t *nstates, float **spikes, uint32_t **cids);
int readHMMFromHDF5file(const char *fname, double **spikeforms, uint32_t *nspikes, uint32_t *nchs, uint32_t *nstates, float **spikes, uint32_t **cids);

