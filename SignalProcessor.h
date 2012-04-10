//
//  SignalProcessor.h
//  RawDataViewer
//
//  Created by Roger Herikstad on 24/3/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "computations.h"

@interface SignalProcessor : NSObject {
    IBOutlet NSView *signalView;
    
    //NSMutableArray *templates;
    //array of arrays
    NSMutableData *templates,*spikes,*cids;
    NSMutableData *numChannels,*cinv;
    NSMutableDictionary *cells;
    uint32_t ntemplates,nspikes;
    NSString *templateFile;
    
}

@property (retain,readwrite) NSString *templateFile;
@property (retain,readwrite) NSMutableData *spikes,*templates,*cinv,*cids;
@property (retain,readwrite) NSMutableDictionary *cells;
@property (assign,readwrite)  uint32_t ntemplates,nspikes;

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(uint32_t)nchs atTimePoint:(float)timept;
-(BOOL)saveTemplates:(NSString*)filename;
-(BOOL)loadSpikesFromFile:(NSString*)filename;
-(BOOL)loadWaveformsFile:(NSString*)filename;
-(BOOL)saveWaveformsFile:(NSString*)filename;
-(void)decodeData:(NSData*)data numRows: (uint32_t)nrows numCols:(uint32_t)ncols channelOffsets:(NSData*)offsets;

@end
