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
    //initialize variables
    vertices = NULL;
    colors = NULL;
    indices = NULL;
    vertexOffset = 0;
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
    NSUInteger npoints,ch,i,j,k;
    int16_t *_data;
    GLfloat peak,trough,d,offset;
    GLfloat *limits;
    npoints = timepoints;
	_data = (int16_t*)[vertex_data bytes];
    //we want to create peaks every 8 points
    chunkSize = 8;
    numPoints = 2*(npoints/chunkSize)*channels;
    //check if we already have allocate space; if so, free
    if( vertices != NULL)
    {
        vertices = realloc(vertices,3*numPoints*sizeof(GLfloat));
    }
    else
    {
        vertices = malloc(3*numPoints*sizeof(GLfloat));
    }
    if( colors != NULL)
    {
        colors = realloc(colors,3*numPoints*sizeof(GLfloat));
    }
    else
    {
        colors = malloc(3*numPoints*sizeof(GLfloat));
    }
    if(indices != NULL)
    {
        indices = realloc(indices,numPoints*sizeof(GLuint));
    }
    else
    {
        indices = malloc(numPoints*sizeof(GLuint));
    }
    //vector to hold the min/max for each channel
    limits = calloc(2*channels,sizeof(GLfloat));
    
    //this works because the data is organized in channel order
    offset = 0;
    xmin = 0;
    //sampling rate of 30 kHz
    xmax = timepoints/30.0;
    windowSize = MIN(10000,xmax);
    //xmax = 20000;
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
    ymax = offset+limits[2*(channels-1)+1];
    free(limits);
    dz = 0.0;
    dy = 0.0;
    dx =0.0;
    //add maximum of the last channel to the offset
    
    ySpan = ymax;
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
    drawingMode = 1; //indicate that we are drawing peaks
    [self setNeedsDisplay: YES];
}

