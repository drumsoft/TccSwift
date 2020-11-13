//
//  TestWithCube_InHand.swift
//  TccSwift_Tests
//
//  Created by hrk on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import TccSwift

fileprivate let BANNER = "== \"In Hand\" Test: Power on and keep the Core Cube in your hand to start the test. =="

class TestWithCube_InHand: QuickSpec {
    override func spec() {
        
        var cube:Cube!
        
        beforeSuite {
            print(BANNER)
            cube = testInitializeCube()
        }
        
        afterSuite {
            testFinalizeCube(cube)
        }
        
        describe("Cube") {
            context("Motion Sensors") {
                
                it("Read Motion Sensor Value") {
                    waitUntil(timeout:DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        cube?.readSensor {
                            expect($0).to(succeededWith(SensorMotionResponse.self))
                            done()
                        }
                        print("-- Knock the Core Cube. --")
                    }
                }
                
                it("Notified Motion Sensor Value") {
                    waitUntil(timeout:DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        var id:UInt? = nil
                        id = cube?.startNotifySensor() {
                            expect($0).to(succeededWith(SensorMotionResponse.self))
                            cube?.stopNotifySensor(id!)
                            done()
                        }
                        print("-- Knock the Core Cube. --")
                    }
                }
                
            }

            context("Button") {
                it("Read Button Values") {
                    waitUntil(timeout:DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        cube?.readButton {
                            expect($0).to(succeededWith(ButtonFunctionResponse.self))
                            done()
                        }
                        print("-- Press function button on the Core Cube. --")
                    }
                }
                it("Notified Button Values") {
                    waitUntil(timeout:DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyButton() {
                            expect($0).to(succeededWith(ButtonFunctionResponse.self))
                            cube?.stopNotifyButton(id!)
                            done()
                        }
                        print("-- Press (or release) function button on the Core Cube. --")
                    }
                }
            }
        }
    }
}
