//
//  ViewController.swift
//  iOS9AudioUnitOutputSample
//
//  Created by 八十嶋祐樹 on 2015/11/23.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import UIKit
import AVFoundation

class GeneratorViewController: UIViewController {
    var audioEngine: AVAudioEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupGeneratorAudioUnit()
    }
    
    func setupGeneratorAudioUnit() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            print(error)
            return
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        AVAudioUnit.instantiateWithComponentDescription(AudioUnitGeneratorSample.audioComponentDescription, options: AudioComponentInstantiationOptions(rawValue: 0)) { (audioUnitNode: AVAudioUnit?, err: ErrorType?) -> Void in
            guard let audioUnitNode = audioUnitNode else {
                print(err)
                return
            }
            
            let generatorUnit = audioUnitNode.AUAudioUnit as! AudioUnitGeneratorSample
            
            var phase: Float64 = 0.0
            
            generatorUnit.kernelRenderBlock = { buffer in
                let format = buffer.format
                let currentPhase: Float64 = phase
                let phasePerFrame: Float64 = 1000.0 / format.sampleRate * 2.0 * M_PI;
                for ch in 0..<format.channelCount {
                    phase = fillSine(buffer.floatChannelData[Int(ch)], length: buffer.frameLength, startPhase: currentPhase, phasePerFrame: phasePerFrame)
                }
            }
            
            engine.attachNode(audioUnitNode)
            
            let sampleRate: Double = AVAudioSession.sharedInstance().sampleRate
            let format: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
            
            engine.connect(audioUnitNode, to: engine.mainMixerNode, format: format)
            
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

