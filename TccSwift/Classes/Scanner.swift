//
//  Scanner.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation
import CoreBluetooth

open class Scanner: NSObject, CBCentralManagerDelegate {
    internal static let DEFAULT_TIMEOUT_SECONDS: TimeInterval = 0 // no timeout
    
    private let timeoutSeconds: TimeInterval
    
    private var timeoutTimer: Timer?
    
    private var centralManager:CBCentralManager? = nil
    
    private var scanCallback:((Result<[Cube],Error>)->())?

    /**
     * Constructor of Scanner class
     *
     * @param timeoutSeconds - timeout duration in millisecond. 0 means no timeout.
     */
    init(timeoutSeconds:TimeInterval = Scanner.DEFAULT_TIMEOUT_SECONDS) {
        self.timeoutSeconds = timeoutSeconds
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: [:])
    }
    
    /**
     * Start scanning
     * @param callback - result
     */
    public func start(_ callback: @escaping (Result<[Cube],Error>)->()) {
        scanCallback = callback
        if (self.timeoutSeconds > 0) {
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { t in
                self.failure(TccError.scanTimeouted)
            }
        }
    }
    
    /**
     * Stop scanning
     */
    public func stop() {
        timeoutTimer?.invalidate()
        if centralManager != nil && centralManager!.isScanning {
            centralManager!.stopScan()
        }
    }
    
    /// callback with value
    internal func success(_ result:[Cube]) {
        guard let cb = self.scanCallback else { return }
        self.scanCallback = nil
        stop()
        cb(Result.success(result))
    }
    
    /// callback with error
    internal func failure(_ error:Error) {
        guard let cb = self.scanCallback else { return }
        self.scanCallback = nil
        stop()
        cb(Result.failure(error))
    }
    
    /// make Cube from CBPeripheral
    internal func cubeFromPeripheral(_ peripheral:CBPeripheral) -> Cube {
        return Cube(peripheral, self)
    }
    
    // MARK: Interface for Cube
    
    private var connectingStaff:[UUID:(cube:Cube,timer:Timer)] = [:]
    private var timerForUUID:[UUID:Timer] = [:]

    public func connectForCube(_ cube: Cube) {
        connectingStaff[cube.peripheral.identifier] = (
            cube:cube,
            timer:Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                self.centralManager?.cancelPeripheralConnection(cube.peripheral)
                self.connectingStaff.removeValue(forKey: cube.peripheral.identifier)
                cube.onConnectionFailed(TccError.connectionTimeouted)
            }
        )
        centralManager?.connect(cube.peripheral)
    }
    
    public func disconnectForCube(_ cube: Cube) {
        centralManager?.cancelPeripheralConnection(cube.peripheral)
        connectingStaff[cube.peripheral.identifier]?.timer.invalidate()
        connectingStaff.removeValue(forKey: cube.peripheral.identifier)
    }

    // MARK: CBCentralManagerDelegate
    
    // CBCentralManagerDelegate state changed
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if !central.isScanning {
                central.scanForPeripherals(withServices: [SERVICE_Cube])
            }
        } else {
            if central.isScanning {
                central.stopScan()
            }
        }
    }
    
    // CBCentralManagerDelegate peripheral discovered
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    }
    
    // CBCentralManagerDelegate peripheral connected
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let (cube, timer) = connectingStaff[peripheral.identifier] {
            timer.invalidate()
            cube.onConnected()
        }
    }
    
    // CBCentralManagerDelegate peripheral connection failed
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let (cube, timer) = connectingStaff[peripheral.identifier] {
            timer.invalidate()
            cube.onConnectionFailed(error)
        }
        connectingStaff.removeValue(forKey: peripheral.identifier)
    }
    
    // CBCentralManagerDelegate peripheral connection disconnected
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let (cube, timer) = connectingStaff[peripheral.identifier] {
            timer.invalidate()
            cube.onDisconnected(error)
        }
        connectingStaff.removeValue(forKey: peripheral.identifier)
    }
}
