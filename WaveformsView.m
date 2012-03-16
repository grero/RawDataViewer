//
//  WaveformsView.m
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveformsView.h"

#ifndef MIN
#define MIN(a,b) ((a)>(b)?(b):(a))
#endif
#ifndef MAX
#define MAX(a,b) ((a)>(b)?(a):(b))
#endif
#define PI 3.141516

@implementation WaveformsView

@synthesize highlightWaves;
@synthesize highlightedChannels;

-(void)awakeFromNib
{
    dataLoaded = NO;
}

-(BOOL)acceptsFirstResponder
{
    return YES;
}

+(NSOpenGLPixelFormat*) defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAAllRenderers,YES,
        NSOpenGLPFADoubleBuffer, YES,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 16,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    return pixelFormat;
}



-(id) initWithFrame:(NSRect)frameRect
{
    return [self initWithFrame:frameRect pixelFormat: [WaveformsView defaultPixelFormat]];

}

-(id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format
{
    self = [super initWithFrame:frameRect];
    if( self != nil)
    {
        _pixelFormat = [format retain];
        [self setOpenGLContext: [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil]];
        [[self openGLContext] makeCurrentContext];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector:@selector(_surfaceNeedsUpdate:)
                                                     name: NSViewGlobalFrameDidChangeNotification object: self];
        
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) 
        //                                             name:@"highlight" object:nil];
    }
    return self;
}

-(void) _surfaceNeedsUpdate:(NSNotification*)notification
{
    [self update];
}

-(void) lockFocus
{
    NSOpenGLContext *context = [self openGLContext];
    
    [super lockFocus];
    if( [context view] != self )
    {
        [context setView:self];
    }
    [context makeCurrentContext];
}

-(BOOL) isOpaque
{
    return YES;
}

-(void) setOpenGLContext:(NSOpenGLContext *)context
{
    _oglContext = [context retain];
}

-(NSOpenGLContext*)openGLContext
{
    return _oglContext;
}

-(void)clearGLContext
{
    [[self openGLContext] clearCurrentContext];
    [[self openGLContext] release];
}

-(void)setPixelFormat:(NSOpenGLPixelFormat *)pixelFormat
{
    _pixelFormat = [pixelFormat retain];
}

-(NSOpenGLPixelFormat*)pixelFormat
{
    return _pixelFormat;
}

-(void)update
{
    if( [[self openGLContext] view] == self)
    {
		[self reshape];
        [[self openGLContext] update];
        //TODO: Something happens here; somehow the view doesn't get upated properly when the window is resized.
        //[[self openGLContext] flushBuffer];
		
    }
}



