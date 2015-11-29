//
//  AudioUnitGeneratorSample.h
//  YASiOS9AudioUnitOutputSample
//
//  Created by Yuki Yasoshima on 2015/09/20.
//  Copyright © 2015年 Objective-Audio. All rights reserved.
//

#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitGeneratorSample : AUAudioUnit

+ (AudioComponentDescription)audioComponentDescription;

- (void)setRenderBlock:(void (^)(AVAudioPCMBuffer *))renderBlock;

@end

NS_ASSUME_NONNULL_END
