//
//  SignalProcessor.m
//  RawDataViewer
//
//  Created by Roger Herikstad on 24/3/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "SignalProcessor.h"

@implementation SignalProcessor

- (id)init
{
    self = [super init];
    if (self) {
        templates = [[[[NSMutableData alloc] init] retain] autorelease];
        numChannels  = [[[[NSMutableData alloc] init] retain] autorelease];
        }
    
    return self;
}

-(void)addTemplate:(float*)spike length:(NSInteger)n numChannels:(NSInteger)nchs
{
    [templates appendBytes:spike length:n*sizeof(double)];
    [numChannels appendBytes:&nchs length:sizeof(NSInteger)];
}

-(BOOL)saveTemplates:(NSString*)filename
{
    
}

@end
