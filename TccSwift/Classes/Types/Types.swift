//
//  Types.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

/// Root class for return value from the Cube.
public class TccResponse {}

/// "Writing Operation Succeeded" response from the cube.
public class Succeeded: TccResponse {}

// MARK: Data translation

extension Data {
    internal var uInt8Value: UInt8 {
        withUnsafeBytes{ $0.load(as: UInt8.self) }
    }
    internal var cubeUInt16Value: UInt16 {
        CFSwapInt16LittleToHost(withUnsafeBytes{ $0.load(as: UInt16.self) })
    }
    internal var cubeUInt32Value: UInt32 {
        CFSwapInt32LittleToHost(withUnsafeBytes{ $0.load(as: UInt32.self) })
    }
}

extension UInt16 {
    internal var cubeData: Data {
        var swapped = CFSwapInt16HostToLittle(self)
        return Data(bytes: &swapped, count: MemoryLayout<UInt16>.size)
    }
}
