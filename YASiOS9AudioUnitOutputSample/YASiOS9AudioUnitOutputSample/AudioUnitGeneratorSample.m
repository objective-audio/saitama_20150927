//
//  AudioUnitGeneratorSample.m
//  YASiOS9AudioUnitOutputSample
//
//  Created by Yuki Yasoshima on 2015/09/20.
//  Copyright © 2015年 Objective-Audio. All rights reserved.
//

#import "AudioUnitGeneratorSample.h"
#import <Accelerate/Accelerate.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUnitGeneratorSampleKernel : NSObject
@property (nullable) AVAudioPCMBuffer *outputBuffer;
@property (copy) void (^renderBlock)(AVAudioPCMBuffer *buffer);
@end

@implementation AudioUnitGeneratorSampleKernel

- (void)setupBufferWithFormat:(AVAudioFormat *)format frames:(NSUInteger)frames
{
    self.outputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frames];
}

- (void)disposeBuffer
{
    self.outputBuffer = nil;
}

@end

@interface AudioUnitGeneratorSample ()

@property AudioUnitGeneratorSampleKernel *kernel;
@property (copy) AUInternalRenderBlock internalBlock;

@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@end

@implementation AudioUnitGeneratorSample

+ (AudioComponentDescription)audioComponentDescription
{
    AudioComponentDescription acd = {
        // Generatorはインプットの接続なしでレンダーされる。Effectはインプットに接続しないとレンダーされない
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
    // AudioUnitGeneratorSampleをAudioUnitシステムに登録する
    // サンプル用なのでExtensionではやってはいけない

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self registerSubclass:[AudioUnitGeneratorSample class]
            asComponentDescription:[self audioComponentDescription]
                              name:@"SampleAudioUnitName"
                           version:UINT32_MAX];
    });
}

- (nullable instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                              options:(AudioComponentInstantiationOptions)options
                                                error:(NSError **)outError
{
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    if (self) {
        // バックグラウンドでのオーディオ処理用のオブジェクトを生成
        AudioUnitGeneratorSampleKernel *kernel = [[AudioUnitGeneratorSampleKernel alloc] init];
        self.kernel = kernel;

        self.internalBlock =
            ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timeStamp,
                               AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData,
                               const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
                // このブロックの中はオーディオのレンダースレッドから呼ばれる

                AVAudioPCMBuffer *buffer = kernel.outputBuffer;
                buffer.frameLength = frameCount;

                void (^renderBlock)(AVAudioPCMBuffer *buffer) = kernel.renderBlock;

                if (renderBlock) {
                    renderBlock(buffer);
                }

                for (UInt32 i = 0; i < outputData->mNumberBuffers; ++i) {
                    void *outData = outputData->mBuffers[i].mData;
                    void *inData = buffer.mutableAudioBufferList->mBuffers[i].mData;
                    if (outData == NULL) {
                        outputData->mBuffers[i].mData = inData;
                    } else if (outData != inData) {
                        memcpy(outData, inData, outputData->mBuffers[i].mDataByteSize);
                    }
                }

                return noErr;
            };

        // バスを作る（アウトプットがひとつ）
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
        AUAudioUnitBus *outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
        self.outputBusArray =
            [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses:@[outputBus]];
    }
    return self;
}

- (AUInternalRenderBlock)internalRenderBlock
{
    NSLog(@"call internalRenderBlock");

    return self.internalBlock;
}

- (void)setRenderBlock:(void (^)(AVAudioPCMBuffer *))renderBlock
{
    NSLog(@"call setRenderBlock");

    self.kernel.renderBlock = renderBlock;
}

- (AUAudioUnitBusArray *)outputBusses
{
    NSLog(@"call outputBusses");

    return self.outputBusArray;
}

- (BOOL)shouldChangeToFormat:(AVAudioFormat *)format forBus:(AUAudioUnitBus *)bus
{
    NSLog(@"call shouldChangeToFormat:forBus:");

    return YES;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError *_Nullable __autoreleasing *)outError
{
    NSLog(@"call allocateRenderResourcesAndReturnError");

    BOOL result = [super allocateRenderResourcesAndReturnError:outError];

    if (result) {
        AUAudioUnitBus *bus = self.outputBusArray[0];
        [self.kernel setupBufferWithFormat:bus.format frames:self.maximumFramesToRender];
    }

    return result;
}

- (void)deallocateRenderResources
{
    NSLog(@"call deallocateRenderResources");

    [self.kernel disposeBuffer];

    [super deallocateRenderResources];
}

@end

NS_ASSUME_NONNULL_END
