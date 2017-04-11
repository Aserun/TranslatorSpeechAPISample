//
//  TranslatorSpeechApi.swift
//  TranslatorSpeechAPISample
//
//  Created by SIN on 2017/04/10.
//  Copyright © 2017年 SIN. All rights reserved.
//

import Foundation
import Starscream
import AVFoundation

protocol TranslatorSpeechApiDelegate {
    func finishTranslator(response: TranslatorResponse)
}

class TranslatorResponse {
    var errorString: String?
    var recognition: String?
    var translation: String?
    var data:Data?
}

class TranslatorSpeechApi: NSObject, WebSocketDelegate {
    
    fileprivate let key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    
    fileprivate var socket: WebSocket!
    fileprivate var tokenString = ""
    
    var delegate: TranslatorSpeechApiDelegate?
    
    fileprivate var audioFileBuffer: AVAudioPCMBuffer!
    fileprivate var from = "ja"
    fileprivate var to = "en"
    
    fileprivate var response:TranslatorResponse?
    
    override init() {
        super.init()
    
        token { (token) in
            self.tokenString = token
            print("token = \(self.tokenString)")
        }
    }

    func connect(audioFileBuffer: AVAudioPCMBuffer, from: String, to: String) {
        self.audioFileBuffer = audioFileBuffer
        self.from = from
        self.to = to
        
        print("connectWebsocket")
        
        response = nil
        
        let features = "partial,texttospeech"
        let url = URL(string: "wss://dev.microsofttranslator.com/speech/translate?from=\(from)&to=\(to)&features=\(features)&api-version=1.0")
        socket = WebSocket(url: url!, protocols: nil) // <=　protocols: nil　が必須
        socket.headers["Authorization"] = "Bearer " + (tokenString as String)
        socket.headers["X-ClientTraceId"] = UUID.init().uuidString
        socket.delegate = self
        socket.connect()
    }
    
    fileprivate func setBuffer(header: inout [UInt8], offset: Int, num: Int) -> Int{
        (0..<4).forEach { header[$0 + offset] = UInt8((num >> ($0 * 8)) & 0xff) }
        return offset + 4
    }

    fileprivate func setBuffer(header: inout [UInt8], offset: Int, str: String) -> Int{
        str.utf8.enumerated().forEach { header[$0 + offset] = $1 }
        return offset + str.utf8.count
    }
    
    fileprivate func createHeader(length: Int) -> [UInt8]{
        var header: [UInt8] = [UInt8](repeating : 0, count : 44)
        let dataSize = length + 44
        let samlpleRate = 16000
        let byteRate = 32000

        var offset = 0
        offset = setBuffer(header: &header, offset: offset, str: "RIFF")
        offset = setBuffer(header: &header, offset: offset, num: dataSize)
        offset = setBuffer(header: &header, offset: offset, str: "WAVEfmt ")

        header[16] = 16
        header[20] = 1
        header[22] = 1
        offset += 8
        
        offset = setBuffer(header: &header, offset: offset, num: samlpleRate)
        offset = setBuffer(header: &header, offset: offset, num: byteRate)
        header[32] = 2
        header[34] = 16
        offset += 4

        offset = setBuffer(header: &header, offset: offset, str: "data")
        _ = setBuffer(header: &header, offset: offset, num: length)
        return header
    }
    
    // MARK: - WebSocketDelegate
    
    func websocketDidConnect(_ socket: WebSocket) {
        
        let channels = UnsafeBufferPointer(start: audioFileBuffer?.int16ChannelData, count: 1)
        let length = Int((audioFileBuffer?.frameCapacity)! * (audioFileBuffer?.format.streamDescription.pointee.mBytesPerFrame)!)
        let audioData = NSData(bytes: channels[0], length: length)
        
        var header = createHeader(length: length)
        socket.write(data: NSData(bytes: &header, length: header.count) as Data)
        let sep = 6144
        let num = length / sep
        if length > 64632 {
            for i in 1...(num + 1) {
                socket.write(data: audioData.subdata(with: NSRange(location: (i - 1) * sep, length: sep)))
            }
            var raw_b = 0b0
            let data_b = NSMutableData(bytes: &raw_b, length: MemoryLayout<NSInteger>.size)
            for _ in 0...11000 {
                data_b.append(&raw_b, length: MemoryLayout<NSInteger>.size)
            }
            socket.write(data: data_b as Data)
        } else {
            socket.disconnect()
        }
    }
    
    func websocketDidDisconnect(_ socket: WebSocket, error: NSError?) {
        if response != nil {
            delegate?.finishTranslator(response: response!)
        } else {
            response = TranslatorResponse()
            response?.errorString = "websocket disconnected"
            if let e = error {
                response?.errorString = "websocket is disconnected: \(e.localizedDescription)"
            }
            delegate?.finishTranslator(response: response!)
        }
    }

    func websocketDidReceiveMessage(_ socket: WebSocket, text: String) {
        var messageType = String()
        var htmlString : String!
        let finalText = text.data(using: String.Encoding.utf8)
        if response == nil {
            response = TranslatorResponse()
        }
        do {
            let jsonString = try JSONSerialization.jsonObject(with: finalText!, options: .allowFragments) as! Dictionary<String, Any>
            messageType = (jsonString["type"] as? String)!
            if messageType == "partial" {
                response?.recognition = (jsonString["recognition"] as? String)!
            }
            
            if messageType == "final" {
                response?.translation = (jsonString["translation"] as? String)!
                response?.recognition = (jsonString["recognition"] as? String)!
            }
        } catch {
            response?.errorString = "error serializing"
        }
        defer {
            if messageType == "final" {
                socket.disconnect()
            }
        }
    }
    
    func websocketDidReceiveData(_ socket: WebSocket, data: Data) {
        if response == nil {
            response = TranslatorResponse()
        }
        response?.data = data
    }
    
    // MARK: -  Token
    
    func token(completionHandler: @escaping (String) -> Void) {
        if tokenString != "" {
            completionHandler(tokenString)
        }

        let url = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken?Subscription-Key=\(key)"
        
        let request = NSMutableURLRequest(url: NSURL(string: url)! as URL)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {data, response, error in
            if (error == nil) {
                let str = String(data: data!, encoding: .utf8)
                if str != nil {
                    self.tokenString = str!
                    completionHandler(str!)
                } else {
                    completionHandler("ERROR")
                }
            } else {
                completionHandler(error.debugDescription)
            }
        })
        task.resume()
    }
}
