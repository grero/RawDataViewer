//
//  RawDataViewerAppDelegate.m
//  RawDataViewer
//
//  Created by Roger Herikstad on 10/8/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "RawDataViewerAppDelegate.h"
#import "OpenPanelDelegate.h"

@implementation RawDataViewerAppDelegate

@synthesize window;
@synthesize wf;
@synthesize progress;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
    //we wantt to use threaded animation
    [progress setUsesThreadedAnimation: YES];
    [progress setIndeterminate: YES];
    //Load NSUserDefaults and set values
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:20.0] forKey:@"maxDataSize"]];
}
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    //read data from the file
    //start progress indicator
    BOOL res;
    [[progress window] makeKeyAndOrderFront:self];
    [progress startAnimation:self];
    const char *fname;    
    FILE *fid;
    uint32_t headerSize,samplingRate,npoints,maxSize;
    uint8_t nchs;
    int16_t *data;
    size_t nbytes;
    fname  = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    //check what kind of file we are opening
    NSRange r = [filename rangeOfString:@"waveforms.bin"];
    if(r.location != NSNotFound )
    {
        res = [self loadSpikeTimeStampsFromFile:filename];
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
    }
    else
    {
        maxSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"maxDataSize"];
        
        fid = fopen(fname, "rb");
        //get the header size
        fread(&headerSize, sizeof(uint32_t), 1, fid);
        //check if we have a valid file
        if( (headerSize != 73) && (headerSize != 90 ) )
        {
            NSLog(@"Could not open file %s", fname);
            //not valid file
            [progress stopAnimation:self];
            [[progress window] orderOut:self];
            return NO;
        }
        
        //get the number of channels
        fread(&nchs,sizeof(uint8_t),1,fid);
        if( nchs == 0 )
        {
            NSLog(@"Could not open file %s", fname);
            [progress stopAnimation:self];
            [[progress window] orderOut:self];
            return NO;
        }
        //get the sampling rate
        fread(&samplingRate,sizeof(uint32_t),1,fid);
        if( samplingRate > 1e5 )
        {
            //we made a mistake; try reading in the opposite order
            fseek(fid,-5,SEEK_CUR);
            fread(&samplingRate,sizeof(uint32_t),1,fid);
            fread(&nchs,sizeof(uint8_t),1,fid);
        }
        //check again; if we still didn't get a sensible number, this is probably not a valid file
        if (samplingRate > 1e5 )
        {
            NSLog(@"Could not open file %s", fname);
            [progress stopAnimation:self];
            [[progress window] orderOut:self];
            return NO;
        }
        fseek(fid,0,SEEK_END);
        npoints = (ftell(fid)-headerSize)/sizeof(int16_t);
        //check that we are actually able to load; load a maximum of 100MB
        if(npoints*sizeof(int16_t) > maxSize*1024*1024 )
        {
            npoints = (maxSize*1024*1024/(((uint32_t)nchs)*sizeof(int16_t)))*((uint32_t)nchs);
        }
        data = malloc(npoints*sizeof(int16_t));
        fseek(fid,headerSize,SEEK_SET);
        nbytes = fread(data,sizeof(int16_t),npoints,fid);
        fclose(fid);
        if(nbytes != npoints )
        {
            NSLog(@"Could not open file %s", fname);
            [progress stopAnimation:self];
            [[progress window] orderOut:self];
            return NO;
        }
        //check for the presense of a file called reorder.txt; if we find it, that means we have to reorder the data
        NSString *reOrderPath = [[filename stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
        NSString *sreorder = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:reOrderPath isDirectory:NO]];
        if( sreorder != nil )
        {
            NSLog(@"Reordering data...");
            int *reorder = malloc(nchs*sizeof(int));
            int k = 0;
            NSScanner *scanner = [NSScanner scannerWithString:sreorder];
            [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            //find all the ints
            while( ([scanner isAtEnd] == NO ) && (k < nchs))
            {
                [scanner scanInt:reorder+k];
                k+=1;
            }
            //we need a temporary array to hold the data for each channel
            int16_t *tmp_data = malloc(npoints*sizeof(int16_t));
            //now loop through the data and reorder everything
            uint32_t ch,i,ppc;
            int16_t d;
            ppc = npoints/(uint32_t)nchs;
            for(ch=0;ch<MIN(nchs,k);ch++)
            {
                for(i=0;i<ppc;i++)
                {
                    /*
                    d = data[i*nchs+ch];
                    //subtract 1 since the ordering is (usually!) 1-based
                    data[i*nchs+ch] = data[i*nchs+reorder[ch]-1];
                    data[i*nchs+reorder[ch]-1] = d;
                     */
                    tmp_data[i*nchs+ch] = data[i*nchs+reorder[ch]-1];
                    
                }
            }
            free(reorder);
            memcpy(data, tmp_data, npoints*sizeof(int16_t));
            free(tmp_data);
        }
        //test; compute covariance matrix
        float *cov = malloc(nchs*nchs*sizeof(float));
        computeCovariance(data, nchs, npoints/nchs, 1, cov);
        //[wf createPeakVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
        [wf createConnectedVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];

        //we don't need to keep the data
        free(data);
        //once we have loaded everything, turn off the indicator
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return YES;
    }
    
}