-(void) createPeakVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger) timepoints
{
    NSUInteger npoints,ch,i,j,k,chunkSize;
    int16_t *_data;
    GLfloat peak,trough,d,offset;
    GLfloat *limits;
    npoints = timepoints;
	_data = (int16_t*)[vertex_data bytes];
    //we want to create peaks every 8 points
    chunkSize = 8;
    numPoints = 2*(npoints/chunkSize)*channels;
    vertices = malloc(3*2*(npoints/chunkSize)*channels*sizeof(GLfloat));
    colors = malloc(3*2*(npoints/chunkSize)*channels*sizeof(GLfloat));
    indices = malloc(2*(npoints/chunkSize)*channels*sizeof(GLuint));
    //vector to hold the min/max for each channel
    limits = calloc(2*ch,sizeof(GLfloat));
    
    //this works because the data is organized in channel order
    offset = 0;
    xmin = 0;
    //sampling rate of 30 kHz
    xmax = timepoints/30.0;
    xmax = 20000;
    //find the minimum and maximum for each channel
    for(ch=0;ch<channels;ch++)
    {   
        for(i=0;i<npoints;i++)
        {
            d = (GLfloat)(_data[i*channels+ch]);
            limits[2*ch] = MIN(d,limits[2*ch]);           
            limits[2*ch+1] = MAX(d,limits[2*ch+1]);

        }
    }
    
    for(ch=0;ch<channels;ch++)
    {
        if(ch>0)
        {
            //the offset should be the maximum of the previous channel minus the minimum of this channel
            offset += (-limits[2*ch] + limits[2*(ch-1)+1]);
        }
        else
        {
            offset = -limits[2*ch];
        }
        //maxPeak = 0;
        //maxTrough = 0;
        for(i=0;i<npoints;i+=chunkSize)
        {
            peak = -INFINITY;
            trough = INFINITY;
            for(j=0;j<chunkSize;j++)
            {
                d = (GLfloat)_data[channels*(i+j)+ch];
                
                peak = MAX(peak,d);
                trough = MIN(trough,d);
            }
            k = ch*(npoints/chunkSize) + i/chunkSize;
            //x
            vertices[6*k] = ((GLfloat)i)/30.0;
            //y
            vertices[6*k+1] = trough+offset;
            //z
            vertices[6*k+2] = 0.5;//2*((float)random())/RAND_MAX-1;
            //x
            vertices[6*k+3] = ((GLfloat)i)/30.0;
            //y
            vertices[6*k+4] = peak+offset;
            //z
            vertices[6*k+5] = 0.5;//2*((float)random())/RAND_MAX-1;
            
            //color
            colors[6*k] = 1.0f;
            colors[6*k+1] = 0.5f;
            colors[6*k+2] = 0.3f;
            
            colors[6*k+3] = 1.0f;
            colors[6*k+4] = 0.5f;
            colors[6*k+5] = 0.3f;
            
            //index
            indices[2*k] = 2*k;
            indices[2*k+1] = 2*k+1;
        }
    }
    //we don't need limits anymore
    free(limits);
    dz = 0.0;
    dx =0.0;
    ymax = offset;
    ymin = 0;
    [[self openGLContext] makeCurrentContext];
    //vertices have been created, now push those to the GPU
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer  );
    //allocate space for the buffer
    glBufferData(GL_ARRAY_BUFFER, 2*3*numPoints*sizeof(GLfloat), 0, GL_STATIC_DRAW);
    GLfloat *_vdata = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    //copy vertices
    memcpy(_vdata, vertices, 3*numPoints*sizeof(GLfloat));
    //copy colors
    memcpy(_vdata + 3*numPoints, colors, 3*numPoints*sizeof(GLfloat));
    glUnmapBuffer(GL_ARRAY_BUFFER );
    
    //let opengl know how the data is packed
    glVertexPointer(3, GL_FLOAT, 0, (GLvoid*)0);
    glColorPointer(3, GL_FLOAT, 0, (GLvoid*)((char*)NULL + 3*numPoints*sizeof(GLfloat)));
    //notify that we have loaded the data
    dataLoaded = YES;
    [self setNeedsDisplay: YES];
}


-(void) highlightChannels:(NSArray*)channels
{
	[[self openGLContext] makeCurrentContext];
}





- (void)drawRect:(NSRect)bounds 
{
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
	
	//glLoadIdentity();
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);

    glClearColor(0,0,0,0);
    glClearDepth(1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	//glLoadIdentity();
    //glClear(GL_DEPTH_BUFFER_BIT);
    if(dataLoaded)
    {
		//[self drawLabels];
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		
		/*glOrtho(1.05*xmin-0.05*xmax, 1.05*xmin-0.05*xmax, 1.05*wfMinmax[2]-0.05*wfMinmax[3], 
				1.05*wfMinmax[3]-0.05*wfMinmax[2], wfMinmax[4], wfMinmax[5]);*/
        glOrtho(xmin+dx, 10000+dx, 1.1*ymin, 1.1*ymax, -2.0+dz, 3.0+dz);
        		//activate the dynamicbuffer
        
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glEnableClientState(GL_VERTEX_ARRAY);

        
        //glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glEnableClientState(GL_COLOR_ARRAY);
         
        glDrawArrays(GL_LINES, 0, numPoints);
        
        //GLenum e = glGetError();
        //NSLog(@"gl error: %d", e);
    }
    glFlush();
    [context flushBuffer];
}

