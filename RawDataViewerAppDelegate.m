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
@synthesize timeOffset;

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
- (BOOL)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames
{
	NSString *filename;
	NSEnumerator *_filenames;
	BOOL res,updateSpikes;
	float _color[3];
	uint32_t ch,*cids,n,i;
	NSRange spikeRange;
	ch = 0;
	spikeRange.location = 0;
	updateSpikes = NO;
	//get an enumerator that will enumerate all the files except any files ending in .cut (see below)
	_filenames = [[filenames filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"NOT SELF  ENDSWITH \".cut\""]] objectEnumerator];
	filename = [_filenames nextObject];
    [[progress window] makeKeyAndOrderFront:self];
    [progress startAnimation:self];
	//reset the spikes
	[sp resetSpikes];
	//reset the selected channels
	[wf selectChannels: [wf selectedChannels] usingColor: NULL];
	while( filename )
	{
		NSRange rWf = [filename rangeOfString:@"waveforms.bin"];
		if(rWf.location != NSNotFound )
		{
			NSRange gwf = [filename rangeOfString:@"g0"];
			if(gwf.location != NSNotFound )
			{
				ch = [[filename substringWithRange: NSMakeRange(gwf.location + 1,rWf.location - gwf.location-1)] intValue];
			}
			//generate a random color for this channel
			srandom(ch);
			_color[0] = ((float)random())/RAND_MAX;
			_color[1] = ((float)random())/RAND_MAX;
			_color[2] = ((float)random())/RAND_MAX;
			[wf selectChannels: [NSIndexSet indexSetWithIndex: ch-1] usingColor: [NSData dataWithBytes: _color length: 3*sizeof(float)]];
			res = [sp loadWaveformsFile:filename];
			n = [sp ntemplates];
			spikeRange.length = n-spikeRange.location;
			[sp assignSpikeID: ch forSpikesInRange: spikeRange];

			//check if we are also loading a cut file
			NSString *cutFilename = [filename stringByReplacingOccurrencesOfString:@"bin" withString:@"cut"];
			if([filenames containsObject: cutFilename] )
			{
				//cids = readClusterIds(fname, cids);
				NSArray *lines = [[NSString stringWithContentsOfFile:cutFilename encoding: NSASCIIStringEncoding error: NULL] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
				uint32_t *cids = malloc(([lines count]+1)*sizeof(uint32_t));
				//iteratae through lines
				NSEnumerator *lines_enum = [lines objectEnumerator];
				id line;
				NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
				int cidx = 0;
				while ( (line = [lines_enum nextObject] ) )
				{
					NSNumber *q = [formatter numberFromString:line];
					//if line is not a string, q is nil
					if( q )
					{
						cids[cidx] = (uint32_t)[q intValue];
						cidx+=1;
					}
					
				}
				//done with formatter, so release it
				[formatter release];
				[sp assignSpikeIDs: [NSData dataWithBytes: cids length: (spikeRange.length)*sizeof(uint32_t)] forSpikesInRange: spikeRange];
				free(cids);
			}
			spikeRange.location = n;
			updateSpikes = YES;


		}
		else if([[filename pathExtension] hasSuffix:@"mat"])
		{
			res = [self loadHmmSortResultsFromFile:filename];
		}
		//else if([[filename pathExtension] isEqualToString:@"bin"])
		else if([[filename pathExtension] isEqualToString:@"hdf5"])
		{

		}
		else if([[filename pathExtension] isEqualToString:@"snc"])
		{
			[sp loadSyncsFile: filename];
			updateSpikes = YES;
		}	
		else
		{
			res = [self loadDataFromFile: filename atOffset: 0];
		}
		filename = [_filenames nextObject];

	}
	//check if we did something to the spikes
	if(updateSpikes)
	{
		[wf createSpikeVertices:[sp spikes] numberOfSpikes:[sp ntemplates] channels:nil numberOfChannels:nil 
						 cellID: [sp cids]];
	}
	[progress stopAnimation:self];
	[[progress window] orderOut:self];
	return res;
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
    int16_t *data,*tmp_data;
    size_t nbytes;
    fname  = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    //check what kind of file we are opening
    NSRange rWf = [filename rangeOfString:@"waveforms.bin"];
    if(rWf.location != NSNotFound )
    {
		[sp resetSpikes];
        res = [sp loadWaveformsFile:filename];
        [wf createSpikeVertices:[sp spikes] numberOfSpikes:[sp ntemplates] channels:nil numberOfChannels:nil cellID:NULL];
		//get the channel from the file name
		NSRange gwf = [filename rangeOfString:@"g0"];
		if(gwf.location != NSNotFound )
		{
			//de-select any selected channels
			[wf selectChannels: [wf selectedChannels] usingColor: NULL];
			int ch = [[filename substringWithRange: NSMakeRange(gwf.location + 1,rWf.location - gwf.location-1)] intValue];
			[wf selectChannels: [NSIndexSet indexSetWithIndex: ch-1] usingColor: NULL];
		}

        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return res;
    }
    
    else if([[filename pathExtension] hasSuffix:@"mat"])
    {
        res = [self loadHmmSortResultsFromFile:filename];
        [progress stopAnimation:self];
        [[progress window] orderOut:self];
        return res;
    }
    else
    {
        maxSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"maxDataSize"];
        //TODO: estimate the offset by getting the index and assuming each file before this one in the sequence has the same number of data points 

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
        [sp setSamplingRate:(double)samplingRate];
        numChannels = nchs;
        numActiveChannels = nchs;
        //set the filename
        [self setDataFileName:filename];
		int seqnr = [[filename pathExtension] intValue];
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
		//set the temporal offset for this particular chunk of data
		[[self sp] setTimeOffset:(seqnr-1)*npoints/nchs/(samplingRate/1000)];
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
            //NSLog(cwd);
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
                reorderMax = -1;
                int reorderMin = 100;
                while( ([scanner isAtEnd] == NO ) && (k < nchs))
                {
                    [scanner scanInt:reorder+k];
                    reorderMax = MAX(reorderMax,reorder[k]);
                    reorderMin = MIN(reorderMin,reorder[k]);
                    k+=1;
                    
                }
                
                numActiveChannels = k;
                if (reorderMin ==0)
                {
                    for(i=k;i<nchs;i++)
                    {
                        //plus one because at this point we are using 1-based indexing
                        reorder[i] = i+1;
                    }
                    reorderMax+=1;
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
            int16_t *tmp_data;
            //now loop through the data and reorder everything
           
            int16_t d;
            
            if(reorderMax > nchs )
            {
                //this means that we have missing channels
                tmp_data = calloc(ppc*(reorderMax),sizeof(int16_t));
                for(ch=0;ch<numActiveChannels;ch++)
                {
                    for(i=0;i<ppc;i++)
                    {
                        tmp_data[i*(reorderMax)+reorder[ch]-1] = data[i*numChannels+ch];
                    }
                }
                numActiveChannels = reorderMax;
                
            }
            else
            {
                //we need a temporary array to hold the data for each channel
                tmp_data = malloc(ppc*numActiveChannels*sizeof(int16_t));
                
                //now loop through the data and reorder everything
                
                for(ch=0;ch<numActiveChannels;ch++)
                {
                    for(i=0;i<ppc;i++)
                    {
                        tmp_data[i*numActiveChannels+ch] = data[i*numChannels+reorder[ch]-1];
                    }
                }
            }
            free(data);
            data = tmp_data;
            //memcpy(data, tmp_data, ppc*numActiveChannels*sizeof(int16_t));
            //free(tmp_data);
        }
        //test; compute covariance matrix
        //float *cov = malloc(numActiveChannels*numActiveChannels*sizeof(float));
        //computeCovariance(data, numActiveChannels, npoints/numActiveChannels, 1, cov);
        //matrix_inverse(cov, numActiveChannels, NULL);
        //[sp setCinv:[NSData dataWithBytes:cov length:numActiveChannels*numActiveChannels*sizeof(float)]];
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
   NSInvocationOperation* theOp = [[[NSInvocationOperation alloc] initWithTarget:wf 
																		selector:@selector(saveToPDFAtURL:) object:NULL] autorelease];
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
        NSInvocationOperation* theOp = [[[NSInvocationOperation alloc] initWithTarget:wf 
																			 selector:@selector(saveToPDFAtURL:) object:url] autorelease];
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
	[[progress window] setTitle:@"Loading data..."];
    const char *fname;    
    FILE *fid;
    uint32_t headerSize,samplingRate,npoints,maxSize,k,i;
    uint8_t nchs;
    int16_t *data,*tmp_data;
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
    [sp setSamplingRate:(double)samplingRate];
    [self setDataFileName:filename];
	int seqnr = [[filename pathExtension] intValue];
    fseek(fid,0,SEEK_END);
    npoints = (ftell(fid)-headerSize)/sizeof(int16_t);
	//TODO: this assumes a seqnr that is 1 based.
	[[self sp] setTimeOffset:((double)(seqnr-1))*((double)npoints)/((double)nchs)/(((double)samplingRate)/1000)];
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
	if( numActiveChannels == 0)
	{
		numActiveChannels = nchs;
	}
    [self checkForReorderingForFile:filename];
	if( (reorder != NULL ) && ([[NSUserDefaults standardUserDefaults] boolForKey:@"reorderChannels"]))
    {
        NSLog(@"Reordering data...");
        
        uint32_t ch,ppc,tnchs;
        int16_t d;
        ppc = npoints/(uint32_t)nchs;
        if(reorderMax > nchs )
        {
            //this means that we have missing channels
            tmp_data = calloc(ppc*(reorderMax),sizeof(int16_t));
            tnchs = MIN(nchs,numActiveChannels);
            for(ch=0;ch<tnchs;ch++)
            {
                for(i=0;i<ppc;i++)
                {
                    tmp_data[i*(reorderMax)+reorder[ch]-1] = data[i*numChannels+ch];
                }
            }
            numActiveChannels = reorderMax;

        }
        else
        {
            //we need a temporary array to hold the data for each channel
            tmp_data = malloc(ppc*numActiveChannels*sizeof(int16_t));
        
        //now loop through the data and reorder everything
        
            for(ch=0;ch<numActiveChannels;ch++)
            {
                for(i=0;i<ppc;i++)
                {
                    tmp_data[i*numActiveChannels+ch] = data[i*numChannels+reorder[ch]-1];
                }
            }
        }
        npoints = (npoints/nchs)*numActiveChannels;
        free(data);
        data = tmp_data;
        //memcpy(data, tmp_data, npoints*sizeof(int16_t));
        //free(tmp_data);
    }
    
    //[wf createPeakVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
	
	[[progress window] setTitle:@"Drawing data..."];
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
    [wf createSpikeVertices:[NSData dataWithBytes:spikes length:numSpikes*sizeof(float)] numberOfSpikes:numSpikes channels:NULL numberOfChannels:NULL cellID:NULL];
    free(spikes);
    return YES;
    
}

