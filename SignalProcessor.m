//
//  SignalProcessor.m
//  RawDataViewer
//
//  Created by Roger Herikstad on 24/3/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "SignalProcessor.h"

@implementation SignalProcessor

@synthesize templateFile;
@synthesize spikes,templates,cinv,cells,cids;
@synthesize ntemplates,nspikes,samplingRate;

- (id)init
{
    self = [super init];
    if (self) {
        templates = [[[[NSMutableData alloc] init] retain] autorelease];
        numChannels  = [[[[NSMutableData alloc] init] retain] autorelease];
        spikes  = [[[[NSMutableData alloc] init] retain] autorelease];

        ntemplates = 0;
        nspikes = 0;
        }
    
    return self;
}

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(uint32_t)nchs atTimePoint:(float)timept
{
    [templates appendBytes:spike length:n*sizeof(float)];
    [spikes appendBytes:&timept length:sizeof(float)];
    [numChannels appendBytes:&nchs length:sizeof(uint32_t)];
    ntemplates+=1;
    //create file in the current working directory
    if( templateFile == NULL )
    {
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *filename = [cwd stringByAppendingPathComponent:@"templates.bin"];
        //check if we have write access
        if( [[NSFileManager defaultManager] isWritableFileAtPath:filename] == NO )
        {
            //open up a save panel to get the file name
            NSSavePanel *sPanel = [NSSavePanel savePanel];
            int res = [sPanel runModal];;
            if(res == NSOKButton )
            {
                filename = [sPanel filename];
            }
            else
            {
                filename = NULL;
            }
        }
        [self setTemplateFile:filename];
        //if the file exists, load the existing spikes first
        if([[NSFileManager defaultManager] fileExistsAtPath:filename])
        {
            
        }
    }
    if( templateFile != NULL)
    {
        //[self saveTemplates:templateFile];
        [self saveWaveformsFile:templateFile];
    }
    
}

-(BOOL)saveTemplates:(NSString*)filename
{
    //temporary save routine; this should change
    FILE *fid;
    const char *fname;
    float *temps;
    uint32_t *chs;
    uint32_t spikeSize,i;
    
    temps = (float*)[templates bytes];
    chs = (uint32_t*)[numChannels bytes];
    //get the total size of the spike array
    spikeSize = 0;
    for(i=0;i<ntemplates;i++)
    {
        spikeSize+=32*chs[i];
    }
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    fid = fopen(fname,"w");
    if(fid < 0 )
    {
        return NO;
    }
    //write the number of templates
    fwrite(&ntemplates, sizeof(uint32_t), 1, fid);
    //write the number of channels per template
    fwrite(chs,sizeof(uint32_t),ntemplates,fid);
    //write the templates themselves
    fwrite(temps,sizeof(float),spikeSize,fid);
    fclose(fid);
    return YES;
    
}

-(BOOL)loadSpikesFromFile:(NSString*)filename
{
    const char* fname;
    FILE *fid;
    uint32_t nspikes,i,tsize;
    uint32_t *nchs,*chs;
    float *spikes;
    
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    
    fid = fopen(fname,"r");
    if(fid<0)
    {
        return NO;
    }
    //read the number of spikes in the file
    fread(&nspikes,sizeof(uint32_t),1,fid);
    //get the number of channels per spike
    fread(nchs,sizeof(uint32_t),nspikes,fid);
    //find the total size
    tsize = 0;
    for(i=0;i<nspikes;i++)
    {
        tsize+=nchs[i];
    }
    //get the channels themselves
    //fread(chs,sizeof(uint32_t),tsize,fid);
    //get the spikes
    fread(spikes,sizeof(float),tsize*32,fid);
    
    [templates appendBytes:spikes length:nspikes*sizeof(float)];
    [numChannels appendBytes:nchs length:nspikes*sizeof(uint32_t)];
    ntemplates+=1;
    //determine where to put the spike
    return YES;
}

