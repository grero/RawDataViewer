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
@synthesize timeCoord,ampCoord,chCoord;
@synthesize drawSpikes,drawTemplates,drawGrid,drawData,vZoom,hZoom;
@synthesize sp;
@synthesize endTime;
@synthesize selectedChannels,visibleChannels;
@synthesize channelColors;
//@synthesize currentX,currentY;

-(void)awakeFromNib
{
    dataLoaded = NO;
	gridSpaceX = 10.0;
	gridSpaceY = 100.0;
	hZoom = YES;
	vZoom = YES;
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
    //zoom stack to keep the last ten zoom levels, for both x and y directions
    zoomStackLength = 50;
    zoomStack = malloc(zoomStackLength*4*sizeof(GLfloat));
    zoomStackIdx = 0;
    drawSpikes = NO;
    templatesLoaded = NO;
    spikeIdx = [[NSMutableData dataWithCapacity:100] retain];
    drawCurrentX = NO;
	drawThresholds = NO;
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
    xmax = timepoints/samplingRate;
    windowSize = MIN(xmin+10000,xmax);
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
            vertices[6*k] = ((GLfloat)i)/samplingRate;
            //y
            vertices[6*k+1] = trough+offset;
            //z
            vertices[6*k+2] = 0.5;//2*((float)random())/RAND_MAX-1;
            //x
            vertices[6*k+3] = ((GLfloat)i)/samplingRate;
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
	if(channelLimits == NULL)
	{
		channelLimits = malloc(2*channels*sizeof(GLfloat));
	}
	memcpy(channelLimits,limits,2*channels*sizeof(GLfloat));
    free(limits);
    dz = 0.0;
    dy = 0.0;
    dx =0.0;
    //add maximum of the last channel to the offset
    
    ySpan = ymax;
    ymin = 0;
    
    //set the zoom
    zoomStack[0] = dx;
    zoomStack[1] = windowSize;
    zoomStack[2] = dy;
    zoomStack[3] = ySpan;
    zoomStackIdx = 0;
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
    GLfloat *limits,*choffsets,*chColors;
    dispatch_queue_t queue;
    
    npoints = timepoints;
    numChannels = channels;
	_data = (int16_t*)[vertex_data bytes];
	if( visibleChannels == NULL )
	{
		[self setVisibleChannels: [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0,channels)]];
	}
	else if( [visibleChannels count] == 0)
	{
		[visibleChannels addIndexesInRange: NSMakeRange(0,channels)];
	}
	//get a copy of the channels in a pure c array as well
	numDrawnChannels = [visibleChannels count];
	drawChannels = malloc(numDrawnChannels*sizeof(NSUInteger));
	[visibleChannels getIndexes: drawChannels maxCount: numDrawnChannels inIndexRange:nil];
	if( [channelColors length] == 0)
	{
		[self setChannelColors: [NSMutableData dataWithLength: 3*channels*sizeof(GLfloat)]];
		chColors = (GLfloat*)[[self channelColors] bytes];
		for(ch=0;ch<=channels;ch++)
		{
			chColors[3*ch] = 1.0f;
			chColors[3*ch+1] = 0.5f;
			chColors[3*ch+2] = 0.3f;
		}
	}
	else
	{
		chColors = (GLfloat*)[[self channelColors] bytes];
	}
	chunkSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"chunkSize"];
    //we want to create peaks every 8 points
	if( chunkSize ==0 )
	{
		chunkSize = 2;
	}
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
    if( channelOffsets != NULL )
    {
        channelOffsets = realloc(channelOffsets,channels*sizeof(GLfloat));
    }
    else
    {
        channelOffsets = malloc(numDrawnChannels*sizeof(GLfloat));
    }
    //vector to hold the min/max for each channel
    limits = calloc(2*channels,sizeof(GLfloat));
    //this works because the data is organized in channel order
    //offset = 0;
    samplingRate = [sp samplingRate]/1000.0;
    xmin = vertexOffset/samplingRate;
    //sampling rate of 30 kHz
    
    xmax = xmin+timepoints/samplingRate;
    
    windowSize = MIN(xmin+10000,xmax);
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
    channelOffsets[0] = -limits[2*drawChannels[0]];
    for(ch=1;ch<numDrawnChannels;ch++)
    {
        channelOffsets[ch] = channelOffsets[ch-1] + (-limits[2*drawChannels[ch]] + limits[2*(drawChannels[ch-1])+1]);
    }
    
    //for(ch=0;ch<channels;ch++)
    dispatch_apply(channels, queue, ^(size_t c) 
    {
        NSUInteger i,j,tidx,pidx,k,l;
        GLfloat offset,peak,trough,d;
        
        offset = channelOffsets[c];
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
                vertices[3*k] = xmin+((GLfloat)(i + j))/samplingRate;
                //y
                vertices[3*k+1] = d;// + offset;
                //z
                vertices[3*k+2] = 0.5;//2*((float)random())/RAND_MAX-1;
                
                //color
				/*
				if( [selectedChannels containsIndex: c])
				{
					colors[3*k] = 1.0f;
					colors[3*k+1] = 0.0f;
					colors[3*k+2] = 0.0f;
				}
				else
				{
					colors[3*k] = 1.0f;
					colors[3*k+1] = 0.5f;
					colors[3*k+2] = 0.3f;
				} 
				*/
				colors[3*k] = chColors[3*c];
				colors[3*k+1] = chColors[3*c+1];
				colors[3*k+2] = chColors[3*c+2];
			
                
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
            vertices[3*k] = xmin+((GLfloat)(i + j))/samplingRate;
            //y
            vertices[3*k+1] = d;// + offset;
            //z
            vertices[3*k+2] = 0.5;//2*((float)random())/RAND_MAX-1;
           /* 
            //color
           
			if( [selectedChannels containsIndex: c])
			{
				colors[3*k] = 1.0f;
				colors[3*k+1] = 0.0f;
				colors[3*k+2] = 0.0f;
			}
			else
			{
				colors[3*k] = 1.0f;
				colors[3*k+1] = 0.5f;
				colors[3*k+2] = 0.3f;
			} 
			*/
			colors[3*k] = chColors[3*c];
			colors[3*k+1] = chColors[3*c+1];
			colors[3*k+2] = chColors[3*c+2];

        }
    });

    float m;
    vDSP_minv(vertices, 3, &m, numPoints);
    //we don't need limits anymore
    ymax = channelOffsets[channels-1]+limits[2*(channels-1)+1];
	if(channelLimits == NULL)
	{
		channelLimits = malloc(2*channels*sizeof(GLfloat));
	}
	memcpy(channelLimits,limits,2*channels*sizeof(GLfloat));
    free(limits);
    dz = 0.0;
    dy = 0.0;
    dx =0.0;
	//set the maximum based on the visible channels
	uint32_t miCh,mxCh;
	miCh = [[self visibleChannels] firstIndex];
	mxCh = [[self visibleChannels] lastIndex];
	//set the minimum to the first offset - the peak of the first channel
	dy = channelOffsets[0] + channelLimits[2*drawChannels[0]];
    ySpan = channelOffsets[numDrawnChannels-1] + channelLimits[2*drawChannels[numDrawnChannels-1]+1]-dy;//ymax;
    ymin = 0;//-channelOffsets[0];//+channelLimits[0];
    //push onto the zoom stack
    zoomStack[0] = dx;
    zoomStack[1] = windowSize;
    zoomStack[2] = dy;
    zoomStack[3] = ySpan;
    zoomStackIdx = 0; 
	nValidZoomStacks = 1;
    [[self openGLContext] makeCurrentContext];
    //vertices have been created, now push those to the GPU
    if(dataLoaded == NO )
    {
        glGenBuffers(1, &vertexBuffer);
    }
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
    /*
    glGenBuffers(1,&indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 2*numPoints/chunkSize*sizeof(GLuint), indices, GL_STATIC_DRAW);
    
    
    glIndexPointer(GL_UNSIGNED_INT, 0, (GLvoid*)0);
     */
    //notify that we have loaded the data
    dataLoaded = YES;
	[self setDrawData: YES];
    drawingMode = 0;//indicate that we are drawing everything
    [self setNeedsDisplay: YES];
}

