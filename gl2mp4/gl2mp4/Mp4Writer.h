//
//  Mp4Writer.h
//  GL2Mp4
//
//  Created by harriscao on 13-10-17.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class AVAssetWriter;
@class AVAssetWriterInput;
@class AVAssetWriterInputPixelBufferAdaptor;


// RGBA8888 Supported only
@interface Mp4Writer : NSObject
{  
  @private
  BOOL _started;
  
  NSString *_writePath;
  NSURL *_recordUrl;
  
  AVAssetWriter* _mp4Writer;
  AVAssetWriterInput* _videoWriterInput;
  AVAssetWriterInput* _audioWriterInput;
  
  AVAssetWriterInputPixelBufferAdaptor* _mp4WriterAdaptor;
  
  CMTime _lastFrameTime;
  long _alreadyWriteFrames;
  CMTime _lastVideoFrameTime;
}

@property(readonly) BOOL isStarted;

-(id) initWidthPath:(NSString*) path;

-(void) prepare;
-(void) start;
-(void) stop;

-(BOOL) addVideoFrameIntoMp4:(void*) frameData width:(int) w height:(int) h;
-(BOOL) addImageIntoMp4:(CGImageRef) image;

@end
