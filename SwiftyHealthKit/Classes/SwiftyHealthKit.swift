//
//  SwiftyHealthKit.swift
//  Pods
//
//  Created by 阿部祐也 on 2016/10/07.
//
//

import HealthKit

fileprivate extension HKQuantityTypeIdentifier {
    var type: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: self)!
    }
}

public enum Result<T> {
    case success(T)
    case failure(SHKError)
}

public typealias Callback<T> = (Result<T>) -> Void

public enum SHKError: Error {
    
    case hkError(HKError)
    case error(Error)
    
    var localizedDescription: String {
        switch self {
        case .hkError(let error): return error.localizedDescription
        case .error(let error): return error.localizedDescription
        }
    }
    
    var code: HKError.Code {
        switch self {
        case .hkError(let error): return error.code
        case .error(let error): return HKError.Code.noError
        }
    }
    
    static func from(_ error: Error) -> SHKError {
        if let hkError = error as? HKError {
            return SHKError.hkError(hkError)
        } else {
            return SHKError.error(error)
        }
    }
}

public class SwiftyHealthKit {
    
    //
    // Singleton
    // http://stackoverflow.com/questions/35591466/create-singleton-instance-via-extension-per-app
    //
    open static let shared = SwiftyHealthKit()
    private init() {}
    fileprivate let store = HKHealthStore()
    
    fileprivate var shareIdentifiers: [HKQuantityTypeIdentifier] = []
    fileprivate var readIdentifiers: [HKQuantityTypeIdentifier] = []
}

extension SwiftyHealthKit {
    
    public func setup(share: [HKQuantityTypeIdentifier], read: [HKQuantityTypeIdentifier]) {
        shareIdentifiers = share
        readIdentifiers = read
    }
    
    public func requestHealthKitPermission(completion: @escaping Callback<Bool>) {
        store.requestAuthorization(
            toShare: types(identifiers: shareIdentifiers),
            read: types(identifiers: readIdentifiers)) { success, error in
                if let error = error {
                    completion(Result.failure(SHKError.from(error)))
                    return
                }
                completion(Result.success(success))
        }
    }
    
    private func types(identifiers: [HKQuantityTypeIdentifier]) -> Set<HKQuantityType> {
        var set = Set<HKQuantityType>()
        for id in identifiers {
            set.insert(id.type)
        }
        return set
    }
    
    public var shouldRequestAuthorization: Bool {
        let statuses = (shareIdentifiers + readIdentifiers).map { store.authorizationStatus(for: $0.type) }
        return statuses.filter { $0 == .notDetermined }.count > 0
    }
}

extension SwiftyHealthKit {
    
    public func stepCount(at date: Date, completion: @escaping Callback<Int?>) {
        statisticsCollections(at: date, id: .stepCount, option: .cumulativeSum) { result in
            switch result {
            case .failure(let error): completion(Result.failure(error))
            case .success(let collections):
                guard let results = collections else {
                    completion(Result.success(nil))
                    return
                }
                
                results.enumerateStatistics(from: date, to: date) { results, _ in
                    guard let stepDouble = results.sumQuantity()?.doubleValue(for: HKUnit.count()) else {
                        completion(Result.success(nil))
                        return
                    }
                    
                    completion(Result.success(Int(stepDouble)))
                }
            }
        }
    }
}

extension SwiftyHealthKit {
    
    public func samples(at date: Date, id: HKQuantityTypeIdentifier, completion: @escaping Callback<[HKSample]?>) {
        let query = HKSampleQuery(
            sampleType: id.type,
            predicate: predicateForOneDay(date: date),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil,
            resultsHandler: { _, results, error in
                if let error = error {
                    completion(Result.failure(SHKError.from(error)))
                    return
                }
                
                completion(Result.success(results))
            }
        )
        store.execute(query)
    }
    
    public func statisticsCollections(at date: Date, id: HKQuantityTypeIdentifier, option: HKStatisticsOptions, completion: @escaping Callback<HKStatisticsCollection?>) {
        let cal = Calendar(identifier: .gregorian)
        var comp1 = (cal as NSCalendar).components([.day, .month, .year], from: date)
        comp1.hour = 0
        let anchorDate = cal.date(from: comp1)!
        
        var comp2 = DateComponents()
        comp2.day = 1
        
        let query = HKStatisticsCollectionQuery(
            quantityType: id.type,
            quantitySamplePredicate: nil,
            options: option,
            anchorDate: anchorDate,
            intervalComponents: comp2)
        
        query.initialResultsHandler = { _, results, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            
            completion(Result.success(results))
        }
        store.execute(query)
    }
    
    public func writeSample(at time: Date, id: HKQuantityTypeIdentifier, quantity: HKQuantity, metadata: [String: String]? = nil, completion: @escaping Callback<Bool>) {
        let sample = HKQuantitySample(
            type: id.type,
            quantity: quantity,
            start: time,
            end: time,
            metadata: metadata)
        
        store.save(sample) { success, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(success))
        }
    }
    
    public func deleteData(at date: Date, id: HKQuantityTypeIdentifier, completion: @escaping Callback<Bool>) {
        
        let resultsHandler = { (_: HKSampleQuery, samples: [HKSample]?, error: Error?) in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            guard let items = (samples?.filter { date.isInSameDay(at: $0.startDate) }), items.count > 0 else {
                // Nothing to delete
                completion(Result.success(true))
                return
            }
            
            if #available(iOS 9.0, *) {
                self.store.delete(items) { success, error in
                    if let error = error {
                        completion(Result.failure(SHKError.from(error)))
                        return
                    }
                    completion(Result.success(success))
                }
            } else {
                // TODO: iOS8 support
            }
        }
        
        let query = HKSampleQuery(
            sampleType: id.type,
            predicate: predicateForOneDay(date: date),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil,
            resultsHandler: resultsHandler)
        store.execute(query)
    }
    
    public func delete(item: HKSample, completion: @escaping Callback<Bool>) {
        store.delete(item) { _, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(true))
        }
    }
    
    fileprivate func predicateForOneDay(date: Date) -> NSPredicate {
        return HKQuery.predicateForSamples(
            withStart: date.startOfDay,
            end: date.endOfDay,
            options: .strictStartDate
        )
    }
}

fileprivate extension Date {
    var startOfDay: Date {
        return Calendar(identifier: .gregorian).startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfDay)!
    }
    
    func isInSameDay(at date: Date) -> Bool {
        return Calendar(identifier: .gregorian).isDate(self, inSameDayAs: date)
    }
}
