//
//  Sound.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Sound (Write) CHR_SOUND

public enum SoundEffect: Int {
    case enter = 0
    case selected = 1
    case cancel = 2
    case cursor = 3
    case matIn = 4
    case matOut = 5
    case get1 = 6
    case get2 = 7
    case get3 = 8
    case effect1 = 9
    case effect2 = 10
}

/// parameter for play sound
struct SoundPlayRequest {
    let se: SoundEffect
    let volume: Double // 0.0 to 1.0
    var data:Data {
        Data([
            UInt8(0x02),
            UInt8(se.rawValue),
            UInt8(round(volume * 255))
        ])
    }
}

public struct SoundNoteUnit {
    let duration:TimeInterval // in sec
    let note:Int // 0 to 127, 57 = A4 440Hz, 128 = mute
    let volume: Double // 0.0 to 1.0
    var data:Data {
        Data([
            UInt8(self.duration * 100),
            UInt8(self.note),
            UInt8(round(self.volume * 255))
        ])
    }
}

/// parameter for play notes.
struct SoundPlayNotesRequest {
    let repeats: Int // 0 to infinite loop
    let sequence:[SoundNoteUnit]
    var data:Data {
        Data(
            [UInt8(0x03), UInt8(repeats), UInt8(sequence.count)]
        ) + sequence.map { $0.data }.joined()
    }
}

/// parameter for stop sound
struct SoundStopRequest {
    var data:Data {
        Data([UInt8(0x01)])
    }
}
