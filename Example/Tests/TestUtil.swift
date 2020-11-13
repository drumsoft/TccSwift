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

class TestCubeManagerDelegate: CubeManagerDelegate {
    var onFound:(()->())?
    func cubeManager(_ cubeManager: CubeManager, didCubeFound: Cube) {
        onFound?()
        onFound = nil
    }
}

func testResult<Type>(_ result:Result<Type,Error>) {
    switch result {
    case .success(_):
        break // ok
    case .failure(let error):
        fail(error.localizedDescription)
    }
}

func testResult<Type,T>(_ result:Result<Type,Error>, as type:T.Type) {
    switch result {
    case .success(let r):
        expect(r).to(beAnInstanceOf(type))
    case .failure(let error):
        fail(error.localizedDescription)
    }
}
