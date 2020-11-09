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
        _ = cube.startNotifyId() { self.idNotified($0) }
        _ = cube.startNotifyButton() { self.buttonNotified($0) }
        _ = cube.startNotifyBattery() { self.batteryNotified($0) }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cube.disconnect()
    }
    
    // MARK: notification
    
    private var currentPosition:IdResponse?
    
    private func idNotified(_ result:Result<IdResponse, Error>) {
        switch result {
        case .success(let idResponse):
            self.currentPosition = idResponse
            self.statusUpdated()
        case .failure(let error):
            self.alertError(error)
        }
    }
    
    private var soundEffectIndex:Int = 0
    private func playSound() {
        var se = SoundEffect.init(rawValue: soundEffectIndex)
        if se == nil {
            se = SoundEffect.init(rawValue: 0)
            soundEffectIndex = 0
        }
        cube.writeSoundPlay(se: se!, volume: 1) {
            switch $0 {
            case .success(_):
                print("writeSoundPlay succeeded")
            case .failure(let error):
                self.alertError(error)
            }
        }
        soundEffectIndex += 1
    }
    
    private func buttonNotified(_ result:Result<ButtonResponse, Error>) {
        switch result {
        case .success(let response):
            switch response {
            case let b as ButtonFunctionResponse:
                if b.isPushed {
                    self.playSound()
                }
            default:
                break
            }
        case .failure(let error):
            self.alertError(error)
        }
    }
    
    private var battery:Int?
    
    private func batteryNotified(_ result:Result<BatteryResponse, Error>) {
        switch result {
        case .success(let batteryResponse):
            self.battery = batteryResponse.capacity
            self.statusUpdated()
        case .failure(let error):
            self.alertError(error)
        }
    }
    
    @IBOutlet weak var labelStatus: UILabel!
    
    private func statusUpdated() {
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
            positionText = "no ID provided."
        }
        labelStatus.text = "battery: \(battery.flatMap{String($0)} ?? "?") %\n\(positionText)"
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