-(IBAction)openFile:(id)sender
{
    OpenPanelDelegate *oDelegate = [[OpenPanelDelegate alloc] init];
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    NSInteger result;
    [oPanel setDelegate:oDelegate];
    result = [oPanel runModal];
    if( result == NSOKButton )
    {
        [self loadDataFromFile:[oPanel filename] atOffset:0];
    }
    

}

-(IBAction)saveToPDF:(id)sender
{
   NSOperationQueue *queue = [NSOperationQueue mainQueue];
   NSInvocationOperation* theOp = [[[NSInvocationOperation alloc] initWithTarget:wf                                                                                                    selector:@selector(saveToPDFAtURL:) object:NULL] autorelease];
    [queue addOperation:theOp];
}

-(IBAction)savePDFAs:(id)sender
{
    NSURL *url;
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"pdf", nil]];
    NSInteger result;
    result = [sPanel runModal];
    if( result == NSOKButton )
    {
        url = [NSURL fileURLWithPath:[sPanel filename]];
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        NSInvocationOperation* theOp = [[[NSInvocationOperation alloc] initWithTarget:wf                                                                                                    selector:@selector(saveToPDFAtURL:) object:url] autorelease];
        [queue addOperation:theOp];
    }
}

-(IBAction)changeTime:(id)sender
{
    [wf setCurrentX :[sender floatValue]];
}

-(IBAction)toggleSpikeView:(id)sender
{
    if ([[sender title] isEqualToString:@"Show spikes"] )
    {
        [sender setTitle:@"Hide spikes"];
        [wf setDrawSpikes:YES];
        [wf setNeedsDisplay:YES];
    }
    else if( [[sender title] isEqualToString:@"Hide spikes"] )
    {
        [sender setTitle:@"Show spikes"];
        [wf setDrawSpikes:NO];
        [wf setNeedsDisplay:YES];
    }
}