- (void) reshape
{
 //reshape the view
    NSRect bounds = [self bounds];
    [[self openGLContext] makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    //[self display];
	//[self setNeedsDisplay:YES];    
    
}


- (void) prepareOpenGL
{
    //prepare openGL context
    //wfDataloaded = NO;
    NSOpenGLContext *context = [self openGLContext];
    NSRect bounds = [self bounds];
    [context makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    glLineWidth(1.33);
    glClearColor(0,0, 0, 0);
    glClearDepth(1.0);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glPointSize(10.0f);
    //glShadeModel(GL_SMOOTH);
    //glPointSize(4.0);
    glEnable(GL_BLEND);
    //glEnable(GL_POINT_SMOOTH);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_DST_ALPHA);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    [context flushBuffer];
           
}



-(void) receiveNotification:(NSNotification*)notification
{
    if([[notification name] isEqualToString:@"highlight"])
    {
        [self highlightWaveforms:[[notification userInfo] objectForKey:@"points"]];
    }
}
    
-(void)mouseUp:(NSEvent *)theEvent
{
	//TODO: modify this to incorproate the new index
    //get current point in view coordinates
    NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    //now we will have to figure out which waveform(s) contains this point
    //scale to data coorindates
    NSPoint dataPoint;
    NSRect viewBounds = [self bounds];
    //scale to data coordinates
    dataPoint.x = (currentPoint.x*(xmax-xmin))/viewBounds.size.width+xmin;
    dataPoint.y = (currentPoint.y*(1.1*ymax-1.1*ymin))/viewBounds.size.height+1.1*ymin;
    //here, we can simply figure out the smallest distance between the vector defined by
    //(dataPoint.x,dataPoint.y) and the waveforms vectors
    
    
}

/*-(void)removePoints:(NSIndexSet*)points
{
    //moves the points in indexset from the currently drawn points to the 0-zero cluster
    
}*/


-(void)saveToEPS
{
    NSRect bounds = [self bounds];
    //allocate an image and intialize with the size of the view
    NSImage *image = [[NSImage alloc] initWithSize: bounds.size];
    //add an EPS representation
    NSEPSImageRep *imageRep = [[NSEPSImageRep alloc] init];
    [image addRepresentation: imageRep];
    
    [image lockFocus];
    
        
    [image unlockFocus];
     //get the data
    NSData *imageData = [imageRep EPSRepresentation];
    [imageData writeToFile:@"test.eps" atomically:YES];
    
}

-(NSImage*)image
{
    //for drawing the image
    NSBitmapImageRep *imageRep;
    NSImage *image;
    NSSize viewSize = [self bounds].size;
    int width = viewSize.width;
    int height = viewSize.height;
    
    //[self lockFocus];
    //[self lockFocusIfCanDraw];
    //[self drawRect:[self bounds]];
    //[self unlockFocus];
    [self display];
    imageRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL 
                                                        pixelsWide: width 
                                                        pixelsHigh: height 
                                                      bitsPerSample: 8 
                                                   samplesPerPixel: 4 
                                                          hasAlpha: YES 
                                                          isPlanar: NO 
                                                    colorSpaceName: NSDeviceRGBColorSpace 
                                                       bytesPerRow: width*4     
                                                       bitsPerPixel:32] autorelease];
    
    [[self openGLContext] makeCurrentContext];
    //bind the vertex buffer as an pixel buffer
    //glBindBuffer(GL_PIXEL_PACK_BUFFER, wfVertexBuffer);
    glReadPixels(0,0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, [imageRep bitmapData]);
    image = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
    [image addRepresentation:imageRep];
    [image lockFocusFlipped:YES];
    [imageRep drawInRect:NSMakeRect(0,0,[image size].width, [image size].height)];
    [image unlockFocus];
    return image;
}

//Indicate what kind of drag-operation we are going to support
-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)localDestination
{
	return NSDragOperationMove;
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
    } else {
	}
}

-(void) deleteBackward:(id)sender
{
	
}

//TODO: this is a bit experimental
-(void)scrollWheel:(NSEvent *)theEvent
{
	//set a threshold for when we accept a scroll
	if([theEvent deltaX] > 1 )
	{
		[self moveRight:self];
	}
	else if ( [theEvent deltaX] < -1 )
	{
		[self moveLeft:self];
	}
    dz = [theEvent deltaY];
    dx += [theEvent deltaX]*10;
    [self setNeedsDisplay:YES];
}

-(IBAction)moveRight:(id)sender
{
	//shift highlighted waveform downwards
	
}

-(IBAction)moveLeft:(id)sender
{
	//shift highlighted waveform downwards
}	

-(void)dealloc
{
    free(vertices);
    free(indices);
    //free(wfMinmax);
    free(colors);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewGlobalFrameDidChangeNotification
                                                  object:self];
    [self clearGLContext];
    [_pixelFormat release];
    [drawingColor release];
    [highlightColor release];
	[waveformIndices release];
    [super dealloc];
}

@end