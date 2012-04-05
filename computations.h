//
//  computations.h
//  RawDataViewer
//
//  Created by Roger Herikstad on 23/3/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#ifndef RawDataViewer_computations_h
#define RawDataViewer_computations_h



#endif

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include <gsl/gsl_cdf.h>
#include <gsl/gsl_randist.h>
#include "utils.h"

void computeCovariance(int16_t *data, uint32_t nrows, uint32_t ncols, uint8_t rowvar,float *output);
void malanobisDistance(float *data, uint32_t nrows, uint32_t ncols,uint32_t step, float *columnOffsets, float *cinv, float *mu,uint32_t mustep,float *output);

