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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
}
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    //read data from the file
    const char *fname;    
    FILE *fid;
    uint32_t headerSize,samplingRate,npoints;
    uint8_t nchs;
    int16_t *data;
    size_t nbytes;
    
    fname  = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    fid = fopen(fname, "rb");
    //get the header size
    fread(&headerSize, sizeof(uint32_t), 1, fid);
    //get the number of channels
    fread(&nchs,sizeof(uint8_t),1,fid);
    //get the sampling rate
    fread(&samplingRate,sizeof(uint32_t),1,fid);
    fseek(fid,0,SEEK_END);
    npoints = (ftell(fid)-headerSize)/sizeof(int16_t);
    
    data = malloc(npoints*sizeof(int16_t));
    fseek(fid,headerSize,SEEK_SET);
    nbytes = fread(data,sizeof(int16_t),npoints,fid);
    fclose(fid);
    if(nbytes != npoints )
    {
        NSLog(@"Could not open file %s", fname);
        return NO;
    }
    
    [wf createPeakVertices:[NSData dataWithBytes:data length:npoints*sizeof(int16_t)] withNumberOfWaves:0 channels:(NSUInteger)nchs andTimePoints:(NSUInteger)npoints/nchs];
    //we don't need to keep the data
    free(data);
    return YES;
    
}

@end
