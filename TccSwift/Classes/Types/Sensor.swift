//
//  Sensor.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Sensor (Write, Read, Notify) CHR_SENSOR

public enum SensorOrientation: Int {
    case unknown = -1 // 不明な値
    case top = 1 // 天面が上
    case bottom = 2 // 底面が上
    case back = 3 // 背面が上
    case front = 4 // 正面が上
    case right = 5 // 右側面が上
    case left = 6 // 左側面が上
}

public enum SensorMagnetPosition: Int {
    case unknown = -1 // 不明な値
    case none = 0 // 未装着
    case centerN = 1 // 中央にN極
    case rightN = 2 // 右よりにN極
    case leftN = 3 // 左よりにN極
    case centerS = 4 // 中央にS極
    case rightS = 5 // 右よりにS極
    case leftS = 6 // 左よりにS極
}

/// parameter for request motion sensor value
struct SensorRequestMotionRequest {
    var data:Data {
        Data([UInt8(0x81)])
    }
}

/// parameter for request magnetic sensor value
struct SensorRequestMagneticRequest {
    var data:Data {
        Data([UInt8(0x82)])
    }
}

// Sensor (Motion, Magnetic) return value

public class SensorResponse: TccResponse {
    static func parse(_ data: Data) -> SensorResponse? {
        switch data[0] {
        case 0x01:  return SensorMotionResponse(data)
        case 0x02:  return SensorMagneticResponse(data)
        default:    return nil
        }
    }
}

public class SensorMotionResponse: SensorResponse {
    public let isLevel:Bool
    public let isCollided:Bool
    public let isDoubleTapped:Bool
    /// which side faces up?
    public let orientation:SensorOrientation
    /// 0 is not shaken. 1 to 10 is shaken.
    public let shaken:Int
    init(_ data:Data) {
        isLevel = data[1] != 0 // 1: level, 0: not level
        isCollided = data[2] != 0 // 1: collided, 0: not collided
        if data.count >= 5 {
            isDoubleTapped = data[3] != 0 // 1: doubletapped, 0: not doubletapped
            orientation = SensorOrientation.init(rawValue: Int(data[4])) ?? .unknown
        } else {
            isDoubleTapped = false
            orientation = .unknown
        }
        if data.count >= 6 {
            shaken = Int(data[5])
        } else {
            shaken = 0
        }
    }
}

public class SensorMagneticResponse: SensorResponse {
    /// position of the magnet.
    public let position: SensorMagnetPosition
    init(_ data:Data) {
        position = SensorMagnetPosition.init(rawValue: Int(data[1])) ?? .unknown
    }
}
