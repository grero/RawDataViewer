//
//  SignalProcessor.h
//  RawDataViewer
//
//  Created by Roger Herikstad on 24/3/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SignalProcessor : NSObject {
    IBOutlet NSView *signalView;
    
    //NSMutableArray *templates;
    //array of arrays
    NSMutableData *templates,*spikes;
    NSMutableData *numChannels;
    uint32_t ntemplates;
    NSString *templateFile;
    
}

@property (retain,readwrite) NSString *templateFile;
@property (retain,readwrite) NSMutableData *spikes,*templates;
@property (readonly)  uint32_t ntemplates;

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(uint32_t)nchs atTimePoint:(float)timept;
-(BOOL)saveTemplates:(NSString*)filename;
-(BOOL)loadSpikesFromFile:(NSString*)filename;
-(BOOL)loadWaveformsFile:(NSString*)filename;
-(BOOL)saveWaveformsFile:(NSString*)filename;
@end
