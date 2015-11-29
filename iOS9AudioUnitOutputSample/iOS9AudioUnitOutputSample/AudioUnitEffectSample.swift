//
//  AudioUnitEffectSample.swift
//  iOS9AudioUnitOutputSample
//
//  Created by 八十嶋祐樹 on 2015/11/29.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import AVFoundation

class AudioUnitEffectSample: AUAudioUnit {
    
    // MARK: - Private
    
    private let _kernel: AudioUnitSampleKernel = AudioUnitSampleKernel()
    private var _outputBusArray: AUAudioUnitBusArray?
    private var _inputBusArray: AUAudioUnitBusArray?
    private var _internalRenderBlock: AUInternalRenderBlock?
    
    // MARK: - Global
    
    static let audioComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: hfsTypeCode("efsp"),
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
                asComponentDescription: AudioUnitEffectSample.audioComponentDescription,
                name: "AudioUnitEffectSample",
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
            
            if let pullInputBlock = pullInputBlock {
                pullInputBlock(actionFlags, timeStamp, frameCount, 0, buffer.mutableAudioBufferList)
            }
            
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
            let outputBus = try AUAudioUnitBus(format: format)
            self._outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.Output, busses: [outputBus])
            let inputBus = try AUAudioUnitBus(format: format)
            self._inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.Input, busses: [inputBus])
            
        } catch {
            throw error
        }
    }
    
    override var outputBusses : AUAudioUnitBusArray {
        get {
            return self._outputBusArray!
        }
    }
    
    override var inputBusses : AUAudioUnitBusArray {
        get {
            return self._inputBusArray!
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
        
        let outputBus = self.outputBusses[0]
        let inputBus = self.inputBusses[0]
        
        if outputBus.format == inputBus.format {
            _kernel.buffer = AVAudioPCMBuffer(PCMFormat: outputBus.format, frameCapacity: self.maximumFramesToRender)
        }
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