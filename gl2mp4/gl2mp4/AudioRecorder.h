//
//  AudioRecord.h
//  gl2mp4
//
//  Created by CaoJianhua on 13-10-23.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVAudioRecorder;

@interface AudioRecorder : NSObject<AVAudioRecorderDelegate>
{
  @private
  AVAudioRecorder* _audioRecorder;
  NSString* _audioFilePath;
}

@property(readonly) NSString* audioFilePath;

-(id)initWithPath:(NSString*) path;

-(BOOL) prepare;
-(BOOL) startRecord;
-(BOOL) stopRecord;

@end
