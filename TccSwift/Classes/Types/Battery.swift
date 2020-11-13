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
        BatteryResponse(data)
    }
    
    /// the battery capacity in percent. 0 to 100
    public let capacity: Int
    init(_ data:Data) {
        capacity = Int(data[0])
    }
}
