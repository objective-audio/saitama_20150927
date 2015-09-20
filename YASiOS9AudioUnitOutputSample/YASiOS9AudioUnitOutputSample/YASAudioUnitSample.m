//
//  YASAudioUnitSample.m
//  YASiOS9AudioUnitOutputSample
//
//  Created by Yuki Yasoshima on 2015/09/20.
//  Copyright © 2015年 Objective-Audio. All rights reserved.
//

#import "YASAudioUnitSample.h"
#import <Accelerate/Accelerate.h>

static const UInt32 kMaximumFrames = 4096;

@interface YASAudioUnitSampleKernel : NSObject
@property AVAudioPCMBuffer *outputBuffer;
@property (copy) void (^renderBlock)(AVAudioPCMBuffer *buffer);
@end

@implementation YASAudioUnitSampleKernel

- (instancetype)init
{
    self = [super init];
    if (self) {
        AVAudioFormat *bufferFormat =
            [[AVAudioFormat alloc] initStandardFormatWithSampleRate:kSampleRate channels:kChannels];
        self.outputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:bufferFormat frameCapacity:kMaximumFrames];
    }
    return self;
}

@end

@interface YASAudioUnitSample ()

@property YASAudioUnitSampleKernel *kernel;

@property AVAudioFormat *format;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@end

@implementation YASAudioUnitSample

+ (AudioComponentDescription)audioComponentDescription
{
    AudioComponentDescription acd = {
        // Generatorはインプットなしでレンダーされる。Effectだとインプットに接続しないとレンダーされない
        .componentType = kAudioUnitType_Generator,
        .componentSubType = 'smpl',
        .componentManufacturer = 'Demo',
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };
    return acd;
}

+ (void)initialize
{
    // サンプル用なのでExtensionではやってはいけない
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self registerSubclass:[YASAudioUnitSample class]
            asComponentDescription:[self audioComponentDescription]
                              name:@"SampleAudioUnitName"
                           version:UINT32_MAX];
    });
}

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError
{
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    if (self) {
        // １回で処理できる最大フレーム数を設定
        self.maximumFramesToRender = kMaximumFrames;

        // とりあえず適当にフォーマットを決める
        self.format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:kSampleRate channels:kChannels];

        // バックグラウンドでのオーディオ処理用のオブジェクトを生成
        self.kernel = [[YASAudioUnitSampleKernel alloc] init];

        AUAudioUnitBus *outputBus = [[AUAudioUnitBus alloc] initWithFormat:self.format error:nil];
        self.outputBusArray =
            [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[outputBus]];
    }
    return self;
}

- (AUAudioUnitBusArray *)outputBusses
{
    return self.outputBusArray;
}

- (AUInternalRenderBlock)internalRenderBlock
{
    // オーディオ処理をするブロックを返す

    YASAudioUnitSampleKernel *kernel = self.kernel;

    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timeStamp,
                              AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData,
                              const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
        AVAudioPCMBuffer *buffer = kernel.outputBuffer;
        buffer.frameLength = frameCount;

        void (^renderBlock)(AVAudioPCMBuffer *buffer) = kernel.renderBlock;

        if (renderBlock) {
            renderBlock(buffer);
        }

        for (UInt32 i = 0; i < outputData->mNumberBuffers; ++i) {
            if (outputData->mBuffers[i].mData == NULL) {
                outputData->mBuffers[i].mData = buffer.mutableAudioBufferList->mBuffers[i].mData;
            }
        }

        return noErr;
    };

    return noErr;
}

- (void)setRenderCallback:(void (^)(AVAudioPCMBuffer *))renderCallback
{
    self.kernel.renderBlock = renderCallback;
}

@end
