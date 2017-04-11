//
//  Audio.swift
//  TranslatorSpeechAPISample
//
//  Created by SIN on 2017/04/10.
//  Copyright © 2017年 SIN. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioDelegate {
    func finishPlaying()
}

class Audio: NSObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    
    fileprivate var audioPlayer : AVAudioPlayer?
    fileprivate var audioRecorder : AVAudioRecorder?
    fileprivate var url : URL?
    
    var delegate: AudioDelegate?
    
    func recordingStart() {
        print("recording Start")
        if ((audioRecorder?.isRecording) != nil) {
            recordingStop()
        }
        let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let path = "\(dirPath)/tmp.wav"
        url = URL(fileURLWithPath: path)
        let recordSettings = [AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
                                   AVEncoderBitRateKey: 16,
                                 AVNumberOfChannelsKey: 1,
                                       AVSampleRateKey: 16000.0] as [String : Any]
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            audioRecorder = try AVAudioRecorder(url: url! as URL, settings: recordSettings as [String : AnyObject])
        } catch _ {
            print("error AVAudioRecorder")
        }
        audioRecorder!.isMeteringEnabled = true
        audioRecorder!.prepareToRecord()
        audioRecorder!.record()
    }

    func recordingStop() {
        print("recording Stop")
        audioRecorder?.stop()
    }
    
    func read () -> AVAudioPCMBuffer {
        
//        テスト用
//        let path = Bundle.main.path(forResource: "voice2", ofType: "wav")
//        let url = URL(fileURLWithPath: path!)
        var audioFileBuffer : AVAudioPCMBuffer
        var audioFile : AVAudioFile?
        
        do {
            audioFile = try AVAudioFile.init(forReading: url!, commonFormat: .pcmFormatInt16, interleaved: false)
            print(audioFile!.processingFormat)
            
        }catch{
            print("error reading file")
        }
        
        audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFile!.processingFormat, frameCapacity: UInt32(audioFile!.length))
        
        do {
            try audioFile!.read(into: audioFileBuffer)
        }catch{
            print("error loading buffer")
        }
        return audioFileBuffer
    }
    
    func play(data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            audioPlayer = try AVAudioPlayer(data:data)
            audioPlayer!.delegate = self
            audioPlayer!.prepareToPlay()
            audioPlayer!.play()
        }catch let error {
            print("error Audio Player : \(error)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.finishPlaying()
    }
}