-(void)createSpikeVertices:(NSData*)spikes numberOfSpikes: (NSUInteger)nspikes channels:(NSData*)chs numberOfChannels: (NSData*)nchs cellID:(NSData*)cellid
{
    NSUInteger i,ch,k;
    float *spikeData;
    GLfloat *spikeVertices;
    NSUInteger nvertices;
    NSUInteger *nChannels,*channels;
    GLfloat *spikeColors;
    uint32_t *cids;
    
    if(nchs != NULL)
    {
        nChannels = (NSUInteger*)[nchs bytes];
    }
    else
    {
        nChannels = malloc(nspikes*sizeof(NSUInteger));
        for(i=0;i<nspikes;i++)
        {
            nChannels[i] = 2;
        }
    }
    if(chs != NULL )
    {
        channels = (NSUInteger*)[chs bytes];
    }
    else
    {
        channels = malloc(nspikes*2*sizeof(NSUInteger));
        for(i=0;i<nspikes;i++)
        {
            /*
            for(k=0;k<numChannels;k++)
            {
                channels[i*numChannels+k] = k;
            }*/
            channels[i*2] = 0;
            channels[i*2+1] = numChannels-1;
        }
    }
    if(cellid != NULL )
    {
        spikeColors = malloc(nspikes*3*sizeof(GLfloat));
        cids = (uint32_t*)[cellid bytes];
        for(i=0;i<nspikes;i++)
        {
            //this is just a round-about way of making sure all spikes belonging to the same cells get the same color
			if(cids[i]==0)
			{
				//noise cluster
				spikeColors[3*i] = 1.0;
				spikeColors[3*i+1] = 1.0;
				spikeColors[3*i+2] = 1.0;

			}
			else
			{
				srandom(cids[i]);
				spikeColors[3*i] = ((GLfloat)random())/RAND_MAX;
				spikeColors[3*i+1] = ((GLfloat)random())/RAND_MAX;
				spikeColors[3*i+2] = ((GLfloat)random())/RAND_MAX;
			}
        }
        useSpikeColors = YES;
    }
    else{
        useSpikeColors = NO;
    }
    nvertices = 0;
    for(i=0;i<nspikes;i++)
    {
        nvertices+=nChannels[i];
    }
    spikeData = (float*)[spikes bytes];
    
    [[self openGLContext] makeCurrentContext];
    //only generate if we have not already loaded spikes
    if(spikesLoaded == NO )
    {
        glGenBuffers(1, &spikesBuffer);
    }
    glBindBuffer(GL_ARRAY_BUFFER, spikesBuffer);
    if(useSpikeColors==YES)
    {
        glBufferData(GL_ARRAY_BUFFER, 2*3*nvertices*sizeof(GLfloat), 0, GL_STATIC_DRAW);
    }
    else
    {
        glBufferData(GL_ARRAY_BUFFER, 3*nvertices*sizeof(GLfloat), 0, GL_STATIC_DRAW);
    }
    spikeVertices = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    GLenum e = glGetError();
    k=0;
    for(i=0;i<nspikes;i++)
    {
        //for(ch=0;ch<nChannels[i];ch++)
        //{
            //x-value
        spikeVertices[2*3*k] = spikeData[i];
        if( channels[i*2] == 0 )
        {
            spikeVertices[2*3*k+1] = channelOffsets[channels[i*2]]-0.5*(channelOffsets[channels[i*2]+1]);
        }
        else
        {
            spikeVertices[2*3*k+1] = channelOffsets[channels[i*2]]-0.5*(channelOffsets[channels[i*2]+1]-channelOffsets[channels[i*2]-1]);
        }
        if( channels[i*2+1]==numChannels-1 )
        {
            spikeVertices[2*3*k+4] = channelOffsets[channels[i*2+1]]+0.5*(ymax-channelOffsets[channels[i*2+1]-1]);
        }
        else
        {
           spikeVertices[2*3*k+4] = channelOffsets[channels[i*2+1]]+0.5*(channelOffsets[channels[i*2+1]+1]-channelOffsets[channels[i*2+1]-1]);
        }
        spikeVertices[2*3*k+3] = spikeData[i];
        //z
        spikeVertices[2*3*k+2] = 0.5;
        spikeVertices[2*3*k+5] = 0.5;
        k+=1;
        //}
    }
    if(useSpikeColors == YES)
    {
        //fill the last part of the buffer with the colors
        for(i=0;i<nspikes;i++)
        {
            spikeVertices[3*nvertices+2*3*i] = spikeColors[3*i];
            spikeVertices[3*nvertices+2*3*i+1] = spikeColors[3*i+1];
            spikeVertices[3*nvertices+2*3*i+2] = spikeColors[3*i+2];
            
            spikeVertices[3*nvertices+2*3*i+3] = spikeColors[3*i];
            spikeVertices[3*nvertices+2*3*i+4] = spikeColors[3*i+1];
            spikeVertices[3*nvertices+2*3*i+5] = spikeColors[3*i+2];
        }
    }
    if(chs==NULL)
    {
        free(channels);
    }
    if(nchs==NULL)
    {
        free(nChannels);
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    glVertexPointer(3, GL_FLOAT, 0, (GLvoid*)0);
    glColorPointer(3, GL_FLOAT, 0, (GLvoid*)((char*)NULL + 3*nvertices*sizeof(GLfloat)));
    drawSpikes = YES;
    numSpikes = nspikes;
    spikesLoaded = YES;
    [[[[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"View"] submenu] itemWithTitle:@"Hide spikes"] setEnabled:YES];
    
    [self setNeedsDisplay:YES];
}
-(void)updateTemplateVerticesWithChannels: (NSData*)channels numChannels: (NSData*)numChannels
{
	NSUInteger i,ch,nspikes,*_channels,*_nchannels;
	GLfloat *spikeVertices;
    glBindBuffer(GL_ARRAY_BUFFER, templatesBuffer);
    spikeVertices = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
	_channels = (NSUInteger*)[channels bytes];
	_nchannels = (NSUInteger*)[numChannels bytes];
	nspikes = [channels length]/(2*sizeof(NSUInteger));
	if(spikeVertices != NULL)
	{
		//change the y-value
		for(i=0;i<nspikes;i++)
		{
			for(ch=0;ch<_nchannels[i];ch++)
			{
				spikeVertices[3*i+1] = channelOffsets[_channels[2*i]+ch];
			}

		}
	}
	glUnmapBuffer(GL_ARRAY_BUFFER);
}

-(void)createTemplateVertices:(NSData*)spikes timestamps:(NSData*)timestamps numberOfSpikes: (NSUInteger)nspikes timepts:(NSInteger)timepts channels:(NSData*)chs numberOfChannels: (NSData*)nchs cellID:(NSData*)cellid
{
    NSUInteger i,ch,k;
    int l;
    float *spikeData,*_timestamps;
    GLfloat *spikeVertices;
    NSUInteger nvertices;
    NSUInteger *nChannels,*channels;
    GLfloat *spikeColors;
    uint32_t *cids,in_offset;
    int32_t out_offset;
	templatesPerChannel = realloc(templatesPerChannel,numChannels*sizeof(NSUInteger));
	//set the zero
	bzero(templatesPerChannel,numChannels*sizeof(NSUInteger));
    if(nchs != NULL)
    {
        nChannels = (NSUInteger*)[nchs bytes];
    }
    else
    {
        nChannels = malloc(nspikes*sizeof(NSUInteger));
        for(i=0;i<nspikes;i++)
        {
            nChannels[i] = numChannels;
        }
    }
    if(chs != NULL )
    {
        channels = (NSUInteger*)[chs bytes];
    }
    else
    {
        channels = malloc(nspikes*2*sizeof(NSUInteger));
        for(i=0;i<nspikes;i++)
        {
            /*
             for(k=0;k<numChannels;k++)
             {
             channels[i*numChannels+k] = k;
             }*/
            channels[i*2] = 0;
            channels[i*2+1] = numChannels-1;
        }
    }
    if(cellid != NULL )
    {
        spikeColors = malloc(nspikes*3*sizeof(GLfloat));
        cids = (uint32_t*)[cellid bytes];
        for(i=0;i<nspikes;i++)
        {
            //this is just a round-about way of making sure all spikes belonging to the same cells get the same color
            srandom(cids[i]);
            spikeColors[3*i] = ((GLfloat)random())/RAND_MAX;
            spikeColors[3*i+1] = ((GLfloat)random())/RAND_MAX;
            spikeColors[3*i+2] = ((GLfloat)random())/RAND_MAX;
        }
        useSpikeColors = YES;
    }
    else{
        useSpikeColors = NO;
    }
    nvertices = 0;
    for(i=0;i<nspikes;i++)
    {
        //+2 because we add an extra point to the beginning and end of each template
        nvertices+=nChannels[i]*(timepts+2);
		templatesPerChannel[channels[2*i]]+=nChannels[i]*(timepts+2);;
    }
    //.. then we remove the first and the last point
    nvertices-=2;
    numTemplateVertices = nvertices;
    spikeData = (float*)[spikes bytes];
    _timestamps = (float*)[timestamps bytes];
    [[self openGLContext] makeCurrentContext];
    //only generate if we have not already loaded spikes
    if(templatesLoaded == NO )
    {
        glGenBuffers(1, &templatesBuffer);
    }
    glBindBuffer(GL_ARRAY_BUFFER, templatesBuffer);
    if(useSpikeColors==YES)
    {
        glBufferData(GL_ARRAY_BUFFER, 2*3*nvertices*sizeof(GLfloat), 0, GL_STATIC_DRAW);
    }
    else
    {
        glBufferData(GL_ARRAY_BUFFER, 3*nvertices*sizeof(GLfloat), 0, GL_STATIC_DRAW);
    }
    spikeVertices = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
	if( spikeVertices == NULL )
	{
		GLenum e = glGetError();
		NSLog(@"Spike vertices could not be allocated. Opengl error code %d", e);
		return;
	}
    k=0;
    in_offset = 0;
    out_offset = 0;
    for(i=0;i<nspikes;i++)
    {
        float d,q;
        int minpt;
        in_offset = cids[i]*nChannels[cids[i]]*timepts;
        //find the location of the minimm point
        for(ch=0;ch<nChannels[i];ch++)
        {
            for(l=0;l<timepts;l++)
            {
                q = spikeData[in_offset+ch*timepts+l];
                minpt = (q<d)?l:minpt;
                d = (q<d)?q:d;
            }
            
        }
        for(ch=0;ch<nChannels[i];ch++)
        {
            if( (ch==0) && (i==0) )
            {
                //ch==0
                for(l=0;l<timepts;l++)
                {
                    //x-value
                    spikeVertices[3*l] = _timestamps[i]+(-minpt+l)/samplingRate;
                    //y-vaue
					//TODO: channelOffsets refers to the currently visible channels 
                    spikeVertices[3*l+1] = spikeData[in_offset+ch*timepts+l];// + channelOffsets[channels[2*i]+ch];
                    //z-value
                    spikeVertices[3*l+2] = 1.0;
                }
                out_offset = -1;
                
            }

            else 
            {
                l = 0;
                //x-value
                spikeVertices[3*(out_offset+ch*(timepts+2)+l)] = _timestamps[i]+(-minpt+l)/samplingRate;
                //y-vaue
                spikeVertices[3*(out_offset+ch*(timepts+2)+l)+1] = spikeData[in_offset+ch*timepts+l];// + channelOffsets[channels[2*i]+ch];
                //z-value
                spikeVertices[3*(out_offset+ch*(timepts+2)+l)+2] = -3.5;

            
                for(l=1;l<timepts+1;l++)
                {
                    //x-value
                    spikeVertices[3*(out_offset+ch*(timepts+2)+l)] = _timestamps[i]+(-minpt+l-1)/samplingRate;
                    //y-vaue
                    spikeVertices[3*(out_offset+ch*(timepts+2)+l)+1] = spikeData[in_offset+ch*timepts+l-1];// + channelOffsets[channels[2*i]+ch];
                    //z-value
                    spikeVertices[3*(out_offset+ch*(timepts+2)+l)+2] = 1.0;
                }
            }
            if ((i<nspikes-1) || (ch<nChannels[i]-1))
            {
                l = timepts+1;
                //add an extra point unless we at the last channel of the last spike
                spikeVertices[3*(out_offset+ch*(timepts+2)+timepts+1)] = _timestamps[i]+(-minpt+l-2)/samplingRate;
                spikeVertices[3*(out_offset+ch*(timepts+2)+timepts+1)+1] = spikeData[in_offset+ch*timepts+l-2] ;//+ channelOffsets[channels[2*i]+ch];
                spikeVertices[3*(out_offset+ch*(timepts+2)+timepts+1)+2] = -4.0;
            }
        }
        out_offset+=nChannels[i]*(timepts+2);
        //in_offset+=nChannels[i]*timepts;
    }
    int32_t offset;
    if(useSpikeColors == YES)
    {
        //fill the last part of the buffer with the colors
        offset = 0;
        for(i=0;i<nspikes;i++)
        {
            for(ch=0;ch<nChannels[i];ch++)
            {
                if( (ch==0) && (i==0) )
                {
                    //ch==0
                    for(l=0;l<timepts;l++)
                    {
                        spikeVertices[3*nvertices+3*(offset+l) ] = spikeColors[3*i];
                        spikeVertices[3*nvertices+3*(offset+l)+1] = spikeColors[3*i+1];
                        spikeVertices[3*nvertices+3*(offset+l)+2] = spikeColors[3*i+2];
                        
                    }
                    offset-=1;
                    
                    
                }

                else
                {
                    l = 0;
                    spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+l) ] = spikeColors[3*i];
                    spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+l)+1] = spikeColors[3*i+1];
                    spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+l)+2] = spikeColors[3*i+2];
                    for(l=1;l<timepts+1;l++)
                    {
                        spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+l) ] = spikeColors[3*i];
                        spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+l)+1] = spikeColors[3*i+1];
                        spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+l)+2] = spikeColors[3*i+2];
                        
                    }
                }
                
                if ((i<nspikes-1) || (ch<nChannels[i]-1))
                {
                    spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+timepts+1)] = spikeColors[3*i]; 
                    spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+timepts+1)+1] = spikeColors[3*i+1];
                    spikeVertices[3*nvertices+3*(offset+ch*(timepts+2)+timepts+1)+2] = spikeColors[3*i+2];
                }
            }
            
            offset+=nChannels[i]*(timepts+2);
        }
    }
    if(chs==NULL)
    {
        free(channels);
    }
    if(nchs==NULL)
    {
        free(nChannels);
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    glVertexPointer(3, GL_FLOAT, 0, (GLvoid*)0);
    //glColorPointer(3, GL_FLOAT, 0, (GLvoid*)((char*)NULL + 3*nvertices*sizeof(GLfloat)));
    drawTemplates = YES;
    numSpikes = nspikes;
    templatesLoaded = YES;
	//make sure we enable the menu item allowing us to show/hide templates
    [[[[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"View"] submenu] itemWithTitle:@"Hide templates"] setEnabled:YES];
    
    [self setNeedsDisplay:YES];
}

