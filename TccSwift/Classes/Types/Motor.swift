//
//  Motor.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Motor (Write without response, Read, Notify) CHR_MOTOR

public enum MotorDestinationStatus: Int {
    case unknown = -1
    case succeeded = 0
    case timeouted = 1
    case toioIdMissed = 2
    case alreadyAtDestination = 3
    case turnedOff = 4
    case canceledByOtherDestination = 5
    case tooSlowMaxVelocitySet = 6
    case rejected = 7
}

// 進行方向は使う機能によって指定する値が変わるので機能ごとにハードコードする

public enum MotorDestinationCurve: Int {
    case withRotating = 0
    case withRotatingOnlyForward = 1
    case moveAfterRotate = 2
}

public enum MotorDestinationEasing: Int {
    case linear = 0
    case easeIn = 1
    case easeOut = 2
    case easeInOut = 3
}

public enum MotorDestinationFinalRotation: Int {
    case absoluteRotationAny = 0
    case absoluteRotationClockwise = 1
    case absoluteRotationCounterclockwise = 2
    case relativeRotationClockwise = 3
    case relativeRotationCounterclockwise = 4
    case noRotation = 5
    case keepStartingRotation = 6
}

public enum MotorDestinationWriteMode: Int {
    case overwrite = 0
    case append = 1
}

public enum MotorAcceralationPriority: Int {
    case velocity = 0
    case angularVelocity = 1
}

/// parameter for activate motor
struct MotorActivateRequest {
    let left: Int // -115 to -8 = backward, -7 to 7 = stop, 8 to 115 = forward (up to 494 rpm)
    let right: Int
    var data:Data {
        Data([
            UInt8(0x01),
            UInt8(0x01),
            UInt8(left >= 0 ? 1 : 2),
            UInt8(abs(left)),
            UInt8(0x02),
            UInt8(right >= 0 ? 1 : 2),
            UInt8(abs(right))
        ])
    }
}

/// parameter for activate motor with duration
struct MotorActivateWithDurationRequest {
    let left: Int // -115 to -8 = backward, -7 to 7 = stop, 8 to 115 = forward (up to 494 rpm)
    let right: Int
    let duration: TimeInterval
    var data:Data {
        Data([
            UInt8(0x02),
            UInt8(0x01),
            UInt8(left >= 0 ? 1 : 2),
            UInt8(abs(left)),
            UInt8(0x02),
            UInt8(right >= 0 ? 1 : 2),
            UInt8(abs(right)),
            UInt8(round(duration * 100))
        ])
    }
}

public struct MotorDestinationUnit {
    let destinationX: Int
    let destinationY: Int
    let finalRotation: Int
    let finalRotationType: MotorDestinationFinalRotation
    public init(destinationX: Int, destinationY: Int, finalRotation: Int, finalRotationType: MotorDestinationFinalRotation) {
        self.destinationX = destinationX
        self.destinationY = destinationY
        self.finalRotation = finalRotation
        self.finalRotationType = finalRotationType
    }
    var data:Data {
        var rotType = finalRotationType
        if finalRotation < 0 {
            switch finalRotationType {
            case .absoluteRotationClockwise:
                rotType =  .absoluteRotationCounterclockwise
            case .absoluteRotationCounterclockwise:
                rotType =  .absoluteRotationClockwise
            case .relativeRotationClockwise:
                rotType =  .relativeRotationCounterclockwise
            case .relativeRotationCounterclockwise:
                rotType =  .relativeRotationClockwise
            default: break
            }
        }
        return UInt16(destinationX).cubeData +
            UInt16(destinationY).cubeData +
            UInt16(
                (rotType.rawValue << 13 & 0xE000) | (abs(finalRotation) & 0x1FFF)
            ).cubeData
    }
}

/// parameter for moving to destination
struct MotorMoveToDestinationRequest {
    let id: Int
    let timeout: TimeInterval // in seconds. 0 means 10 seconds.
    let curve: MotorDestinationCurve
    let maxVelocity: Int
    let easing: MotorDestinationEasing
    let destination:MotorDestinationUnit
    var data:Data {
        Data([
            UInt8(0x03),
            UInt8(id),
            UInt8(floor(timeout)),
            UInt8(curve.rawValue),
            UInt8(maxVelocity),
            UInt8(easing.rawValue),
            UInt8(0x00)
        ]) + destination.data
    }
}

/// parameter for moving to multiple destination
struct MotorMoveToMultipleDestinationRequest {
    let id: Int
    let timeout: TimeInterval // in seconds. 0 means 10 seconds.
    let curve: MotorDestinationCurve
    let maxVelocity: Int
    let easing: MotorDestinationEasing
    let writeMode: MotorDestinationWriteMode
    let destinations:[MotorDestinationUnit]
    var data:Data {
        Data([
            UInt8(0x04),
            UInt8(id),
            UInt8(floor(timeout)),
            UInt8(curve.rawValue),
            UInt8(maxVelocity),
            UInt8(easing.rawValue),
            UInt8(0x00),
            UInt8(writeMode.rawValue)
        ]) + destinations.map { $0.data }.joined()
    }
}

/// parameter for moving with acceralation
struct MotorActivateWithAcceralationRequest {
    let velocity: Int
    let acceralation: Int // Δvelocity / Δ(100ms), 0 means immediately set to specified velocity.
    let angularVelocity: Int // 0 to 65535, degree/sec
    let priority: MotorAcceralationPriority
    let duration: TimeInterval // in seconds (set with x 10ms)
    var data:Data {
        Data([
            UInt8(0x05),
            UInt8(abs(velocity)),
            UInt8(acceralation)]) +
            UInt16(abs(angularVelocity)).cubeData +
        Data([
            UInt8(angularVelocity >= 0 ? 0 : 1), // angular orientation 0: clockwise, 1:counterClockwise
            UInt8(velocity >= 0 ? 0 : 1), // orientation 0: forward, 1: backwored
            UInt8(priority.rawValue),
            UInt8(round(duration * 100))
        ])
    }
}

/// Motor return value
public class MotorResponse: TccResponse {
    static func parse(_ data: Data) -> MotorResponse? {
        switch data[0] {
        case 0x83:  return MotorDestinationResultResponse(data)
        case 0x84:  return MotorMultipleDestinationResultResponse(data)
        case 0xe0:  return MotorVelocitiesResponse(data)
        default:    return nil
        }
    }
}

public class MotorDestinationResultResponse: MotorResponse {
    public let id: Int
    public let status: MotorDestinationStatus
    
    init(_ data:Data) {
        id = Int(data[1])
        status = MotorDestinationStatus.init(rawValue: Int(data[2])) ?? .unknown
    }
}

public class MotorMultipleDestinationResultResponse: MotorResponse {
    public let id: Int
    public let status: MotorDestinationStatus
    
    init(_ data:Data) {
        id = Int(data[1])
        status = MotorDestinationStatus.init(rawValue: Int(data[2])) ?? .unknown
    }
}

public class MotorVelocitiesResponse: MotorResponse {
    public let left:Int
    public let right:Int
    
    init(_ data:Data) {
        left = Int(data[1])
        right = Int(data[2])
    }
}
