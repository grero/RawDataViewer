/*
 *  fileReaders.h
 *  RawDataViewer
 *
 *  Created by Roger Herikstad on 24/8/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */
#import <matio.h>
typedef struct {
    int ndim;
    int rows;
    int cols;
} header;

header *readMatlabFeatureHeader(char *fname, header *H, char* varname);
float *readMatlabFeatureData(char *fname,float *data, char* varname);

