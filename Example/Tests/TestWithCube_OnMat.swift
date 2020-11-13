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

class TestWithCube_OnMat: QuickSpec {
    
    override func spec() {
        
        let scale:Int = 10

        var cube:Cube?
        
        print("\"On Mat\" Test: Power on and place the Core Cube on Play Mat to start the test.")
        
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
            var x:Int = 0, y:Int = 0, rotation:Int = 0
            var destinationId:Int = 0
            var responseId:Int = -1

            // fetch x and y
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
            
            // receive destination result
            let notifyId = cube?.startNotifyMotor {
                switch $0 {
                case .success(let r):
                    switch r {
                    case let d as MotorDestinationResultResponse:
                        responseId = d.id
                    case let d as MotorMultipleDestinationResultResponse:
                        responseId = d.id
                    default: break
                    }
                case .failure(let error): fail(error.localizedDescription)
                }
            }
            
            it("move to destination: moveAfterRotate, to right top, linear speed, rotate to -45") {
                destinationId += 1
                cube?.writeMoveToDestination(
                    id: destinationId, timeout: 10, curve: .moveAfterRotate, maxVelocity: 16, easing: .linear,
                    destinationX: x + scale, destinationY: y - scale, finalRotation: -45+360, finalRotationType: .absoluteRotationAny
                )
                expect(responseId).toEventually(equal(destinationId))
            }
            it("move to destination: withRotating, to right bottom, increasing speed, rotate to 45") {
                destinationId += 1
                cube?.writeMoveToDestination(
                    id: destinationId, timeout: 10, curve: .withRotating, maxVelocity: 40, easing: .easeIn,
                    destinationX: x + scale, destinationY: y + scale, finalRotation: 45, finalRotationType: .absoluteRotationClockwise
                )
                expect(responseId).toEventually(equal(destinationId))
            }
            it("move to destination: withRotatingOnlyForward, to left bottom, decreasing speed, rotate to 135") {
                destinationId += 1
                cube?.writeMoveToDestination(
                    id: destinationId, timeout: 10, curve: .withRotatingOnlyForward, maxVelocity: 40, easing: .easeOut,
                    destinationX: x - scale, destinationY: y + scale, finalRotation: 135, finalRotationType: .absoluteRotationCounterclockwise
                )
                expect(responseId).toEventually(equal(destinationId))
            }
            it("move to destination: moveAfterRotate, to left top, increasing and decreasing speed, rotate to 135") {
                destinationId += 1
                cube?.writeMoveToDestination(
                    id: destinationId, timeout: 10, curve: .moveAfterRotate, maxVelocity: 40, easing: .easeInOut,
                    destinationX: x - scale, destinationY: y - scale, finalRotation: 0, finalRotationType: .keepStartingRotation
                )
                expect(responseId).toEventually(equal(destinationId))
            }
            
            it("move to multiple destination") {
                destinationId += 1
                cube?.writeMoveToMultipleDestination(
                    id: destinationId, timeout: 30, curve: .withRotating, maxVelocity: 255, easing: .linear,
                    writeMode: .overwrite, destinations: [
                        MotorDestinationUnit(destinationX: x + scale, destinationY: y - scale, finalRotation: 0, finalRotationType:.noRotation),
                        MotorDestinationUnit(destinationX: x + scale, destinationY: y + scale, finalRotation: 90, finalRotationType:.relativeRotationClockwise),
                        MotorDestinationUnit(destinationX: x - scale, destinationY: y + scale, finalRotation: -90, finalRotationType:.relativeRotationClockwise),
                        MotorDestinationUnit(destinationX: x - scale, destinationY: y - scale, finalRotation: 90, finalRotationType:.relativeRotationCounterclockwise),
                        MotorDestinationUnit(destinationX: x, destinationY: y, finalRotation: rotation, finalRotationType:.absoluteRotationAny)
                    ]
                )
                expect(responseId).toEventually(equal(destinationId))
            }
            
            cube?.stopNotifyMotor(notifyId!)
        }
    }
}
