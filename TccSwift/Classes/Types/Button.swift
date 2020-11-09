//
//  Button.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation

// Button (Read, Notify): Bool CHR_BUTTON

public class ButtonResponse: TccResponse {
    static func parse(_ data: Data) -> ButtonResponse? {
        switch data[0] {
        case 0x01:  return ButtonFunctionResponse(data)
        default:    return nil
        }
    }
}

public class ButtonFunctionResponse: ButtonResponse {
    public var isPushed: Bool
    init(_ data:Data) {
        isPushed = data[1] != 0 // 0x80 pushed, 0x00 released
    }
}
