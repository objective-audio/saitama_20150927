//
//  ViewController.m
//  YASiOS9AudioUnitOutputSample
//
//  Created by Yuki Yasoshima on 2015/09/20.
//  Copyright © 2015年 Objective-Audio. All rights reserved.
//

#import "ViewController.h"
#import "YASAudioUnitSample.h"
#import <Accelerate/Accelerate.h>

Float32 fill_sine(Float32 *out_data, const UInt32 length, const Float64 start_phase, const Float64 phase_per_frame)
{
    if (!out_data || length == 0) {
        return start_phase;
    }

    Float64 phase = start_phase;

    for (UInt32 i = 0; i < length; ++i) {
        out_data[i] = phase;
        phase = fmod(phase + phase_per_frame, 2.0 * M_PI);
    }

    const int len = length;
    vvsinf(out_data, out_data, &len);

    return phase;
}

@interface ViewController ()

@property (nonatomic) AVAudioEngine *engine;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil]) {
        NSLog(@"%@", error);
        return;
    }

    self.engine = [[AVAudioEngine alloc] init];

    // 非同期でAVAudioUnit（AVAudioNode）を生成する
    [AVAudioUnit
        instantiateWithComponentDescription:[YASAudioUnitSample audioComponentDescription]
                                    options:0
                          completionHandler:^(__kindof AVAudioUnit *_Nullable audioUnit, NSError *_Nullable error) {
                              if (!audioUnit) {
                                  return;
                              }

                              YASAudioUnitSample *sampleUnit = (YASAudioUnitSample *)audioUnit.AUAudioUnit;

                              __block Float64 phase = 0;
                              [sampleUnit setRenderCallback:^(AVAudioPCMBuffer *buffer) {
                                  AVAudioFormat *format = buffer.format;
                                  const Float64 currentPhase = phase;
                                  const Float64 phasePerFrame = 1000.0 / format.sampleRate * 2.0 * M_PI;
                                  for (UInt32 ch_idx = 0; ch_idx < format.channelCount; ++ch_idx) {
                                      Float32 *ptr = buffer.floatChannelData[ch_idx];
                                      phase = fill_sine(ptr, buffer.frameLength, currentPhase, phasePerFrame);
                                  }
                              }];

                              [self.engine attachNode:audioUnit];
                              [self.engine connect:audioUnit to:self.engine.mainMixerNode format:sampleUnit.format];

                              NSError *localError = nil;

                              if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
                                  NSLog(@"%@", localError);
                                  return;
                              }

                              if (![self.engine startAndReturnError:&localError]) {
                                  NSLog(@"%@", localError);
                              }
                          }];
}

@end
