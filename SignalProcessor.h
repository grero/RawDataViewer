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
    NSMutableData *numChannels,*cinv,*channels;
    NSMutableDictionary *cells;
    uint32_t ntemplates,nspikes,timepts;
    NSString *templateFile;
    double samplingRate,timeOffset;
    
}

@property (retain,readwrite) NSString *templateFile;
@property (retain,readwrite) NSMutableData *spikes,*templates,*cinv,*cids,*channels,*numChannels;
@property (retain,readwrite) NSMutableDictionary *cells;
@property (assign,readwrite)  uint32_t ntemplates,nspikes,timepts;
@property (assign,readwrite) double samplingRate,timeOffset;

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(uint32_t)nchs atTimePoint:(float)timept;
-(BOOL)saveTemplates:(NSString*)filename;
-(BOOL)loadSpikesFromFile:(NSString*)filename;
-(BOOL)loadSyncsFile:(NSString*)filename;
-(BOOL)loadWaveformsFile:(NSString*)filename;
-(BOOL)saveWaveformsFile:(NSString*)filename;
-(void)decodeData:(NSData*)data numRows: (uint32_t)nrows numCols:(uint32_t)ncols channelOffsets:(NSData*)offsets;
-(void)resetSpikes;
-(void)assignSpikeID:(NSInteger)spid;
-(void)assignSpikeID:(NSInteger)spid forSpikesInRange: (NSRange)range;
-(void)assignSpikeIDs:(NSData*)spids forSpikesInRange: (NSRange)range;

@end
