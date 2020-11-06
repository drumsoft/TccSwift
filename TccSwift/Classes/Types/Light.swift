//
//  Light.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Light (Write) CHR_LIGHT

public struct LightOnUnit {
    var duration:TimeInterval // in sec
    var red:Double // 0.0 to 1.0
    var green:Double // 0.0 to 1.0
    var blue:Double // 0.0 to 1.0
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
    var unit:LightOnUnit
    var data:Data {
        Data([UInt8(0x03)]) + unit.data
    }
}

/// parameter for light on sequencial
struct LightOnSequenceRequest {
    var repeats: Int // 0 to infinite loop
    var sequence:[LightOnUnit]
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
