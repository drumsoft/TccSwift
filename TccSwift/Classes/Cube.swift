//
//  Cube.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation
import CoreBluetooth

/// Delegate to receive unhandled error.
public protocol CubeDelegate {
    func cube(_ cube: Cube, didReceivedUnhandled error: Error)
}

/// Core Cube class
open class Cube {
    
    // MARK: IDs
    
    static internal let SERVICE_Cube = CBUUID(string: "10B20100-5B3B-4571-9508-CF3EFCD7BBAE")

    static private let CHR_ID = CBUUID(string: "10B20101-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_SENSOR = CBUUID(string: "10B20106-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_BUTTON = CBUUID(string: "10B20107-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_BATTERY = CBUUID(string: "10B20108-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_MOTOR = CBUUID(string: "10B20102-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_LIGHT = CBUUID(string: "10B20103-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_SOUND = CBUUID(string: "10B20104-5B3B-4571-9508-CF3EFCD7BBAE")
    static private let CHR_CONFIGURATION = CBUUID(string: "10B201FF-5B3B-4571-9508-CF3EFCD7BBAE")

    static private let SERVICES = [SERVICE_Cube]
    static private let CHARACTERISTICS = [
        SERVICE_Cube: [CHR_ID, CHR_SENSOR, CHR_BUTTON, CHR_BATTERY, CHR_MOTOR, CHR_LIGHT, CHR_SOUND, CHR_CONFIGURATION],
    ]
    
    // MARK: Defaults

    public static let CUBE_CONNECTION_TIMEOUT_DEFAULT:TimeInterval = 5
    
    // MARK: init
    
    internal let peripheral:CBPeripheral
    private var peripheralDelegate:PeripheralDelegate!
    
    internal let manager:CubeManager
    
    public var delegate:CubeDelegate?
    
    public required init(peripheral:CBPeripheral, manager: CubeManager) {
        self.peripheral = peripheral
        self.manager = manager
    }
    
    // MARK: Identifiers
    
    /// name for the Cube peripheral
    open var name:String? { peripheral.name }
    /// identifier string for the Cube peripheral
    open var identifierString:String { peripheral.identifier.uuidString }
    
    // MARK: Manage Connection
    
    private var connectionCallback:((Result<Cube,Error>)->())?
    private var connectionTimer:Timer?
    
    /// Connect to Cube
    ///
    /// - Parameters:
    ///   - timeout: Timeout in seconds.
    ///   - callback: callback for connection.
    open func connect(timeout:TimeInterval = CUBE_CONNECTION_TIMEOUT_DEFAULT, callback: @escaping (Result<Cube,Error>)->()) {
        connectionCallback = callback
        connectionTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            self.manager.disconnectFromCube(self)
            self.onConnectionFailed(TccError.connectionTimeouted)
        }
        manager.connectFromCube(self)
    }
    
    /// disconnect from Cube
    /// if disconnected while connection, connection callback will receive TccError.disconnectedWhileConnection error.
    open func disconnect() {
        manager.disconnectFromCube(self)
        connectionTimer?.invalidate()
        connectionTimer = nil
        if let cb = connectionCallback {
            connectionCallback = nil
            cb(Result.failure(TccError.disconnectedWhileConnection))
        }
    }
    
    internal func onConnected() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        peripheralDelegate = PeripheralDelegate(cube:self)
        peripheral.delegate = peripheralDelegate
        peripheral.discoverServices(Cube.SERVICES)
    }
    
    internal func onConnectionFailed(_ error:Error) {
        connectionTimer?.invalidate()
        connectionTimer = nil
        if let cb = connectionCallback {
            connectionCallback = nil
            cb(Result.failure(error))
        }
    }
    
    internal func onDisconnected(_ error:Error?) {
        connectionTimer?.invalidate()
        connectionTimer = nil
        if let cb = connectionCallback {
            connectionCallback = nil
            cb(Result.failure(error ?? TccError.disconnectedWhileConnection))
        }
    }
    
    internal func onConnectionSucceeded() {
        if let cb = connectionCallback {
            connectionCallback = nil
            cb(Result.success(self))
        }
    }
    
    // MARK: Services, Characteristics
    
    private var characteristics:[CBUUID:CBCharacteristic] = [:]
    
    private class PeripheralDelegate: NSObject, CBPeripheralDelegate {
        let cube:Cube
        
        required init(cube:Cube) {
            self.cube = cube
        }
        
        /// Services を検出 -> Characteristics を検索
        public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            guard error == nil else {
                cube.onConnectionFailed(error!)
                cube.disconnect()
                return
            }
            guard peripheral.services != nil && (SERVICES.allSatisfy{ serviceUUID in peripheral.services!.contains{ $0.uuid == serviceUUID } }) else {
                cube.onConnectionFailed(TccError.requiredServiceNotFound)
                cube.disconnect()
                return
            }
            for service in peripheral.services! {
                peripheral.discoverCharacteristics(CHARACTERISTICS[service.uuid], for: service)
            }
        }
        
        /// Characteristics を検出 -> 接続完了にする
        public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            guard error == nil else {
                cube.onConnectionFailed(error!)
                cube.disconnect()
                return
            }
            for characteristic in service.characteristics! {
                cube.characteristics[characteristic.uuid] = characteristic
            }
            cube.onConnectionSucceeded()
        }
        