-(BOOL)loadWaveformsFile:(NSString *)filename
{
    const char* fname;
    FILE *fid;
    uint64_t *timestamps;
    float *_spikes,s;
    int16_t *spikeForms;
    uint8_t nchs;
    uint32_t headerSize,numSpikes,timepts,i,_nchs;
    
    timepts = 32;
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    
    fid = fopen(fname,"r");
    if(fid<0)
    {
        return NO;
    }
    
    //get the headersize
    fread(&headerSize,sizeof(uint32_t),1,fid);
    //get the number of spikes
    fread(&numSpikes,sizeof(uint32_t),1,fid);
    //get the number of channels
    fread(&nchs,sizeof(uint8_t),1,fid);
    //read the spikeForms
    spikeForms = malloc(numSpikes*((uint32_t)nchs)*timepts*sizeof(int16_t));
    fseek(fid, headerSize, 0);
    fread(spikeForms, sizeof(int16_t), numSpikes*((uint32_t)nchs)*timepts, fid);
    //convert to float
    for(i=0;i<numSpikes*((uint32_t)nchs)*timepts;i++)
    {
        s = (float)spikeForms[i];
        [templates appendBytes:&s length:sizeof(float)];
    }
    free(spikeForms);
    //seek to the appropriate position
    fseek(fid, headerSize+numSpikes*(uint32_t)nchs*timepts*2, 0);
    //read the timestamps
    //allocate space
    timestamps = malloc(numSpikes*sizeof(uint64_t));
    fread(timestamps, sizeof(uint64_t), numSpikes, fid);
    //timestamps are stored with a precision of microseconds, so we need to convert to milliseconds first
    fclose(fid);
    _spikes = malloc(numSpikes*sizeof(float));
    for(i=0;i<numSpikes;i++)
    {
        _spikes[i] = 0.001*(float)timestamps[i];
    }
    free(timestamps);
    [spikes appendBytes:_spikes length:numSpikes*sizeof(float)];
    free(_spikes);
    ntemplates+=numSpikes;
    //TODO: add number of channels as well
    _nchs = (uint32_t)nchs;
    for(i=0;i<numSpikes;i++)
    {
        [numChannels appendBytes:&_nchs length:sizeof(uint32_t)];
    }
    nspikes+=numSpikes;
    //this assumes we want to keep using the same file
    [self setTemplateFile:filename];
    
    return YES;
}

-(BOOL)saveWaveformsFile:(NSString *)filename
{
    //save to waveformsfile
    FILE *fid;
    const char *fname;
    float *spikeForms;
    float *_spikes;
    uint32_t nspikes,nchs,timepts,headerSize,i,spikeFormsSize;
    uint8_t _nchs;
    int16_t *_spikeForms;
    uint64_t *_timestamps;
    
    _spikes = (float*)[spikes bytes];
    nspikes = [spikes length]/sizeof(float);
    spikeForms = (float*)[templates bytes];
    
    
    nchs = *((uint32_t*)[numChannels bytes]);
    timepts = [templates length]/(sizeof(float)*nspikes*nchs);
    spikeFormsSize = nspikes*timepts*nchs;
    _spikeForms = malloc(spikeFormsSize*sizeof(int16_t));
    //we need to convert to spike shapes to int16
    for(i=0;i<spikeFormsSize;i++)
    {
        _spikeForms[i] = (int16_t)spikeForms[i];
    }
    _timestamps = malloc(nspikes*sizeof(uint64_t));
    for(i=0;i<nspikes;i++)
    {
        _timestamps[i] = (uint64_t)(_spikes[i]*1000);
    }
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    fid = fopen(fname,"w");
    if(fid<0)
    {
        return NO;
    }
    headerSize = 100;
    //write the header size
    fwrite(&headerSize, sizeof(uint32_t), 1, fid);
    //write the number of spikes
    fwrite(&nspikes,sizeof(uint32_t),1,fid);
    //write the number of channels
    _nchs = (uint8_t)nchs;
    fwrite(&_nchs, sizeof(uint8_t), 1, fid);
    fseek(fid,headerSize,0);
    //write the spike shapes
    fwrite(_spikeForms,  sizeof(int16_t),nspikes*nchs*timepts, fid);
    //we don't need _spikeforms any more
    free(_spikeForms);
    //write the timestamps
    fwrite(_timestamps,sizeof(uint64_t),nspikes,fid);
    free(_timestamps);
    fclose(fid);
    
    return YES;
}

