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

fileprivate let BANNER = "== \"Leave it\" Test: Power on and leave the Core Cube on your desk to start the test. =="

class TestWithCube_Basic: QuickSpec {
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
            
            context("Battery") {
                
                it("Read Battery Values") {
                    waitUntil { done in
                        cube?.readBattery {
                            expect($0).to(succeededWith(BatteryResponse.self))
                            done()
                        }
                    }
                }
                
                it("Notified Battery Values") {
                    // notification for battery is emitted 5 seconds interval.
                    waitUntil(timeout: 7) { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyBattery() {
                            expect($0).to(succeededWith(BatteryResponse.self))
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
                    cube?.writeLightOn(duration: 1, red: 1, green: 1, blue: 1) { expect($0).to(succeeded()) }
                    sleep(1)
                }
                
                it("Light Off") {
                    cube?.writeLightAllOff() { expect($0).to(succeeded()) }
                    sleep(1)
                }
                
                it("Light On Sequence") {
                    cube?.writeLightSequence(repeats: 2, sequence: [
                        LightOnUnit(duration: 0.3, red: 1, green: 0, blue: 0),
                        LightOnUnit(duration: 0.3, red: 0, green: 0, blue: 1),
                        LightOnUnit(duration: 0.3, red: 0, green: 1, blue: 0)
                    ]) {
                        expect($0).to(succeeded())
                    }
                    sleep(2)
                }
            }
            
            context("Sound") {
                
                it("Sound Effect") {
                    cube?.writeSoundPlay(se: .effect1, volume: 1) { expect($0).to(succeeded()) }
                    sleep(1)
                }
                
                it("Sound Effect And Stop") {
                    cube?.writeSoundPlay(se: .effect2, volume: 1) { expect($0).to(succeeded()) }
                    usleep( 10000)
                    cube?.writeSoundStop { expect($0).to(succeeded()) }
                    usleep(990000)
                }
                
                it("Play Sound Sequence") {
                    cube?.writeSoundPlayNotes(repeats: 2, sequence: [
                        SoundNoteUnit(duration:0.2, note:57, volume: 1),
                        SoundNoteUnit(duration:0.2, note:61, volume: 1),
                        SoundNoteUnit(duration:0.2, note:64, volume: 1),
                        SoundNoteUnit(duration:0.2, note:69, volume: 1)
                    ]) {
                        expect($0).to(succeeded())
                    }
                    sleep(2)
                }
                
            }
            
            context("Configuration Read") {
                
                it("Read Configuration Value") {
                    waitUntil { done in
                        cube?.readConfiguration {
                            expect($0).to(succeededWith(ConfigurationBLEProtocolVersionResponse.self))
                            done()
                        }
                        cube?.writeConfigurationRequestBLEProtocolVersion {
                            expect($0).to(succeeded())
                        }
                    }
                }
                
                it("Notified Configuration Value") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifyConfiguration() {
                            expect($0).to(succeededWith(ConfigurationBLEProtocolVersionResponse.self))
                            cube?.stopNotifyConfiguration(id!)
                            done()
                        }
                        cube?.writeConfigurationRequestBLEProtocolVersion {
                            expect($0).to(succeeded())
                        }
                    }
                }
                
            }

            context("Configuration Write") {
                
                it("Configuration Motion Senser Level Threshold") {
                    cube?.writeConfigurationSensorLevelThreshold(value: 15) {
                        expect($0).to(succeeded())
                    }
                }
                
                it("Configuration Motion Senser Level Threshold") {
                    cube?.writeConfigurationSensorCollisionThreshold(value: 5) {
                        expect($0).to(succeeded())
                    }
                }
                
                it("Configuration Motion Senser Level Threshold") {
                    cube?.writeConfigurationSensorDoubleTapInterval(value: 4) {
                        expect($0).to(succeeded())
                    }
                }
                
            }
        }
    }
}
