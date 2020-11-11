//
//  CubeControllerPage.swift
//  TccSwift_Example
//
//  Created by hrk on 2020/11/06.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import TccSwift

class CubeControllerPage: UIViewController, CubeDelegate {
    
    internal var cube: Cube!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sliderLeft.transform = sliderLeft.transform.rotated(by: CGFloat(Float.pi * -90 / 180))
        sliderRight.transform = sliderRight.transform.rotated(by: CGFloat(Float.pi * -90 / 180))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cube.delegate = self
        
        _ = cube.startNotifyConfiguration { self.configurationNotified($0) }
        
        cube.writeConfigurationRequestBLEProtocolVersion() {
            switch $0 {
            case .failure(let error): self.alertError(error)
            case .success(_): break
            }
        }
        
        cube.writeConfigurationSensorMagneticAvailability(value: true) {
            switch $0 {
            case .failure(let error): self.alertError(error)
            case .success(_): break
            }
        }
        
        _ = cube.startNotifyId() { self.idNotified($0) }
        _ = cube.startNotifySensor() { self.sensorNotified($0) }
        _ = cube.startNotifyButton() { self.buttonNotified($0) }
        _ = cube.startNotifyBattery() { self.batteryNotified($0) }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cube.disconnect()
    }
    
    // MARK: configuration
    
    var bleProtocolVersion:String?
    
    private func configurationNotified(_ result:Result<ConfigurationResponse, Error>) {
        switch result {
        case .failure(let error): self.alertError(error)
        case .success(let response):
            switch response {
            case let r as ConfigurationBLEProtocolVersionResponse:
                bleProtocolVersion = r.version
                statusUpdated()
            case let r as ConfigurationIdNotifyFrequencyResponse:
                print("Config IdNotifyFrequency: \(r.isSucceeded ? "succeeded" : "failed")")
            case let r as ConfigurationIdMissedNotifyThresholdResponse:
                print("Config IdMissedNotifyThreshold: \(r.isSucceeded ? "succeeded" : "failed")")
            case let r as ConfigurationMagneticSensorAvailabilityResponse:
                print("Config MagneticSensorAvailability: \(r.isSucceeded ? "succeeded" : "failed")")
            case let r as ConfigurationMotorVelocityAvailabilityResponse:
                print("Config MotorVelocityAvailability: \(r.isSucceeded ? "succeeded" : "failed")")
            default: break
            }
        }
    }

    // MARK: notification
    
    private var currentPosition:IdResponse?
    private var isInMat:Bool = false
    
    private func idNotified(_ result:Result<IdResponse, Error>) {
        switch result {
        case .failure(let error): self.alertError(error)
        case .success(let response):
            switch currentPosition {
            case is IdPositionResponse:
                if !isInMat {
                    isInMat = true
                    playSound(.matIn)
                }
            case is IdPositionIdMissedResponse:
                if isInMat {
                    isInMat = false
                    playSound(.matOut)
                }
            default: break
            }
            self.currentPosition = response
            self.statusUpdated()
        }
    }
    
    private var currentMotion:SensorMotionResponse?
    private var currentMagnetic:SensorMagneticResponse?

    private func sensorNotified(_ result:Result<SensorResponse, Error>) {
        switch result {
        case .failure(let error): self.alertError(error)
        case .success(let response):
            switch response {
            case let r as SensorMotionResponse:
                if r.isCollided {
                    self.playSound(.get1)
                    self.lightOn(.red)
                }
                if r.isDoubleTapped {
                    self.playSound(.get2)
                    self.lightOn(.green)
                }
                if r.shaken > 7 {
                    self.playSound(.get3)
                    self.lightOn(.blue)
                }
                currentMotion = r
                self.statusUpdated()
            case let r as SensorMagneticResponse:
                if r.position != .none && r.position != currentMagnetic?.position {
                    self.playSound(.effect1)
                    self.lightOn(.magenta)
                }
                currentMagnetic = r
                self.statusUpdated()
            default:
                break
            }
            self.statusUpdated()
        }
    }

    private func buttonNotified(_ result:Result<ButtonResponse, Error>) {
        switch result {
        case .failure(let error): self.alertError(error)
        case .success(let response):
            switch response {
            case let b as ButtonFunctionResponse:
                if b.isPushed {
                    self.playSound(.selected)
                    self.lightOn(.cyan)
                }
            default:
                break
            }
        }
    }
    
    private var battery:Int?
    
    private func batteryNotified(_ result:Result<BatteryResponse, Error>) {
        switch result {
        case .failure(let error): self.alertError(error)
        case .success(let response):
            self.battery = response.capacity
            self.statusUpdated()
        }
    }
    
    @IBOutlet weak var labelStatus: UILabel!
    
    private func statusUpdated() {
        // Position ID
        let positionText:String
        switch currentPosition {
        case let p as IdPositionResponse:
            positionText = "Position ID: (\(p.cubeX), \(p.cubeY)), rotation: \(p.cubeRotation)"
        case let p as IdStandardResponse:
            positionText = "Standard ID: \(p.id), rotation: \(p.cubeRotation)"
        case is IdPositionIdMissedResponse:
            positionText = "removed from Position ID"
        case is IdStandardResponse:
            positionText = "removed from Standard ID"
        default:
            positionText = ""
        }
        
        // Motion
        let motionText:String
        if let m = currentMotion {
            motionText = "level:\(m.isLevel), collided:\(m.isCollided), doubleTapped:\(m.isDoubleTapped), orientation:\(m.orientation), shaken:\(m.shaken)"
        } else {
            motionText = ""
        }

        // Magnetic
        let magneticText:String
        if let m = currentMagnetic {
            magneticText = "position:\(m.position)"
        } else {
            magneticText = ""
        }

        labelStatus.text =
            "Version: \(bleProtocolVersion ?? "")\n" +
            "Battery: \(battery.flatMap{String($0)} ?? "?") %\n" +
            "ID: \(positionText)\n" +
            "Motion: \(motionText)\n" +
            "Magnet: \(magneticText)\n"
    }
    
    // MARK: other operation
    
    private func playSound(_ se:SoundEffect) {
        cube.writeSoundPlay(se: se, volume: 1) {
            switch $0 {
            case .failure(let error): self.alertError(error)
            case .success(_): break
            }
        }
    }
    
    private func lightOn(_ color:UIColor) {
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        cube.writeLightOn(duration: 0.5, red: Double(r), green: Double(g), blue: Double(b)) {
            switch $0 {
            case .failure(let error): self.alertError(error)
            case .success(_): break
            }
        }
    }

    // MARK: sliders for motor

    @IBOutlet private weak var sliderLeft: UISlider!
    @IBOutlet private weak var sliderRight: UISlider!
    
    @IBAction private func onSliderChanged(_ sender: Any) {
        updateMotorSpeed()
    }
    @IBAction private func onSliderReleased(_ sender: Any) {
        if let slider = sender as? UISlider {
            slider.value = 0
            updateMotorSpeed()
        }
    }
    
    // MARK: motor
    
    var current_left:Int = 0
    var current_right:Int = 0
    
    private func updateMotorSpeed() {
        let left = Int(round(sliderLeft.value * 115))
        let right = Int(round(sliderRight.value * 115))
        if current_left != left || current_right != right {
            cube.writeActivateMotor(left: left, right: right)
            current_left = left
            current_right = right
        }
    }
    
    // MARK: CubeDelegate
    
    func cube(_ cube: Cube, didReceivedUnhandled error: Error) {
        self.alertError(error)
    }
    
    // MARK: Alert
    
    func alertError(_ error:Error) {
        let alertController = UIAlertController(title: "Error from Cube", message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alertController, animated: true, completion: nil)
    }
}
