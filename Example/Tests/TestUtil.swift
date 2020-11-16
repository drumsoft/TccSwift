//
//  TestUtil.swift
//  TccSwift_Tests
//
//  Created by hrk on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import TccSwift

let DEFAULT_TIMEOUT_FOR_HUMAN:TimeInterval = 20

class TestCubeProvider {
    
    private static var cube:Cube?
    
    private static let cubeManager = CubeManager()
    private static let cubeManagerDelegate = TestCubeManagerDelegate()

    private class TestCubeManagerDelegate: CubeManagerDelegate {
        var onFound:(()->())?
        func cubeManager(_ cubeManager: CubeManager, didCubeFound: Cube) {
            onFound?()
            onFound = nil
        }
    }
    
    static var isCubeReady:Bool { cube != nil }
    
    /// returns connected cube.
    static func initialize() -> Cube {
        if TestCubeProvider.cube != nil {
            return TestCubeProvider.cube!
        }
        
        var cube:Cube? = nil
        
        if cubeManager.delegate == nil {
            cubeManager.delegate = cubeManagerDelegate
        }
        
        waitUntil(timeout: DEFAULT_TIMEOUT_FOR_HUMAN) { done in
            cubeManagerDelegate.onFound = done
            cubeManager.startScan()
        }
        
        cubeManager.stopScan()
        cube = cubeManager.foundCubeEntries.first
        
        if cube == nil {
            fail("Error: no Core Cube found.")
        }
        
        waitUntil { done in
            cube!.connect {
                switch $0 {
                case .success(_):
                    done()
                case .failure(let error):
                    fail(error.localizedDescription)
                }
            }
        }
        
        TestCubeProvider.cube = cube
        return TestCubeProvider.cube!
    }
    
    /// disconnect the cube.
    static func finalize() {
        waitUntil { done in
            TestCubeProvider.cube?.disconnect { error in
                if error != nil {
                    fail(error!.localizedDescription)
                }
                done()
            }
            TestCubeProvider.cube = nil
        }
    }
}

public func succeeded<Type>() -> Predicate<Result<Type,Error>> {
    let errorMessage = "suceeded"
    return Predicate.define { (actualExpression:Expression<Result<Type,Error>>) in
        if let instance = try actualExpression.evaluate() {
            switch instance {
            case .success(_):
                return PredicateResult(
                    status: .matches,
                    message: .expectedTo("succeeded")
                )
            case .failure(let error):
                return PredicateResult(
                    status: .doesNotMatch,
                    message: .expectedCustomValueTo(errorMessage, "<Error: \(error.localizedDescription)>")
                )
            }
        } else {
            return PredicateResult(
                status: .doesNotMatch,
                message: .expectedActualValueTo(errorMessage)
            )
        }
    }
}

public func succeededWith<Type,T>(_ expectedType: T.Type) -> Predicate<Result<Type,Error>> {
    let errorMessage = "suceeded with instance of \(String(describing: expectedType))"
    return Predicate.define { (actualExpression:Expression<Result<Type,Error>>) in
        if let instance = try actualExpression.evaluate() {
            switch instance {
            case .success(let r):
                return PredicateResult(
                    status: PredicateStatus(bool: type(of: r) == expectedType),
                    message: .expectedCustomValueTo(errorMessage, ".success(\(String(describing: type(of: r))))")
                )
            case .failure(let error):
                return PredicateResult(
                    status: .doesNotMatch,
                    message: .expectedCustomValueTo(errorMessage, ".failure(\(error.localizedDescription))")
                )
            }
        } else {
            return PredicateResult(
                status: .doesNotMatch,
                message: .expectedActualValueTo(errorMessage)
            )
        }
    }
}
