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
    NSMutableData *templates;
    NSMutableData *numChannels;
    uint32_t ntemplates;
    NSString *templateFile;
    
}

@property (retain,readwrite) NSString *templateFile;

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(uint32_t)nchs;
-(BOOL)saveTemplates:(NSString*)filename;
@end