-(void) highlightChannels:(NSArray*)channels
{
	[[self openGLContext] makeCurrentContext];
}


-(void)setGridSpaceX:(float)_dx
{
	gridSpaceX = _dx;
	[self setNeedsDisplay:YES];
}

-(void)setGridSpaceY:(float)_dy
{
	gridSpaceY = _dy;
	[self setNeedsDisplay:YES];
}

-(GLfloat)gridSpaceX
{
	return gridSpaceX;
}
-(GLfloat)gridSpaceY
{
	return gridSpaceY;
}

-(void)drawGridLines
{
	float _dx,_dy;
	int nx,ny,i,j;
	_dx = gridSpaceX; //10ms grid size in x-direction
	_dy = gridSpaceY; //100 micro volts in y-direction
	//get the number of grid lines
	ny = (int)(ySpan/_dy);
	nx = (int)(windowSize/_dx);
	//draw the grid
	for(i=0;i<=nx;i++)
	{
		glBegin(GL_LINES);
		glColor4f(0.5,0.5,0.5,0.5);
		glVertex3f(dx+i*_dx,dy,0);
		glColor4f(0.5,0.5,0.5,0.5);
		glVertex3f(dx+i*_dx,dy+ySpan,0);
		glEnd();
	}
	for(j=0;j<=ny;j++)
	{
		glBegin(GL_LINES);
		glColor4f(0.5,0.5,0.5,0.5);
		glVertex3f(dx,dy+j*_dy,0);
		glColor4f(0.5,0.5,0.5,0.5);
		glVertex3f(dx+windowSize,dy+j*_dy,0);
		glEnd();
	}
	

}
- (void)drawRect:(NSRect)bounds 
{
	NSUInteger ch,np;
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
       	glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		if( drawData )
		{
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
				np = numPoints/numChannels;
				glVertexPointer(3, GL_FLOAT, 0, (GLvoid*)0);
				glColorPointer(3, GL_FLOAT, 0, (GLvoid*)((char*)NULL + 3*numPoints*sizeof(GLfloat)));
				//TODO: here we should be able to select channels
				for(ch=0;ch<numDrawnChannels;ch++)
				{
					//note we could also use channelLimits here
					glPushMatrix();
					glTranslatef(0,channelOffsets[ch],0);
					glDrawArrays(GL_LINES, drawChannels[ch]*np, np);
					glDrawArrays(GL_LINES, drawChannels[ch]*np+1, np-1);
					glPopMatrix();
					
				}
			}
			glDisableClientState(GL_VERTEX_ARRAY);
			glDisableClientState(GL_COLOR_ARRAY);
		}
		if( drawThresholds )
		{
			//draw extraction thresholds for each channel
			for(ch = 0; ch < numChannels;ch++)
			{
				glBegin(GL_LINES);
				glVertex3f(xmin+dx,extractionThresholds[ch]+channelOffsets[ch],0.5);
	            glVertex3f(windowSize+dx,extractionThresholds[ch]+channelOffsets[ch],0.5);
				glEnd();
			}
		}
        if ( (drawSpikes == YES) && ( spikesLoaded == YES))
        {
			//glMatrixMode(GL_PROJECTION);
			//glPushMatrix();
			//glLoadIdentity();
			//glOrtho(xmin+dx, windowSize+dx, 0, 1, -2.0+dz, 3.0+dz);
			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();
			//glTranslatef(0.0,-channelOffsets[0],0.0);
			glScalef(1.0,channelOffsets[numChannels-1]-channelOffsets[0],1.0);
            glBindBuffer(GL_ARRAY_BUFFER, spikesBuffer);
            glEnableClientState(GL_VERTEX_ARRAY);
            glVertexPointer(3, GL_FLOAT, 0, (GLvoid*)0);
            if( useSpikeColors == NO )
            {
                glColor3f(1.0,0.0,0.0);
            }
            else
            {
                glEnableClientState(GL_COLOR_ARRAY);
                glColorPointer(3, GL_FLOAT, 0, (GLvoid*)((char*)NULL + 3*numSpikes*2*sizeof(GLfloat)));                
            }
            glDrawArrays(GL_LINES, 0, 2*numSpikes);
            glDisableClientState(GL_VERTEX_ARRAY);
            if(useSpikeColors == YES)
            {
                glDisableClientState(GL_COLOR_ARRAY);
            }
			//glMatrixMode(GL_PROJECTION);
			//glPopMatrix();
			//glMatrixMode(GL_MODELVIEW);
            //GLenum e = glGetError();
            //NSLog(@"Error %d", e);
        }
        if( (drawTemplates) && ( templatesLoaded == YES))
        {
			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();
            glBindBuffer(GL_ARRAY_BUFFER, templatesBuffer);
            glEnableClientState(GL_VERTEX_ARRAY);
            glVertexPointer(3, GL_FLOAT, 0, (GLvoid*)0);
            if( useSpikeColors == NO )
            {
                glColor3f(1.0,0.0,0.0);
            }
            else
            {
                //glColor3f(1.0,0.0,0.0);
                glEnableClientState(GL_COLOR_ARRAY);
                glColorPointer(3, GL_FLOAT, 0, (GLvoid*)((char*)NULL + 3*numTemplateVertices*sizeof(GLfloat)));
            }
			int _offset = 0;
			for(ch=0;ch<numDrawnChannels;ch++)
			{
				glPushMatrix();
				glTranslatef(0,channelOffsets[ch],0);
				glDrawArrays(GL_LINES, _offset, templatesPerChannel[drawChannels[ch]]);
				glDrawArrays(GL_LINES, _offset+1, templatesPerChannel[drawChannels[ch]]-1);
				glPopMatrix();
				_offset += templatesPerChannel[drawChannels[ch]];
			}
            glDisableClientState(GL_VERTEX_ARRAY);
            if(useSpikeColors == YES)
            {
                glDisableClientState(GL_COLOR_ARRAY);
            }
        }
        if( drawCurrentX)
        {
            //draw a line at the currentX value
            glBegin(GL_LINES);
            glColor3f(1.0, 0, 0);
            glVertex3d(currentX, ymin+dy, 0.5);
            glColor3f(1.0, 0, 0);
            glVertex3d(currentX, ySpan+dy, 0.5);
            glEnd();
        }
        //GLenum e = glGetError();
        //NSLog(@"gl error: %d", e);
    }
	if( drawGrid )
	{
		glLoadIdentity();
		[self drawGridLines];
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
        windowSize = MIN(10000+xmin,xmax);
        dx = 0;
        
		//ySpan = channelOffsets[numDrawnChannels-1]+limits[2*(drawChannels[numDrawnChannels-1])+1];
        //ySpan = ymax;
        //dy = 0;
		//dy = channelOffsets[0] + channelLimits[2*drawChannels[0]];
        zoomStackIdx = 0;
		dx = zoomStack[zoomStackIdx*4];
		windowSize = zoomStack[zoomStackIdx*4+1];
		dy = zoomStack[zoomStackIdx*4+2];
		ySpan = zoomStack[zoomStackIdx*4+3];
		[self setVisibleChannels: [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0,numChannels)]];
        
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
        if([theEvent modifierFlags] & NSAlternateKeyMask )
        {
			int	ch = 0;
			while( (channelOffsets[ch]  + channelLimits[2*drawChannels[ch]+1]< dataPoint.y ) && (ch < numDrawnChannels-1))
				ch++;
			//ch-=1;
			//ch = MAX(ch,0);
            //report the current coordinates to the text field
            [timeCoord setStringValue:[NSString stringWithFormat:@"%.2f",dataPoint.x]];
            [ampCoord setStringValue:[NSString stringWithFormat:@"%.2f",dataPoint.y-channelOffsets[ch]]];
            currentX = dataPoint.x;
            currentY = dataPoint.y;
			[self setDrawCurrentX:YES];
			//get the channel
            [chCoord setStringValue:[NSString stringWithFormat:@"%d",drawChannels[ch]]];
			//get the already selected channels; this will make sure that only the selected channel is highlighted
			NSMutableIndexSet *_index = [NSMutableIndexSet indexSetWithIndex: drawChannels[ch]];
			[_index addIndexes: [self selectedChannels]];
			[self selectChannels: _index usingColor: NULL];

            [[timeCoord window] orderFront:self];
		}
		else if([theEvent modifierFlags] & NSShiftKeyMask )
		{
			//get the channel
			int	ch = 0;
			while( (channelOffsets[ch]  + channelLimits[2*drawChannels[ch]+1]< dataPoint.y ) && (ch < numDrawnChannels-1))
				ch++;
            [chCoord setStringValue:[NSString stringWithFormat:@"%d",drawChannels[ch]]];
			//NSLog(@"Selected channel: %d", ch);
			//NSLog(@"currentY: %f", currentY);
			//NSLog(@"channelOffset[ch] = %f",channelOffsets[ch]);
			[self selectChannels: [NSIndexSet indexSetWithIndex: drawChannels[ch]] usingColor: NULL];
            [[timeCoord window] orderFront:self];

        }
        else
        {
            //make sure we actually moved
            if( (fabs((tx-dataPoint.x)/windowSize) > 0.001) && (fabs((ty-dataPoint.y)/ySpan) > 0.001))
            {
				if( hZoom )
				{
					windowSize = dataPoint.x-tx;
					dx = tx;
					//make sure we are not flipping
					if(dataPoint.x < tx+xmin)
					{
						dx = dataPoint.x-xmin;
						windowSize = tx+xmin-dx;
					}
				}
               
				if( vZoom )
				{
					ySpan = dataPoint.y-ty;
					dy = ty;
					if(dataPoint.y < ty+ymin )
					{
						dy = dataPoint.y-ymin;
						ySpan = ty + ymin -dy;
					}
					//determine the channel
					uint32_t ch1,ch2,ch = 0;
					while( (channelOffsets[ch]+channelLimits[2*ch+1] <= MIN(ty,dataPoint.y)) && (ch < numChannels ))
						ch++;
					ch1 = ch;
					while( (channelOffsets[ch]+channelLimits[2*ch+1] < MAX(ty,dataPoint.y )) && (ch < numChannels ))
						ch++;
					ch2 = ch;
					[self setVisibleChannels: [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(ch1,ch2-ch1)]];
					//NSLog(@"Visible channels: %@",[self visibleChannels]);
				}
                if( zoomStackIdx<zoomStackLength-1 )
                {
                    zoomStackIdx+=1;
					nValidZoomStacks+=1;
                }
                else
                {
                    //shift back, discard the first stack

                    memmove(zoomStack, zoomStack+4,(zoomStackLength-1)*4*sizeof(NSUInteger));

                }
                zoomStack[zoomStackIdx*4] = dx;
                zoomStack[zoomStackIdx*4+1] = windowSize;
                zoomStack[zoomStackIdx*4+2] = dy;
                zoomStack[zoomStackIdx*4+3] = ySpan;
            }
                
        }
    }
    [self setNeedsDisplay:YES];
    
}

