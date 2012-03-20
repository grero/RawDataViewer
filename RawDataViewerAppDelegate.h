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
    IBOutlet NSWindow *window;
    IBOutlet WaveformsView *wf;
    IBOutlet NSProgressIndicator *progress;
    
    NSData *signalData; //data containing the signals
    
}

-(IBAction)openFile:(id)sender;
-(IBAction)saveToPDF:(id)sender;

-(BOOL)loadDataFromFile:(NSString *)filename atOffset:(NSUInteger)offset;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformsView *wf;
@property (assign) IBOutlet NSProgressIndicator *progress;
@end
