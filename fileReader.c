//
//  fileReader.c
//  RawDataViewer
//
//  Created by Roger Herikstad on 3/4/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "fileReader.h"


int readHMMFromMatfile(const char *fname, float **spikeforms, uint32_t *nspikes, uint32_t *nchs, uint32_t *nstates, float **spikes, uint32_t **cids, uint32_t *nSpikeForms, int16_t **data, uint32_t *npoints)
{
    uint32_t _npoints,_nchs,_nstates,_nspikes,_ntemps,k;
    double minpt,*mlseq,d;
    int* minpts,i,ch,j;
    matvar_t *mlseqVar,*spikeFormsVar, *dataVar;
	mat_t *mat;
    
    //open file
	mat = Mat_Open(fname,MAT_ACC_RDONLY);
    if( mat == NULL )
    {
        //if we cannot open the file, try using the hdf5 library instead
        return -1;
    }
    //load the sequence
	mlseqVar = Mat_VarRead(mat,"mlseq");
	//int err = Mat_VarReadDataAll(mat,matvar);
	//int nel = (matvar->nbytes)/(matvar->data_size);
    if( mlseqVar == NULL)
    {
        return -1;
    }
	mlseq = mlseqVar->data;
    if(mlseq == NULL)
    {
        return -1;
    }
    _ntemps = mlseqVar->dims[0];
    _npoints = mlseqVar->dims[1];
    spikeFormsVar = Mat_VarRead(mat,"spikeForms");
    if (spikeFormsVar == NULL )
    {
        //sometimes the variable could be named spkform instead
        spikeFormsVar = Mat_VarRead(mat,"spkform");
        
        if( spikeFormsVar == NULL )
        {
            return -1;
        }
    }
    
    if( spikeFormsVar->data== NULL)
    {
        return -1;
    }
    if(spikeFormsVar->data_type == MAT_T_CELL )
    {
        int ncells = spikeFormsVar->dims[1];
        *nSpikeForms = ncells;
        matvar_t *cell;
        i = 0;
        cell = Mat_VarGetCell(spikeFormsVar, i);
        _nstates = cell->dims[1];
        _nchs = cell->dims[0];
        *nchs = _nchs;
        *nstates = _nstates;
        *spikeforms = malloc(_ntemps*_nchs*_nstates*sizeof(float));
        for(i=0;i<ncells;i++)
        {
            cell = Mat_VarGetCell(spikeFormsVar, i);
            for(j=0;j<_nchs;j++)
            {
                for(k=0;k<_nstates;k++)
                {
                    (*spikeforms)[i*_nstates*_nchs + j*_nstates + k] = (float)(((double*)(cell->data))[k*_nchs+j]);
                }
            }
        }
        
    }
    else
    {
        _nstates = spikeFormsVar->dims[2];
        _nchs = spikeFormsVar->dims[1];
        *nchs = _nchs;
        *nstates = _nstates;
        *nSpikeForms = spikeFormsVar->dims[0];
        //figure out what data type spikeForms is
        *spikeforms = malloc(_ntemps*_nchs*_nstates*sizeof(float));
        for(i=0;i<_ntemps;i++)
        {
            for(j=0;j<_nchs;j++)
            {
                for(k=0;k<_nstates;k++)
                {
                    (*spikeforms)[i*_nstates*_nchs + j*_nstates + k] = (float)(((double*)(spikeFormsVar->data))[k*_nchs*_ntemps+j*_ntemps+i]);
                }
            }
        }

    }
    //find the minium point of each template; this will be where the spike was "triggered"

    minpts = malloc(_ntemps*sizeof(int));
    for(i=0;i<_ntemps;i++)
    {
        minpt = INFINITY;
        for(ch=0;ch<_nchs;ch++)
        {
            
            for(j=0;j<_nstates;j++)
            {
                //row order
                d = (*spikeforms)[i*_nchs*_nstates+ch*_nstates + j];
                minpts[i] = (d<minpt) ? j : minpts[i];
                minpt = (d<minpt) ? d : minpt;
            }
        }
    }
    //now loop through the sequence and put spikes where each template reaches its peak state
    //first count the number of spikes
    _nspikes = 0;
    for(j=0;j<_ntemps;j++)
    {
        for(i=0;i<_npoints;i++)
        {
            if(mlseq[i*_ntemps+j] == minpts[j] )
            {
                _nspikes+=1;
            }
        }
    }
    *nspikes = _nspikes;
    //now allocate space for the spikes
    *spikes = malloc(_nspikes*sizeof(float));
    *cids = malloc((*nspikes)*sizeof(uint32_t));

    k = 0;
    for(i=0;i<_npoints;i++)
    {
        for(j=0;j<_ntemps;j++)
        {
            if(mlseq[i*_ntemps+j] == minpts[j] )
            {
                (*spikes)[k] = ((float)i)/29.990;
                (*cids)[k] = j;
                k+=1;
            }
        }
    }
    free(minpts);
    //check if there was a data variable as well
    dataVar = Mat_VarRead(mat,"data");
    if(dataVar != NULL )
    {
        //data should have dimensions of _nchs X _npoints
        int npts = dataVar->dims[1];
        *npoints = npts;
        *data = malloc(npts*_nchs*sizeof(int16_t));
        for(i=0;i<npts;i++)
        {
            for(j=0;j<_nchs;j++)
            {
                //column order
                (*data)[i*_nchs+j] = (int16_t)(((double*)dataVar->data)[i*_nchs+j]);
            }
        }
    }
    else
    {
        *data = NULL;
    }
    Mat_VarFree(mlseqVar);
    Mat_VarFree(spikeFormsVar);
	Mat_Close(mat);

    return 0;

}