-(void)rightMouseDown:(NSEvent *)theEvent
{

	NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
	[theMenu insertItemWithTitle:@"Vertical zoom" action:@selector(changeZoomType:) keyEquivalent:@"" atIndex:0];
	[[theMenu itemAtIndex: 0] setEnabled: YES];
	[[theMenu itemAtIndex: 0] setState: [self vZoom]];
	[theMenu insertItemWithTitle:@"Horizontal zoom" action:@selector(changeZoomType:) keyEquivalent:@"" atIndex:1];
	[[theMenu itemAtIndex: 1] setEnabled: YES];
	[[theMenu itemAtIndex: 1] setState: [self hZoom]];
	 
	[NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:self];
}

-(IBAction)changeZoomType:(id)sender
{
	if( [[sender title] isEqualToString: @"Vertical zoom"] )
	{
		[self setVZoom: !vZoom];
		[sender setState: [self vZoom]];
	}
	else if( [[sender title] isEqualToString: @"Horizontal zoom"] )
	{
		[self setHZoom: !hZoom];
		[sender setState: [self hZoom]];
	}
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
    [imageData writeToFile:@"/tmp/test.eps" atomically:YES];
    
}

-(void)saveToTikzAtURL:(NSURL*)url
{
	int i,np,j,offset,k,q;
	char *fname;
	FILE *fid;
	NSUInteger nchs,ch,ch1,ch2,timepts;
	timepts = [sp timepts];
	//get the currently visible channels
	nchs = [visibleChannels count];
	//get the first and last visible channel
	ch1 = [visibleChannels firstIndex];
	ch2 = [visibleChannels lastIndex];
	//save the current view to a tikz figure at the given url
	fname = [[url path] cStringUsingEncoding: NSASCIIStringEncoding];
	//open file
	fid = fopen(fname,"w");
	//set up the preample
	fprintf(fid, "\\documentclass{article}\n");
	fprintf(fid, "\\usepackage{tikz}\n");
	fprintf(fid, "\\usepackage{pgfplots}\n");
	fprintf(fid, "\\begin{document}\n");
	//set up the figure
	fprintf(fid,"\\begin{tikzpicture}\n");
	fprintf(fid,"\\begin{axis}[\n");
	fprintf(fid,"axis x line=bottom, axis y line=left,\n");
	fprintf(fid,"xmin=%f, xmax=%f, ymin=%f, ymax=%f,\n",
		  xmin+dx, dx+windowSize, channelLimits[2*drawChannels[0]],
		  channelOffsets[nchs-1] - channelOffsets[0] + channelLimits[2*drawChannels[nchs-1]+1]);
	fprintf(fid,"xlabel = Time (ms), ylabel=Amplitude (mV)]\n");
	//lines = [lines stringByAppendingString: @"xticks=, yticks="]
  np = numPoints/numChannels;
  //draw the coordinate
  ch = [visibleChannels firstIndex];
  //get the y-offset
  q = 0;
  while(ch != NSNotFound )
  {
	  fprintf(fid,"\\addplot[blue]\n");
	  fprintf(fid,"coordinates{\n");
	i = 0;
	while( (vertices[3*(ch*np+i)] < xmin+dx ) && (i < np))
	{
		i++;
	}
	if(i < np )
	{
		while( (vertices[3*(ch*np+i)] < windowSize+dx) && (i < np ))
		{
			fprintf(fid,"(%f,%f) ", 
				  vertices[3*(ch*np+i)], vertices[3*(ch*np+i)+1] + channelOffsets[q] - channelOffsets[0]);
			i++;
		}
	}
	  //end the coordinate list
	  fprintf(fid,"};\n");
	ch = [visibleChannels indexGreaterThanIndex: ch];
	q+=1;
  }
  //TODO: check if there are any spikes to draw
  if( ( numSpikes > 0) && drawTemplates)
  {
	  //map the spike vertices
	  GLfloat *spikeVertices;
	  glBindBuffer(GL_ARRAY_BUFFER, templatesBuffer);
   	  spikeVertices = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
	  if( spikeVertices != NULL )
	  {
			ch = [visibleChannels firstIndex];
			q = 0;

			while(ch != NSNotFound )
			{
				k = 1;
				offset = 0;
				for(i=0;i<ch-1;i++)
					offset += templatesPerChannel[i];
				for(i=offset; i < offset+templatesPerChannel[ch]; i+=1*(timepts+2))
				{
					//check if the x-value is within the x-bounds
					//TODO: this does not work
					if( (spikeVertices[3*i+3*(timepts)] < dx+windowSize ) &&
					(spikeVertices[3*i] > xmin+dx ) &&
					(spikeVertices[3*i+3*(timepts)] > spikeVertices[3*i]))
					{
						//grab the color
						GLfloat *_color = spikeVertices + 3*numTemplateVertices + 3*i;

						//the color specification
						fprintf(fid, "\\definecolor{color%d}{rgb}{%f,%f,%f}\n", k, _color[0],_color[1],_color[2]);
						//plot this spike
						fprintf(fid,"\\addplot[color%d]\n", k);
						fprintf(fid,"coordinates{\n");
						for(j=0;j<timepts; j++)
						{
							fprintf(fid,"(%f, %f) ",spikeVertices[3*(i+j)], 
							spikeVertices[3*(i+j)+1] + channelOffsets[q] - channelOffsets[0]);
						}
						fprintf(fid,"};\n");
						k+=1;
					}
				}
				ch = [visibleChannels indexGreaterThanIndex: ch];
				q +=1 ;
			}
			glUnmapBuffer(GL_ARRAY_BUFFER);
		}
  }
  fprintf(fid,"\\end{axis}\n");
  fprintf(fid,"\\end{tikzpicture}\n");
  //close the document
  fprintf(fid,"\\end{document}\n");
  fclose(fid);
}

