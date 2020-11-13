//
//  TestWithCube_Manager.swift
//  TccSwift_Tests
//
//  Created by hrk on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import TccSwift

fileprivate let BANNER = "== Cube Manager Test: Power on a Core Cube to start the test. =="

class TestWithCube_Manager: QuickSpec {
    
    override func spec() {
        
        describe("CubeManager and Connection") {
            var cube:Cube!
            
            let cubeManager = CubeManager()
            let cubeManagerDelegate = TestCubeManagerDelegate()
            cubeManager.delegate = cubeManagerDelegate

            it("will find the cube.") {
                waitUntil(timeout: DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                    print(BANNER)
                    cubeManagerDelegate.onFound = {
                        done()
                    }
                    cubeManager.startScan()
                }
                
                cubeManager.stopScan()
                
                expect(cubeManager.foundCubeEntries.count).to(beGreaterThanOrEqualTo(1))
                
                cube = cubeManager.foundCubeEntries.first
                
                expect(cube).toNot(beNil())
                
                waitUntil { done in
                    cube.connect {
                        expect($0).to(succeeded())
                        done()
                    }
                }
                
                sleep(1)
                
                cube.disconnect()
            }
        }
    }
}
