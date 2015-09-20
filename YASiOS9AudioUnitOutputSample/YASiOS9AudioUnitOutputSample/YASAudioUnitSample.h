//
//  YASAudioUnitSample.h
//  YASiOS9AudioUnitOutputSample
//
//  Created by Yuki Yasoshima on 2015/09/20.
//  Copyright © 2015年 Objective-Audio. All rights reserved.
//

#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

static const Float64 kSampleRate = 44100.0;
static const UInt32 kChannels = 2;

@interface YASAudioUnitSample : AUAudioUnit

+ (AudioComponentDescription)audioComponentDescription;

- (AVAudioFormat *)format;
- (void)setRenderCallback:(void (^)(AVAudioPCMBuffer *))renderCallback;

@end
