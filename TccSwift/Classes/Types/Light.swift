//
//  Light.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Light (Write) CHR_LIGHT

public struct LightOnUnit {
    let duration:TimeInterval // in sec
    let red:Double // 0.0 to 1.0
    let green:Double // 0.0 to 1.0
    let blue:Double // 0.0 to 1.0
    public init(duration:TimeInterval, red:Double, green:Double, blue:Double) {
        self.duration = duration
        self.red = red
        self.green = green
        self.blue = blue
    }
    var data:Data {
        Data([
            UInt8(floor(self.duration * 100)),
            UInt8(1),
            UInt8(1),
            UInt8(round(self.red * 255)),
            UInt8(round(self.green * 255)),
            UInt8(round(self.blue * 255))
        ])
    }
}

/// parameter for light on
struct LightOnRequest {
    let unit:LightOnUnit
    var data:Data {
        Data([UInt8(0x03)]) + unit.data
    }
}

/// parameter for light on sequencial
struct LightOnSequenceRequest {
    let repeats: Int // 0 to infinite loop
    let sequence:[LightOnUnit]
    var data:Data {
        Data(
            [UInt8(0x04), UInt8(repeats), UInt8(sequence.count)]
        ) + sequence.map { $0.data }.joined()
    }
}

/// parameter for light all off
struct LightAllOffRequest {
    var data:Data {
        Data([UInt8(0x01)])
    }
}