-(BOOL)loadHmmSortResultsFromFile:(NSString*)filename
{
    const char* fname;
    double *mlseq,minpt,d;
    float *spikes,*_spikeForms;
    int16_t *data;
    uint32_t ntemps,nchs,timepts,npoints,i,j,ch,k;
    int *minpts,res;
    uint32_t nspikes, *cids,nSpikeForms;
	NSUInteger *channels,*nchannels;
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
	//get the channel from the group
	NSRange rWf = [filename rangeOfString:@".mat"];
	NSRange gwf = [filename rangeOfString:@"g0"];
	if(gwf.location != NSNotFound )
	{
		ch = [[filename substringWithRange: NSMakeRange(gwf.location + 1,rWf.location - gwf.location-1)] intValue];
		ch-=1;
	}
    res = readHMMFromMatfile(fname, &_spikeForms, &nspikes, &nchs, &timepts, &spikes, &cids,&nSpikeForms,&data,&npoints,[sp samplingRate]/1000.0);
    if( res==-1)
    {
        //matlab read failed, try hdf5 read
        res = readHMMFromHDF5file(fname, &_spikeForms, &nspikes, &nchs, &timepts, &spikes,&cids,&nSpikeForms,&data,&npoints,[sp samplingRate]/1000.0);
    }
    if( res != 0)
    {
        //could not read file; return
        return NO;
    }
    if( data != NULL )
    {
        [wf createConnectedVertices:[NSData dataWithBytes:data length:npoints*nchs*sizeof(int16_t)] withNumberOfWaves:0 channels:nchs andTimePoints:npoints];
    }
	channels = malloc(2*nspikes*sizeof(NSUInteger));
	nchannels = malloc(nspikes*sizeof(NSUInteger));
	for(i=0;i<nspikes;i++)
	{
		channels[2*i] = ch;
		channels[2*i+1] = ch+1;
		nchannels[i] = 1;
	}
    [sp setTemplates:[NSMutableData dataWithBytes:_spikeForms length:nSpikeForms*nchs*timepts*sizeof(float)]];
    [sp setSpikes:[NSMutableData dataWithBytes:spikes length:nspikes*sizeof(float)]];
    [sp setNspikes:nspikes];
    [sp setNtemplates:nSpikeForms];
    [sp setCids:[NSMutableData dataWithBytes:cids length:nspikes*sizeof(uint32_t)]];
	[sp setChannels: [NSMutableData dataWithBytes: channels length: nspikes*2*sizeof(NSUInteger)]];
	[sp setNumChannels: [NSMutableData dataWithBytes: nchannels length: nspikes*sizeof(NSUInteger)]];
	[sp setTimepts: timepts];
    [wf createSpikeVertices:[NSData dataWithBytes:spikes length:nspikes*sizeof(float)] numberOfSpikes:nspikes channels:NULL numberOfChannels:NULL cellID:[NSData dataWithBytes:cids length:nspikes*sizeof(uint32_t)]];
    [wf createTemplateVertices:[sp templates] timestamps:[sp spikes] numberOfSpikes:nspikes timepts:timepts 
					  channels:[NSData dataWithBytes: channels length:nspikes*2*sizeof(NSUInteger)] 
			  numberOfChannels:[NSData dataWithBytes: nchannels length: nspikes*sizeof(NSUInteger)] cellID:[sp cids]];
	free(channels);
	free(nchannels);
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
		//also redraw the template vertices, but only if requested
		if( [wf drawTemplates] )
		{
			[wf createTemplateVertices:[sp templates] timestamps:[sp spikes] numberOfSpikes:[sp nspikes] timepts:[sp timepts]
						  channels:[sp channels] 
				  numberOfChannels:[sp numChannels] cellID:[sp cids]];
		}

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"loadMoreData" object:nil];
    }
}
-(void)checkForReorderingForFile:(NSString*)filename
{
    uint32_t i,k,l;
    NSString *sreorder,*reOrderPath;
    int mxCh;
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    //check for reorder in cwd
    //NSLog(cwd);
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
        int reorderMin = 100;
        reorderMax = -1;
        while( ([scanner isAtEnd] == NO ) && (k < numChannels))
        {
            [scanner scanInt:reorder+k];
            reorderMax = MAX(reorderMax,reorder[k]);
            reorderMin = MIN(reorderMin,reorder[k]);
            k+=1;

        }
        
        if (k < numChannels)
        {
            for(i=k;i<numChannels;i++)
            {
                //plus one because at this point we are using 1-based indexing
                reorder[i] = i+1;
            }
            reorderMax+=1;
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
