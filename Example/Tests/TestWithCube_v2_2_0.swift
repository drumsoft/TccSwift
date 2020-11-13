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

fileprivate let BANNER = "== \"v2.2.0\" Test: Power on and leave the Core Cube on your desk to start the test. =="

class TestWithCube_v2_2_0: QuickSpec {
    var bleProtocolVersion:String?
    var locationNotificationFrequencyIsSet:Bool?
    var locationMissedThresholdIsSet:Bool?
    var magneticSensorAvailabilityIsSet:Bool?
    var motorVelocityAvailabilityIsSet:Bool?
    
    private func updateWithConfigurationResult(_ result:Result<ConfigurationResponse,Error>) {
        switch result {
        case .success(let response):
            switch response {
            case let r as ConfigurationBLEProtocolVersionResponse:
                bleProtocolVersion = r.version
            case let r as ConfigurationLocationNotificationFrequencyResponse:
                locationNotificationFrequencyIsSet = r.isSucceeded
            case let r as ConfigurationLocationMissedThresholdResponse:
                locationMissedThresholdIsSet = r.isSucceeded
            case let r as ConfigurationMagneticSensorAvailabilityResponse:
                magneticSensorAvailabilityIsSet = r.isSucceeded
            case let r as ConfigurationMotorVelocityAvailabilityResponse:
                motorVelocityAvailabilityIsSet = r.isSucceeded
            default:
                print("WARNING: unknown configuration response received: \(response)")
            }
        case .failure(let error):
            fail(error.localizedDescription)
        }
    }
    
    override func spec() {
        
        var cube:Cube!
        
        var notifyId:UInt?
        
        beforeSuite {
            print(BANNER)
            cube = testInitializeCube()
            
            notifyId = cube.startNotifyConfiguration {
                self.updateWithConfigurationResult($0)
            }
            cube.writeConfigurationRequestBLEProtocolVersion {
                expect($0).to(succeeded())
            }
            
            expect(self.bleProtocolVersion).toEventually(beGreaterThanOrEqualTo("2.2.0"), timeout: 5)
            print("the Cube's protocol version: \(self.bleProtocolVersion!)")
        }
        
        afterSuite {
            cube.stopNotifyConfiguration(notifyId!)
            testFinalizeCube(cube)
        }
        
        describe("Cube") {
            describe("Configuration") {

                it("Configuration Id Notification Frequency") {
                    cube?.writeConfigurationIdNotificationFrequency(interval: 0.03, condition: .atLeast300millisec) {
                        expect($0).to(succeeded())
                    }
                    expect(self.locationNotificationFrequencyIsSet).toEventually(beTrue())
                }
                
                it("Configuration Id Missed Threshold") {
                    cube?.writeConfigurationIdMissedThreshold(0.1) {
                        expect($0).to(succeeded())
                    }
                    expect(self.locationMissedThresholdIsSet).toEventually(beTrue())
                }
                
                it("Configuration Magnetic Sensor Availability") {
                    cube?.writeConfigurationMagneticSensorAvailability(true) {
                        expect($0).to(succeeded())
                    }
                    expect(self.magneticSensorAvailabilityIsSet).toEventually(beTrue())
                }
                
                it("Configuration Motor Velocity Availability") {
                    cube?.writeConfigurationMotorVelocityAvailability(true) {
                        expect($0).to(succeeded())
                    }
                    expect(self.motorVelocityAvailabilityIsSet).toEventually(beTrue())
                }
                
            }
            
            describe("Sensors") {
                
                it("Read Magnetic Sensor Value") {
                    waitUntil { done in
                        // a value will have been delivered after magnetic sensor enabled.
                        cube?.readSensor {
                            expect($0).to(succeededWith(SensorMagneticResponse.self))
                            done()
                        }
                    }
                }
                
                // Requesting Magnetic Sensor Value seems not implemented.
                xit("Requesting Magnetic Sensor Value") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifySensor() {
                            expect($0).to(succeededWith(SensorMagneticResponse.self))
                            cube?.stopNotifySensor(id!)
                            done()
                        }
                        cube?.writeRequestMagneticSensorValues {
                            expect($0).to(succeeded())
                        }
                    }
                }
                
                // Requesting Motion Sensor Value seems not implemented.
                xit("Motion Sensor Request") {
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube?.startNotifySensor() {
                            expect($0).to(succeededWith(SensorMotionResponse.self))
                            cube?.stopNotifySensor(id!)
                            done()
                        }
                        cube?.writeRequestMotionSensorValues {
                            expect($0).to(succeeded())
                        }
                    }
                }
                
            }
            
            describe("Motor Velocities") {
                
                // read for Motor seems not implemented.
                xit("Read Motor Velocities Value") {
                    cube?.writeActivateMotor(velocity: 80, acceralation: 4, angularVelocity: 180, priority: .angularVelocity, duration: 1.5)
                    sleep(1)
                    waitUntil { done in
                        cube.readMotor {
                            expect($0).to(succeededWith(MotorVelocitiesResponse.self))
                            done()
                        }
                    }
                }
                
                it("Notify Motor Velocities Value") {
                    cube?.writeActivateMotor(velocity: 80, acceralation: 4, angularVelocity: 180, priority: .angularVelocity, duration: 1.5)
                    sleep(1)
                    waitUntil { done in
                        var id:UInt? = nil
                        id = cube.startNotifyMotor() {
                            expect($0).to(succeededWith(MotorVelocitiesResponse.self))
                            cube?.stopNotifyMotor(id!)
                            done()
                        }
                    }
                }
                
            }
        }
    }
}
