//
//  Battery.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Battery (Read, Notify): Int (0...100) CHR_BATTERY

public class BatteryResponse: TccResponse {
    static func parse(_ data: Data) -> BatteryResponse? {
        switch data[0] {
        case 0x01:  return BatteryResponse(data)
        default:    return nil
        }
    }
    
    /// the battery capacity in percent. 0 to 100
    var capacity: Int
    init(_ data:Data) {
        capacity = Int(data[0])
    }
}
