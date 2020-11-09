//
//  TccError.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

public enum TccError: String, Error {
    case scanTimeouted = "BLE scanning timeouted"
    case connectionTimeouted = "Connection to the Cube timeouted"
    case connectionFailedWithNoReason = "Connection to the Cube failed but no reason provided."
    case disconnectedWhileConnection = "Disconnected while connection."
    case requiredServiceNotFound = "Required services are not found on the connected Cube."
    case characteristicNotSupported = "Requested characteristic is not supported by current Cube."
    case resultIsNil = "Result value from characteristic is nil."
    case resultTypeUnmatch = "Type of value from characteristic is not match for callback."
    case resultParseFailed = "Parsing value from characteristic failed."
    var localizedDescription: String { self.rawValue }
}
