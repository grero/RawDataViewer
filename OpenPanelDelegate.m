//
//  OpenPanelDelegate.m
//  FeatureViewer
//
//  Created by Grogee on 10/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "OpenPanelDelegate.h"


@implementation OpenPanelDelegate

@synthesize basePath;
@synthesize extension;
@synthesize extensions;

-(BOOL)panel:(id)sender shouldEnableURL: (NSURL*)url
{
    char const *path;
    uint32_t headerSize,samplingRate;
    uint8_t numChannels;
    FILE *fid;
    
    path = [[url path] cStringUsingEncoding: NSASCIIStringEncoding];
    
    //check if the file is valid; by reading the header
    fid = fopen(path,"r");
    fread(&headerSize,sizeof(uint32_t),1,fid);
    if( (headerSize != 73) && (headerSize != 90) )
    {
        fclose(fid);
        return NO;
    }
    fclose(fid);
    return YES;
}

@end
