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
@synthesize spikes,templates;
@synthesize ntemplates;

- (id)init
{
    self = [super init];
    if (self) {
        templates = [[[[NSMutableData alloc] init] retain] autorelease];
        numChannels  = [[[[NSMutableData alloc] init] retain] autorelease];
        spikes  = [[[[NSMutableData alloc] init] retain] autorelease];

        ntemplates = 0;
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
    float *_spikes;
    float *spikeForms;
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
    spikeForms = malloc(numSpikes*((uint32_t)nchs)*timepts*sizeof(float));
    fseek(fid, headerSize, 0);
    fread(spikeForms, sizeof(float), numSpikes*((uint32_t)nchs)*timepts, fid);
    [templates appendBytes:spikeForms length:numSpikes*((uint32_t)nchs)*timepts*sizeof(float)];
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
    int16_t *_spikeForms,*_timestamps;
    
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
    _timestamps = malloc(nspikes*sizeof(int16_t));
    for(i=0;i<nspikes;i++)
    {
        _timestamps[i] = (int16_t)(_spikes[i]*1000);
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
    fwrite(_spikeForms, nspikes*nchs*timepts, sizeof(int16_t), fid);
    //we don't need _spikeforms any more
    free(_spikeForms);
    //write the timestamps
    fwrite(_timestamps,nspikes,sizeof(int16_t),fid);
    free(_timestamps);
    fclose(fid);
    
    return YES;
}

@end
