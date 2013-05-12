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
#import "SignalProcessor.h"
#import "fileReader.h"
#import <matio.h>

@interface RawDataViewerAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSWindow *window;
    IBOutlet WaveformsView *wf;
    IBOutlet SignalProcessor *sp;
    IBOutlet NSProgressIndicator *progress;
    NSData *signalData; //data containing the signals
    NSData *spikeForms;
    NSString *dataFileName;
    NSUInteger numChannels,numActiveChannels;
    NSMutableDictionary *workspace;
    int *reorder,reorderMax;
    BOOL reorderMissing;
	double  timeOffset;
}

-(IBAction)openFile:(id)sender;
-(IBAction)saveToPDF:(id)sender;
-(IBAction)savePDFAs:(id)sender;
-(IBAction)changeTime:(id)sender;
-(IBAction)changeAmp:(id)sender;
-(IBAction)toggleSpikeView:(id)sender;

-(BOOL)loadDataFromFile:(NSString *)filename atOffset:(NSUInteger)offset;
-(BOOL)loadSpikesFromFile:(NSString*)filename;
-(BOOL)loadSpikeTimeStampsFromFile:(NSString*)filename;
-(BOOL)loadHmmSortResultsFromFile:(NSString*)filename;
-(void)checkForReorderingForFile:(NSString*)filename;
-(void)receiveNotification:(NSNotification*)notification;
-(void)processWorkspace;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WaveformsView *wf;
@property (assign) IBOutlet SignalProcessor *sp;
@property (assign) double timeOffset;

@property (assign) IBOutlet NSProgressIndicator *progress;
@property (retain,readwrite) NSString *dataFileName;
@property (retain,readwrite) NSMutableDictionary *workspace;
@end
