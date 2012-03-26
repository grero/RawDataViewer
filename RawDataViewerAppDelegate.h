//
//  RawDataViewerAppDelegate.h
//  RawDataViewer
//
//  Created by Roger Herikstad on 10/8/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "WaveformsView.h"
#import "computations.h"
#import "utils.h"

@interface RawDataViewerAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSWindow *window;
    IBOutlet WaveformsView *wf;
    IBOutlet NSProgressIndicator *progress;
    NSData *signalData; //data containing the signals
    NSData *spikeForms;
}

-(IBAction)openFile:(id)sender;
-(IBAction)saveToPDF:(id)sender;
-(IBAction)savePDFAs:(id)sender;
-(IBAction)changeTime:(id)sender;
-(IBAction)changeAmp:(id)sender;

-(BOOL)loadDataFromFile:(NSString *)filename atOffset:(NSUInteger)offset;
-(BOOL)loadSpikesFromFile:(NSString*)filename;
-(BOOL)loadSpikeTimeStampsFromFile:(NSString*)filename;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformsView *wf;
@property (assign) IBOutlet NSProgressIndicator *progress;
@end