-(void)saveToPDFAtURL:(NSURL*)url
{
    
    NSRect bounds,scaleBar;
    CGFloat ys;
    char *label;
    char sunit[2] = "ms";
    char chs;
    bounds = [self bounds];
    if(url == NULL )
    {
        url = [NSURL fileURLWithPath:@"/tmp/test.pdf"];
    }
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
    //create xscale
    //setup text
    CGContextSelectFont(ctx, "Times New Roman", 12, kCGEncodingMacRoman);
    CGContextSetTextDrawingMode (ctx, kCGTextStroke);
    //make the length of vertical line 1% of the height
    CGContextMoveToPoint(ctx, 0.1*bounds.size.width, 0.05*bounds.size.height);
    CGContextAddLineToPoint(ctx, 0.1*bounds.size.width, 0.06*bounds.size.height);
    CGContextStrokePath(ctx);
    label = malloc(30*sizeof(char));
    snprintf(label, 30,"%-30.2f", xmin+dx+0.1*(windowSize-xmin));
    i = 0;
    
    while( (i < 30) && ((chs = label[i]) != ' '))
    {
        i++;
    }
   
    strncpy(label+i+1, "ms", 2);
    snprintf(label, 30,"%-30s", label);
    CGContextShowTextAtPoint(ctx, 0.1*bounds.size.width, 0.035*bounds.size.height, label, i+3);
    CGContextMoveToPoint(ctx, 0.9*bounds.size.width, 0.05*bounds.size.height);
    CGContextAddLineToPoint(ctx, 0.9*bounds.size.width, 0.06*bounds.size.height);
    CGContextStrokePath(ctx);
    
    snprintf(label, 30,"%-30.2f ms", xmin+dx+0.9*(windowSize-xmin));
    i = 0;
    
    while( (i < 30) && ((chs = label[i]) != ' '))
    {
        i++;
    }
    strncpy(label+i+1, "ms", 2);
    snprintf(label, 30,"%-30s", label);
    CGContextShowTextAtPoint(ctx, 0.9*bounds.size.width, 0.035*bounds.size.height, label, i+3);
    
    //create a scale bar for the y-axis
    //get an approrpiate y-scale
    ys = 100.0/(ySpan-ymin)*bounds.size.height;
    scaleBar = CGRectMake(0.1*bounds.size.width, 0.3*bounds.size.height, 0.01*bounds.size.width , ys);
    CGContextFillRect(ctx, scaleBar);
    //rotate 90 degrees
    m = CGAffineTransformMakeRotation(pi/2.0);
    CGContextSetTextMatrix(ctx,m);
    CGContextShowTextAtPoint(ctx, 0.12*bounds.size.width, 0.32*bounds.size.height, "100 mV", 6);
    
    CGContextEndPage(ctx);
    CGContextRelease(ctx);
    free(label);
    
    
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
    //print the keycode
    //NSLog(@"keycode: %d", [theEvent keyCode]);
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        
        //we don't want to use interpret keys because moving the mouse and using the right/left arrow keys are interpreted as the event, by default
		if( ([theEvent keyCode]==124) || ([theEvent keyCode] == 123))
		{
			if([theEvent keyCode] == 124 )
			{
				//right arrow
				//move down the zoom stack
				if( (zoomStackIdx < zoomStackLength-1) && (zoomStackIdx < nValidZoomStacks-1) )
				{
					zoomStackIdx+=1;
				}

			}
			else if( [theEvent keyCode] == 123 )
			{
				if(zoomStackIdx>0)
				{
					zoomStackIdx-=1;
				}
				
			}
			dx = zoomStack[zoomStackIdx*4];
			windowSize = zoomStack[zoomStackIdx*4+1];
			dy = zoomStack[zoomStackIdx*4+2];
			ySpan = zoomStack[zoomStackIdx*4+3];
		}
        else
        {
            [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
        }
		//set the according to the zoom stack
		/*
		//also update the visible channels
		uint32_t ch1,ch2,ch = 0;
		while( (channelOffsets[ch]+channelLimits[2*ch+1] <= dy) && (ch < numChannels ))
			ch++;
		ch1 = ch;
		while( (channelOffsets[ch]+channelLimits[2*ch] < dy+ySpan) && (ch < numChannels ))
			ch++;
		ch2 = ch;
		[self setVisibleChannels: [NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(ch1,ch2-ch1)]];*/
        [self setNeedsDisplay:YES];
        
        //[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
    } 
    else 
    {
        if( [[theEvent characters] isEqualToString:@"e"] )
        {
            //create local points to global variables
            float *_vertices, *_channelOffsets, _currentX,_currentY;
            _vertices = vertices;
            _channelOffsets = channelOffsets;
            _currentX = currentX;
            _currentY = currentY;
            int np,_numChannels;
            _numChannels = numChannels;
            np = numPoints/numChannels;
            //dispath this piece of code
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(queue, ^{
               
                float *spikes;
                
                int i,j,currentXidx;
                int ch,minch,maxch;
                //figure out which channel we are at
                minch = 0;
                currentXidx = 0;
                //find the index of the currentX point
                while( (_vertices[3*currentXidx] < _currentX) && (currentXidx<np) )
                {
                    currentXidx++;
                }
                while( (ymin+dy > _channelOffsets[minch]) && (minch < _numChannels) )
                {
                    minch++;
                }
                maxch=minch;
                while( (ySpan+dy > _channelOffsets[maxch]) && (maxch < _numChannels) )
                {
                    maxch++;
                }
                //we don't really want to store just the active channels; this should perhaps be made a preference
                spikes = malloc(_numChannels*32*sizeof(float));
                //we want to fill the non-active channel with zeros
                for(ch=0;ch<minch;ch++)
                {
                    for(i=0;i<32;i++)
                    {
                        spikes[ch*32+i] = 0;
                    }
                }
                for(ch=minch;ch<maxch;ch++)
                //for(ch=minch;ch<maxch;ch++)
                {
                    for (i=0; i<32; i++) 
                    {
                        j = currentXidx-10+i;
                        spikes[ch*32+i] = _vertices[3*(ch*np+j)+1] - _channelOffsets[ch];
                    }
                }
                for(ch=maxch;ch<_numChannels;ch++)
                {
                    for(i=0;i<32;i++)
                    {
                        spikes[ch*32+i] = 0;
                    }
                }
                
                [sp addTemplate:spikes length:32*_numChannels numChannels:(uint32_t)_numChannels atTimePoint:_currentX];
            });
            [spikeIdx appendBytes:&currentX length:sizeof(GLfloat)];
            [self createSpikeVertices:[sp spikes] numberOfSpikes:[sp ntemplates] channels:NULL numberOfChannels:NULL cellID:NULL];
        }
        else if( [[theEvent characters] isEqualToString:@"d"] )
        {
            //decode the current view using the already extracted spikes
            [sp decodeData:[NSData dataWithBytesNoCopy:vertices length:numPoints*3*sizeof(GLfloat) freeWhenDone:NO] numRows:numChannels numCols:numPoints/numChannels channelOffsets:[NSData dataWithBytesNoCopy:channelOffsets length:numChannels*sizeof(GLfloat) freeWhenDone:NO]];
            [self createSpikeVertices:[sp spikes] numberOfSpikes:[sp nspikes] channels:NULL numberOfChannels:NULL cellID:NULL];
        }
        else if( [[theEvent characters] isEqualToString:@"n"] )
        {
            //go the next spike
            //map the spikevertices first
            [[self openGLContext] makeCurrentContext];
            glBindBuffer(GL_ARRAY_BUFFER, spikesBuffer);
            GLfloat *spikeVertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
			if(spikeVertices != NULL)
			{
				int i = 0;
				float v;
				if( ( currentX > xmax) || (currentX < xmin) )
				{
					currentX = xmin;
				}
				while( (currentX >= spikeVertices[2*3*i] ) && (i<numSpikes-1) && (spikeVertices[2*3*i] <= xmax) )
				{
					i+=1;
				}
				v = spikeVertices[2*3*i];
				//make sure we free up the buffer before calling setCurrentX, as setCurrentX might need to change the vertexBuffer
				glUnmapBuffer(GL_ARRAY_BUFFER);
				[self setCurrentX: v];
				//give the array back
				//update the zoom
				windowSize = 5+xmin;
				dx = currentX-2.5-xmin;
				
				[self setNeedsDisplay:YES];
			}
        }
        else if( [[theEvent characters] isEqualToString:@"p"] )
        {
            [[self openGLContext] makeCurrentContext];
            glBindBuffer(GL_ARRAY_BUFFER, spikesBuffer);
            GLfloat *spikeVertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
			if(spikeVertices != NULL)
			{
				int i = numSpikes-1;
				float v;
				currentX = MAX(currentX,xmin);
				while( (currentX <= spikeVertices[2*3*i] ) && (i>0) && (spikeVertices[2*3*i] >= xmin))
				{
					i-=1;
				}
				v = spikeVertices[2*3*i];
				glUnmapBuffer(GL_ARRAY_BUFFER);
				[self setCurrentX: v];
				//give the array back
				//update the zoom
				windowSize = 5+xmin;
				dx = currentX-2.5-xmin;
				
				[self setNeedsDisplay:YES];
			}

   
        }
        else if ([[theEvent characters] isEqualToString:@"a"])
        {
            //only do this if the timer is not already running
            if( animationTimer == nil )
            {
                if( spikeIdx != nil)
                {
					[self setDrawCurrentX: NO];
                    //turn off cursor
                    [NSCursor hide];
                    unsigned int _spidx = 0;
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_spidx], @"spikeIdx", nil];
                    animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(animateTransition:) userInfo:userInfo repeats:YES] retain];
                }
            }
        }
        else if (([theEvent keyCode] == 49))
        {
            //space bar
            if ( animationTimer != nil)
            {
                //pause the timer
                if( [animationTimer isValid])
                {
                    [animationTimer invalidate];
                }
                [animationTimer release];
                animationTimer = nil;
            }
            //turn cursor back on
            [NSCursor unhide];
			[self setDrawCurrentX: YES];
            
        }
        else if( [[theEvent characters] isEqualToString:@"h"] )
		{
			//draw only the selected channels
			//only do this if we have some channels selected
			if( [selectedChannels count] > 0)
			{
				int ch;
				[visibleChannels removeAllIndexes];
				[visibleChannels addIndexes: selectedChannels];
				numDrawnChannels = [visibleChannels count];
				drawChannels = realloc(drawChannels,numDrawnChannels*sizeof(NSUInteger));
				[visibleChannels getIndexes: drawChannels maxCount: numDrawnChannels inIndexRange:nil];
				channelOffsets[0] = -channelLimits[2*drawChannels[0]];
				for(ch=1;ch<numDrawnChannels;ch++)
				{
					channelOffsets[ch] = channelOffsets[ch-1] + (-channelLimits[2*drawChannels[ch]] + channelLimits[2*(drawChannels[ch-1])+1]);
				}
				dy = channelOffsets[0] + channelLimits[2*drawChannels[0]];
				ySpan = channelOffsets[numDrawnChannels-1] + channelLimits[2*(drawChannels[numDrawnChannels-1])+1]-dy;//ymax;
				//select the visible channels again to un-select them
				[self selectChannels: selectedChannels usingColor: NULL];

				[self setNeedsDisplay: YES];
			}


		}
        else if( [[theEvent characters] isEqualToString:@"H"] )
		{
			//reset to drawing all channels
			//reselect the visible channels
			[self selectChannels: visibleChannels usingColor: NULL];
			int ch; 
			[self setVisibleChannels:[NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange(0,numChannels)]];
			numDrawnChannels = numChannels;
			drawChannels = realloc(drawChannels,numDrawnChannels*sizeof(NSUInteger));
			[visibleChannels getIndexes: drawChannels maxCount: numDrawnChannels inIndexRange:nil];
			channelOffsets[0] = -channelLimits[2*drawChannels[0]];
			for(ch=1;ch<numDrawnChannels;ch++)
			{
				channelOffsets[ch] = channelOffsets[ch-1] + (-channelLimits[2*drawChannels[ch]] + channelLimits[2*(drawChannels[ch-1])+1]);
			}
			dy = channelOffsets[0] + channelLimits[2*drawChannels[0]];
			ySpan = channelOffsets[numDrawnChannels-1] + channelLimits[2*drawChannels[numDrawnChannels-1]+1]-dy;//ymax;
			[self setNeedsDisplay: YES];
		}
        else if( [[theEvent characters] isEqualToString:@"g"] )
       	{
			[self setDrawGrid: ([self drawGrid])==0];
			[self setNeedsDisplay: YES];
		}
        else
        {
            [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
        }
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
        windowSize = windowSize-xmin + (windowSize-xmin)*([theEvent deltaX]/10);
        windowSize+=xmin;
        windowSize = MIN(windowSize,xmax);
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
        dx += [theEvent deltaX]*0.001*(windowSize-xmin);
        if( (xmax-dx)/xmax > 0.9 )
        {
            //we are approaching the end of the current buffer; notify that app that we need more data
            //[[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset+0.5*windowSize*samplingRate],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",nil]]];
        }
        else if ((dx-xmin)/(xmax-xmin) < 0.1 )
        {
            //we are approaching the beginning of the current buffer; notify that app that we need more data
            //[[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset+05*windowSize*samplingRate],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",nil]]];   
        }
        if( dx < 0)
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
	//move down the zoom stack
    /*
    if(zoomStackIdx < zoomStackLength-1)
    {
        zoomStackIdx+=1;
        dx = zoomStack[zoomStackIdx*4];
        windowSize = zoomStack[zoomStackIdx*4+1];
        dy = zoomStack[zoomStackIdx*4+2];
        ySpan = zoomStack[zoomStackIdx*4+3];
        
    }
    [self setNeedsDisplay:YES];
    */
	
}

