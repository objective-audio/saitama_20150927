//
//  AudioUnitGeneratorSample.swift
//  iOS9AudioUnitOutputSample
//
//  Created by 八十嶋祐樹 on 2015/11/23.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import AVFoundation

class AudioUnitGeneratorSample: AUAudioUnit {
    
    // MARK: - Private
    
    private let _kernel: AudioUnitSampleKernel = AudioUnitSampleKernel()
    private var _outputBusArray: AUAudioUnitBusArray?
    private var _internalRenderBlock: AUInternalRenderBlock?
    
    // MARK: - Global
    
    static let audioComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Generator,
        componentSubType: hfsTypeCode("gnsp"),
        componentManufacturer: hfsTypeCode("Demo"),
        componentFlags: 0,
        componentFlagsMask: 0
    );
    
    override static func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            AUAudioUnit.registerSubclass(
                self,
                asComponentDescription: AudioUnitGeneratorSample.audioComponentDescription,
                name: "AudioUnitGeneratorSample",
                version: UINT32_MAX
            )
        }
    }
    
    // MARK: - Override
    
    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        let kernel = self._kernel
        
        self._internalRenderBlock = { (actionFlags, timeStamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock) in
            
            guard let buffer = kernel.buffer else {
                return noErr
            }
            
            buffer.frameLength = frameCount
            
            if let renderBlock = kernel.renderBlock {
                renderBlock(buffer: buffer)
            }
            
            let out_abl = UnsafeMutableAudioBufferListPointer(outputData)
            let in_abl = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            
            for i in 0..<out_abl.count {
                let out_data = out_abl[i].mData
                let in_data = in_abl[i].mData
                
                if out_data == nil {
                    out_abl[i].mData = in_data
                } else if out_data != in_data {
                    memcpy(out_data, in_data, Int(out_abl[i].mDataByteSize))
                }
            }
            
            return noErr
        }
        
        do {
            try super.init(componentDescription: componentDescription, options: options)
            
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
            let bus = try AUAudioUnitBus(format: format)
            self._outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.Output, busses: [bus])
        } catch {
            throw error
        }
    }
    
    override var outputBusses : AUAudioUnitBusArray {
        get {
            return self._outputBusArray!
        }
    }
    
    override var internalRenderBlock: AUInternalRenderBlock {
        get {
            return self._internalRenderBlock!
        }
    }
    
    override func shouldChangeToFormat(format: AVAudioFormat, forBus bus: AUAudioUnitBus) -> Bool {
        return true
    }
    
    override func allocateRenderResources() throws {
        do {
            try super.allocateRenderResources()
        } catch {
            throw error
        }
        
        let bus = self.outputBusses[0]
        _kernel.buffer = AVAudioPCMBuffer(PCMFormat: bus.format, frameCapacity: self.maximumFramesToRender)
    }
    
    override func deallocateRenderResources() {
        _kernel.buffer = nil
    }
    
    // MARK: - Accessor
    
    var kernelRenderBlock: KernelRenderBlock? {
        get {
            return _kernel.renderBlock
        }
        set {
            _kernel.renderBlock = newValue
        }
    }
}
