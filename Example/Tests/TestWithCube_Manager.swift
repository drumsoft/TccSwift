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

/// Cube Manager Test: Power on a Core Cube to start the test.
class TestWithCube_Manager: QuickSpec {
    
    private class TestCubeManagerDelegate: CubeManagerDelegate {
        var onFound:(()->())?
        func cubeManager(_ cubeManager: CubeManager, didCubeFound: Cube) {
            onFound?()
            onFound = nil
        }
    }

    override func spec() {
        
        beforeEach {
            /// disconnect the cube (if connected)
            if TestCubeProvider.isCubeReady {
                TestCubeProvider.finalize()
            }
        }
        
        describe("CubeManager and Connection") {

            it("will find the cube.") {
                var cube:Cube!
                
                let cubeManager = CubeManager()
                let cubeManagerDelegate = TestCubeManagerDelegate()
                cubeManager.delegate = cubeManagerDelegate
                
                /// start scan
                waitUntil(timeout: DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                    cubeManagerDelegate.onFound = {
                        done()
                    }
                    cubeManager.startScan()
                }
                
                cubeManager.stopScan()
                
                /// test cube is found.
                expect(cubeManager.foundCubeEntries.count).to(beGreaterThanOrEqualTo(1))
                
                cube = cubeManager.foundCubeEntries.first
                
                expect(cube).toNot(beNil())
                
                // test connect
                waitUntil { done in
                    cube.connect {
                        expect($0).to(succeeded())
                        done()
                    }
                }
                
                sleep(1)
                
                // test disconnect
                waitUntil { done in
                    cube.disconnect() { error in
                        expect(error).to(beNil())
                        done()
                    }
                }
            }
            
        }
    }
}
