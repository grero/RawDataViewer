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
@synthesize sp;
@synthesize progress;
@synthesize dataFileName;
@synthesize workspace;

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
    uint32_t i,k;
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
        res = [sp loadWaveformsFile:filename];
        [wf createSpikeVertices:[sp spikes] numberOfSpikes:[sp ntemplates] channels:nil numberOfChannels:nil];

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
        numChannels = nchs;
        numActiveChannels = nchs;
        //set the filename
        [self setDataFileName:filename];

        //attempt to get a dictionary for this file
        if( [[NSUserDefaults standardUserDefaults] dictionaryForKey:filename] == nil )
        {
            //no workspace found, so create one
            workspace = [NSMutableDictionary dictionaryWithCapacity:3];
            //[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:workspace forKey:filename]];
        }
        else
        {
            workspace = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:filename]];
        }
        fseek(fid,0,SEEK_END);
        npoints = (ftell(fid)-headerSize)/sizeof(int16_t);
        //check that we are actually able to load; load a maximum of 100MB
        if(npoints*sizeof(int16_t) > maxSize*1024*1024 )
        {
            npoints = (maxSize*1024*1024/(((uint32_t)nchs)*sizeof(int16_t)))*((uint32_t)nchs);
        }
        if( npoints == 0 )
        {
            return NO;
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
        if(reorder == NULL )
        {
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
                reorder = malloc(nchs*sizeof(int));
                k = 0;
                NSScanner *scanner = [NSScanner scannerWithString:sreorder];
                [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                //find all the ints
                while( ([scanner isAtEnd] == NO ) && (k < nchs))
                {
                    [scanner scanInt:reorder+k];
                    k+=1;
                }
                numActiveChannels = k;
                if (k < nchs)
                {
                    for(i=k;i<nchs;i++)
                    {
                        //plus one because at this point we are using 1-based indexing
                        reorder[i] = i+1;
                    }
                }
            }
        }
        //check again
        if( reorder != NULL )
        {
            NSLog(@"Reordering data...");

            uint32_t ch,ppc;
            ppc = npoints/(uint32_t)nchs;
            //we need a temporary array to hold the data for each channel
            int16_t *tmp_data = malloc(ppc*numActiveChannels*sizeof(int16_t));
            //now loop through the data and reorder everything
           
            int16_t d;
            
            for(ch=0;ch<numActiveChannels;ch++)
            {
                for(i=0;i<ppc;i++)
                {
                    /*
                    d = data[i*nchs+ch];
                    //subtract 1 since the ordering is (usually!) 1-based
                    data[i*nchs+ch] = data[i*nchs+reorder[ch]-1];
                    data[i*nchs+reorder[ch]-1] = d;
                     */
                    tmp_data[i*numActiveChannels+ch] = data[i*nchs+reorder[ch]-1];
                    
                }
            }
            memcpy(data, tmp_data, ppc*numActiveChannels*sizeof(int16_t));
            free(tmp_data);
        }
        //test; compute covariance matrix
        float *cov = malloc(numActiveChannels*numActiveChannels*sizeof(float));
        computeCovariance(data, numActiveChannels, npoints/numActiveChannels, 1, cov);
        //[wf createPeakVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
        [wf createConnectedVertices:[NSData dataWithBytes:data length:(npoints/nchs)*numActiveChannels*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)numActiveChannels andTimePoints:(NSUInteger)npoints/nchs];

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
    uint32_t headerSize,samplingRate,npoints,maxSize,k,i;
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
    [self setDataFileName:filename];
    fseek(fid,0,SEEK_END);
    npoints = (ftell(fid)-headerSize)/sizeof(int16_t);
    //notify the drawing window of the file size
    [wf setEndTime:npoints/nchs];
    npoints-=offset*nchs;
    //check that we are actually able to load;
    if(npoints*sizeof(int16_t) > maxSize*1024*1024 )
    {
        npoints = (maxSize*1024*1024/(((uint32_t)nchs)*sizeof(int16_t)))*((uint32_t)nchs);
    }
    if( npoints <= 0 )
    {
        NSLog(@"No data read from  %s", fname);
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return NO;
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
    numChannels = nchs;
    [self checkForReorderingForFile:filename];
    if(reorder != NULL )
    {
        NSLog(@"Reordering data...");
        
        uint32_t ch,ppc;
        int16_t d;
        ppc = npoints/(uint32_t)nchs;
        //we need a temporary array to hold the data for each channel
        int16_t *tmp_data = malloc(ppc*numActiveChannels*sizeof(int16_t));
        //now loop through the data and reorder everything
        
        for(ch=0;ch<numActiveChannels;ch++)
        {
            for(i=0;i<ppc;i++)
            {
                tmp_data[i*numActiveChannels+ch] = data[i*numChannels+reorder[ch]-1];
            }
        }
        npoints = (npoints/nchs)*numActiveChannels;
        memcpy(data, tmp_data, npoints*sizeof(int16_t));
        free(tmp_data);
    }
    
    //[wf createPeakVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
    [wf createConnectedVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)numActiveChannels andTimePoints:(NSUInteger)npoints/numActiveChannels];
    
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
    int *minpts,res;
    uint32_t nspikes;
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    res = readHMMFromMatfile(fname, &_spikeForms, &nspikes, &nchs, &timepts, &spikes);
    if( res==-1)
    {
        //matlab read failed, try hdf5 read
        res = readHMMFromHDF5file(fname, &_spikeForms, &nspikes, &nchs, &timepts, &spikes);
    }
    if( res != 0)
    {
        //could not read file; return
        return NO;
    }
    [wf createSpikeVertices:[NSData dataWithBytes:spikes length:nspikes*sizeof(float)] numberOfSpikes:nspikes channels:NULL numberOfChannels:NULL];
    free(spikes);
  
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
-(void)checkForReorderingForFile:(NSString*)filename
{
    uint32_t i,k;
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
        reorder = malloc(numChannels*sizeof(int));
        k = 0;
        NSScanner *scanner = [NSScanner scannerWithString:sreorder];
        [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        //find all the ints
        while( ([scanner isAtEnd] == NO ) && (k < numChannels))
        {
            [scanner scanInt:reorder+k];
            k+=1;
        }
        if (k < numChannels)
        {
            for(i=k;i<numChannels;i++)
            {
                //plus one because at this point we are using 1-based indexing
                reorder[i] = i+1;
            }
        }
    }
}

-(void)processWorkspace
{
    //set various default attributes based on what we find in the workspace
    if(workspace != nil)
    {
        NSString *spikeFile = [workspace objectForKey:@"spikeFile"];
        if( spikeFile != nil)
        {
            //ask user if the file should be used
            NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"You have already created a spike file for this data called %@. Do you want to continue using it, or create a new file?",spikeFile]  defaultButton:@"Use old file" alternateButton:@"Create a new file" otherButton:nil informativeTextWithFormat:nil];
            NSInteger res = [alert runModal];
            if( res == NSAlertFirstButtonReturn )
            {
                //Use the file, i.e. load the spikes
                [sp loadSpikesFromFile:spikeFile];
                
            }
            [sp setTemplateFile:spikeFile];
        }
    }
}

    



@end
