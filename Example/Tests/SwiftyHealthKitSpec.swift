// https://github.com/Quick/Quick

import Quick
import Nimble
import SwiftyHealthKit
import HealthKit

class SwiftyHealthKitSpec: QuickSpec {
    
    override func spec() {
        
        let shk = SwiftyHealthKit.shared
        
        beforeSuite {
            let requireIDsForTest: [HKQuantityTypeIdentifier] = [.stepCount, .bodyMass]
            shk.setup(share: requireIDsForTest, read: [])
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
                SwiftyHealthKitSpec.delete(id: .stepCount)
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
                            done()
                        }
                    }
                    
                    waitUntil { done in
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
        
        describe("write bodyMass") {
            beforeEach {
                SwiftyHealthKitSpec.delete(id: .bodyMass)
            }
            
            context("when no data") {
                it("") {
                    waitUntil { done in
                        shk.quantity(at: Date(), id: .bodyMass, option: .discreteMax) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let quantity): expect(quantity).to(beNil())
                            }
                            done()
                        }
                    }
                }
            }
            
            context("when 1 record") {
                it("should return the quantity") {
                    let unit = HKUnit.gramUnit(with: .kilo)
                    let quantity = HKQuantity(unit: unit, doubleValue: 60)
                    
                    waitUntil { done in
                        shk.writeSample(at: Date(), id: .bodyMass, quantity: quantity) { result in
                            if case .failure(let error) = result {
                                fail("\(error)")
                            }
                            done()
                        }
                    }
                    
                    waitUntil { done in
                        shk.quantity(at: Date(), id: .bodyMass, option: .discreteMax) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let quantity):
                                expect(quantity?.doubleValue(for: unit)).to(equal(Double(60)))
                            }
                            done()
                        }
                    }
                }
            }
        }
        
        describe("overwrite bodyMass") {
            beforeEach {
                SwiftyHealthKitSpec.delete(id: .bodyMass)
            }
            
            context("when no data") {
                it("") {
                    let unit = HKUnit.gramUnit(with: .kilo)
                    let quantity = HKQuantity(unit: unit, doubleValue: 60)
                    
                    waitUntil { done in
                        shk.overwriteSample(at: Date(), id: .bodyMass, quantity: quantity) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let success): expect(success).to(beTrue())
                            }
                            done()
                        }
                    }
                    
                    waitUntil { done in
                        shk.quantity(at: Date(), id: .bodyMass, option: .discreteMax) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let quantity):
                                expect(quantity?.doubleValue(for: unit)).to(equal(Double(60)))
                            }
                            done()
                        }
                    }
                }
            }
            
            context("when overwrite 1 record") {
                it("should return the new record") {
                    let unit = HKUnit.gramUnit(with: .kilo)
                    let oldQuantity = HKQuantity(unit: unit, doubleValue: 60)
                    
                    waitUntil { done in
                        shk.writeSample(at: Date(), id: .bodyMass, quantity: oldQuantity) { result in
                            if case .failure(let error) = result {
                                fail("\(error)")
                            }
                            done()
                        }
                    }
                    
                    let newQuantity = HKQuantity(unit: unit, doubleValue: 55)
                    waitUntil { done in
                        shk.overwriteSample(at: Date(), id: .bodyMass, quantity: newQuantity) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let success): expect(success).to(beTrue())
                            }
                            done()
                        }
                    }
                    
                    waitUntil { done in
                        shk.quantity(at: Date(), id: .bodyMass, option: .discreteMax) { result in
                            switch result {
                            case .failure(let error): fail("\(error)")
                            case .success(let quantity):
                                expect(quantity?.doubleValue(for: unit)).to(equal(Double(55)))
                            }
                            done()
                        }
                    }
                }
            }           
        }
    }
}

extension SwiftyHealthKitSpec {
    
    fileprivate static func delete(id: HKQuantityTypeIdentifier) {
        waitUntil { done in
            SwiftyHealthKit.shared.deleteData(at: Date(), id: id) { result in
                if case .failure(let error) = result {
                    fail("\(error)")
                }
                done()
            }
        }       
    }
}
