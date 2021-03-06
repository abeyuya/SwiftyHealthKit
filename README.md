# SwiftyHealthKit

[![CI Status](http://img.shields.io/travis/abeyuya/SwiftyHealthKit.svg?style=flat)](https://travis-ci.org/abeyuya/SwiftyHealthKit)
[![Version](https://img.shields.io/cocoapods/v/SwiftyHealthKit.svg?style=flat)](http://cocoapods.org/pods/SwiftyHealthKit)
[![License](https://img.shields.io/cocoapods/l/SwiftyHealthKit.svg?style=flat)](http://cocoapods.org/pods/SwiftyHealthKit)
[![Platform](https://img.shields.io/cocoapods/p/SwiftyHealthKit.svg?style=flat)](http://cocoapods.org/pods/SwiftyHealthKit)

SwiftyHealthKit is a thin wrapper for iOS HealthKit for iOS8.0+, Swift3.0+.

In most cases, I think that dealing with the data of HealthKit by day.
So SwiftyHealthKit dealing with the data by day.

## Example

```swift
SwiftyHealthKit.stepCount(at: Date()) { result in
    switch result {
    case .failure(let error): print("\(error)")
    case .success(let step): print("Steps of today: \(step)")
    }
}
```

### Read

```swift
SwiftyHealthKit.quantity(at: Date(), id: .bodyMass, option: .discreteMax) { result in
    switch result {
    case .failure(let error): print("\(error)")
    case .success(let quantity):
        guard let quantity = quantity else {
            // No bodymass data for today
            return
        }
        
        let kilogram = quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
        print("Max bodymass of today: \(kilogram)kg")
        
        let pound = quantity.doubleValue(for: HKUnit.pound())
        print("Max bodymass of today: \(pound)lb")
    }
}
```

### Write

```swift
let unit = HKUnit.gramUnit(with: .kilo)
let quantity = HKQuantity(unit: unit, doubleValue: 60)

SwiftyHealthKit.writeSample(at: Date(), id: .bodyMass, quantity: quantity) { result in
    if case .failure(let error) = result {
        print("Error: \(error)")
        return
    }

    print("Write success!")
}
```


## Requirements

- Swift3.0+
- Xcode8.0+
- iOS8.0+

## Installation

### CocoaPods

```ruby
pod 'SwiftyHealthKit', git: 'https://github.com/abeyuya/SwiftyHealthKit'
```

### Carthage

TODO

## Author

abeyuya, yuya.abe.0525@gmail.com

## License

SwiftyHealthKit is available under the MIT license. See the LICENSE file for more info.