-(IBAction)moveLeft:(id)sender
{
	//go back into the zoom stack
    /*
    if(zoomStackIdx>0)
    {
        zoomStackIdx-=1;
        dx = zoomStack[zoomStackIdx*4];
        windowSize = zoomStack[zoomStackIdx*4+1];
        dy = zoomStack[zoomStackIdx*4+2];
        ySpan = zoomStack[zoomStackIdx*4+3];
    }
    else
    {
        //reset everything
        windowSize = MIN(10000,xmax);
        dx = 0;
        
        ySpan = ymax;
        dy = 0;
        zoomStackIdx = 0;
    }
    [self setNeedsDisplay:YES];
     */
}	

-(void)moveUp:(id)sender
{
    //what happens when we reach the end?
    vertexOffset+=(NSInteger)(1.0*(xmax-xmin)*samplingRate);
	if(vertexOffset < endTime)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",nil]]];
		
	}
	else
	{
		vertexOffset = 0;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset],[NSNumber numberWithBool: YES],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",@"nextFile",nil]]];
		
	}
}

-(void)moveDown:(id)sender
{
    if(vertexOffset>0)
    {
        vertexOffset = MAX(0,(NSInteger)vertexOffset-(NSInteger)(1.0*(xmax-xmin)*samplingRate));
        [[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",nil]]];
    }
	else
	{
        vertexOffset = MAX(0,(NSInteger)endTime-(NSInteger)(1.0*(xmax-xmin)*samplingRate));
		[[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset],[NSNumber numberWithBool: YES],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",@"prevFile",nil]]];
		
	}
}

-(void)setCurrentX:(GLfloat)_currentX
{
    
    //center on currentX
    //check if currentX is within limits
    NSUInteger offset;
    GLfloat _xmin,_dx;
    _dx = _currentX-0.5*(windowSize-xmin);
    if( _currentX > xmax)
    {
        //need to load more data
        //find out how many windows we need to skip
        offset = (_currentX-xmin)/(xmax-xmin);
        vertexOffset+=offset*(NSInteger)(1.0*(xmax-xmin)*samplingRate);
        vertexOffset = MIN(vertexOffset,endTime-10000);
        _xmin = vertexOffset/samplingRate;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",nil]]];
    }
    else if( _currentX < xmin )
    {
        offset = ceil((xmin-_currentX)/(xmax-xmin));
        if(vertexOffset>0)
        {
            vertexOffset = MAX(0,(NSInteger)vertexOffset-offset*(NSInteger)(1.0*(xmax-xmin)*samplingRate));
            [[NSNotificationCenter defaultCenter] postNotificationName:@"loadMoreData" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithInt:vertexOffset],nil] forKeys:[NSArray arrayWithObjects:@"currentPos",nil]]];
        }

    }
    else
    {
        _xmin = xmin;
    }
    //dx = _dx-_xmin;
    currentX = _currentX;

    [self setNeedsDisplay:YES];
}

