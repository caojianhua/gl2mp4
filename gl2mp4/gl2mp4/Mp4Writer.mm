//
//  Mp4Writer.mm
//  GL2Mp4
//
//  Created by harriscao on 13-10-17.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import "Mp4Writer.h"
#import <AVFoundation/AVFoundation.h>

@interface Mp4Writer()
{
  
}

-(void) addVideoWriter:(AVAssetWriter*) mp4Writer;
-(void) addAudioWriter:(AVAssetWriter*) mp4Writer;

-(CVPixelBufferRef) createPixelBufferRefFromPixels:(void*) data
                                             width:(int) w
                                            height:(int) h;

-(CVPixelBufferRef) createPixelBufferRefFromImage:(CGImageRef) image;

-(void)complitemp4Writer;

@end


@implementation Mp4Writer

@synthesize isStarted = _isStarted;

-(id) initWidthPath:(NSString*) path
{
  self = [super init];
  
  _writePath = path;
  
  _alreadyWriteFrames = 0;
  _lastFrameTime = kCMTimeZero;
  _isStarted = NO;
  
  return self;
}

-(void) prepare
{
  [[NSFileManager defaultManager] removeItemAtPath:_writePath error:nil];
  NSURL* _recordUrl = [NSURL fileURLWithPath:_writePath];
  
  NSError *error = nil;
  _mp4Writer = [[AVAssetWriter alloc] initWithURL:_recordUrl
                                         fileType:AVFileTypeQuickTimeMovie
                                            error:&error];
  NSParameterAssert(_mp4Writer);
  
  [self addVideoWriter:_mp4Writer];
  
}

-(void) start
{
  if (_mp4Writer.status == AVAssetWriterStatusUnknown)
  {
    [_mp4Writer startWriting];
    [_mp4Writer startSessionAtSourceTime:kCMTimeZero];
    
    _alreadyWriteFrames = 0;
  }
  
  if(_mp4Writer.status == AVAssetWriterStatusWriting)
  {
    NSLog(@"Start mp4 writer OK!");
    _isStarted = YES;
  }
}

-(void) stop
{
  _isStarted = NO;
  
  [_videoWriterInput markAsFinished];
  
  [_mp4Writer endSessionAtSourceTime:_lastFrameTime];
  
  [_mp4Writer finishWritingWithCompletionHandler: ^{
    [self complitemp4Writer];
  }];
  CVPixelBufferPoolRelease(_mp4WriterAdaptor.pixelBufferPool);
}

-(BOOL) addVideoFrameIntoMp4:(void*) frameData width:(int) w height:(int) h
{
  if(_mp4Writer.status != AVAssetWriterStatusWriting)
  {
    NSLog(@"Can't write video into mp4 writer.status(%d)", _mp4Writer.status);
    return NO;
  }
  
  CMTime currentTime = CMTimeAdd(_lastFrameTime, CMTimeMake(1, 30));
  _lastFrameTime = currentTime;
  
  CVPixelBufferRef pxBufferRef = [self createPixelBufferRefFromPixels:frameData width:w height:h];
  NSParameterAssert(pxBufferRef);
  
  BOOL result = [_mp4WriterAdaptor appendPixelBuffer:pxBufferRef withPresentationTime:currentTime];
  if(!result)
  {
    NSLog(@"failed to append buffer");
    NSLog(@"The error is %@", [_mp4Writer error]);
  }
  
  CVPixelBufferRelease(pxBufferRef);
  _alreadyWriteFrames++;
  
  return result;
}