-(void) createConnectedVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger) timepoints
{
    NSUInteger npoints,ch,left;//i,j,k,pidx,tidx;
    int16_t *_data;
    //GLfloat offset;//d,peak,trough;
    GLfloat *limits,*choffsets;
    dispatch_queue_t queue;
    
    npoints = timepoints;
    numChannels = channels;
	_data = (int16_t*)[vertex_data bytes];
    //we want to create peaks every 8 points
    chunkSize = 8;
    left = npoints - (npoints/chunkSize)*chunkSize; //figure out how much we have to pad
    numPoints = npoints*channels;
    //check if we already have allocate space; if so, free
    if( vertices != NULL)
    {
        vertices = realloc(vertices,3*numPoints*sizeof(GLfloat));
    }
    else
    {
        vertices = malloc(3*numPoints*sizeof(GLfloat));
    }
    if( colors != NULL)
    {
        colors = realloc(colors,3*numPoints*sizeof(GLfloat));
    }
    else
    {
        colors = malloc(3*numPoints*sizeof(GLfloat));
    }
    if(indices != NULL)
    {
        indices = realloc(indices,2*numPoints*sizeof(GLuint));
    }
    else
    {
        indices = malloc(2*numPoints*sizeof(GLuint));
    }
    //vector to hold the min/max for each channel
    limits = calloc(2*channels,sizeof(GLfloat));
    choffsets = malloc(channels*sizeof(GLfloat));
    //this works because the data is organized in channel order
    //offset = 0;
    xmin = 0;
    //sampling rate of 30 kHz
    xmax = timepoints/30.0;
    windowSize = MIN(10000,xmax);
    //xmax = 20000;
    //find the minimum and maximum for each channel
    queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(channels, queue, ^(size_t c) 
    { 
        NSUInteger i;
        GLfloat d;
        for(i=0;i<npoints;i++)
        {
            d = (GLfloat)(_data[i*channels+c]);
            limits[2*c] = MIN(d,limits[2*c]);           
            limits[2*c+1] = MAX(d,limits[2*c+1]);
            
        }
    });
    choffsets[0] = -limits[0];
    for(ch=1;ch<channels;ch++)
    {
        choffsets[ch] = choffsets[ch-1] + (-limits[2*ch] + limits[2*(ch-1)+1]);
    }
    
    //for(ch=0;ch<channels;ch++)
    dispatch_apply(channels, queue, ^(size_t c) 
    {
        NSUInteger i,j,tidx,pidx,k,l;
        GLfloat offset,peak,trough,d;
        
        offset = choffsets[c];
        l = (npoints/chunkSize)*chunkSize;
        for(i=0;i<l;i+=chunkSize)
        {
            //find the peak and trough
            peak = -INFINITY;
            trough = INFINITY;
            tidx = 0;
            pidx = 0;
            for(j=0;j<chunkSize;j++)
            {
                d = (GLfloat)_data[channels*(i+j)+c];
                //do we over-write something here?
                k = c*npoints + i + j;
                
                //determine the peak/trough indices
                pidx = d > peak ? k : pidx;
                peak = MAX(peak,d);
                tidx = d < trough ? k : tidx;
                trough = MIN(trough,d);
            

                
                //x
                vertices[3*k] = ((GLfloat)(i + j))/30.0;
                //y
                vertices[3*k+1] = d + offset;
                //z
                vertices[3*k+2] = 0.5;//2*((float)random())/RAND_MAX-1;
                
                //color
                colors[3*k] = 1.0f;
                colors[3*k+1] = 0.5f;
                colors[3*k+2] = 0.3f;
                
                
            }
    
            //index
            indices[2*c*((npoints+i)/chunkSize)] = tidx;
            indices[2*c*((npoints+i)/chunkSize)+1] = pidx;
        }
        //do the remainder separately
        //find the peak and trough
        peak = -INFINITY;
        trough = INFINITY;
        tidx = 0;
        pidx = 0;
        l = npoints-(npoints/chunkSize)*chunkSize;
        for(j=0;j<l;j++)
        {
            d = (GLfloat)_data[channels*(i+j)+c];
            //do we over-write something here?
            k = c*npoints + i + j;
            
            //determine the peak/trough indices
            pidx = d > peak ? k : pidx;
            peak = MAX(peak,d);
            tidx = d < trough ? k : tidx;
            trough = MIN(trough,d);
            
            
            
            //x
            vertices[3*k] = ((GLfloat)(i + j))/30.0;
            //y
            vertices[3*k+1] = d + offset;
            //z
            vertices[3*k+2] = 0.5;//2*((float)random())/RAND_MAX-1;
            
            //color
            colors[3*k] = 1.0f;
            colors[3*k+1] = 0.5f;
            colors[3*k+2] = 0.3f;

        }
    });

    float m;
    vDSP_minv(vertices, 3, &m, numPoints);
    //we don't need limits anymore
    ymax = choffsets[channels-1]+limits[2*(channels-1)+1];
    free(limits);
    free(choffsets);
    dz = 0.0;
    dy = 0.0;
    dx =0.0;
    //add maximum of the last channel to the offset
    
    ySpan = ymax;
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
    //indices
    glGenBuffers(1,&indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 2*numPoints/chunkSize*sizeof(GLuint), indices, GL_STATIC_DRAW);
    
    
    glIndexPointer(GL_UNSIGNED_INT, 0, (GLvoid*)0);
    //notify that we have loaded the data
    dataLoaded = YES;
    drawingMode = 0;//indicate that we are drawing everything
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
		
        glOrtho(xmin+dx, windowSize+dx, ymin+dy, ySpan+dy, -2.0+dz, 3.0+dz);
        		//activate the dynamicbuffer
        
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glEnableClientState(GL_VERTEX_ARRAY);

        
        //glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glEnableClientState(GL_COLOR_ARRAY);
        if( drawingMode == 1)
        {
            //only draw peaks
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
            glEnableClientState(GL_INDEX_ARRAY);
            glDrawElements(GL_LINES, numPoints/chunkSize, GL_UNSIGNED_INT, (GLvoid*)0);
            //glDrawArrays(GL_LINES, 0, numPoints);
        }
        else if (drawingMode == 0 )
        {
            //draw everything
            NSUInteger ch,np;
            np = numPoints/numChannels;
            
            for(ch=0;ch<numChannels;ch++)
            {
                glDrawArrays(GL_LINES, ch*np, np);
                glDrawArrays(GL_LINES, ch*np+1, np-1);
                
            }
        }
        
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
    if( [theEvent clickCount] == 2 )
    {
        //double click;reset window to 10000 points
        windowSize = MIN(10000,xmax);
        dx = 0;
        
        ySpan = ymax;
        dy = 0;
        
    }
    else
    {
        //TODO: modify this to incorproate the new index
        //get current point in view coordinates
        NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
        //now we will have to figure out which waveform(s) contains this point
        //scale to data coorindates
        NSPoint dataPoint;
        NSRect viewBounds = [self bounds];
        //scale to data coordinates
        dataPoint.x = (currentPoint.x*(windowSize-xmin))/viewBounds.size.width+xmin+dx;
        dataPoint.y = (currentPoint.y*(ySpan-ymin))/viewBounds.size.height+ymin+dy;
        //now we set dx and window size
        //dx = xmin-dataPoint.x;
        
        windowSize = dataPoint.x-tx;
        dx = tx;
        //make sure we are not flipping
        if(dataPoint.x < tx+xmin)
        {
            dx = dataPoint.x-xmin;
            windowSize = tx+xmin-dx;
        }
        
        ySpan = dataPoint.y-ty;
        dy = ty;
        if(dataPoint.y < ty+ymin )
        {
            dy = dataPoint.y-ymin;
            ySpan = ty + ymin -dy;
        }
        //here, we can simply figure out the smallest distance between the vector defined by
        //(dataPoint.x,dataPoint.y) and the waveforms vectors
    }
    [self setNeedsDisplay:YES];
    
}

