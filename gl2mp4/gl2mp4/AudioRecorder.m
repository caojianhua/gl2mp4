//
//  AudioRecord.m
//  gl2mp4
//
//  Created by CaoJianhua on 13-10-23.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//


#import <AVFoundation/AVFoundation.h>

#import "AudioRecorder.h"

@implementation AudioRecorder

@synthesize audioFilePath = _audioFilePath;

-(id)initWithPath:(NSString*) path
{
  self = [super init];
  _audioFilePath = path;
  
  return self;
}

-(BOOL) prepare
{
  if ([[NSFileManager defaultManager] fileExistsAtPath:_audioFilePath])
  {
    [[NSFileManager defaultManager] removeItemAtPath:_audioFilePath error:nil];
  }
  
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  
  NSError *err = nil;
  
  [audioSession setCategory :AVAudioSessionCategoryPlayAndRecord error:&err];
  
  if(err){
    NSLog(@"audioSession: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
    return NO;
  }
  [audioSession setActive:YES error:&err];
  
  err = nil;
  
  if(err){
    NSLog(@"audioSession: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
    
    return NO;
  }
  
  NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
  
  [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
  
  [recordSetting setValue:[NSNumber numberWithFloat:8000.0] forKey:AVSampleRateKey];
  [recordSetting setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
  [recordSetting setValue :[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
  [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
  [recordSetting setValue :[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
  
  // Create a new dated file
  NSURL *url = [NSURL fileURLWithPath:_audioFilePath];
  
  err = nil;
  _audioRecorder = [[ AVAudioRecorder alloc] initWithURL:url settings:recordSetting error:&err];
  if(!_audioRecorder){
    NSLog(@"recorder: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
    return NO;
  }
  
  //prepare to record
  [_audioRecorder setDelegate:self];
  [_audioRecorder prepareToRecord];
  _audioRecorder.meteringEnabled = YES;
  BOOL audioHWAvailable = audioSession.inputIsAvailable;
  if (! audioHWAvailable) {
    NSLog(@"Warning: Audio input hardware not available");
    return NO;
  }
  
  return YES;
}

-(BOOL) startRecord
{
  [_audioRecorder record];
  return YES;
}

-(BOOL) stopRecord
{
  [_audioRecorder stop];
  return YES;
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
  NSLog(@"Audio recording finish!");
}



@end
