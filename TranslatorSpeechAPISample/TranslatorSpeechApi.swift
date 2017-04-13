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
    
    //Riff Chunk
    fileprivate func riff() -> Data {
        let size = 4
        let buffer = Buffer(size: size + 8)
        buffer.append("RIFF")
        buffer.append(int: size)
        buffer.append("WAVE")
        return buffer.data
    }
    
    // Wave Format Chunk
    fileprivate func waveFormat() -> Data {
        let size = 16
        let buffer = Buffer(size: size + 8)
        buffer.append("fmt ")
        buffer.append(int: size)
        buffer.append(short: 1) // Audio Format
        buffer.append(short: 1) // Channels
        buffer.append(int: 16000) // SamplePerSecond
        buffer.append(int: 32000) // BytesPerSecond
        buffer.append(short: 2) // BlockAlign
        buffer.append(short: 16) //  BitsPerSample
        return buffer.data
    }
    
    // Wave Data Chunk (Header)
    fileprivate func dataHeader(count: Int) -> Data {
        let buffer = Buffer(size: 8)
        buffer.append("data")
        buffer.append(int: count)
        return buffer.data
    }
    
    // MARK: - WebSocketDelegate
    
    func websocketDidConnect(_ socket: WebSocket) {
        
        let channels = UnsafeBufferPointer(start: audioFileBuffer?.int16ChannelData, count: 1)
        let length = Int((audioFileBuffer?.frameCapacity)! * (audioFileBuffer?.format.streamDescription.pointee.mBytesPerFrame)!)
        let audioData = NSData(bytes: channels[0], length: length)

        if length > 50000 {
            socket.write(data: riff())
            socket.write(data: waveFormat())
            socket.write(data: dataHeader(count: length))
            socket.write(data: audioData as Data)
            socket.write(data: Buffer(size: 100000).data)
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

class Buffer {
    
    var offset = 0
    var buffer: [UInt8]
    
    init(size: Int) {
        buffer = [UInt8](repeating : 0, count : size)
    }
    
    func append(short: Int16) {
        let num16: Int = Int(short)
        (0..<2).forEach { buffer[$0 + offset] = UInt8((num16 >> ($0 * 8)) & 0xff) }
        offset += 2
    }

    func append(int: Int) {
        (0..<4).forEach { buffer[$0 + offset] = UInt8((int >> ($0 * 8)) & 0xff) }
        offset += 4
    }
    
    func append(_ str: String) {
        str.utf8.enumerated().forEach { buffer[$0 + offset] = $1 }
        offset += str.utf8.count
    }
    
    var data: Data {
        return Data(bytes: buffer)
    }
}
