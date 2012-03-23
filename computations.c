//
//  computations.c
//  RawDataViewer
//
//  Created by Roger Herikstad on 23/3/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//


#include "computations.h"

void computeCovariance(int16_t *data, uint32_t nrows, uint32_t ncols, uint8_t rowvar,float *output)
{
    //observations in columns
    uint32_t i,j,k;
    float *m;
    m = malloc(nrows*sizeof(float));
    //first compute mean for each row
    if( rowvar == 0 )
    {
        for(i=0;i<nrows;i++)
        {
            m[i] = 0;
            for(k=0;k<ncols;k++)
            {
                m[i]+=(float)data[i*ncols+k];
            }
            m[i]=m[i]/ncols;
        }
        
        for(i=0;i<nrows;i++)
        {
            for(j=i;j<nrows;j++)
            {
                output[i*nrows+j] = 0;
                for(k=0;k<ncols;k++)
                {
                    output[i*nrows+j]+=((float)data[i*ncols+k]-m[i])*((float)data[j*ncols+k]-m[j]);
                }
                output[i*nrows+j] = output[i*nrows+j]/(ncols-1);
                //symmetric
                output[j*nrows+i] = output[i*nrows+j];
            }
        }
    }
    else
    {
        //transpose
        for(i=0;i<nrows;i++)
        {
            m[i] = 0;
            for(k=0;k<ncols;k++)
            {
                m[i]+=(float)data[k*nrows+i];
            }
            m[i]=m[i]/ncols;
        }
        
        for(i=0;i<nrows;i++)
        {
            for(j=i;j<nrows;j++)
            {
                output[i*nrows+j] = 0;
                for(k=0;k<ncols;k++)
                {
                    output[i*nrows+j]+=((float)data[k*nrows+i]-m[i])*((float)data[k*nrows+j]-m[j]);
                }
                output[i*nrows+j] = output[i*nrows+j]/(ncols-1);
                //symmetric
                output[j*nrows+i] = output[i*nrows+j];
            }
        }

    }
    free(m);
}