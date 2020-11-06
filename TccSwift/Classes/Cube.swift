//
//  Cube.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation
import CoreBluetooth

internal let SERVICE_Cube = CBUUID(string: "10B20100-5B3B-4571-9508-CF3EFCD7BBAE")

private let CHR_ID = CBUUID(string: "10B20101-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_SENSOR = CBUUID(string: "10B20106-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_BUTTON = CBUUID(string: "10B20107-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_BATTERY = CBUUID(string: "10B20108-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_MOTOR = CBUUID(string: "10B20102-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_LIGHT = CBUUID(string: "10B20103-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_SOUND = CBUUID(string: "10B20104-5B3B-4571-9508-CF3EFCD7BBAE")
private let CHR_CONFIGURATION = CBUUID(string: "10B201FF-5B3B-4571-9508-CF3EFCD7BBAE")

private let SERVICES = [SERVICE_Cube]
private let CHARACTERISTICS = [
    SERVICE_Cube: [CHR_ID, CHR_SENSOR, CHR_BUTTON, CHR_BATTERY, CHR_MOTOR, CHR_LIGHT, CHR_SOUND, CHR_CONFIGURATION],
]

/// Core Cube class
open class Cube: NSObject, CBPeripheralDelegate {
    internal let peripheral: CBPeripheral
    private let scanner: Scanner
    
    /**
     * Create a new cube instance
     *
     * @param peripheral - a noble's peripheral object
     */
    init(_ peripheral:CBPeripheral, _ scanner:Scanner) {
        self.peripheral = peripheral
        self.scanner = scanner
    }
    
    /**
     * id of cube as a BLE Peripheral
     */
    public var id: UUID {
        return self.peripheral.identifier
    }
    
    /**
     * address of cube as a BLE Peripheral
     */
    public var address: String? {
        return getAddress(self.peripheral.identifier).address
    }
    
    private enum AddressType {
        case PUBLIC
        case RANDOM
        case UNKNOWN
    }
    
    /// get address with UUID
    /// from https://github.com/Timeular/noble-mac/blob/master/src/objc_cpp.mm
    private func getAddress(_ uuid: UUID) -> (address:String?, type:AddressType) {
        let deviceUuid:String = uuid.uuidString;
        let plist = NSDictionary.init(contentsOf: NSURL.fileURL(withPath: "/Library/Preferences/com.apple.Bluetooth.plist"))
        if plist != nil {
            let cache = plist!.object(forKey: "CoreBluetoothCache") as? NSDictionary
            if cache != nil {
                let entry = cache!.object(forKey: deviceUuid) as? NSDictionary
                if entry != nil {
                    let type = entry!.object(forKey: "DeviceAddressType") as? NSNumber
                    let addressType:AddressType = type.map { $0.boolValue ? .RANDOM : .PUBLIC } ?? .UNKNOWN
                    let address = entry!.object(forKey: "DeviceAddress") as? NSString
                    if (address != nil) {
                        return (String(address!), addressType)
                    }
                }
            }
        }
        return (nil, .UNKNOWN);
    }
    
    // MARK: Connection

    /**
     * Connect to the cube
     */
    public func connect(_ callback: @escaping (Result<Cube,Error>)->()) {
        connectionCallback = callback
        scanner.connectForCube(self)
    }
    
    /// disconnect the cube.
    public func disconnect() {
        scanner.disconnectForCube(self)
    }

    // MARK: Connection Callbacks

    private var connectionCallback:((Result<Cube,Error>)->())?
    
    private func connectionSucceeded() {
        connectionCallback?(Result.success(self))
        connectionCallback = nil
    }
    
    private func connectionFailed(_ error: Error?) {
        connectionCallback?(Result.failure(error ?? TccError.connectionFailedWithNoReason))
        connectionCallback = nil
    }
    
    /// Connection callback when connected.
    internal func onConnected() {
        peripheral.delegate = self
        peripheral.discoverServices(SERVICES)
    }
    
    /// Connection callback when connection failed.
    internal func onConnectionFailed(_ error: Error?) {
        connectionFailed(error)
    }
    
    /// Connection callback when connection disconnected.
    internal func onDisconnected(_ error: Error?) {
        connectionFailed(error)
    }
    
    // MARK: Services, Characteristics
    
    private var characteristics:[CBUUID:CBCharacteristic] = [:]

    /// Services を検出 -> Characteristics を検索
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            connectionFailed(error)
            self.disconnect()
            return
        }
        guard peripheral.services != nil && (SERVICES.allSatisfy{ serviceUUID in peripheral.services!.contains{ $0.uuid == serviceUUID } }) else {
            connectionFailed(TccError.requiredServiceNotFound)
            self.disconnect()
            return
        }
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(CHARACTERISTICS[service.uuid], for: service)
        }
    }
    
    /// Characteristics を検出 -> 接続完了にする
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            connectionFailed(error)
            self.disconnect()
            return
        }
        for characteristic in service.characteristics! {
            characteristics[characteristic.uuid] = characteristic
        }
        connectionSucceeded()
    }
    
    /// "Notify" result callback
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // characteristic.isNotifying ? notify subscribed : canceled.
    }
    
    /// "Read" or "Notify" callback
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let chr_id = characteristic.uuid
        // check if read or notify waiting exists
        guard (readWaiting[chr_id] != nil && readWaiting[chr_id]!.count > 0) ||
                (notifyWaiting[chr_id] != nil && notifyWaiting[chr_id]!.count > 0) else {
            return
        }
        // parse value
        let result = parseData(characteristic.value, for: chr_id)
        // read callbacks
        if readWaiting[chr_id] != nil {
            while readWaiting[chr_id]!.count > 0 {
                callbackResult(result, to: readWaiting[chr_id]!.removeFirst(), for: chr_id)
            }
        }
        // notify callbacks
        if notifyWaiting[chr_id] != nil {
            for waiting in notifyWaiting[chr_id]! {
                callbackResult(result, to: waiting, for: chr_id)
            }
        }
    }
    
    /// "Writre" callback
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let chr_id = characteristic.uuid
        if writeWaiting[chr_id] != nil && writeWaiting[chr_id]!.count > 0 {
            let result = error == nil ? Result.success(Succeeded()) : Result.failure(error!)
            while writeWaiting[chr_id]!.count > 0 {
                (writeWaiting[chr_id]!.removeFirst() as? Waiting<Succeeded>)?.callback(result)
            }
        }
    }
    
    // MARK: parse value and manage callbacks
    
    private func parseData(_ data:Data?, for chr_id:CBUUID) -> TccResponse? {
        guard data != nil else {
            return nil
        }
        switch chr_id {
        case CHR_ID:
            return IdResponse.parse(data!)
        case CHR_SENSOR:
            return SensorResponse.parse(data!)
        case CHR_BUTTON:
            return ButtonResponse.parse(data!)
        case CHR_BATTERY:
            return BatteryResponse.parse(data!)
        case CHR_MOTOR:
            return MotorResponse.parse(data!)
        case CHR_CONFIGURATION:
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

    private func callbackResult(_ result:TccResponse?, to waiting:Any, for chr_id:CBUUID) {
        switch chr_id {
        case CHR_ID:
            callbackFor(result: result, to: waiting as! Waiting<IdResponse>)
        case CHR_SENSOR:
            callbackFor(result: result, to: waiting as! Waiting<SensorResponse>)
        case CHR_BUTTON:
            callbackFor(result: result, to: waiting as! Waiting<ButtonResponse>)
        case CHR_BATTERY:
            callbackFor(result: result, to: waiting as! Waiting<BatteryResponse>)
        case CHR_MOTOR:
            callbackFor(result: result, to: waiting as! Waiting<MotorResponse>)
        case CHR_CONFIGURATION:
            callbackFor(result: result, to: waiting as! Waiting<ConfigurationResponse>)
        default:
            break
        }
    }
    
    private func callbackFor<ResultType:TccResponse>(result:TccResponse?, to waiting:Waiting<ResultType>) {
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
        readCharacteristic(CHR_ID, callback)
    }
    
    /// Start notify ID (Position ID, Standard ID) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyId(_ callback: @escaping (Result<IdResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(CHR_ID, callback)
    }
    
    /// Stop notify ID (Position ID, Standard ID) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyId(_ id: UInt) {
        stopNotifyCharacteristic(CHR_ID, id)
    }
    
    // MARK: Sensor (Write, Read, Notify) CHR_SENSOR
    
    /// Read Sensor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readSensor(_ callback: @escaping (Result<SensorResponse,Error>)->()) {
        readCharacteristic(CHR_SENSOR, callback)
    }
    
    /// Start notify Sensor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifySensor(_ callback: @escaping (Result<SensorResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(CHR_SENSOR, callback)
    }
    
    /// Stop notify Sensor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifySensor(_ id: UInt) {
        stopNotifyCharacteristic(CHR_SENSOR, id)
    }
    
    /// Request Motion Sensor Notification
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeRequestMotionSensorValues(callback:((Result<Succeeded,Error>)->())?) {
        let data = SensorRequestMotionRequest().data
        writeCharacteristic(CHR_SENSOR, data: data, callback)
    }
    
    /// Request Magnetic Sensor Notification
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeRequestMagneticSensorValues(callback:((Result<Succeeded,Error>)->())?) {
        let data = SensorRequestMagneticRequest().data
        writeCharacteristic(CHR_SENSOR, data: data, callback)
    }
    
    // MARK: Button (Read, Notify): Bool CHR_BUTTON
    
    /// Read Button values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readButton(_ callback: @escaping (Result<ButtonResponse,Error>)->()) {
        readCharacteristic(CHR_BUTTON, callback)
    }
    
    /// Start notify Button values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyButton(_ callback: @escaping (Result<ButtonResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(CHR_BUTTON, callback)
    }
    
    /// Stop notify Button values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyButton(_ id: UInt) {
        stopNotifyCharacteristic(CHR_BUTTON, id)
    }

    // MARK: Battery (Read, Notify): Int (0...100) CHR_BATTERY
    
    /// Read Battery values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readBattery(_ callback: @escaping (Result<BatteryResponse,Error>)->()) {
        readCharacteristic(CHR_BATTERY, callback)
    }
    
    /// Start notify Battery values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyBattery(_ callback: @escaping (Result<BatteryResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(CHR_BATTERY, callback)
    }
    
    /// Stop notify Battery values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyBattery(_ id: UInt) {
        stopNotifyCharacteristic(CHR_BATTERY, id)
    }

    // MARK: Motor (Write without response, Read, Notify) CHR_MOTOR
    
    /// Read Motor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readMotor(_ callback: @escaping (Result<MotorResponse,Error>)->()) {
        readCharacteristic(CHR_MOTOR, callback)
    }
    
    /// Start notify Motor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyMotor(_ callback: @escaping (Result<MotorResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(CHR_MOTOR, callback)
    }
    
    /// Stop notify Motor values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyMotor(_ id: UInt) {
        stopNotifyCharacteristic(CHR_MOTOR, id)
    }
    
    /// Activate Motors.
    ///
    /// - Parameters:
    ///   - left:       left motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - right:      right motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - callback:   callback after write succeeded.
    open func writeActivateMotor(left: Int, right: Int, callback:((Result<Succeeded,Error>)->())?) {
        let data = MotorActivateRequest(left: left, right: right).data
        writeCharacteristic(CHR_MOTOR, data: data, callback)
    }
    
    /// Activate Motors with duration.
    ///
    /// - Parameters:
    ///   - left:       left motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - right:      right motor velocity. 0 to 7: stop, 8 to 115 go forward (34 to 494 rpm), go backward with negative value.
    ///   - duration:   duration to activate motors. 0.01 to 2.55 seconds. 0 means infinite.
    ///   - callback:   callback after write succeeded.
    open func writeActivateMotor(left: Int, right: Int, duration:TimeInterval, callback:((Result<Succeeded,Error>)->())?) {
        let data = MotorActivateWithDurationRequest(left: left, right: right, duration: duration).data
        writeCharacteristic(CHR_MOTOR, data: data, callback)
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
    ///   - callback:           callback after write succeeded.
    open func writeMoveToDestination(id: Int, timeout: TimeInterval, curve: MotorDestinationCurve, maxVelocity: Int, easing: MotorDestinationEasing, destinationX: Int, destinationY: Int, finalRotation: Int, finalRotationType: MotorDestinationFinalRotation, callback:((Result<Succeeded,Error>)->())?) {
        let data = MotorMoveToDestinationRequest(id: id, timeout: timeout, curve: curve, maxVelocity: maxVelocity, easing: easing, destination: MotorDestinationUnit(destinationX: destinationX, destinationY: destinationY, finalRotation: finalRotation, finalRotationType: finalRotationType)).data
        writeCharacteristic(CHR_MOTOR, data: data, callback)
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
    open func writeMoveToMultipleDestination(id: Int, timeout: TimeInterval, curve: MotorDestinationCurve, maxVelocity: Int, easing: MotorDestinationEasing, writeMode: MotorDestinationWriteMode, destinations: [MotorDestinationUnit], callback:((Result<Succeeded,Error>)->())?) {
        let data = MotorMoveToMultipleDestinationRequest(id: id, timeout: timeout, curve: curve, maxVelocity: maxVelocity, easing: easing, writeMode: writeMode, destinations: destinations).data
        writeCharacteristic(CHR_MOTOR, data: data, callback)
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
    open func writeMoveToMultipleDestination(velocity: Int, acceralation: Int, angularVelocity: Int, priority: MotorAcceralationPriority, duration: TimeInterval, callback:((Result<Succeeded,Error>)->())?) {
        let data = MotorMoveWithAcceralationRequest(velocity: velocity, acceralation: acceralation, angularVelocity: angularVelocity, priority: priority, duration: duration).data
        writeCharacteristic(CHR_MOTOR, data: data, callback)
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
    open func writeLightOn(duration:TimeInterval, red:Double, green:Double, blue:Double, callback:((Result<Succeeded,Error>)->())?) {
        let data = LightOnRequest(unit:LightOnUnit(duration: duration, red: red, green: green, blue: blue)).data
        writeCharacteristic(CHR_LIGHT, data: data, callback)
    }
    
    /// Turn on (and off) the light in sequence.
    ///
    /// - Parameters:
    ///   - repeats:    repeat sequence as loop. 0 means infinite loop.
    ///   - sequence:   sequence of light controls.
    ///   - callback:   callback after write succeeded.
    open func writeLightSequence(repeats: Int, sequence:[LightOnUnit], callback:((Result<Succeeded,Error>)->())?) {
        let data = LightOnSequenceRequest(repeats: repeats, sequence: sequence).data
        writeCharacteristic(CHR_LIGHT, data: data, callback)
    }

    /// Turn off all light.
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeLightAllOff(callback:((Result<Succeeded,Error>)->())?) {
        writeCharacteristic(CHR_LIGHT, data: LightAllOffRequest().data, callback)
    }
    
    // MARK: Sound (Write) CHR_SOUND
    
    /// Play a sound effect.
    ///
    /// - Parameters:
    ///   - se:         select sound effect.
    ///   - volume:     0 means mute, 1 to 255 means max volume.
    ///   - callback:   callback after write succeeded.
    open func writeSoundPlay(se:SoundEffect, volume:Double, callback:((Result<Succeeded,Error>)->())?) {
        let data = SoundPlayRequest(se: se, volume: volume).data
        writeCharacteristic(CHR_SOUND, data: data, callback)
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
    open func writeSoundPlayNotes(repeats: Int, sequence:[SoundNoteUnit], callback:((Result<Succeeded,Error>)->())?) {
        let data = SoundPlayNotesRequest(repeats: repeats, sequence: sequence).data
        writeCharacteristic(CHR_SOUND, data: data, callback)
    }

    /// Stop playing sound.
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeSoundStop(callback:((Result<Succeeded,Error>)->())?) {
        writeCharacteristic(CHR_SOUND, data: SoundStopRequest().data, callback)
    }

    // MARK: Configuration (Write, Read, Notify) CHR_CONFIGURATION
    
    /// Read Configuration values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when value read.
    open func readConfiguration(_ callback: @escaping (Result<ConfigurationResponse,Error>)->()) {
        readCharacteristic(CHR_CONFIGURATION, callback)
    }
    
    /// Start notify Configuration values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - callback: callback when values notified.
    ///
    /// - Returns:    the notification id.
    open func startNotifyConfiguration(_ callback: @escaping (Result<ConfigurationResponse,Error>)->()) -> UInt {
        return startNotifyCharacteristic(CHR_CONFIGURATION, callback)
    }
    
    /// Stop notify Configuration values (Motion, Magnetic) from the Cube
    ///
    /// - Parameters:
    ///   - id:     the notification id.
    open func stopNotifyConfiguration(_ id: UInt) {
        stopNotifyCharacteristic(CHR_CONFIGURATION, id)
    }
    
    /// Configuration: request BLE Protocol Version.
    ///
    /// - Parameters:
    ///   - callback: callback after write succeeded.
    open func writeConfigurationRequestBLEProtocolVersion(callback:((Result<Succeeded,Error>)->())?) {
        writeCharacteristic(CHR_CONFIGURATION, data: ConfigurationRequestBLEProtocolVersionRequest().data, callback)
    }
    
    /// Configuration: Motion sensor's "level" threshold.
    ///
    /// - Parameters:
    ///   - value:      level threshold in degree 1 to 45.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorLevelThreshold(value: Int, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationSensorLevelThresholdRequest(value: value).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Motion sensor's collision threshold.
    ///
    /// - Parameters:
    ///   - value:      collision threshold in 1 to 10 collision level.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorCollisionThreshold(value: Int, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationSensorCollisionThresholdRequest(value: value).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Motion sensor's double tap interval limit.
    ///
    /// - Parameters:
    ///   - value:      double tap interval limit in 0 to 7 level.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorDoubleTapInterval(value: Int, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationSensorDoubleTapIntervalRequest(value: value).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: ID (Position ID, Standard ID) notification frequency.
    ///
    /// - Parameters:
    ///   - interval:   minimum notify interval in 0.00 to 2.55 seconds.
    ///   - condition:  condition to notify.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorIdFrequency(interval: TimeInterval, condition: ConfigurationSensorIdNotifyCondition, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationSensorIdFrequencyRequest(interval: interval, condition: condition).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: threshold time to determined as "ID missed".
    ///
    /// - Parameters:
    ///   - value:      threshold time to determined as "ID missed" in 0.00 to 2.55 seconds.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorIdMissedThreshold(value: TimeInterval, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationSensorIdMissedThresholdRequest(value: value).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Magnetic sensor availability.
    ///
    /// - Parameters:
    ///   - value:      availability.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationSensorMagneticAvailability(value: Bool, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationSensorMagneticAvailabilityRequest(value: value).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }

    /// Configuration: Velocity values availability.
    ///
    /// - Parameters:
    ///   - value:      availability.
    ///   - callback:   callback after write succeeded.
    open func writeConfigurationMotorVelocityAvailability(value: Bool, callback:((Result<Succeeded,Error>)->())?) {
        let data = ConfigurationMotorVelocityAvailabilityRequest(value: value).data
        writeCharacteristic(CHR_CONFIGURATION, data: data, callback)
    }
}
