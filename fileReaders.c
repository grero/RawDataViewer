/*
 *  fileReaders.c
 *  RawDataViewer
 *
 *  Created by Roger Herikstad on 24/8/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */

#include "fileReaders.h"

header *readMatlabFeatureHeader(char *fname, header *H, char* varname)
{
	matvar_t *matvar;
	mat_t *mat;
	
	//open file
	mat = Mat_Open(fname,MAT_ACC_RDONLY);
	if (mat==NULL) {
		H->ndim=0;
		H->rows=-1;
		H->cols=1;
		return H;
	}
	matvar = Mat_VarReadInfo(mat,varname);
	H->ndim = matvar->rank;
	size_t *dims = matvar->dims;
	//swap these since we want to read in row major order
	H->rows = dims[1];
	H->cols = dims[0];
	Mat_Close(mat);
	return H;
}

float *readMatlabFeatureData(char *fname,float *data, char* varname)
{
	matvar_t *matvar;
	mat_t *mat;
	
	//open file
	mat = Mat_Open(fname,MAT_ACC_RDONLY);
	matvar = Mat_VarReadInfo(mat,varname);
	int err = Mat_VarReadDataAll(mat,matvar);
	int nel = (matvar->nbytes)/(matvar->data_size);
	double *_data = matvar->data;
	int i,j;
	int rows,cols;
	rows = matvar->dims[0];
	cols = matvar->dims[1];
	//copy and transpose
	for(i=0;i<rows;i++)
	{
		for(j=0;j<cols;j++)
		{
			//data[i*cols+j] = (float)_data[j*rows+i];
			data[i*cols+j] = (float)_data[i*cols+j];
			
		}
	}
	Mat_VarFree(matvar);
	Mat_Close(mat);
	return data;
}
