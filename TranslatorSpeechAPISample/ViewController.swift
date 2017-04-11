//
//  ViewController.swift
//  TranslatorSpeechAPISample
//
//  Created by SIN on 2017/04/10.
//  Copyright © 2017年 SIN. All rights reserved.
//

import UIKit

class ViewController: UIViewController, TranslatorSpeechApiDelegate, AudioDelegate {

    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var outputTextView: UITextView!
    @IBOutlet weak var infomationLabel: UILabel!
    @IBOutlet weak var recordingButton: UIImageView!
    @IBOutlet weak var langSegmentedControl: UISegmentedControl!
    
    var audio: Audio!
    var translatorSpeechApi: TranslatorSpeechApi!
    
    enum Status {
        case idle
        case record
        case wait
        case play
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        audio = Audio()
        audio.delegate = self
        translatorSpeechApi = TranslatorSpeechApi()
        translatorSpeechApi.delegate = self
        
        prepare()
    }
    
    // MARK: - change Status
    var status: Status = .idle {
        didSet{
            DispatchQueue.main.async {
                switch self.status {
                case .idle:
                    self.infomationLabel.text = "Press and hold to speak"
                    self.recordingButton.image = UIImage(named: "Idle")
                    self.recordingButton.alpha = 1.0
                case .record:
                    self.infomationLabel.text = "listening"
                    self.recordingButton.image = UIImage(named: "Record")
                    self.recordingButton.alpha = 1.0
                case .wait:
                    self.infomationLabel.text = "thinking"
                    self.recordingButton.image = UIImage(named: "Record")
                    self.recordingButton.alpha = 0.4
                case .play:
                    self.infomationLabel.text = "speaking"
                    self.recordingButton.image = UIImage(named: "Play")
                    self.recordingButton.alpha = 1.0
                }
            }
            
        }
    }
    
    // MARK: - Touch Event
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches , with:event)
        if status == .idle {
            if event?.touches(for: recordingButton) != nil {
                outputTextView.text = ""
                inputTextView.text = ""
                status = .record
                audio.recordingStart()
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if status == .record {
            audio.recordingStop()
            status = .wait
            translatorSpeechApi.token(completionHandler: { (token) in
                self.status = .wait
                let from = self.langSegmentedControl.selectedSegmentIndex == 0 ? "ja" : "en"
                let to = self.langSegmentedControl.selectedSegmentIndex == 0 ? "en" : "ja"
                self.translatorSpeechApi.connect(audioFileBuffer: self.audio.read(), from: from, to: to)
                
            })
        }
    }
    
    // MARK: - AudioDelegate
    
    func finishPlaying() {
        status = .idle
    }
    
    // MARK: - TranslatorSpeechApiDelegate
    func finishTranslator(response: TranslatorResponse) {
        DispatchQueue.main.async {
            if response.errorString == nil {
                self.inputTextView.text = response.recognition
                self.outputTextView.text = response.translation
                if response.data != nil {
                    self.audio.play(data: response.data!)
                    self.status = .play
                    return
                }
            } else {
                self.inputTextView.text = response.errorString
            }
        }
        status = .idle
    }
    
    func finishTranslator(recognition: String, translation: String, data: Data?) {
        DispatchQueue.main.async {
            self.inputTextView.text = recognition
            self.outputTextView.text = translation
            if data != nil {
                self.audio.play(data: data!)
            }
        }
        status = .idle
    }
    
    // MARK: - private
    func prepare() {
        inputTextView.layer.cornerRadius = 20
        inputTextView.layer.borderWidth = 2
        inputTextView.layer.borderColor = UIColor.lightGray.cgColor

        outputTextView.layer.cornerRadius = 20
        outputTextView.layer.borderWidth = 2
        outputTextView.layer.borderColor = UIColor.lightGray.cgColor
        
        status = .idle
        
    }
}