        /// "Notify" result callback
        public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            // characteristic.isNotifying ? notify subscribed : canceled.
        }
        
        /// "Read" or "Notify" callback
        public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            cube.didUpdateValueFor(characteristic: characteristic, error: error)
        }
        
        /// "Writre" callback
        public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            cube.didWriteValueFor(characteristic: characteristic, error: error)
        }
    }
    
    private func didUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        let chr_id = characteristic.uuid
        if error != nil {
            if notifyWaiting[chr_id] != nil && notifyWaiting[chr_id]!.count > 0 {
                for waiting in notifyWaiting[chr_id]! {
                    callbackResult(nil, error!, to: waiting, for: chr_id)
                }
            } else {
                didReceivedUnhandledError(error!)
            }
        }
    }
    
    private func didUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        let chr_id = characteristic.uuid
        var callbacked = false
        // parse value
        let result = parseData(characteristic.value, for: chr_id)
        // read callbacks
        if readWaiting[chr_id] != nil && readWaiting[chr_id]!.count > 0 {
            while readWaiting[chr_id]!.count > 0 {
                callbackResult(result, error, to: readWaiting[chr_id]!.removeFirst(), for: chr_id)
            }
            callbacked = true
        }
        // notify callbacks
        if notifyWaiting[chr_id] != nil && notifyWaiting[chr_id]!.count > 0 {
            for waiting in notifyWaiting[chr_id]! {
                callbackResult(result, error, to: waiting, for: chr_id)
            }
            callbacked = true
        }
        // unhandled error
        if !callbacked && error != nil {
            didReceivedUnhandledError(error!)
        }
    }
    
    private func didWriteValueFor(characteristic: CBCharacteristic, error: Error?) {
        let chr_id = characteristic.uuid
        if writeWaiting[chr_id] != nil && writeWaiting[chr_id]!.count > 0 {
            while writeWaiting[chr_id]!.count > 0 {
                callbackResult(error == nil ? Succeeded() : nil, error, to: writeWaiting[chr_id]!.removeFirst(), for: chr_id)
            }
        } else if error != nil {
            didReceivedUnhandledError(error!)
        }
    }
    
    private func didReceivedUnhandledError(_ error:Error) {
        delegate?.cube(self, didReceivedUnhandled: error)
    }

    // MARK: parse value and manage callbacks
    
    private func parseData(_ data:Data?, for chr_id:CBUUID) -> TccResponse? {
        guard data != nil else {
            return nil
        }
        switch chr_id {
        case Cube.CHR_ID:
            return IdResponse.parse(data!)
        case Cube.CHR_SENSOR:
            return SensorResponse.parse(data!)
        case Cube.CHR_BUTTON:
            return ButtonResponse.parse(data!)
        case Cube.CHR_BATTERY:
            return BatteryResponse.parse(data!)
        case Cube.CHR_MOTOR:
            return MotorResponse.parse(data!)
        case Cube.CHR_CONFIGURATION:
            return ConfigurationResponse.parse(data!)
        default:
            return nil
        }
    }
    
    private var seed:UInt = 1
    
    private struct Waiting<ResultType:TccResponse> {
        var id: UInt
        var callback:(Result<ResultType,Error>)->()
        func success(_ value:TccResponse) {
            if value is ResultType {
                callback(Result.success(value as! ResultType))
            } else {
                callback(Result.failure(TccError.resultTypeUnmatch))
            }
        }
        func failure(_ error:Error) {
            callback(Result.failure(error))
        }
    }
    
    private var readWaiting:[CBUUID:[Any]] = [:]
    private var notifyWaiting:[CBUUID:[Any]] = [:]
    private var writeWaiting:[CBUUID:[Any]] = [:]
    
    private func callbackResult(_ result:TccResponse? = nil, _ error:Error? = nil, to waiting:Any, for chr_id:CBUUID) {
        switch chr_id {
        case Cube.CHR_ID:
            callbackFor(result: result, error: error, to: waiting as! Waiting<IdResponse>)
        case Cube.CHR_SENSOR:
            callbackFor(result: result, error: error, to: waiting as! Waiting<SensorResponse>)
        case Cube.CHR_BUTTON:
            callbackFor(result: result, error: error, to: waiting as! Waiting<ButtonResponse>)
        case Cube.CHR_BATTERY:
            callbackFor(result: result, error: error, to: waiting as! Waiting<BatteryResponse>)
        case Cube.CHR_MOTOR:
            callbackFor(result: result, error: error, to: waiting as! Waiting<MotorResponse>)
        case Cube.CHR_CONFIGURATION:
            callbackFor(result: result, error: error, to: waiting as! Waiting<ConfigurationResponse>)
        default:
            break
        }
    }
    
    private func callbackFor<ResultType:TccResponse>(result:TccResponse?, error:Error?, to waiting:Waiting<ResultType>) {
        if error != nil {
            waiting.callback(Result.failure(error!))
            return
        }
        guard result != nil else {
            waiting.callback(Result.failure(TccError.resultParseFailed))
            return
        }
        guard let r = result as? ResultType else {
            waiting.callback(Result.failure(TccError.resultTypeUnmatch))
            return
        }
        waiting.callback(Result.success(r))
    }
    
    // MARK: Cube Interface

    private func readCharacteristic<ResultType:TccResponse>(_ charid:CBUUID, _ callback: @escaping (Result<ResultType,Error>)->()) {
        guard let characteristic = characteristics[charid] else {
            callback(Result.failure(TccError.characteristicNotSupported))
            return
        }
        let isNew = readWaiting[charid] == nil || readWaiting[charid]!.count == 0
        if readWaiting[charid] == nil { readWaiting[charid] = [] }
        readWaiting[charid]!.append(
            Waiting(id: 0, callback: callback)
        )
        if isNew {
            peripheral.readValue(for: characteristic)
        }
    }
    private func writeCharacteristic(_ charid:CBUUID, data: Data, _ callback: ((Result<Succeeded,Error>)->())? ) {
        guard let characteristic = characteristics[charid] else {
            callback?(Result.failure(TccError.characteristicNotSupported))
            return
        }
        if callback != nil {
            if writeWaiting[charid] == nil { writeWaiting[charid] = [] }
            writeWaiting[charid]!.append(
                Waiting(id: 0, callback: callback!)
            )
        }
        peripheral.writeValue(data, for: characteristic, type: callback != nil ? .withResponse : .withoutResponse)
    }
    private func startNotifyCharacteristic<ResultType:TccResponse>(_ charid:CBUUID, _ callback: @escaping (Result<ResultType,Error>)->()) -> UInt {
        guard let characteristic = characteristics[charid] else {
            callback(Result.failure(TccError.characteristicNotSupported))
            return 0
        }
        let isNew = notifyWaiting[charid] == nil || notifyWaiting[charid]!.count == 0
        if notifyWaiting[charid] == nil { notifyWaiting[charid] = [] }
        let id = seed
        seed += 1
        notifyWaiting[charid]!.append(
            Waiting(id: id, callback: callback)
        )
        if isNew {
            peripheral.setNotifyValue(true, for: characteristic)
        }
        return id
    }
    private func stopNotifyCharacteristic(_ charid:CBUUID, _ id: UInt) {
        guard let characteristic = characteristics[charid] else {
            return
        }
        if notifyWaiting[charid] != nil {
            if let i = (notifyWaiting[charid]!.firstIndex{ ($0 as? Waiting<TccResponse>)?.id == id }) {
                notifyWaiting[charid]!.remove(at: i)
            }
        }
        if notifyWaiting[charid] == nil || notifyWaiting[charid]!.count == 0 {
            peripheral.setNotifyValue(false, for: characteristic)
        }
    }
    
    // MARK: Cube Interfaces

    // MARK: ID (Read, Notify) CHR_ID

    /// Read ID (Position ID, Standard ID) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readId(_ callback: @escaping (Result<IdResponse,Error>)->()) {
        readCharacteristic(Cube.CHR_ID, callback)
    }
    
    /// Start notify ID (Position ID, Standard ID) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyId(_ callback: @escaping (Result<IdResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(Cube.CHR_ID, callback)
    }
    
    /// Stop notify ID (Position ID, Standard ID) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyId(_ id: UInt) {
        stopNotifyCharacteristic(Cube.CHR_ID, id)
    }
    
    // MARK: Sensor (Write, Read, Notify) CHR_SENSOR
    
    /// Read Sensor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readSensor(_ callback: @escaping (Result<SensorResponse,Error>)->()) {
        readCharacteristic(Cube.CHR_SENSOR, callback)
    }
    
    /// Start notify Sensor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifySensor(_ callback: @escaping (Result<SensorResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(Cube.CHR_SENSOR, callback)
    }
    
    /// Stop notify Sensor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifySensor(_ id: UInt) {
        stopNotifyCharacteristic(Cube.CHR_SENSOR, id)
    }
    
    /// Request Motion Sensor Notification
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeRequestMotionSensorValues(callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = SensorRequestMotionRequest().data
        writeCharacteristic(Cube.CHR_SENSOR, data: data, callback)
    }
    
    /// Request Magnetic Sensor Notification
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeRequestMagneticSensorValues(callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = SensorRequestMagneticRequest().data
        writeCharacteristic(Cube.CHR_SENSOR, data: data, callback)
    }
    
    // MARK: Button (Read, Notify): Bool CHR_BUTTON
    
    /// Read Button values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readButton(_ callback: @escaping (Result<ButtonResponse,Error>)->()) {
        readCharacteristic(Cube.CHR_BUTTON, callback)
    }
    
    /// Start notify Button values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyButton(_ callback: @escaping (Result<ButtonResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(Cube.CHR_BUTTON, callback)
    }
    
    /// Stop notify Button values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyButton(_ id: UInt) {
        stopNotifyCharacteristic(Cube.CHR_BUTTON, id)
    }

    // MARK: Battery (Read, Notify): Int (0...100) CHR_BATTERY
    
    /// Read Battery values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readBattery(_ callback: @escaping (Result<BatteryResponse,Error>)->()) {
        readCharacteristic(Cube.CHR_BATTERY, callback)
    }
    
    /// Start notify Battery values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyBattery(_ callback: @escaping (Result<BatteryResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(Cube.CHR_BATTERY, callback)
    }
    
    /// Stop notify Battery values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyBattery(_ id: UInt) {
        stopNotifyCharacteristic(Cube.CHR_BATTERY, id)
    }

    // MARK: Motor (Write without response, Read, Notify) CHR_MOTOR
    
    /// Read Motor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readMotor(_ callback: @escaping (Result<MotorResponse,Error>)->()) {
        readCharacteristic(Cube.CHR_MOTOR, callback)
    }
    
    /// Start notify Motor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyMotor(_ callback: @escaping (Result<MotorResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(Cube.CHR_MOTOR, callback)
    }
    
    /// Stop notify Motor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyMotor(_ id: UInt) {
        stopNotifyCharacteristic(Cube.CHR_MOTOR, id)
    }
    
    /// Activate Motors.
    ///
    /// - Parameters:
    ///   - left:       left motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - right:      right motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    open func writeActivateMotor(left: Int, right: Int) {
        let data = MotorActivateRequest(left: left, right: right).data
        writeCharacteristic(Cube.CHR_MOTOR, data: data, nil)
    }
    
    /// Activate Motors with duration.
    ///
    /// - Parameters:
    ///   - left:       left motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - right:      right motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - duration:   duration to activate motors. 0.01 to 2.55 seconds. 0 means infinite.
    open func writeActivateMotor(left: Int, right: Int, duration:TimeInterval) {
        let data = MotorActivateWithDurationRequest(left: left, right: right, duration: duration).data
        writeCharacteristic(Cube.CHR_MOTOR, data: data, nil)
    }
    
    /// Move To Destination.
    ///
    /// - Parameters:
    ///
    ///   - id:                 Arbitrary value between 0 to 255. This value is used to identify the MotorDestinationResultResponse.
    ///   - timeout:            Timeout from 1 to 255 seconds. 0 means 10 seconds.
    ///   - curve:              the Cube's moving curve type.
    ///   - maxVelocity:        the Cube's maximum velocity during moving. set 10 to 255.
    ///   - easing:             easing to the Cube's velocity change.
    ///   - destinationX:       destination position X in Position ID.
    ///   - destinationY:       destination position Y in Position ID.
    ///   - finalRotation:      final Cube's rotation. value. meaning of this value depends on the finalRotationType.
    ///   - finalRotationType:  final Cube's rotation type.
    open func writeMoveToDestination(id: Int, timeout: TimeInterval, curve: MotorDestinationCurve, maxVelocity: Int, easing: MotorDestinationEasing, destinationX: Int, destinationY: Int, finalRotation: Int, finalRotationType: MotorDestinationFinalRotation) {
        let data = MotorMoveToDestinationRequest(id: id, timeout: timeout, curve: curve, maxVelocity: maxVelocity, easing: easing, destination: MotorDestinationUnit(destinationX: destinationX, destinationY: destinationY, finalRotation: finalRotation, finalRotationType: finalRotationType)).data
        writeCharacteristic(Cube.CHR_MOTOR, data: data, nil)
    }
    
    /// Move To Multiple Destination.
    ///
    /// - Parameters:
    ///
    ///   - id:             Arbitrary value between 0 to 255. This value is used to identify the MotorDestinationResultResponse.
    ///   - timeout:        Timeout from 1 to 255 seconds. 0 means 10 seconds.
    ///   - curve:          the Cube's moving curve type.
    ///   - maxVelocity:    the Cube's maximum velocity during moving. set 10 to 255.
    ///   - easing:         easing to the Cube's velocity change.
    ///   - writeMode:      overwrite to current moving or append.
    ///   - destinations:   list of destinations
    ///   - callback:       callback after write succeeded.
    open func writeMoveToMultipleDestination(id: Int, timeout: TimeInterval, curve: MotorDestinationCurve, maxVelocity: Int, easing: MotorDestinationEasing, writeMode: MotorDestinationWriteMode, destinations: [MotorDestinationUnit]) {
        let data = MotorMoveToMultipleDestinationRequest(id: id, timeout: timeout, curve: curve, maxVelocity: maxVelocity, easing: easing, writeMode: writeMode, destinations: destinations).data
        writeCharacteristic(Cube.CHR_MOTOR, data: data, nil)
    }
    
    /// Move with accelarated velocity.
    ///
    /// - Parameters:
    ///
    ///   - velocity:           Final velocity. go backward with negative value.
    ///   - acceralation:       Velocity increase per 100 milliseconds. 1 to 255. 0 means constant velocity.
    ///   - angularVelocity:    Rotation speed clockwise in 0 to 65535 degree/sec. counterclockwise with negative value.
    ///   - priority:           Set priority to keep velocity or angularVelocity .
    ///   - duration:           0.01 to 2.55 seconds. 0 means infinite.
    ///   - callback:           callback after write succeeded.
    open func writeMoveToMultipleDestination(velocity: Int, acceralation: Int, angularVelocity: Int, priority: MotorAcceralationPriority, duration: TimeInterval) {
        let data = MotorMoveWithAcceralationRequest(velocity: velocity, acceralation: acceralation, angularVelocity: angularVelocity, priority: priority, duration: duration).data
        writeCharacteristic(Cube.CHR_MOTOR, data: data, nil)
    }

    // MARK: Light (Write) CHR_LIGHT

    /// Turn on (and off) the light.
    ///
    /// - Parameters:
    ///   - duration: Turn off the light after duration time in seconds. Setting 0 means no turn off.
    ///   - red:      color red value 0.0 to 1.0
    ///   - green:    color green value 0.0 to 1.0
    ///   - blue:     color blue value 0.0 to 1.0
    ///   - callback: callback after write succeeded.
    open func writeLightOn(duration:TimeInterval, red:Double, green:Double, blue:Double, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = LightOnRequest(unit:LightOnUnit(duration: duration, red: red, green: green, blue: blue)).data
        writeCharacteristic(Cube.CHR_LIGHT, data: data, callback)
    }
    
    /// Turn on (and off) the light in sequence.
    ///
    /// - Parameters:
    ///   - repeats:    repeat sequence as loop. 0 means infinite loop.
    ///   - sequence:   sequence of light controls.
    ///   - callback:   callback after write succeeded.
    open func writeLightSequence(repeats: Int, sequence:[LightOnUnit], callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = LightOnSequenceRequest(repeats: repeats, sequence: sequence).data
        writeCharacteristic(Cube.CHR_LIGHT, data: data, callback)
    }

    /// Turn off all light.
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeLightAllOff(callback:((Result<Succeeded,Error>)->())? = nil) {
        writeCharacteristic(Cube.CHR_LIGHT, data: LightAllOffRequest().data, callback)
    }
    
    // MARK: Sound (Write) CHR_SOUND
    
    /// Play a sound effect.
    ///
    /// - Parameters:
    ///   - se:         select sound effect.
    ///   - volume:     0 means mute, 1 to 255 means max volume.
    ///   - callback:   callback after write succeeded.
    open func writeSoundPlay(se:SoundEffect, volume:Double, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = SoundPlayRequest(se: se, volume: volume).data
        writeCharacteristic(Cube.CHR_SOUND, data: data, callback)
    }
    
    /// Play notes.
    ///
    /// - Parameters:
    ///   - repeats:    repeat sequence as loop. 0 means infinite loop.
    ///   - sequence:   sequence of note for play.
    ///   - callback:   callback after write succeeded.
    ///
    /// SoundNoteUnit:
    ///   - duration:   0.01 to 2.55 seconds.
    ///   - note:   0 to 127, 57 = A4 440Hz, 128 = mute
    ///   - volume:     0 means mute, 1 to 255 means max volume.
    open func writeSoundPlayNotes(repeats: Int, sequence:[SoundNoteUnit], callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = SoundPlayNotesRequest(repeats: repeats, sequence: sequence).data
        writeCharacteristic(Cube.CHR_SOUND, data: data, callback)
    }

    /// Stop playing sound.
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeSoundStop(callback:((Result<Succeeded,Error>)->())? = nil) {
        writeCharacteristic(Cube.CHR_SOUND, data: SoundStopRequest().data, callback)
    }

    // MARK: Configuration (Write, Read, Notify) CHR_CONFIGURATION
    
    /// Read Configuration values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readConfiguration(_ callback: @escaping (Result<ConfigurationResponse,Error>)->()) {
        readCharacteristic(Cube.CHR_CONFIGURATION, callback)
    }
    
    /// Start notify Configuration values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyConfiguration(_ callback: @escaping (Result<ConfigurationResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(Cube.CHR_CONFIGURATION, callback)
    }
    
    /// Stop notify Configuration values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyConfiguration(_ id: UInt) {
        stopNotifyCharacteristic(Cube.CHR_CONFIGURATION, id)
    }
    
    /// Configuration: request BLE Protocol Version.
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeConfigurationRequestBLEProtocolVersion(callback:((Result<Succeeded,Error>)->())? = nil) {
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: ConfigurationRequestBLEProtocolVersionRequest().data, callback)
    }
    
    /// Configuration: Motion sensor's "level" threshold.
    ///
    /// - Parameters:
    ///   - value:      level threshold in degree 1 to 45.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorLevelThreshold(value: Int, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationSensorLevelThresholdRequest(value: value).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Motion sensor's collision threshold.
    ///
    /// - Parameters:
    ///   - value:      collision threshold in 1 to 10 collision level.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorCollisionThreshold(value: Int, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationSensorCollisionThresholdRequest(value: value).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Motion sensor's double tap interval limit.
    ///
    /// - Parameters:
    ///   - value:      double tap interval limit in 0 to 7 level.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorDoubleTapInterval(value: Int, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationSensorDoubleTapIntervalRequest(value: value).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: ID (Position ID, Standard ID) notification frequency.
    ///
    /// - Parameters:
    ///   - interval:   minimum notify interval in 0.00 to 2.55 seconds.
    ///   - condition:  condition to notify.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorIdFrequency(interval: TimeInterval, condition: ConfigurationSensorIdNotifyCondition, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationSensorIdFrequencyRequest(interval: interval, condition: condition).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: threshold time to determined as "ID missed".
    ///
    /// - Parameters:
    ///   - value:      threshold time to determined as "ID missed" in 0.00 to 2.55 seconds.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorIdMissedThreshold(value: TimeInterval, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationSensorIdMissedThresholdRequest(value: value).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Magnetic sensor availability.
    ///
    /// - Parameters:
    ///   - value:      availability.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorMagneticAvailability(value: Bool, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationSensorMagneticAvailabilityRequest(value: value).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Velocity values availability.
    ///
    /// - Parameters:
    ///   - value:      availability.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationMotorVelocityAvailability(value: Bool, callback:((Result<Succeeded,Error>)->())? = nil) {
        let data = ConfigurationMotorVelocityAvailabilityRequest(value: value).data
        writeCharacteristic(Cube.CHR_CONFIGURATION, data: data, callback)
    }
}