-(BOOL)loadClusterIDs:(NSString*)filename
{
    const char *fname;
    
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    //clusterids are con
}

-(void)decodeData:(NSData*)data numRows: (uint32_t)nrows numCols:(uint32_t)ncols channelOffsets:(NSData*)offsets
{
    
    float *spikeForms,*_data,*_cinv,*_offsets,*bp,sq;
    double d;
    uint32_t i,j,k,l,timepts,*C,_nspikes;
    dispatch_queue_t queue;
    
    _data = (float*)[data bytes];
    spikeForms = (float*)[[self templates] bytes];
    timepts = [[self templates] length]/(ntemplates*nrows*sizeof(float));
    _cinv = (float*)[[self cinv] bytes];
    _offsets = (float*)[offsets bytes];
    //loop through spikeforms
    
    C = calloc(ntemplates*(ncols-timepts),sizeof(uint32_t));
    
    bp = malloc(ntemplates*(ncols-timepts)*sizeof(float));
    _nspikes=0;
    queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    //TODO: should also do template combinations here
    dispatch_apply(ntemplates, queue, ^(size_t i)
    //for(i=0;i<ntemplates;i++)
    {
        uint32_t j,k,l;
        float d;
        float *mD = malloc(timepts*sizeof(float));
        float *_tmpData = malloc(timepts*nrows*sizeof(float));
        //use a step of 3 since we are expecting to analyze the vertex array
        for(j=0;j<ncols-timepts;j++)
        {
            //copy into temporary data
            for(k=0;k<nrows;k++)
            {
                for(l=0;l<timepts;l++)
                {
                    _tmpData[k*timepts+l] = _data[k*ncols*3+3*(j+l)+1];
                }
            }
            malanobisDistance(_tmpData, nrows, timepts, 1,_offsets,_cinv, spikeForms+i*nrows*timepts, 1,mD);
            //compute the probability that a distance larger than or equal to this could be optained by chance
            for(k=0;k<timepts;k++)
            {
                d = 1-chi2_cdf((double)(mD[k]), nrows);
                //check if the probability of the measured distance, under the assumption of zero mean gaussian, is less than 0.05
                if(d < 0.05)
                {
                    C[i*(ncols-timepts)+j]+=1;
                }
                
            }
            //compute the probabilty of getting C number of violations by chance assuming that the violations are binomially distributed with p = 0.05. If the resulting probability is itself  greater than 0.05, we have a match
            bp[i*(ncols-timepts)+j] = gsl_ran_binomial_pdf(C[i*(ncols-timepts)+j],0.05,timepts);
        }
        free(_tmpData);
        free(mD);
    });
    
    _nspikes = 0;
    //go through and create spikes
    //nspikes = ntemplates;
    for(i=0;i<ntemplates;i++)
    {
        for(j=0;j<(ncols-timepts);j++)
        {
            d = bp[i*(ncols-timepts)+j];
            if(d > 0.05)
            {
                _nspikes+=1;
                //since we normally trigger of the 10th point
                //get the x-value of the corresponding vertex
                sq = _data[3*(j+10)];
                //add this timepoint to the spikes
                [[self spikes] appendBytes:&sq length:sizeof(float)];
                nspikes+=1;
                //ntemplates+=1;
            }
        }
    }
    //ntemplates = nspikes;
    
    free(C);
    free(bp);
}

-(void)findPeaks:(float*)data length:(NSUInteger)length stride:(NSUInteger)stride;
{
    //search the vector indirectly
    /*
    vDSP_Length *idx;
    idx = malloc(length*sizeof(vDSP_Length));
    vDSP_vsorti(data,idx,NULL,)
     */
    
}

@end
