//
//  EffectViewController.swift
//  iOS9AudioUnitOutputSample
//
//  Created by 八十嶋祐樹 on 2015/11/29.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

class EffectViewController: UIViewController {
    var audioEngine: AVAudioEngine?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupEffectAudioUnit()
    }
    
    func setupEffectAudioUnit() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch {
            print(error)
            return
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        AVAudioUnit.instantiateWithComponentDescription(AudioUnitEffectSample.audioComponentDescription, options: AudioComponentInstantiationOptions(rawValue: 0)) { (audioUnitNode: AVAudioUnit?, err: ErrorType?) in
            guard let audioUnitNode = audioUnitNode else {
                print(err)
                return
            }
            
            guard let inputNode = engine.inputNode else {
                return
            }
            
            engine.attachNode(audioUnitNode)
            
            let sampleRate = AVAudioSession.sharedInstance().sampleRate
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
            
            engine.connect(audioUnitNode, to: engine.mainMixerNode, format: format)
            engine.connect(inputNode, to: audioUnitNode, format: format)
            
            let delayBuffer = AVAudioPCMBuffer(PCMFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate))
            delayBuffer.frameLength = delayBuffer.frameCapacity
            var delayFrame: AVAudioFrameCount = 0
            
            let effectUnit = audioUnitNode.AUAudioUnit as! AudioUnitEffectSample
            
            effectUnit.kernelRenderBlock = { buffer in
                let format = buffer.format
                var bufferFrame: AVAudioFrameCount = 0
                
                while bufferFrame < buffer.frameLength {
                    let copyFrame = min(delayBuffer.frameLength - delayFrame, buffer.frameLength - bufferFrame)
                    
                    for ch in 0..<format.channelCount {
                        let bufferData = buffer.floatChannelData[Int(ch)].advancedBy(Int(bufferFrame))
                        let delayData = delayBuffer.floatChannelData[Int(ch)].advancedBy(Int(delayFrame))
                        vDSP_vswap(bufferData, 1, delayData, 1, vDSP_Length(copyFrame))
                    }
                    
                    delayFrame += copyFrame
                    if delayFrame != 0 {
                        delayFrame %= delayBuffer.frameLength
                    }
                    bufferFrame += copyFrame
                }
            }
            
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            } catch {
                print(error)
                return
            }
        }
    }
}
