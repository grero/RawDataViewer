//
//  RawDataViewerAppDelegate.m
//  RawDataViewer
//
//  Created by Roger Herikstad on 10/8/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "RawDataViewerAppDelegate.h"

@implementation RawDataViewerAppDelegate

@synthesize window;
@synthesize wf;
@synthesize progress;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
    //we wantt to use threaded animation
    [progress setUsesThreadedAnimation: YES];
    [progress setIndeterminate: YES];
}
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
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
    
    maxSize = 20; //limit the amount of data to load to 20 MB
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
        for(ch=0;ch<nchs;ch++)
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

@end
