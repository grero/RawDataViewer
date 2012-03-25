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
    
}

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(NSInteger)nchs;
-(BOOL)saveTemplates:(NSString*)filename;
@end
