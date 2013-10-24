//
//  Mp4Writer.mm
//  GL2Mp4
//
//  Created by harriscao on 13-10-17.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import "VideoRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface VideoRecorder()
{
  
}

-(void) addVideoWriter:(AVAssetWriter*) mp4Writer;

-(CVPixelBufferRef) createPixelBufferRefFromPixels:(void*) data
                                             width:(int) w
                                            height:(int) h;

-(CVPixelBufferRef) createPixelBufferRefFromImage:(CGImageRef) image;

-(void)complitemp4Writer;

@end

@implementation VideoRecorder

@synthesize isStarted = _isStarted;

-(id) initWithPath:(NSString*) videoPath;
{
  self = [super init];
  
  _videoFilePath = videoPath;
  
  _alreadyWriteVideoFrames = 0;
  _lastVideoFrameTime = kCMTimeZero;
  
  _alreadyWriteAudioSamples = 0;
  _lastAudioSampleTime = kCMTimeZero;
  
  _isStarted = NO;
  
  _aacBufferSize = 1024 * 5;
  _aacBuffer = (char*)malloc(_aacBufferSize);
  
  return self;
}

-(void) prepare
{
  if ([[NSFileManager defaultManager] fileExistsAtPath:_videoFilePath])
  {
    [[NSFileManager defaultManager] removeItemAtPath:_videoFilePath error:nil];
  }
  
  NSURL* _recordUrl = [NSURL fileURLWithPath:_videoFilePath];
  
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
    
    _alreadyWriteVideoFrames = 0;
  }
  
  if(_mp4Writer.status == AVAssetWriterStatusWriting)
  {
    NSLog(@"Start mp4 writer OK!");
    _isStarted = YES;
  }
}

-(void) stop
{
  if(!_isStarted)
  {
    return;
  }
  
  _isStarted = NO;
  
  // stop audio file record
  
  [_videoWriterInput markAsFinished];
  
  [_mp4Writer endSessionAtSourceTime:_lastVideoFrameTime];
  
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
  
  CMTime currentTime = CMTimeAdd(_lastVideoFrameTime, CMTimeMake(1, 30));
  _lastVideoFrameTime = currentTime;
  
  CVPixelBufferRef pxBufferRef = [self createPixelBufferRefFromPixels:frameData width:w height:h];
  NSParameterAssert(pxBufferRef);
  
  BOOL result = [_mp4WriterAdaptor appendPixelBuffer:pxBufferRef withPresentationTime:currentTime];
  if(!result)
  {
    NSLog(@"failed to append buffer");
    NSLog(@"The error is %@", [_mp4Writer error]);
  }
  
  CVPixelBufferRelease(pxBufferRef);
  _alreadyWriteVideoFrames++;
  
  return result;
}


