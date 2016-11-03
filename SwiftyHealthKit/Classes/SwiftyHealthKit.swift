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
    private init() {}
    fileprivate static let shared = SwiftyHealthKit()
    public let store = HKHealthStore()
    
    fileprivate var writeIdentifiers: [HKQuantityTypeIdentifier] = []
    fileprivate var readIdentifiers: [HKQuantityTypeIdentifier] = []
}

extension SwiftyHealthKit {
    
    public static func setup(share: [HKQuantityTypeIdentifier], read: [HKQuantityTypeIdentifier]) {
        shared.writeIdentifiers = share
        shared.readIdentifiers = read
    }
    
    public static func requestHealthKitPermission(completion: @escaping Callback<Bool>) {
        guard (shared.writeIdentifiers + shared.readIdentifiers).count > 0 else {
            debugCrash(message: "You should set shareIdentifiers or readIdentifiers --- Must request authorization for at least one data type")
            return
        }
        
        shared.store.requestAuthorization(
            toShare: types(identifiers: shared.writeIdentifiers),
            read: types(identifiers: shared.readIdentifiers)
        ) { success, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(success))
        }
    }
    
    private static func types(identifiers: [HKQuantityTypeIdentifier]) -> Set<HKQuantityType> {
        var set = Set<HKQuantityType>()
        for id in identifiers { set.insert(id.type) }
        return set
    }
    
    public static var shouldRequestAuthorization: Bool {
        let statuses = (shared.writeIdentifiers + shared.readIdentifiers).map { shared.store.authorizationStatus(for: $0.type) }
        return statuses.filter { $0 == .notDetermined }.count > 0
    }
}

extension SwiftyHealthKit {
    
    public static func stepCount(at date: Date, completion: @escaping Callback<Int?>) {
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
    
    public static func samples(at date: Date, id: HKQuantityTypeIdentifier, completion: @escaping Callback<[HKSample]?>) {
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
        shared.store.execute(query)
    }
    
    public static func quantity(at date: Date, id: HKQuantityTypeIdentifier, option: SHKStatisticsOptions, completion: @escaping Callback<HKQuantity?>) {
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
    
    private static func statistics(at date: Date, id: HKQuantityTypeIdentifier, option: HKStatisticsOptions, completion: @escaping Callback<HKStatistics?>) {
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
    
    private static func statisticsCollection(at date: Date, id: HKQuantityTypeIdentifier, option: HKStatisticsOptions, completion: @escaping Callback<HKStatisticsCollection?>) {
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
        
        shared.store.execute(query)
    }
    
    public static func writeSample(at time: Date, id: HKQuantityTypeIdentifier, quantity: HKQuantity, metadata: [String: String]? = nil, completion: @escaping Callback<Bool>) {
        let sample = HKQuantitySample(
            type: id.type,
            quantity: quantity,
            start: time,
            end: time,
            metadata: metadata)
        
        shared.store.save(sample) { success, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(success))
        }
    }
    
    public static func deleteData(at date: Date, id: HKQuantityTypeIdentifier, completion: @escaping Callback<Bool>) {
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
                guard let items = (samples?.filter { date.isInSameDay(at: $0.startDate) }), items.count > 0 else {
                    // Nothing to delete
                    completion(Result.success(true))
                    return
                }
                
                delete(samples: items, completion: completion)
            }
        )
        shared.store.execute(query)
    }
    
    public static func delete(samples: [HKSample], completion: @escaping Callback<Bool>) {
        guard #available(iOS 9.0, *) else {
            // NOTE: iOS8 support
            let group = DispatchGroup()
            var errors: [Error] = []
            
            for sample in samples {
                let queue = DispatchQueue(label: "SwiftyHealthKit.parallelDelete")
                queue.async(group: group) {
                    shared.store.delete(sample) { success, error in
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
        
        shared.store.delete(samples) { success, error in
            if let error = error {
                completion(Result.failure(SHKError.from(error)))
                return
            }
            completion(Result.success(success))
        }
    }
    
    public static func overwriteSample(at date: Date, id: HKQuantityTypeIdentifier, quantity: HKQuantity, metadata: [String: String]? = nil, completion: @escaping Callback<Bool>) {
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
    
    fileprivate static func predicateForOneDay(date: Date) -> NSPredicate {
        return HKQuery.predicateForSamples(
            withStart: date.startOfDay,
            end: date.endOfDay,
            options: .strictStartDate)
    }
}

fileprivate extension SwiftyHealthKit {
    static func debugCrash(message: String) {
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