-(void)mouseDown:(NSEvent *)theEvent
{
    if( [theEvent clickCount] == 2 )
    {
        
    }
    else
    {
        NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
        NSPoint dataPoint;
        NSRect viewBounds = [self bounds];
        dataPoint.x = (currentPoint.x*(windowSize-xmin))/viewBounds.size.width+xmin+dx;
        dataPoint.y = (currentPoint.y*(ySpan-ymin))/viewBounds.size.height+ymin+dy;
        //set dx such that we shift the appropriate amount from the current xmin
        tx = dataPoint.x-xmin;
        ty = dataPoint.y-ymin;
    }
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

-(void)saveToPDF
{
    NSRect bounds = [self bounds];
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/test.pdf"];
    CGContextRef ctx = CGPDFContextCreateWithURL(url,&bounds,NULL);
    CGContextSetLineWidth(ctx,1.0);
    CGFloat color[4] = {0.0f,0.0f,0.0f, 1.0f};
    CGContextSetStrokeColor(ctx, color);
    //now, repeat all the commands necessary to re-draw the current view
    NSUInteger ch,i,xmx,xmi,ymx,ymi,np;
    //create an affine transform to transform from data to view coordinates
    CGAffineTransform m;
    //first move to zero
    m = CGAffineTransformMakeTranslation(-xmin-dx,-ymin-dy);
    //.. then scale
    m = CGAffineTransformConcat(m,CGAffineTransformMakeScale(bounds.size.width/(windowSize-xmin),bounds.size.height/(ySpan-ymin)));
    //float d;
    np = numPoints/numChannels;
    CGContextBeginPage(ctx,&bounds);
    for(ch=0;ch<numChannels;ch++)
    {
        i = 0;
        while( (vertices[3*(ch*np+i)] < xmin+dx ) && (i < np))
        {
            i++;
        }
        if(i < np )
        {
            CGMutablePathRef p = CGPathCreateMutable();
            CGPathMoveToPoint(p, &m, vertices[3*(ch*np+i)], vertices[3*(ch*np+i)+1]);
            while( (vertices[3*(ch*np+i)] < windowSize+dx) && (i < np ))
            {
                CGPathAddLineToPoint(p, &m, vertices[3*(ch*np+i)], vertices[3*(ch*np+i)+1]);
                i++;
            }
            //add the path
            CGContextAddPath(ctx, p);
            //stroke the path
            CGContextStrokePath(ctx);
        }
    }
    CGContextEndPage(ctx);
    CGContextRelease(ctx);
    
    
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
    if( [theEvent modifierFlags] & NSCommandKeyMask )
    {
        //if we are pressin the control key, we are requesting a zoom
        windowSize +=windowSize*([theEvent deltaX]/10);
    }
    else
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
        //dz = [theEvent deltaY];
        dx += [theEvent deltaX]*0.001*windowSize;
        if( (xmax-dx)/xmax > 0.9 )
        {
            //we are approaching the end of the current buffer; notify that app that we need more data
            [[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset+dx*30.0],nil] forKeys:[NSArray arrayWithObjects:@"currenPos",nil]]];
        }
        else if ((dx-xmin)/(xmax-xmin) < 0.1 )
        {
            //we are approaching the beginning of the current buffer; notify that app that we need more data
            [[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset+dx*30.0],nil] forKeys:[NSArray arrayWithObjects:@"currenPos",nil]]];   
        }
        if( dx < xmin)
        {
            dx = 0;
        }
        else if( dx > xmax-windowSize)
        {
            dx = xmax-windowSize;
        }
    }
    [self setNeedsDisplay:YES];
}

-(void)magnifyWithEvent:(NSEvent*)theEvent
{
    GLfloat m = [theEvent magnification];
    //change the window size
    windowSize = windowSize*(1+m);
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