-(BOOL) addImageIntoMp4:(CGImageRef) image
{
  if(_mp4Writer.status != AVAssetWriterStatusWriting)
  {
    NSLog(@"Can't write image into mp4 writer.status(%d)", _mp4Writer.status);
    return NO;
  }
  
  CMTime currentTime = CMTimeAdd(_lastVideoFrameTime, CMTimeMake(1, 30));
  _lastVideoFrameTime = currentTime;
  
  CVPixelBufferRef pxBufferRef = [self createPixelBufferRefFromImage:image];
  NSParameterAssert(pxBufferRef);
  
  BOOL result = [_mp4WriterAdaptor appendPixelBuffer:pxBufferRef withPresentationTime:currentTime];
  if(!result)
  {
    NSLog(@"failed to append buffer");
    NSLog(@"The error is %@", [_mp4Writer error]);
  }
  
  CVPixelBufferRelease(pxBufferRef);
  _alreadyWriteVideoFrames++;

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
  
  // rgb565
//  [attributes setObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_16LE565] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
  
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
  AudioChannelLayout acl;
  bzero( &acl, sizeof(acl));
  acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
  
  NSDictionary* audioOutputSettings =  [NSDictionary dictionaryWithObjectsAndKeys:
                                        [ NSNumber numberWithInt: kAudioFormatMPEG4AAC ], AVFormatIDKey,
                                        [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                        [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                                        [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                                        nil];

  _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeAudio
                                                         outputSettings: nil ];
  _audioWriterInput.expectsMediaDataInRealTime = YES;
  [mp4Writer addInput:_audioWriterInput];
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

  //RGB565
//  CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, w, h, kCVPixelFormatType_16LE565, data,
//                                                 2 * w, NULL, NULL, (__bridge CFDictionaryRef)options, &pxbuffer);

  
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
  NSLog(@"Video recording finish!");
}

// capture audio samples
/*
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  if( !CMSampleBufferDataIsReady(sampleBuffer) )
  {
    NSLog( @"sample buffer is not ready. Skipping sample" );
    return;
  }
  
  if( _isStarted == YES )
  {
    _lastAudioSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if([_audioWriterInput isReadyForMoreMediaData])
    {
      CMFormatDescriptionRef cmFormat = CMSampleBufferGetFormatDescription(sampleBuffer);
      
      // get the audio samples into a common buffer _pcmBuffer
      CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
      CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
      
      // use AudioConverter to
      UInt32 ouputPacketsCount = 1;
      AudioBufferList bufferList;
      bufferList.mNumberBuffers = 1;
      bufferList.mBuffers[0].mNumberChannels = 1;
      bufferList.mBuffers[0].mDataByteSize = _aacBufferSize;
      bufferList.mBuffers[0].mData = _aacBuffer;
      OSStatus st = AudioConverterFillComplexBuffer(_audioConverterRef, AudioConverterComplexInputData, (__bridge void *) self, &ouputPacketsCount, &bufferList, NULL);
      
      if (0 == st && ouputPacketsCount > 0) {
        // ... send bufferList.mBuffers[0].mDataByteSize bytes from _aacBuffer...
        NSLog(@"ouputPacketsCount: %ld", ouputPacketsCount);
        void* aacData = bufferList.mBuffers[0].mData;
        int aacDataSize = bufferList.mBuffers[0].mDataByteSize;

        CMSampleBufferRef aacSampleBufferRef;
        CMBlockBufferRef aacBlockBuffer = NULL;
        CMAudioFormatDescriptionRef aacFormatDescriptionRef;
        static int64_t sample_position_ = 0;
        AudioStreamPacketDescription aacPacketDescriptions;
        
        OSStatus result;
        
        result = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                    NULL,
                                                    aacDataSize,
                                                    kCFAllocatorDefault,
                                                    NULL,
                                                    0,
                                                    aacDataSize,
                                                    kCMBlockBufferAssureMemoryNowFlag,
                                                    &aacBlockBuffer);

        
        result = CMBlockBufferReplaceDataBytes(aacData,
                                               aacBlockBuffer,
                                               0,
                                               aacDataSize);
        
        
        AudioStreamBasicDescription aacASBD = {0};
        aacASBD.mFormatID = kAudioFormatMPEG4AAC;
        aacASBD.mSampleRate = 44100.0;
        aacASBD.mChannelsPerFrame = 1;
        UInt32 size = sizeof(aacASBD);
        AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &aacASBD);
        
        CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                       &aacASBD,
                                       0,
                                       NULL,
                                       0,
                                       NULL,
                                       NULL,
                                       &aacFormatDescriptionRef
                                       );
        
        aacPacketDescriptions.mStartOffset = 0;
        aacPacketDescriptions.mVariableFramesInPacket = 1;
        aacPacketDescriptions.mDataByteSize = aacDataSize;
        
        
        CMTime timestamp = CMTimeMake(sample_position_, 44100);
        sample_position_ += 1;
        
        result = CMAudioSampleBufferCreateWithPacketDescriptions(kCFAllocatorDefault,
                                                                 aacBlockBuffer,
                                                                 TRUE,
                                                                 NULL,
                                                                 NULL,
                                                                 aacFormatDescriptionRef,
                                                                 1,
                                                                 timestamp,
                                                                 &aacPacketDescriptions,
                                                                 &aacSampleBufferRef);
        
        CMFormatDescriptionRef cmFormat = CMSampleBufferGetFormatDescription(aacSampleBufferRef);
        
        
        CMTime time = CMTimeMake(0, 30);
        
        CFDictionaryRef v = CMTimeCopyAsDictionary (time, kCFAllocatorDefault);
        CMSetAttachment(aacSampleBufferRef, kCMSampleBufferAttachmentKey_TrimDurationAtStart, v, NULL);
        
        CFTypeRef ref = CMGetAttachment(aacSampleBufferRef, kCMSampleBufferAttachmentKey_TrimDurationAtStart, NULL);
        
        BOOL res = [_audioWriterInput appendSampleBuffer:aacSampleBufferRef];
        
        CFRelease(aacBlockBuffer);
        CFRelease(aacFormatDescriptionRef);
        CFRelease(aacSampleBufferRef);
      }
    
      //BOOL res = [_audioWriterInput appendSampleBuffer:sampleBuffer];
      
    }
  }
}
 */

/*
- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer
{
  static AudioClassDescription desc;
  
  UInt32 encoderSpecifier = type;
  OSStatus st;
  
  UInt32 size;
  st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                  sizeof(encoderSpecifier),
                                  &encoderSpecifier,
                                  &size);
  if (st) {
    //NSLog(@"error getting audio format propery info: %d", st);
    return nil;
  }
  
  unsigned int count = size / sizeof(AudioClassDescription);
  AudioClassDescription descriptions[count];
  st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                              sizeof(encoderSpecifier),
                              &encoderSpecifier,
                              &size,
                              descriptions);
  if (st) {
    //NSLog(@"error getting audio format propery: %s", st);
    return nil;
  }
  
  for (unsigned int i = 0; i < count; i++) {
    if ((type == descriptions[i].mSubType) &&
        (manufacturer == descriptions[i].mManufacturer)) {
      memcpy(&desc, &(descriptions[i]), sizeof(desc));
      return &desc;
    }
  }
  
  return nil;
}
 */

/*
-(BOOL) createAudioConvert:(AudioConverterRef*) convert;
{
  AudioStreamBasicDescription pcmASBD = {0};
  pcmASBD.mSampleRate = 44100.0;
  pcmASBD.mFormatID = kAudioFormatLinearPCM;
  pcmASBD.mFormatFlags = kAudioFormatFlagsCanonical;
  pcmASBD.mChannelsPerFrame = 1;
  pcmASBD.mBytesPerFrame = 2;
  pcmASBD.mFramesPerPacket = 1;
  pcmASBD.mBytesPerPacket = 2;
  pcmASBD.mBitsPerChannel = 16;
  
  AudioStreamBasicDescription aacASBD = {0};
  aacASBD.mFormatID = kAudioFormatMPEG4AAC;
  aacASBD.mSampleRate = pcmASBD.mSampleRate;
  aacASBD.mChannelsPerFrame = pcmASBD.mChannelsPerFrame;
  UInt32 size = sizeof(aacASBD);
  AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &aacASBD);
  
  AudioClassDescription *description = [self
                                        getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                        fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
  
  if (!description) {
    return NO;
  }
  
  OSStatus st = AudioConverterNewSpecific(&pcmASBD, &aacASBD, 1, description, convert);
  
  return (st == 0);
}
 */

/*
OSStatus AudioConverterComplexInputData(AudioConverterRef inAudioConverter,
                                        UInt32* ioNumberDataPackets,
                                        AudioBufferList* ioData,
                                        AudioStreamPacketDescription** outDataPacketDescription,
                                        void* inUserData)
{
  return 0;
}
 */

/*
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *) aRecorder successfully:(BOOL)flag
{

}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)arecorder error:(NSError *)error
{

}
 */


@end
