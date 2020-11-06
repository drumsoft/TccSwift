//
//  Id.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// ID (Read, Notify) CHR_ID

/// ID (Position ID, Standard ID) return value
public class IdResponse: TccResponse {
    static func parse(_ data: Data) -> IdResponse? {
        switch data[0] {
        case 0x01:  return IdPositionResponse(data)
        case 0x02:  return IdStandardResponse(data)
        case 0x03:  return IdPositionIdMissedResponse()
        case 0x04:  return IdStandardIdMissedResponse()
        default:    return nil
        }
    }
}
/// The Cube is on Position ID Mat.
public class IdPositionResponse: IdResponse {
    /// Position of the center of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    var cubeX:Int
    /// Position of the center of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    var cubeY:Int
    /// Rotation of the center of the cube. 0 to 360. The value is 0 at the X-axis direction and increase when rotated clockwise.
    var cubeRotation:Int
    /// Position of the sensor of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    var sensorX:Int
    /// Position of the sensor of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    var sensorY:Int
    /// Rotation of the sensor of the cube. 0 to 360. The value is 0 at the X-axis direction and increase when rotated clockwise.
    var sensorRotation:Int
    
    init(_ data: Data) {
        cubeX = Int(data.subdata(in: 1..<3).cubeUInt16Value)
        cubeY = Int(data.subdata(in: 3..<5).cubeUInt16Value)
        cubeRotation = Int(data.subdata(in: 5..<7).cubeUInt16Value)
        sensorX = Int(data.subdata(in: 7..<9).cubeUInt16Value)
        sensorY = Int(data.subdata(in: 9..<11).cubeUInt16Value)
        sensorRotation = Int(data.subdata(in: 11..<13).cubeUInt16Value)
    }
}
/// The Cube is on Standard ID Card.
public class IdStandardResponse: IdResponse {
    /// ID of the Standard ID Card.
    var id:UInt
    /// Rotation of the cube on the Standard ID Card. 0 to 360.
    var cubeRotation:Int
    
    init(_ data: Data) {
        id = UInt(data.subdata(in: 1..<5).cubeUInt32Value)
        cubeRotation = Int(data.subdata(in: 5..<7).cubeUInt16Value)
    }
}
/// The Cube is displaced from Position ID Mat.
public class IdPositionIdMissedResponse: IdResponse {}
/// The Cube is displaced from Standard ID Card.
public class IdStandardIdMissedResponse: IdResponse {}
