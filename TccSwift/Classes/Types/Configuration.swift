//
//  Configuration.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Configuration (Write, Read, Notify) CHR_CONFIGURATION

struct ConfigurationRequestBLEProtocolVersionRequest {
    var data:Data {
        Data([UInt8(0x01), UInt8(0)])
    }
}

struct ConfigurationSensorLevelThresholdRequest {
    let value: Int // in degree, 1 to 45
    var data:Data {
        Data([UInt8(0x05), UInt8(0), UInt8(value)])
    }
}

struct ConfigurationSensorCollisionThresholdRequest {
    let value: Int // collision level, 1 to 10
    var data:Data {
        Data([UInt8(0x06), UInt8(0), UInt8(value)])
    }
}

struct ConfigurationSensorDoubleTapIntervalRequest {
    let value: Int // double tap interval, 0 to 10
    var data:Data {
        Data([UInt8(0x17), UInt8(0), UInt8(value)])
    }
}

public enum ConfigurationSensorIdNotifyCondition: Int {
    case always = 0 // notify always.
    case onValueChanged = 1 // notify when values changed.
    case atLeast300millisec = 2 // notify when values changed and after 300 millisec interval.
}

struct ConfigurationSensorIdFrequencyRequest {
    let interval: TimeInterval
    let condition: ConfigurationSensorIdNotifyCondition
    var data:Data {
        Data([UInt8(0x18), UInt8(0), UInt8(interval * 100), UInt8(condition.rawValue)])
    }
}

struct ConfigurationSensorIdMissedThresholdRequest {
    let value: TimeInterval
    var data:Data {
        Data([UInt8(0x19), UInt8(0), UInt8(round(value * 100))])
    }
}

struct ConfigurationSensorMagneticAvailabilityRequest {
    let value: Bool
    var data:Data {
        Data([UInt8(0x1b), UInt8(0), UInt8(value ? 1 : 0)])
    }
}

struct ConfigurationMotorVelocityAvailabilityRequest {
    let value: Bool
    var data:Data {
        Data([UInt8(0x1c), UInt8(0), UInt8(value ? 1 : 0)])
    }
}

/// Configuration return value.
public class ConfigurationResponse: TccResponse {
    static func parse(_ data: Data) -> ConfigurationResponse? {
        switch data[0] {
        case 0x81:  return ConfigurationBLEProtocolVersionResponse(data)
        case 0x98:  return ConfigurationIdNotifyFrequencyResponse(data)
        case 0x99:  return ConfigurationIdMissedNotifyThresholdResponse(data)
        case 0x9b:  return ConfigurationMagneticSensorAvailabilityResponse(data)
        case 0x9c:  return ConfigurationMotorVelocityAvailabilityResponse(data)
        default:    return nil
        }
    }
}

public class ConfigurationBLEProtocolVersionResponse: ConfigurationResponse {
    public let version:String?
    init(_ data:Data) {
        version = String(data: data.subdata(in: 2..<(data.count)), encoding: .utf8)
    }
}

public class ConfigurationIdNotifyFrequencyResponse: ConfigurationResponse {
    public let isSucceeded: Bool
    init(_ data:Data) {
        isSucceeded = data[2] == 0
    }
}

public class ConfigurationIdMissedNotifyThresholdResponse: ConfigurationResponse {
    public let isSucceeded: Bool
    init(_ data:Data) {
        isSucceeded = data[2] == 0
    }
}

public class ConfigurationMagneticSensorAvailabilityResponse: ConfigurationResponse {
    public let isSucceeded: Bool
    init(_ data:Data) {
        isSucceeded = data[2] == 0
    }
}

public class ConfigurationMotorVelocityAvailabilityResponse: ConfigurationResponse {
    public let isSucceeded: Bool
    init(_ data:Data) {
        isSucceeded = data[2] == 0
    }
}