int readHMMFromHDF5file(const char *fname, float **spikeforms, uint32_t *nspikes, uint32_t *nchs, uint32_t *nstates, float **spikes, uint32_t **cids, uint32_t *nSpikeForms, int16_t **data,uint32_t *npoints)
{
    hid_t file_id;
    herr_t status;
    hsize_t spikeFormDims[3],mlseqDims[2];
    int *mlseq,*minpts;
    double minpt,d,*_spikeforms;
    uint32_t _ntemps,_nchs,_timepts,_npoints,i,j,k,ch;
    
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
    status = H5LTget_dataset_info(file_id,"/spikeForms",spikeFormDims,NULL,NULL);
    if(status != 0 )
    {
        status = H5LTget_dataset_info(file_id,"/spkform",spikeFormDims,NULL,NULL);
        if (status !=0)
        {
            return status;
        }
    }
    //allocate space for spikeforms
    _spikeforms = malloc(spikeFormDims[0]*spikeFormDims[1]*spikeFormDims[2]*sizeof(double));
    *spikeforms = malloc(spikeFormDims[0]*spikeFormDims[1]*spikeFormDims[2]*sizeof(float));

    //read the data set
    status = H5LTread_dataset_double(file_id,"/spikeForms",_spikeforms);
    if(status != 0 )
    {
        status = H5LTread_dataset_double(file_id,"/spkform",_spikeforms);
        if(status != 0 )
        {
            return status;
        }
    }
    *nchs = spikeFormDims[1];
    *nstates = spikeFormDims[2];
    _timepts = spikeFormDims[2];
    _nchs = spikeFormDims[1];
    *nSpikeForms = spikeFormDims[0];
    //convert from double to float
    for(i=0;i<*nSpikeForms;i++)
    {
        for(j=0;j<_nchs;j++)
        {
            for(k=0;k<_timepts;k++)
            {
                (*spikeforms)[i*_nchs*_timepts+j*_timepts + k] = (float)(_spikeforms[i*_nchs*_timepts+j*_timepts+k]);
            }
        }
    }
    //free the temporary variable
    free(_spikeforms);
    //read the sequence
    status = H5LTget_dataset_info(file_id,"/mlseq",mlseqDims,NULL,NULL);
    if(status != 0 )
    {
        return status;
    }
    //allocate space for the sequence
    mlseq = malloc(mlseqDims[0]*mlseqDims[1]*sizeof(int));
    status = H5LTread_dataset_int(file_id,"/mlseq",mlseq);
    if( status!=0)
    {
        return status;
    }
    _ntemps = mlseqDims[1];
    _npoints = mlseqDims[0];
    
    minpts = malloc(_ntemps*sizeof(int));
    for(i=0;i<_ntemps;i++)
    {
        minpt = INFINITY;
        for(ch=0;ch<_nchs;ch++)
        {
            
            for(j=0;j<_timepts;j++)
            {
                //row order
                d = (*spikeforms)[i*_timepts*_nchs+ch*_timepts + j];
                minpts[i] = (d<minpt) ? j : minpts[i];
                minpt = (d<minpt) ? d : minpt;
            }
        }
    }
    //now loop through the sequence and put spikes where each template reaches its peak state
    //first count the number of spikes
    *nspikes = 0;
    for(i=0;i<_npoints;i++)
    {
        for(j=0;j<_ntemps;j++)
        {
            if(mlseq[i*_ntemps+j] == minpts[j] )
            {
                *nspikes+=1;
            }
        }
    }
    //now allocate space for the spikes
    *spikes = malloc((*nspikes)*sizeof(float));
    *cids = malloc((*nspikes)*sizeof(uint32_t));
    k = 0;
    for(i=0;i<_npoints;i++)
    {
        for(j=0;j<_ntemps;j++)
        {
            if(mlseq[i*_ntemps+j] == minpts[j] )
            {
                (*spikes)[k] = ((float)i)/29.990;
                (*cids)[k] = j;
                k+=1;
            }
        }
    }
    free(minpts);
    return 0;
}
