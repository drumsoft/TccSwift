//
//  TestWithCube_OnMat.swift
//  TccSwift_Tests
//
//  Created by hrk on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import TccSwift

/// "On Mat" Test: Power on and place the Core Cube on Play Mat to start the test.
class TestWithCube_OnMat: QuickSpec {
    var destinationId:Int = 0
    var responseId:Int = -1
    
    override func spec() {
        
        let SCALE:Int = 20
        let TIMEOUT_TO_MOTOR:TimeInterval = 10
        
        var cube:Cube!
        
        var notifyId:UInt?
        
        beforeEach {
            cube = TestCubeProvider.initialize()
            
            // receive destination result
            notifyId = cube.startNotifyMotor {
                switch $0 {
                case .success(let r):
                    switch r {
                    case let d as MotorDestinationResultResponse:
                        self.responseId = d.id
                    case let d as MotorMultipleDestinationResultResponse:
                        self.responseId = d.id
                    default: break
                    }
                case .failure(let error): fail(error.localizedDescription)
                }
            }
        }
        
        afterEach {
            cube.stopNotifyMotor(notifyId!)
        }
        
        afterSuite {
            TestCubeProvider.finalize()
        }
        
        describe("Cube") {
            var x:Int = 0, y:Int = 0, rotation:Int = 0
            
            it("move to destination") {
                waitUntil { done in
                    cube?.readId {
                        switch $0 {
                        case .success(let r):
                            switch r {
                            case let position as LocationPositionIdResponse:
                                x = position.cubeX
                                y = position.cubeY
                                rotation = position.cubeRotation
                            default:
                                print("put the cube on the Play Mat.")
                            }
                        case .failure(let error):
                            fail(error.localizedDescription)
                        }
                        done()
                    }
                }
                
                print("move to destination: moveAfterRotate, to right top, linear speed, rotate to -45")
                self.destinationId += 1
                cube?.writeMoveToDestination(
                    id: self.destinationId, timeout: TIMEOUT_TO_MOTOR, curve: .moveAfterRotate, maxVelocity: 16, easing: .linear,
                    destinationX: x + SCALE, destinationY: y - SCALE, finalRotation: -45+360, finalRotationType: .absoluteRotationAny
                )
                expect(self.responseId).toEventually(equal(self.destinationId), timeout: TIMEOUT_TO_MOTOR)

                print("move to destination: withRotating, to right bottom, increasing speed, rotate to 45")
                self.destinationId += 1
                cube?.writeMoveToDestination(
                    id: self.destinationId, timeout: TIMEOUT_TO_MOTOR, curve: .withRotating, maxVelocity: 40, easing: .easeIn,
                    destinationX: x + SCALE, destinationY: y + SCALE, finalRotation: 45, finalRotationType: .absoluteRotationClockwise
                )
                expect(self.responseId).toEventually(equal(self.destinationId), timeout: TIMEOUT_TO_MOTOR)

                print("move to destination: withRotatingOnlyForward, to left bottom, decreasing speed, rotate to 135")
                self.destinationId += 1
                cube?.writeMoveToDestination(
                    id: self.destinationId, timeout: TIMEOUT_TO_MOTOR, curve: .withRotatingOnlyForward, maxVelocity: 40, easing: .easeOut,
                    destinationX: x - SCALE, destinationY: y + SCALE, finalRotation: 135, finalRotationType: .absoluteRotationCounterclockwise
                )
                expect(self.responseId).toEventually(equal(self.destinationId), timeout: TIMEOUT_TO_MOTOR)

                print("move to destination: moveAfterRotate, to left top, increasing and decreasing speed, rotate to 135")
                self.destinationId += 1
                cube?.writeMoveToDestination(
                    id: self.destinationId, timeout: TIMEOUT_TO_MOTOR, curve: .moveAfterRotate, maxVelocity: 40, easing: .easeInOut,
                    destinationX: x - SCALE, destinationY: y - SCALE, finalRotation: 0, finalRotationType: .keepStartingRotation
                )
                expect(self.responseId).toEventually(equal(self.destinationId), timeout: TIMEOUT_TO_MOTOR)
                
                print("move to multiple destination")
                self.destinationId += 1
                cube?.writeMoveToMultipleDestination(
                    id: self.destinationId, timeout: TIMEOUT_TO_MOTOR * 4, curve: .withRotating, maxVelocity: 255, easing: .linear,
                    writeMode: .overwrite, destinations: [
                        MotorDestinationUnit(destinationX: x + SCALE, destinationY: y - SCALE, finalRotation: 0, finalRotationType:.noRotation),
                        MotorDestinationUnit(destinationX: x + SCALE, destinationY: y + SCALE, finalRotation: 90, finalRotationType:.relativeRotationClockwise),
                        MotorDestinationUnit(destinationX: x - SCALE, destinationY: y + SCALE, finalRotation: -90, finalRotationType:.relativeRotationClockwise),
                        MotorDestinationUnit(destinationX: x - SCALE, destinationY: y - SCALE, finalRotation: 90, finalRotationType:.relativeRotationCounterclockwise),
                        MotorDestinationUnit(destinationX: x, destinationY: y, finalRotation: rotation, finalRotationType:.absoluteRotationAny)
                    ]
                )
                expect(self.responseId).toEventually(equal(self.destinationId), timeout: TIMEOUT_TO_MOTOR * 4)
                
            }
        }
    }
}
