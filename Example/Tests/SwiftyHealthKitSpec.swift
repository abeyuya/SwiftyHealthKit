// https://github.com/Quick/Quick

import Quick
import Nimble
import SwiftyHealthKit
import HealthKit

class SwiftyHealthKitSpec: QuickSpec {
    override func spec() {
        
        let shk = SwiftyHealthKit.shared
        
        beforeSuite {
            shk.setup(share: [.stepCount], read: [])
            guard shk.shouldRequestAuthorization == false else {
                fail("Need to authorize HealthKit permission before run test.")
                return
            }
        }
        
        describe("shouldRequestAuthorization") {
            beforeEach {
                shk.setup(share: [], read: [])
            }
            
            context("empty identifiers") {
                it("should be false") {
                    expect(shk.shouldRequestAuthorization).to(beFalse())
                }
            }
        }
        
        describe("stepCount") {
            beforeEach {
                waitUntil { done in
                    shk.deleteData(at: Date(), id: .stepCount) { result in
                        if case .failure(let error) = result {
                            fail("\(error)")
                        }
                        done()
                    }
                }
            }
            
            context("when no data") {
                it("should be nil") {
                    waitUntil { done in
                        shk.stepCount(at: Date()) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let step): expect(step).to(beNil())
                            }
                            done()
                        }
                    }
                }
            }
            
            context("when 10 steps") {
                it("should return 10") {
                    let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: 10)
                    
                    waitUntil { done in
                        shk.writeSample(at: Date(), id: .stepCount, quantity: quantity) { result in
                            if case .failure(let error) = result {
                                fail("\(error)")
                            }
                            
                            shk.stepCount(at: Date()) { result in
                                switch result {
                                case .failure(let error): fail("\(error)")
                                case .success(let step): expect(step).to(equal(Int(10)))
                                }
                                done()
                            }
                        }
                    }
                }
            }
        }
    }
}
