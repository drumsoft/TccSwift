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
        sliderLeft.removeConstraints(sliderLeft.constraints)
        sliderRight.removeConstraints(sliderRight.constraints)
        sliderLeft.translatesAutoresizingMaskIntoConstraints = true
        sliderRight.translatesAutoresizingMaskIntoConstraints = true
        sliderLeft.transform = sliderLeft.transform.rotated(by: CGFloat(Float.pi * 90 / 180))
        sliderRight.transform = sliderRight.transform.rotated(by: CGFloat(Float.pi * 90 / 180))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cube.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cube.disconnect()
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
            print("MOTOR: \(left), \(right)")
            cube.writeActivateMotor(left: left, right: right)
            current_left = left
            current_right = right
        }
    }
    
    // MARK: CubeDelegate
    
    func cube(_ cube: Cube, didReceivedUnhandled error: Error) {
        let alertController = UIAlertController(title: "Error from Cube", message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alertController, animated: true, completion: nil)
    }
}