-(GLfloat)currentX
{
    return currentX;
}

-(void)setCurrentY:(GLfloat)_currentY
{
    currentY = _currentY;
    
    //center on currentY
    dy = currentY-ymin-dy-0.5*ySpan;
    
    [self setNeedsDisplay:YES];
}

-(GLfloat)currentY
{
    return currentY;
}

-(void)animateTransition: (NSTimer*)timer
{
    GLfloat endx,step,startx,d,*_spikeIdx;
    unsigned int _spidx,_nspikes;
    _spidx = [[[timer userInfo] objectForKey:@"spikeIdx"] unsignedIntValue];
    glBindBuffer(GL_ARRAY_BUFFER, spikesBuffer);
    _spikeIdx = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
    _nspikes = numSpikes;
    if (_spidx == 0)
    {
        startx = xmin;
    }
    else
    {
        startx = _spikeIdx[6*((_spidx-1)%_nspikes)];
    }
    endx = _spikeIdx[6*_spidx];
    glUnmapBuffer(GL_ARRAY_BUFFER);
    d = (endx-startx)-currentX;
    //step = expf(-d*d/1000.0);
    //step = (1.0/(1+expf(currentX-0.95*endx)))*(1.0/(1+expf(-(currentX-1.1*startx))));
    d = (endx-startx);
    //spend 2 seconds per transition; the first 10% of the transition should take 100ms
    if ( fabs(currentX-endx)<5 )
    {
        //spend 2 seconds around each spike
        step = (5/2)*0.01;
    }
    else
    {
        step = ((d-5)/2)*0.01;
    }
    
	if( currentX > xmax )
	{
		//load more data
		[self moveUp: self];
	}
    if(currentX < endx )
    {
        currentX+=step;
        //update the zoom
        windowSize = 10+xmin;
        dx = currentX-5-xmin;

        [self setNeedsDisplay:YES];
    }
    else
    {
        [timer invalidate];
        [animationTimer release];
        if( (currentX >= _spikeIdx[6*(_nspikes-1)]) || (currentX >= xmax))
        {
            //reset
            currentX = 0;
            _spidx = 0;
        }
        else
        {
            _spidx = (_spidx+1) % _nspikes; 
        }
        
        //schedule a new timer if there are still more spikes
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_spidx], @"spikeIdx", nil];
        animationTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(animateTransition:) userInfo:userInfo repeats:YES] retain];
        
    }
}

