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
    
    public var localizedDescription: String {
        switch self {
        case .hkError(let error): return error.localizedDescription
        case .error(let error): return error.localizedDescription
        }
    }
    
    public var code: HKError.Code {
        switch self {
        case .hkError(let error): return error.code
        case .error(let error): return HKError.Code.noError
        }
    }
    
    public static func from(_ error: Error) -> SHKError {
        if let hkError = error as? HKError {
            return SHKError.hkError(hkError)
        } else {
            return SHKError.error(error)
        }
    }
}

public enum SHKStatisticsOptions {
    case discreteAverage
    case discreteMax
    case discreteMin
    case cumulativeSum
//    case separateBySource
    
    var origin: HKStatisticsOptions {
        switch self {
        case .discreteAverage: return HKStatisticsOptions.discreteAverage
        case .discreteMax: return HKStatisticsOptions.discreteMax
        case .discreteMin: return HKStatisticsOptions.discreteMin
        case .cumulativeSum: return HKStatisticsOptions.cumulativeSum
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
    public let store = HKHealthStore()
    
    fileprivate var shareIdentifiers: [HKQuantityTypeIdentifier] = []
    fileprivate var readIdentifiers: [HKQuantityTypeIdentifier] = []
}

extension SwiftyHealthKit {
    
    public func setup(share: [HKQuantityTypeIdentifier], read: [HKQuantityTypeIdentifier]) {
        shareIdentifiers = share
        readIdentifiers = read
    }
    
    public func requestHealthKitPermission(completion: @escaping Callback<Bool>) {
        guard (shareIdentifiers + readIdentifiers).count > 0 else {
            debugCrash(message: "You should set shareIdentifiers or readIdentifiers --- Must request authorization for at least one data type")
            return
        }
        
        store.requestAuthorization(
            toShare: types(identifiers: shareIdentifiers),
            read: types(identifiers: readIdentifiers)
        ) { success, error in
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
        quantity(at: date, id: .stepCount, option: .cumulativeSum) { result in
            switch result {
            case .failure(let error): completion(Result.failure(error))
            case .success(let quantity):
                guard let quantity = quantity else {
                    completion(Result.success(nil))
                    return
                }
                
                let stepCount = quantity.doubleValue(for: HKUnit.count())
                completion(Result.success(Int(stepCount)))
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
            resultsHandler: { _, samples, error in
                if let error = error {
                    completion(Result.failure(SHKError.from(error)))
                    return
                }
                completion(Result.success(samples))
            }
        )
        store.execute(query)
    }
    
    public func quantity(at date: Date, id: HKQuantityTypeIdentifier, option: SHKStatisticsOptions, completion: @escaping Callback<HKQuantity?>) {
        statistics(at: date, id: id, option: option.origin) { result in
            switch result {
            case .failure(let error): completion(Result.failure(error))
            case .success(let statistics):
                guard let statistics = statistics else {
                    completion(Result.success(nil))
                    return
                }
                
                let quantity: HKQuantity? = {
                    switch option {
                    case .discreteAverage: return statistics.averageQuantity()
                    case .discreteMax: return statistics.maximumQuantity()
                    case .discreteMin: return statistics.minimumQuantity()
                    case .cumulativeSum: return statistics.sumQuantity()
                    }
                }()
                
                completion(Result.success(quantity))
            }
        }
    }
    
    private func statistics(at date: Date, id: HKQuantityTypeIdentifier, option: HKStatisticsOptions, completion: @escaping Callback<HKStatistics?>) {
        
        statisticsCollection(at: date, id: id, option: option) { result in
            switch result {
            case .failure(let error): completion(Result.failure(error))
            case .success(let collection):
                
                guard let collection = collection else {
                    completion(Result.success(nil))
                    return
                }
                
                guard collection.statistics().count > 0 else {
                    completion(Result.success(nil))
                    return
                }
                
                collection.enumerateStatistics(from: date, to: date) { statistics, _ in
                    completion(Result.success(statistics))
                }
            }
        }
    }
    
    private func statisticsCollection(at date: Date, id: HKQuantityTypeIdentifier, option: HKStatisticsOptions, completion: @escaping Callback<HKStatisticsCollection?>) {
        let cal = Calendar(identifier: .gregorian)
        var comp1 = cal.dateComponents([.day, .month, .year], from: date)
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
        
        query.initialResultsHandler = { _, collection, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(collection))
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
            
            self.delete(samples: items, completion: completion)
        }
        
        let query = HKSampleQuery(
            sampleType: id.type,
            predicate: predicateForOneDay(date: date),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil,
            resultsHandler: resultsHandler)
        store.execute(query)
    }
    
    public func delete(samples: [HKSample], completion: @escaping Callback<Bool>) {
        guard #available(iOS 9.0, *) else {
            // NOTE: iOS8 support
            let group = DispatchGroup()
            var errors: [Error] = []
            
            for sample in samples {
                let queue = DispatchQueue(label: "SwiftyHealthKit.parallelDelete")
                queue.async(group: group) {
                    self.store.delete(sample) { success, error in
                        if let error = error {
                            errors.append(error)
                        }
                    }
                }
            }
            
            group.notify(queue: DispatchQueue.main) {
                if let error = errors.first {
                    completion(Result.failure(SHKError.from(error)))
                    return
                }
                completion(Result.success(true))
            }
            return
        }
        
        self.store.delete(samples) { success, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(success))
        }
    }
    
    public func overwriteSample(at date: Date, id: HKQuantityTypeIdentifier, quantity: HKQuantity, metadata: [String: String]? = nil, completion: @escaping Callback<Bool>) {
        
        deleteData(at: date, id: id) { result in
            switch result {
            case .failure(let error): completion(Result.failure(error))
            case .success(_):
                self.writeSample(at: date, id: id, quantity: quantity, metadata: metadata) { result in
                    switch result {
                    case .failure(let error): completion(Result.failure(error))
                    case .success(let success): completion(Result.success(success))
                    }
                }
            }
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

fileprivate extension SwiftyHealthKit {
    fileprivate func debugCrash(message: String) {
        assertionFailure([
            "",
            "------------",
            "SwiftyHealthKit: " + message,
            "------------",
            ""
            ].joined(separator: "\n"))
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
