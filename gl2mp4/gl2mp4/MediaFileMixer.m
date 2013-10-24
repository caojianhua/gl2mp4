//
//  MediaFileMixer.m
//  gl2mp4
//
//  Created by CaoJianhua on 13-10-23.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import "MediaFileMixer.h"

#import <AVFoundation/AVFoundation.h>

@implementation MediaFileMixer

+(BOOL) mixAduio:(NSString*)aacPath video:(NSString*)mp4Path toMov:(NSString*)movPath
{
  AVMutableComposition* mixComposition = [AVMutableComposition composition];
  
  NSURL* audio_inputFileUrl = [NSURL fileURLWithPath:aacPath];
  NSURL* video_inputFileUrl = [NSURL fileURLWithPath:mp4Path];

  NSURL* outputFileUrl = [NSURL fileURLWithPath:movPath];
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:movPath])
  {
    [[NSFileManager defaultManager] removeItemAtPath:movPath error:nil];
  }

  CMTime nextClipStartTime = kCMTimeZero;

  AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
  CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);

  AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:nextClipStartTime error:nil];

  AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
  CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);

  AVMutableCompositionTrack *b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
  [b_compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:nextClipStartTime error:nil];
  
  AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];

  _assetExport.outputFileType = AVFileTypeQuickTimeMovie;
  _assetExport.outputURL = outputFileUrl;
  
  [_assetExport exportAsynchronouslyWithCompletionHandler:

   ^(void ) {
 
   }
   ];

  return YES;
}

@end
