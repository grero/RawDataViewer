//
//  RawDataViewerAppDelegate.h
//  RawDataViewer
//
//  Created by Roger Herikstad on 10/8/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "WaveformsView.h"

@interface RawDataViewerAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformsView *wf;
@end
