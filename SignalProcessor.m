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
@synthesize spikes,templates,cinv,cells,cids,channels,numChannels,markers;
@synthesize ntemplates,nspikes,samplingRate,timepts,timeOffset;

- (id)init
{
    self = [super init];
    if (self) {
        templates = [[[[NSMutableData alloc] init] retain] autorelease];
        numChannels  = [[[[NSMutableData alloc] init] retain] autorelease];
        spikes  = [[[[NSMutableData alloc] init] retain] autorelease];
        markers  = [[[[NSMutableData alloc] init] retain] autorelease];

        ntemplates = 0;
        nspikes = 0;
		nmarkers = 0;
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
	double fconv;
    int16_t *spikeForms;
    uint8_t nchs;
    uint32_t headerSize,numSpikes,timepts,i,_nchs,conv;
    
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
	fread(&conv,sizeof(uint32_t),1,fid);
	fread(&timepts,sizeof(uint32_t),1,fid);
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
	//convert from microseconds to miliseconds
	fconv = 0.001;
    for(i=0;i<numSpikes;i++)
    {
        _spikes[i] = (float)(fconv*(double)(timestamps[i]) - timeOffset);
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

-(BOOL)loadSyncsFile:(NSString*)filename
{
	//snc file containing stimulus sync time stamps, expressed in data points
	const char *_fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
	FILE *fid;
	int32_t headerSize,nsyncs,i,*syncs;
	size_t q;
	float fconv,*_spikes;
	fid = fopen(_fname,"r");
	//read reahder header
	q = fread(&headerSize,sizeof(int32_t),1,fid);
	//skeeip 260 bytes reserved for info
	q = fseek(fid,260,SEEK_CUR);
	//read the number of syncs
	q = fread(&nsyncs,sizeof(int32_t),1,fid);
	//allocate space for the syncs themselves
	syncs = malloc(nsyncs*sizeof(int32_t));
	//seek to the beginning of the syncs
	q = fseek(fid,headerSize,SEEK_SET);
	//read the syncs
	q = fread(syncs,sizeof(int32_t),nsyncs,fid);
	fclose(fid);

    _spikes = malloc(nsyncs*sizeof(float));
	//convert from microseconds to miliseconds
	fconv = 1.0/(samplingRate/1000);
    for(i=0;i<nsyncs;i++)
    {
        _spikes[i] = fconv*(float)syncs[i];
    }
    free(syncs);
    [markers appendBytes:_spikes length:nsyncs*sizeof(float)];
    free(_spikes);
    nmarkers+=nsyncs;
    
    return YES;

}

-(BOOL)saveWaveformsFile:(NSString *)filename
{
    //save to waveformsfile
    FILE *fid;
    const char *fname;
    float *spikeForms;
    float *_spikes;
    uint32_t nspikes,nchs,timepts,headerSize,i,spikeFormsSize,conv;
    uint8_t _nchs;
    int16_t *_spikeForms;
    uint64_t *_timestamps;
    
    _spikes = (float*)[spikes bytes];
    nspikes = [spikes length]/sizeof(float);
    spikeForms = (float*)[templates bytes];
    
   	conv = 1000.0; 
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
	fwrite(&conv,sizeof(uint32_t),1,fid);
	fwrite(&timepts,sizeof(uint32_t),1,fid);
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

-(void)extractSpikesFromData:(NSData*)data numRows: (uint32_t)nrows numCols:(uint32_t)ncols channelOffsets:(NSData*)offsets xOffset:(float)xoffset
{
	uint32_t i,j,k,l;
	float *_data,*_tmpData,*_cinv,*_offset,*mD,d,alpha,*spikeidx,q,r,sq;


	_data = (float*)[data bytes];
	_cinv = (float*)[[self cinv] bytes];
	_offset = (float*)[offsets bytes];
	mD = malloc(ncols*sizeof(float));
	//TODO: make this a setting
	alpha = 0.001;
	//compute mahalanobis distance
	malanobisDistance(_data,nrows,ncols,1,_offset,_cinv,NULL,0,mD);
	spikeidx = malloc(ncols*sizeof(float));
	for(i=0;i<ncols;i++)
	{
		//compute the probability for observing this distance under the null hypothesis
		d = 1-chi2_cdf((double)mD[i],nrows);
		//if d is less than the threshold, this is a spike
		spikeidx[i] = d < alpha;

	}
	free(mD);
	//for each continuous group, find the minimum
	i = 0;
	while(i < ncols)
	{
		j = i;
		l = -1;
		r= HUGE_VAL;
		while( (spikeidx[j]==1) && (j < ncols))
		{
			q = HUGE_VAL;
			for(k=0;k<nrows;k++)
			{
				d = _data[k*ncols+j];
				q = MIN(d,q);
			}
			//set the minimum index
			l = q > r ? j : l;
			r = MIN(q,r);
			j+=1;

		}
		//r is now the spike index
		//add the spike; verify that there was indeed a spike
		if( (j < ncols ) && (j>0)  )
		{
			if(spikeidx[j-1]==1)
			{
			    sq = xoffset + j/(samplingRate/1000);
				[[self spikes] appendBytes: &sq length:sizeof(float)];
				nspikes+=1;
				i=j+1;
			}
			else
			{
				i+=1;
			}
		}
		else
		{
			i+=1;
		}
	}

	free(spikeidx);
}

-(void)resetSpikes
{
	[[self spikes] setLength:0];
	[[self templates] setLength:0];
	ntemplates = 0;
	nspikes = 0;
}

-(void)resetMarkers
{
	[[self markers] setLength:0];
	nmarkers = 0;
}

-(void)assignSpikeID:(NSInteger)spid
{
	uint32_t i,*_cids;;
	_cids = malloc(nspikes*sizeof(uint32_t));
	for(i=0;i<nspikes;i++)
	{
		_cids[i] = spid;
	}
	[self setCids: [NSMutableData dataWithBytes: _cids length: nspikes*sizeof(uint32_t)]];
	free(_cids);
}

-(void)sortSpikes
{
	float *_spikes,*_newspikes;
	vDSP_Length i,*idx;
	uint32_t *_cids,*_newcids;
	_spikes = (float*)[[self spikes] bytes];
	_newspikes = malloc(nspikes*sizeof(float));
	idx = malloc(nspikes*sizeof(vDSP_Length));
	//fill the index vector first
	for(i=0;i<nspikes;i++)	
	{
		idx[i] = i;
	}
	//do an indirect sort of the spikes
	vDSP_vsorti(_spikes,idx,NULL,nspikes,1);
	//idx now contains the sorted indices
	//rearrange both the spikes and the template ids
	_cids = (uint32_t*)[[self cids] bytes];
	if(_cids!=NULL)
	{
		_newcids = malloc(nspikes*sizeof(uint32_t));
		for(i=0;i<nspikes;i++)
		{
			_newcids[i] = _cids[idx[i]];
		}
		//update cids
		[[self cids] replaceBytesInRange:NSMakeRange(0,nspikes*sizeof(uint32_t)) withBytes: _newcids];
		free(_newcids);
	}
	//rearrange spikes
	for(i=0;i<nspikes;i++)
	{
		_newspikes[i] = _spikes[idx[i]];
	}
	//replace spikes
	[[self spikes] replaceBytesInRange:NSMakeRange(0,nspikes*sizeof(float)) withBytes: _newspikes];
	//we don't need _newspikes anymore
	free(_newspikes);
	

}
-(void)assignSpikeID:(NSInteger)spid forSpikesInRange: (NSRange)range
{
	uint32_t i,*_cids,n;;
	NSRange byteRange;
	_cids = malloc(range.length*sizeof(uint32_t));
	n = range.location + range.length;
	if( cids == NULL )
	{
		[self setCids: [NSMutableData dataWithLength: nspikes*sizeof(uint32_t)]];
	}
	else
	{
		//resize the data
		[[self cids] setLength: nspikes*sizeof(uint32_t)];
	}
	for(i=0;i<range.length;i++)
	{
		_cids[i] = spid;
	}
	//need to convert to byte range	
	byteRange = NSMakeRange(range.location*sizeof(uint32_t),range.length*sizeof(uint32_t));
	[[self cids] replaceBytesInRange: byteRange withBytes: _cids length: range.length*sizeof(uint32_t)];
	free(_cids);
}
-(void)assignSpikeIDs:(NSData*)spids forSpikesInRange: (NSRange)range
{
	uint32_t n,i,*_cids;
	NSRange byteRange;
	n = [spids length]/sizeof(uint32_t);
	if(n != range.length)
	{
		return;
	}
	if( cids == NULL )
	{
		[self setCids: [NSMutableData dataWithLength: nspikes*sizeof(uint32_t)]];
	}
	else
	{
		//resize the data
		[[self cids] setLength: nspikes*sizeof(uint32_t)];
	}
	_cids = (uint32_t*) [spids bytes];
	//need to convert to byte range	
	byteRange = NSMakeRange(range.location*sizeof(uint32_t),range.length*sizeof(uint32_t));
	[[self cids] replaceBytesInRange: byteRange withBytes: _cids length: range.length*sizeof(uint32_t)];
	
}

@end
