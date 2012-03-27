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
@synthesize dataFileName;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
    //we wantt to use threaded animation
    [progress setUsesThreadedAnimation: YES];
    [progress setIndeterminate: YES];
    //Load NSUserDefaults and set values
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:20.0] forKey:@"maxDataSize"]];
    //Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"loadMoreData" object:nil];
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
    NSRange rWf = [filename rangeOfString:@"waveforms.bin"];
    if(rWf.location != NSNotFound )
    {
        res = [self loadSpikeTimeStampsFromFile:filename];
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return res;
    }
    
    else if([[filename pathExtension] isEqualToString:@"mat"])
    {
        res = [self loadHmmSortResultsFromFile:filename];
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return res;
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
        //set the filename
        [self setDataFileName:filename];
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
        NSString *sreorder,*reOrderPath;
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        //check for reorder in cwd
        NSLog(cwd);
        if([[NSFileManager defaultManager] isReadableFileAtPath:[cwd stringByAppendingPathComponent:@"reorder.txt"]])
        {
            reOrderPath = [cwd stringByAppendingPathComponent: @"reorder.txt"];
        }
        else
        {
            reOrderPath = [[filename stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
        }
        if([[NSFileManager defaultManager] isReadableFileAtPath:reOrderPath] == NO )
        {
            reOrderPath = [[[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
        }
        sreorder = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:reOrderPath isDirectory:NO]];
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
    
    maxSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"maxDataSize"];
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
    npoints = (ftell(fid)-headerSize)/sizeof(int16_t)-offset*nchs;
    //check that we are actually able to load; load a maximum of 100MB
    if(npoints*sizeof(int16_t) > maxSize*1024*1024 )
    {
        npoints = (maxSize*1024*1024/(((uint32_t)nchs)*sizeof(int16_t)))*((uint32_t)nchs);
    }
    data = malloc(npoints*sizeof(int16_t));
    fseek(fid,headerSize+offset*nchs*sizeof(int16_t),SEEK_SET);
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
    NSString *sreorder,*reOrderPath;
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    //check for reorder in cwd
    if([[NSFileManager defaultManager] isReadableFileAtPath:[cwd stringByAppendingPathComponent:@"reorder.txt"]])
    {
        reOrderPath = [cwd stringByAppendingPathComponent: @"reorder"];
    }
    else
    {
        reOrderPath = [[filename stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
    }
    sreorder = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:reOrderPath isDirectory:NO]];
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

-(BOOL)loadHmmSortResultsFromFile:(NSString*)filename
{
    const char* fname;
    double *mlseq,*_spikeForms,minpt,d;
    float *spikes;
    uint32_t ntemps,nchs,timepts,npoints,i,j,ch,k;
    int *minpts;
    uint32_t nspikes;
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    
    matvar_t *mlseqVar,*spikeFormsVar;
	mat_t *mat;
	
	//open file
	mat = Mat_Open(fname,MAT_ACC_RDONLY);
    
    //load the sequence
	mlseqVar = Mat_VarRead(mat,"mlseq");
	//int err = Mat_VarReadDataAll(mat,matvar);
	//int nel = (matvar->nbytes)/(matvar->data_size);
	mlseq = mlseqVar->data;
    if(mlseq == NULL)
    {
        return NO;
    }
    ntemps = mlseqVar->dims[0];
    npoints = mlseqVar->dims[1];
    spikeFormsVar = Mat_VarRead(mat,"spikeForms");
    _spikeForms = spikeFormsVar->data;
    
    if( _spikeForms== NULL)
    {
        return NO;
    }
    nchs = spikeFormsVar->dims[1];
    timepts = spikeFormsVar->dims[2];
    //find the maximum point of each template; this will be where the spike was "triggered"
    minpts = malloc(ntemps*sizeof(int));
    for(i=0;i<ntemps;i++)
    {
        minpt = INFINITY;
        for(ch=0;ch<nchs;ch++)
        {
            
            for(j=0;j<timepts;j++)
            {
                //column order
                d = _spikeForms[j*ntemps*nchs+ch*ntemps + i];
                minpts[i] = (d<minpt) ? j : minpts[i];
                minpt = (d<minpt) ? d : minpt;
            }
        }
    }
    //now loop through the sequence and put spikes where each template reaches its peak state
    //first count the number of spikes
    nspikes = 0;
    for(j=0;j<ntemps;j++)
    {
        for(i=0;i<npoints;i++)
        {
            if(mlseq[i*ntemps+j] == minpts[j] )
            {
                nspikes+=1;
            }
        }
    }
    //now allocate space for the spikes
    spikes = malloc(nspikes*sizeof(float));
    k = 0;
    for(j=0;j<ntemps;j++)
    {
        for(i=0;i<npoints;i++)
        {
        
            if(mlseq[i*ntemps+j] == minpts[j] )
            {
                spikes[k] = ((float)i)/29.990;
                k+=1;
            }
        }
    }
    free(minpts);
    [wf createSpikeVertices:[NSData dataWithBytes:spikes length:nspikes*sizeof(float)] numberOfSpikes:nspikes channels:NULL numberOfChannels:NULL];
    free(spikes);
    Mat_VarFree(mlseqVar);
    Mat_VarFree(spikeFormsVar);
	Mat_Close(mat);
	return YES;

}

-(void)receiveNotification:(NSNotification*)notification
{
    if([[notification name] isEqualToString:@"loadMoreData"] )
    {
        //we are instructed to load more data
        NSDictionary *dict = [notification userInfo];
        NSInteger currentPos = [[dict objectForKey:@"currentPos"] intValue];
        //currentPos is the position of where we are right now;
        //temporarily remove self
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [self loadDataFromFile:[self dataFileName] atOffset:currentPos];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"loadMoreData" object:nil];
    }
}


@end
