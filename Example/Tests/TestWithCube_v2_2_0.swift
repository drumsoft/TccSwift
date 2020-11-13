//
//  TestWithCube_v2_2_0.swift
//  TccSwift_Tests
//
//  Created by hrk on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import TccSwift

class TestWithCube_v2_2_0: QuickSpec {
    override func spec() {
        
        var cube:Cube?
        
        print("\"v2.2.0\" Test: Power on and leave the Core Cube on your desk to start the test.")

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
            context("Configuration for 2.2.0") {
                
                it("Configuration Id Notification Frequency") {
                    waitUntil { done in
                        cube?.readConfiguration {
                            testResult($0, as: ConfigurationLocationNotificationFrequencyResponse.self)
                        }
                        cube?.writeConfigurationIdNotificationFrequency(interval: 0.03, condition: .atLeast300millisec) {
                            testResult($0)
                        }
                    }
                }
                
                it("Configuration Id Missed Threshold") {
                    waitUntil { done in
                        cube?.readConfiguration {
                            testResult($0, as: ConfigurationLocationMissedThresholdResponse.self)
                        }
                        cube?.writeConfigurationIdMissedThreshold(0.1) {
                            testResult($0)
                        }
                    }
                }
                
                it("Configuration Magnetic Sensor Availability") {
                    waitUntil { done in
                        cube?.readConfiguration {
                            testResult($0, as: ConfigurationMagneticSensorAvailabilityResponse.self)
                        }
                        cube?.writeConfigurationMagneticSensorAvailability(true) {
                            testResult($0)
                        }
                    }
                }

                it("Configuration Motor Velocity Availability") {
                    waitUntil { done in
                        cube?.readConfiguration {
                            testResult($0, as: ConfigurationMotorVelocityAvailabilityResponse.self)
                        }
                        cube?.writeConfigurationMotorVelocityAvailability(true) {
                            testResult($0)
                        }
                    }
                }
            }
            
            context("Magnetic Sensors") {
                it("Read Magnetic Sensor Value") {
                    waitUntil { done in
                        cube?.readSensor {
                            testResult($0, as: SensorMagneticResponse.self)
                            done()
                        }
                        cube?.writeRequestMagneticSensorValues {
                            testResult($0)
                        }
                    }
                }
                it("Notified Magnetic Sensor Value") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifySensor() {
                            testResult($0, as: SensorMagneticResponse.self)
                            cube?.stopNotifySensor(id!)
                            done()
                        }
                        cube?.writeRequestMagneticSensorValues {
                            testResult($0)
                        }
                    }
                }
            }
            
            context("Motor Velocities") {
                cube?.writeActivateMotor(velocity:  80, acceralation: 2, angularVelocity: 90, priority: .angularVelocity, duration: 4)
                sleep(1)
                it("Read Motor Velocities Value") {
                    waitUntil { done in
                        cube?.readMotor {
                            testResult($0, as: MotorVelocitiesResponse.self)
                            done()
                        }
                    }
                }
                sleep(1)
                it("Notified Motor Velocities Value") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyMotor() {
                            testResult($0, as: MotorVelocitiesResponse.self)
                            cube?.stopNotifyMotor(id!)
                            done()
                        }
                    }
                }
            }
        }
    }
}
