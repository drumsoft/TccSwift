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

class TestWithCube_InHand: QuickSpec {
    override func spec() {
        
        var cube:Cube?
        
        print("\"In Hand\" Test: Power on and keep the Core Cube in your hand to start the test.")
        
        beforeSuite({
            let cubeManager = CubeManager()
            let cubeManagerDelegate = TestCubeManagerDelegate()
            cubeManager.delegate = cubeManagerDelegate
            waitUntil(timeout: DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                cubeManagerDelegate.onFound = done
                cubeManager.startScan()
            }
            cubeManager.stopScan()
            cube = cubeManager.foundCubeEntries.first
        })
        
        describe("Cube") {
            context("Button") {
                it("Read Button Values") {
                    waitUntil(timeout:DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        cube?.readButton {
                            testResult($0, as: ButtonResponse.self)
                            done()
                        }
                        print("-- Press function button on the Core Cube. --")
                    }
                }
                it("Notified Button Values") {
                    waitUntil(timeout:DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyButton() {
                            testResult($0, as: ButtonResponse.self)
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