-(BOOL)loadDataFromFile:(NSString *)filename atOffset:(NSUInteger)offset
{
    //read data from the file
    //start progress indicator
    [[progress window] makeKeyAndOrderFront:self];
    [progress startAnimation:self];
    const char *fname;    
    FILE *fid;
    uint32_t headerSize,samplingRate,npoints,maxSize;
    uint8_t nchs;
    int16_t *data;
    size_t nbytes;
    
    maxSize = 20; //maximum data size in MB
    fname  = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    fid = fopen(fname, "rb");
    //get the header size
    fread(&headerSize, sizeof(uint32_t), 1, fid);
    //check if we have a valid file
    if( (headerSize != 73) && (headerSize != 90 ) )
    {
        //not valid file
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        NSLog(@"Unrecognized header size");
        return NO;
    }
    
    //get the number of channels
    fread(&nchs,sizeof(uint8_t),1,fid);
    if( nchs == 0 )
    {
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return NO;
    }
    //get the sampling rate
    fread(&samplingRate,sizeof(uint32_t),1,fid);
    if( samplingRate > 1e5 )
    {
        //we made a mistake; try reading in the opposite order
        fseek(fid,-5,SEEK_CUR);
        fread(&samplingRate,sizeof(uint32_t),1,fid);
        fread(&nchs,sizeof(uint8_t),1,fid);
    }
    //check again; if we still didn't get a sensible number, this is probably not a valid file
    if (samplingRate > 1e5 )
    {
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return NO;
    }
    fseek(fid,0,SEEK_END);
    npoints = (ftell(fid)-headerSize)/sizeof(int16_t);
    //check that we are actually able to load; load a maximum of 100MB
    if(npoints*sizeof(int16_t) > maxSize*1024*1024 )
    {
        npoints = (maxSize*1024*1024/(((uint32_t)nchs)*sizeof(int16_t)))*((uint32_t)nchs);
    }
    data = malloc(npoints*sizeof(int16_t));
    fseek(fid,headerSize,SEEK_SET);
    nbytes = fread(data,sizeof(int16_t),npoints,fid);
    fclose(fid);
    if(nbytes != npoints )
    {
        NSLog(@"Could not open file %s", fname);
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return NO;
    }
    //check for the presense of a file called reorder.txt; if we find it, that means we have to reoder the data
    NSString *reOrderPath = [[filename stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
    NSString *sreorder = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:reOrderPath isDirectory:NO]];
    if( sreorder != nil )
    {
        int *reorder = malloc(nchs*sizeof(int));
        int k = 0;
        NSScanner *scanner = [NSScanner scannerWithString:sreorder];
        [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        //find all the ints
        while( ([scanner isAtEnd] == NO ) && (k < nchs))
        {
            [scanner scanInt:reorder+k];
            k+=1;
        }
        //we need a temporary array to hold the data for each channel
        //now loop through the data and reorder everything
        uint32_t ch,i,ppc;
        int16_t d;
        ppc = npoints/(uint32_t)nchs;
        for(ch=0;ch<MIN(nchs,k);ch++)
        {
            for(i=0;i<ppc;i++)
            {
                d = data[i*nchs+ch];
                //subtract 1 since the ordering is (usually!) 1-based
                data[i*nchs+ch] = data[i*nchs+reorder[ch]-1];
                data[i*nchs+reorder[ch]-1] = d;
                
            }
        }
        free(reorder);
    }
    
    //[wf createPeakVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
    [wf createConnectedVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
    
    //we don't need to keep the data
    free(data);
    //once we have loaded everything, turn off the indicator
    [progress stopAnimation:self];
    [[progress window] orderOut:self];
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
    fread(chs,sizeof(uint32_t),tsize,fid);
    //get the spikes
    fread(spikes,sizeof(float),tsize*32,fid);
          
    if(spikeForms == NULL)
    {
        spikeForms = [NSData dataWithBytes:spikes length:tsize*32*sizeof(float)];
    }
    return YES;
}

-(BOOL)loadSpikeTimeStampsFromFile:(NSString *)filename
{
    const char* fname;
    FILE *fid;
    uint64_t *timestamps;
    float *spikes;
    uint8_t nchs;
    uint32_t headerSize,numSpikes,timepts,i;
    
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
    //seek to the appropriate position
    fseek(fid, headerSize+numSpikes*(uint32_t)nchs*timepts*2, 0);
    //read the timestamps
    //allocate space
    timestamps = malloc(numSpikes*sizeof(uint64_t));
    fread(timestamps, sizeof(uint64_t), numSpikes, fid);
    //timestamps are stored with a precision of 0.1 millisecond, so we need to convert to milliseconds first
    spikes = malloc(numSpikes*sizeof(float));
    for(i=0;i<numSpikes;i++)
    {
        spikes[i] = 0.001*(float)timestamps[i];
    }
    free(timestamps);
    [wf createSpikeVertices:[NSData dataWithBytes:spikes length:numSpikes*sizeof(float)] numberOfSpikes:numSpikes channels:NULL numberOfChannels:NULL];
    free(spikes);
    return YES;
    
}

@end
