//
//  TestWithCube_Basic.swift
//  TccSwift_Tests
//
//  Created by hrk on 2020/11/11.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import TccSwift

class TestWithCube_Basic: QuickSpec {
    override func spec() {
        
        var cube:Cube?
        
        print("\"Leave it\" Test: Power on and leave the Core Cube on your desk to start the test.")
        
        describe("CubeManager") {
            let cubeManager = CubeManager()
            let cubeManagerDelegate = TestCubeManagerDelegate()
            cubeManager.delegate = cubeManagerDelegate

            context("Find Cubes with CubeManager") {
                it("Cubes will be found.") {
                    waitUntil(timeout: DEFAULT_TIMEOUT_FOR_HUMAN) { done in
                        cubeManagerDelegate.onFound = done
                        cubeManager.startScan()
                    }
                    
                    cubeManager.stopScan()

                    expect(cubeManager.foundCubeEntries.count).to(beGreaterThanOrEqualTo(1))
                    
                    cube = cubeManager.foundCubeEntries.first
                    expect(cube).toNot(beNil())
                }
            }
        }
        
        describe("Cube") {
            context("Connect to the Cube") {
                it("Connect") {
                    waitUntil { done in
                        cube?.connect {
                            switch $0 {
                            case .success(let c):
                                expect(c).to(be(cube))
                            case .failure(let error):
                                fail(error.localizedDescription)
                            }
                            done()
                        }
                    }
                }
            }
            
            context("Motion Sensors") {
                it("Read Motion Sensor Value") {
                    waitUntil { done in
                        cube?.readSensor {
                            testResult($0, as: SensorMotionResponse.self)
                            done()
                        }
                        cube?.writeRequestMotionSensorValues {
                            testResult($0)
                        }
                    }
                }
                it("Notified Motion Sensor Value") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifySensor() {
                            testResult($0, as: SensorMotionResponse.self)
                            cube?.stopNotifySensor(id!)
                            done()
                        }
                        cube?.writeRequestMotionSensorValues {
                            testResult($0)
                        }
                    }
                }
            }
            
            context("Battery") {
                it("Read Battery Values") {
                    waitUntil { done in
                        cube?.readBattery {
                            testResult($0, as: BatteryResponse.self)
                            done()
                        }
                    }
                }
                it("Notified Battery Values") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyBattery() {
                            testResult($0, as: BatteryResponse.self)
                            cube?.stopNotifyBattery(id!)
                            done()
                        }
                    }
                }
            }
            
            context("Motor without Mat") {
                it("Activate Motor") {
                    cube?.writeActivateMotor(left: 100, right: -100)
                    sleep(2)
                    cube?.writeActivateMotor(left: 0, right: 0)
                    sleep(1)
                }
                it("Activate Motor with Duration") {
                    cube?.writeActivateMotor(left: -100, right: 100, duration: 2)
                    sleep(3)
                }
                it("Activate Motor with Acceralation") {
                    cube?.writeActivateMotor(velocity:  80, acceralation: 4, angularVelocity: 180, priority: .velocity, duration: 2)
                    sleep(3)
                    cube?.writeActivateMotor(velocity: -80, acceralation: 4, angularVelocity: 180, priority: .angularVelocity, duration: 2)
                    sleep(3)
                }
            }
            
            context("Light") {
                it("Light On") {
                    cube?.writeLightOn(duration: 1, red: 1, green: 1, blue: 1) { testResult($0) }
                    sleep(1)
                }
                it("Light Off") {
                    cube?.writeLightAllOff() { testResult($0) }
                    sleep(1)
                }
                it("Light On Sequence") {
                    cube?.writeLightSequence(repeats: 2, sequence: [
                        LightOnUnit(duration: 0.3, red: 1, green: 0, blue: 0),
                        LightOnUnit(duration: 0.3, red: 0, green: 0, blue: 1),
                        LightOnUnit(duration: 0.3, red: 0, green: 1, blue: 0)
                    ]) {
                        testResult($0)
                    }
                    sleep(2)
                }
            }
            
            context("Sound") {
                it("Sound Effect") {
                    cube?.writeSoundPlay(se: .effect1, volume: 1) { testResult($0) }
                    sleep(1)
                }
                it("Sound Effect And Stop") {
                    cube?.writeSoundPlay(se: .effect2, volume: 1) { testResult($0) }
                    usleep( 10000)
                    cube?.writeSoundStop { testResult($0) }
                    usleep(990000)
                }
                it("Play Sound Sequence") {
                    cube?.writeSoundPlayNotes(repeats: 2, sequence: [
                        SoundNoteUnit(duration:0.2, note:57, volume: 1),
                        SoundNoteUnit(duration:0.2, note:61, volume: 1),
                        SoundNoteUnit(duration:0.2, note:64, volume: 1),
                        SoundNoteUnit(duration:0.2, note:69, volume: 1)
                    ]) {
                        testResult($0)
                    }
                    sleep(2)
                }
            }
            
            context("Configuration Read") {
                it("Read Configuration Value") {
                    waitUntil { done in
                        cube?.readConfiguration {
                            testResult($0, as: ConfigurationBLEProtocolVersionResponse.self)
                            done()
                        }
                        cube?.writeConfigurationRequestBLEProtocolVersion {
                            testResult($0)
                        }
                    }
                }
                it("Notified Configuration Value") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyConfiguration() {
                            testResult($0, as: ConfigurationBLEProtocolVersionResponse.self)
                            cube?.stopNotifyConfiguration(id!)
                            done()
                        }
                        cube?.writeConfigurationRequestBLEProtocolVersion {
                            testResult($0)
                        }
                    }
                }
            }

            context("Configuration Write") {
                it("Configuration Motion Senser Level Threshold") {
                    cube?.writeConfigurationSensorLevelThreshold(value: 15) {
                        testResult($0)
                    }
                }
                it("Configuration Motion Senser Level Threshold") {
                    cube?.writeConfigurationSensorCollisionThreshold(value: 5) {
                        testResult($0)
                    }
                }
                it("Configuration Motion Senser Level Threshold") {
                    cube?.writeConfigurationSensorDoubleTapInterval(value: 4) {
                        testResult($0)
                    }
                }
            }
        }
    }
}