-(void)selectChannels:(NSIndexSet*)_channels usingColor:(NSData*)_color
{
	if( [_channels count] == 0)
		return;
	//check that we are not out of bounds
	if( [_channels lastIndex] >= numChannels)
		return;
	float *_colors,*_c,*_cl,*chColors;
	NSUInteger np,ch,i;
	if( _color == NULL )
	{
		_cl = malloc(3*sizeof(float));
		//red
		_cl[0] = 1.0;
		_cl[1] = 0.0;
		_cl[2] = 0.0;
	}
	else
	{
		_cl = (float*)[_color bytes];
	}
	chColors = (float*)[channelColors bytes];
	//change the color
	glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer  );
	_colors = (float*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
	np = (NSUInteger)(numPoints/numChannels);
	if( selectedChannels == NULL )
	{
		selectedChannels = [[NSMutableIndexSet indexSet] retain];
	}
	ch = [_channels firstIndex];
	while(ch != NSNotFound )
	{
		//NSLog(@"ch = %d" ,ch);
		_c = _colors + 3*numPoints + 3*ch*np;
		if( [selectedChannels containsIndex: ch] )
		{
			//channel already selected; deselect
			for(i=0;i<np;i++)
			{
				_c[3*i] = 1.0f;
				_c[3*i+1] = 0.5f;
				_c[3*i+2] = 0.3f;
			}
			[selectedChannels removeIndex: ch];
		}
		else
		{
			for(i=0;i<np;i++)
			{
				_c[3*i] = _cl[0];
				_c[3*i+1] = _cl[1];
				_c[3*i+2] = _cl[2];
			}
			[selectedChannels addIndex: ch];
		}
		//update the channel colors
		[channelColors replaceBytesInRange: NSMakeRange(3*ch*sizeof(float),3*sizeof(float)) withBytes: _c length:3*sizeof(float)];
		ch = [_channels indexGreaterThanIndex: ch];
	}
	glUnmapBuffer(GL_ARRAY_BUFFER);
	if(_color == NULL )
	{
		//cleanup
		free(_cl);
	}
	[self setNeedsDisplay: YES];

}


-(void)setDrawCurrentX:(BOOL)state
{
	if( state )
	{
		[[[[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"View"] submenu] itemWithTitle:@"Show cursor"] setTitle: @"Hide cursor"];
	}
	else
	{
		[[[[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"View"] submenu] itemWithTitle:@"Hide cursor"] setTitle: @"Show cursor"];
	}
	drawCurrentX = state;
	[self setNeedsDisplay:YES];
}

-(void)dealloc
{
    free(vertices);
    free(indices);
	free(channelLimits);
    //free(wfMinmax);
    free(colors);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewGlobalFrameDidChangeNotification
                                                  object:self];
    [self clearGLContext];
    [_pixelFormat release];
    [drawingColor release];
    [highlightColor release];
    [super dealloc];
}

@end
