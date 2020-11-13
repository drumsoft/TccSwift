//
//  Location.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

// Though they call it as "ID" come from "Sensor". Since the words "ID" and "Sensor" are tend to be ambiguous, we will call it "Location".

import Foundation

// Location (Read, Notify) CHR_ID

/// Location (Position ID, Standard ID) return value
public class LocationResponse: TccResponse {
    static func parse(_ data: Data) -> LocationResponse? {
        switch data[0] {
        case 0x01:  return LocationPositionIdResponse(data)
        case 0x02:  return LocationStandardIdResponse(data)
        case 0x03:  return LocationPositionIdMissedResponse()
        case 0x04:  return LocationStandardIdMissedResponse()
        default:    return nil
        }
    }
}
/// The Cube Located on Position ID Mat.
public class LocationPositionIdResponse: LocationResponse {
    /// Position of the center of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    public let cubeX:Int
    /// Position of the center of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    public let cubeY:Int
    /// Rotation of the center of the cube. 0 to 360. The value is 0 at the X-axis direction and increase when rotated clockwise.
    public let cubeRotation:Int
    /// Position of the sensor of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    public let sensorX:Int
    /// Position of the sensor of the cube. 0 to 65535. The actual value depends on the Mat which cube placed on.
    public let sensorY:Int
    /// Rotation of the sensor of the cube. 0 to 360. The value is 0 at the X-axis direction and increase when rotated clockwise.
    public let sensorRotation:Int
    
    init(_ data: Data) {
        cubeX = Int(data.subdata(in: 1..<3).cubeUInt16Value)
        cubeY = Int(data.subdata(in: 3..<5).cubeUInt16Value)
        cubeRotation = Int(data.subdata(in: 5..<7).cubeUInt16Value)
        sensorX = Int(data.subdata(in: 7..<9).cubeUInt16Value)
        sensorY = Int(data.subdata(in: 9..<11).cubeUInt16Value)
        sensorRotation = Int(data.subdata(in: 11..<13).cubeUInt16Value)
    }
}
/// The Cube Located on Standard ID Card.
public class LocationStandardIdResponse: LocationResponse {
    /// ID of the Standard ID Card.
    public let standardId:UInt
    /// Rotation of the cube on the Standard ID Card. 0 to 360.
    public let cubeRotation:Int
    
    init(_ data: Data) {
        standardId = UInt(data.subdata(in: 1..<5).cubeUInt32Value)
        cubeRotation = Int(data.subdata(in: 5..<7).cubeUInt16Value)
    }
}
/// The Cube is displaced from Position ID Mat.
public class LocationPositionIdMissedResponse: LocationResponse {}
/// The Cube is displaced from Standard ID Card.
public class LocationStandardIdMissedResponse: LocationResponse {}
