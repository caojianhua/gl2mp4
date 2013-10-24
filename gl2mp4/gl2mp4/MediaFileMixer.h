//
//  MediaFileMixer.h
//  gl2mp4
//
//  Created by CaoJianhua on 13-10-23.
//  Copyright (c) 2013年 harriscao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MediaFileMixer : NSObject
{
  @private
  
}

+(BOOL) mixAduio:(NSString*)aacPath video:(NSString*)mp4Path toMov:(NSString*)movPath;

@end
