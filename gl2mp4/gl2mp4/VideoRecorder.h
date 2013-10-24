//
//  Mp4Writer.h
//  GL2Mp4
//
//  Created by harriscao on 13-10-17.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

@class AVAssetWriter;
@class AVAssetWriterInput;
@class AVAssetWriterInputPixelBufferAdaptor;
@class AVCaptureAudioDataOutput;
@class AVCaptureSession;
@class AVAudioRecorder;


// RGBA8888 Supported only
@interface VideoRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate, AVAudioRecorderDelegate>
{  
  @private
  BOOL _started;
  
  NSString *_videoFilePath;
  
  NSURL *_recordUrl;
  
  AVAssetWriter* _mp4Writer;
  AVAssetWriterInput* _videoWriterInput;
  AVAssetWriterInput* _audioWriterInput;
  
  AVAssetWriterInputPixelBufferAdaptor* _mp4WriterAdaptor;
  
  AVCaptureSession* _avCaptureSession;
    
  //Audio mic
  AVCaptureAudioDataOutput* _audioCaptureOutput;
  
  AVAudioRecorder* _audioRecorder;
  
  //Audio convert
  AudioConverterRef _audioConverterRef;
  char* _pcmBuffer;
  size_t _pcmBufferSize;
  
  char* _aacBuffer;
  size_t _aacBufferSize;

  long _alreadyWriteVideoFrames;
  CMTime _lastVideoFrameTime;
  
  long _alreadyWriteAudioSamples;
  CMTime _lastAudioSampleTime;
}

@property(readonly) BOOL isStarted;

-(id) initWithPath:(NSString*) videoPath;

-(void) prepare;
-(void) start;
-(void) stop;

-(BOOL) addVideoFrameIntoMp4:(void*) frameData width:(int) w height:(int) h;
-(BOOL) addImageIntoMp4:(CGImageRef) image;

-(BOOL) addAudioSamplesIntoMp4:(void*) samples nsample:(int) n;

@end
