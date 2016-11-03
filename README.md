# SwiftyHealthKit

[![CI Status](http://img.shields.io/travis/abeyuya/SwiftyHealthKit.svg?style=flat)](https://travis-ci.org/abeyuya/SwiftyHealthKit)
[![Version](https://img.shields.io/cocoapods/v/SwiftyHealthKit.svg?style=flat)](http://cocoapods.org/pods/SwiftyHealthKit)
[![License](https://img.shields.io/cocoapods/l/SwiftyHealthKit.svg?style=flat)](http://cocoapods.org/pods/SwiftyHealthKit)
[![Platform](https://img.shields.io/cocoapods/p/SwiftyHealthKit.svg?style=flat)](http://cocoapods.org/pods/SwiftyHealthKit)

## Example

```swift
SwiftyHealthKit.shared.stepCount(at: Date()) { result in
    switch result {
    case .failure(let error): print("\(error)")
    case .success(let step): print("Steps of today: \(step)")
    }
}
```

```swift
SwiftyHealthKit.shared.quantity(at: Date(), id: .bodyMass, option: .discreteMax) { result in
    switch result {
    case .failure(let error): print("\(error)")
    case .success(let quantity):
        guard let quantity = quantity else {
            // No bodymass data for today
            return
        }
        
        let kilogram = quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
        print("Max bodymass of today: \(kilogram)kg")
        
        let pound = quantity.doubleValue(for: HKUnit.pounds())
        print("Max bodymass of today: \(pound)lb")
    }
}
```


## Requirements

- Xcode8+
- Swift3+
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
