//
//  WaveformsView.h
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>

#import "SignalProcessor.h"

//#import "GLString.h"

static void wfPushVertices();
static void wfModifyVertices(GLfloat *vertex_data);
static void wfModifyIndices(GLuint *index_data);
static void wfModifyColors(GLfloat *color_data, GLfloat *color);

@interface WaveformsView : NSView {

    @private
    NSOpenGLContext *_oglContext;
    NSOpenGLPixelFormat *_pixelFormat;
    NSData *drawingColor,*highlightColor;
    NSMutableData *highlightWaves;
	NSMutableArray *highlightedChannels;
	//data to hold information on which waveforms are active
	NSMutableIndexSet *waveformIndices;
    NSUInteger numPoints,numChannels,chunkSize,vertexOffset,zoomStackIdx,zoomStackLength;
    GLfloat xmax,xmin,ymax,ymin,windowSize,ySpan;
    GLfloat *vertices,*colors,*channelLimits,*zoomStack,*channelOffsets;
    GLuint *indices;
    GLfloat dz,dx,dy,tx,ty;
    GLuint indexBuffer,vertexBuffer,colorBuffer;
    NSUInteger drawingMode; //which mode are we using to draw (peak/all)
    GLfloat currentX,currentY;

    BOOL dataLoaded;
    
    SignalProcessor *sp;
    IBOutlet NSTextField *timeCoord,*ampCoord;
}
@property (assign,readwrite) GLfloat currentX,currentY;
@property (assign,readwrite) IBOutlet NSTextField *timeCoord,*ampCoord;
@property (retain,readwrite) NSMutableData *highlightWaves;
@property (retain,readwrite) NSMutableArray *highlightedChannels;


//OpenGL related functions
+(NSOpenGLPixelFormat*)defaultPixelFormat;
-(id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format;
-(void) setOpenGLContext: (NSOpenGLContext*)context;
-(NSOpenGLContext*)openGLContext;
-(void) clearGLContext;
-(void) prepareOpenGL;
-(void) update;
-(void) drawLabels;
-(void) setPixelFormat:(NSOpenGLPixelFormat*)pixelFormat;
-(NSOpenGLPixelFormat*)pixelFormat;
-(void) _surfaceNeedsUpdate:(NSNotification *)notification;
-(void) setColor:(NSData*)color;
-(NSData*)getColor;
-(NSData*)getHighlightColor;
-(BOOL)isOpaque;
//others
-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints andColor: (NSData*)color andOrder: (NSData*)order;
-(void) createPeakVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger) timepoints;
-(void)createConnectedVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger) timepoints;
-(void) highlightWaveform:(NSUInteger)wfidx;
-(void) highlightWaveforms:(NSData*)wfidx;
-(void) highlightChannels:(NSArray*)channels;
-(void) receiveNotification:(NSNotification*)notification;
-(void) hideWaveforms:(NSData*)wfidx;
-(void) hideOutlierWaveforms;
-(void)showOnlyHighlighted;
-(NSImage*)image;
-(void) createAxis;
-(void)saveToPDFAtURL:(NSURL*)url;


@end
