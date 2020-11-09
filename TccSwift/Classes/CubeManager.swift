//
//  CubeManager.swift
//  TccSwift
//
//  Created by hrk on 2020/10/29.
//

import Foundation
import CoreBluetooth

/// Delegate to receive cube scan results.
public protocol CubeManagerDelegate {
    func cubeManager(_ cubeManager: CubeManager, didCubeFound: Cube)
}

/// the Core Cube Manager
open class CubeManager {
    /// Delegate to receive cube scan results.
    public var delegate: CubeManagerDelegate?
    
    private var centralManagerDelegate:CentralManagerDelegate!
    private var centralManager:CBCentralManager!
    
    /// Current found Cube Entries
    private var _foundCubeEntries:[Cube] = []
    /// Cureent found Cube entries
    open var foundCubeEntries:[Cube] { _foundCubeEntries }

    /// Current connecting Cube Entries
    private var _connectingCubeEntries:[UUID:Cube] = [:]

    /// the Core Cube Manager
    public init() {
        centralManagerDelegate = CentralManagerDelegate(self)
        centralManager = CBCentralManager(delegate: centralManagerDelegate, queue: nil, options: [:])
    }
    
    // MARK: Start/Stop scan
    
    private var isScanRequested = false

    /// Start Scan
    open func startScan() {
        isScanRequested = true
        updateScanState()
    }
    
    /// Stop Scan
    open func stopScan() {
        isScanRequested = false
        updateScanState()
    }
    
    /// start/stop scan
    private func updateScanState() {
        if centralManager.state == .poweredOn && isScanRequested {
            if !centralManager.isScanning {
                _foundCubeEntries.removeAll()
                centralManager.scanForPeripherals(withServices: [Cube.SERVICE_Cube])
            }
        } else {
            if centralManager.isScanning {
                centralManager.stopScan()
            }
        }
    }
    
    // MARK: Interface for Cube
    
    /// connect request from cube
    internal func connectFromCube(_ cube: Cube) {
        _connectingCubeEntries[cube.peripheral.identifier] = cube
        centralManager?.connect(cube.peripheral)
    }
    
    /// disconnect request from cube
    internal func disconnectFromCube(_ cube: Cube) {
        centralManager?.cancelPeripheralConnection(cube.peripheral)
        _connectingCubeEntries.removeValue(forKey: cube.peripheral.identifier)
    }
    
    // MARK: Work with peripheral connection events.
    
    private func peripheralFound(_ peripheral:CBPeripheral) {
        guard (_foundCubeEntries.first { $0.peripheral.identifier == peripheral.identifier } == nil) else { return }
        let newCube = Cube(peripheral:peripheral, manager:self)
        _foundCubeEntries.append(newCube)
        delegate?.cubeManager(self, didCubeFound: newCube)
    }
    
    private func peripheralConnected(_ peripheral:CBPeripheral) {
        if let cube = _connectingCubeEntries[peripheral.identifier] {
            cube.onConnected()
        }
    }
    
    private func peripheralFailToConnect(_ peripheral:CBPeripheral, error: Error?) {
        if let cube = _connectingCubeEntries[peripheral.identifier] {
            cube.onConnectionFailed(error ?? TccError.connectionFailedWithNoReason)
            _connectingCubeEntries.removeValue(forKey: peripheral.identifier)
        }
    }
    
    private func peripheralDisconnected(_ peripheral:CBPeripheral, error: Error?) {
        if let cube = _connectingCubeEntries[peripheral.identifier] {
            cube.onDisconnected(error)
            _connectingCubeEntries.removeValue(forKey: peripheral.identifier)
        }
    }

    /// CBCentralManagerDelegate
    private class CentralManagerDelegate: NSObject, CBCentralManagerDelegate {
        private var manager:CubeManager
        
        required init(_ forManager:CubeManager) {
            manager = forManager
        }

        // CBCentralManagerDelegate state changed
        public func centralManagerDidUpdateState(_ central: CBCentralManager) {
            manager.updateScanState()
        }
        
        // CBCentralManagerDelegate peripheral discovered
        public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
            manager.peripheralFound(peripheral)
        }
        
        // CBCentralManagerDelegate peripheral connected
        public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            manager.peripheralConnected(peripheral)
        }
        
        // CBCentralManagerDelegate peripheral connection failed
        public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            manager.peripheralFailToConnect(peripheral, error:error)
        }
        
        // CBCentralManagerDelegate peripheral connection disconnected
        public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            manager.peripheralDisconnected(peripheral, error:error)
        }
    }
}