-(BOOL) addImageIntoMp4:(CGImageRef) image
{
  if(_mp4Writer.status != AVAssetWriterStatusWriting)
  {
    NSLog(@"Can't write image into mp4 writer.status(%d)", _mp4Writer.status);
    return NO;
  }
  
  CMTime currentTime = CMTimeAdd(_lastFrameTime, CMTimeMake(1, 30));
  _lastFrameTime = currentTime;
  
  CVPixelBufferRef pxBufferRef = [self createPixelBufferRefFromImage:image];
  NSParameterAssert(pxBufferRef);
  
  BOOL result = [_mp4WriterAdaptor appendPixelBuffer:pxBufferRef withPresentationTime:currentTime];
  if(!result)
  {
    NSLog(@"failed to append buffer");
    NSLog(@"The error is %@", [_mp4Writer error]);
  }
  
  CVPixelBufferRelease(pxBufferRef);
  _alreadyWriteFrames++;

  return result;
}

// private
-(void) addVideoWriter:(AVAssetWriter*) mp4Writer
{
  NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithDouble:128.0 * 1024.0],
                                         AVVideoAverageBitRateKey,
                                         nil ];
  
  NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                 AVVideoCodecH264, AVVideoCodecKey,
                                 [NSNumber numberWithInt:640], AVVideoWidthKey,
                                 [NSNumber numberWithInt:960], AVVideoHeightKey,
                                 videoCompressionProps, AVVideoCompressionPropertiesKey,
                                 nil];
  _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                         outputSettings:videoSettings];
  NSParameterAssert(_videoWriterInput);
  
  NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
  [attributes setObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
  [attributes setObject:[NSNumber numberWithUnsignedInt:640] forKey:(NSString*)kCVPixelBufferWidthKey];
  [attributes setObject:[NSNumber numberWithUnsignedInt:960] forKey:(NSString*)kCVPixelBufferHeightKey];
  
  _mp4WriterAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput
                                                                                       sourcePixelBufferAttributes:attributes];
  NSParameterAssert([_mp4Writer canAddInput:_videoWriterInput]);
  [_mp4Writer addInput:_videoWriterInput];
  _videoWriterInput.expectsMediaDataInRealTime = YES;
}

-(void) addAudioWriter:(AVAssetWriter*) mp4Writer
{
  
}

-(CVPixelBufferRef) createPixelBufferRefFromPixels:(void*) data
                                             width:(int) w
                                            height:(int) h
{
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           [NSNumber numberWithInt:w], kCVPixelBufferWidthKey,
                           [NSNumber numberWithInt:h], kCVPixelBufferHeightKey,
                           nil];
  
  CVPixelBufferRef pxbuffer = NULL;
  
  CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, data,
                                                 4 * w, NULL, NULL, (__bridge CFDictionaryRef)options, &pxbuffer);
  
  if(status != kCVReturnSuccess)
  {
    NSLog(@"Create PixelBufferRef failed(%d)", status);
  }
  
  return pxbuffer;
}

-(CVPixelBufferRef) createPixelBufferRefFromImage:(CGImageRef) image
{
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           nil];
  
  CVPixelBufferRef pxbuffer = NULL;
  
  CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image),
                      CGImageGetHeight(image), kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                      &pxbuffer);
  
  CVPixelBufferCreateWithBytes(kCFAllocatorDefault, 640, 960, kCVPixelFormatType_32ARGB, NULL,
                               4*CGImageGetWidth(image), NULL, NULL, (__bridge CFDictionaryRef)options, &pxbuffer);
  
  CVPixelBufferLockBaseAddress(pxbuffer, 0);
  void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
  
  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image),
                                               CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace,
                                               kCGImageAlphaNoneSkipFirst);
  
  CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
  
  CGAffineTransform flipVertical = CGAffineTransformMake(
                                                         1, 0, 0, -1, 0, CGImageGetHeight(image)
                                                         );
  CGContextConcatCTM(context, flipVertical);
  
  CGAffineTransform flipHorizontal = CGAffineTransformMake(
                                                           -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0
                                                           );
  
  CGContextConcatCTM(context, flipHorizontal);

  CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);

  CGColorSpaceRelease(rgbColorSpace);
  CGContextRelease(context);
  
  CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
  
  return pxbuffer;

}

-(void)complitemp4Writer
{
  
}

@end
