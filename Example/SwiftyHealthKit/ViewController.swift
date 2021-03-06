//
//  ViewController.swift
//  SwiftyHealthKit
//
//  Created by abeyuya on 10/03/2016.
//  Copyright (c) 2016 abeyuya. All rights reserved.
//

import UIKit
import SwiftyHealthKit
import HealthKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func tapAuthButton(_ sender: AnyObject) {
        let requireIDsForTest: [HKQuantityTypeIdentifier] = [.stepCount, .bodyMass]
        
        SwiftyHealthKit.setup(share: requireIDsForTest, read: [])
        if SwiftyHealthKit.shouldRequestAuthorization {
            SwiftyHealthKit.requestHealthKitPermission() { result in
                switch result {
                case .failure(let error): print("\(error)")
                case .success(let success): print(success)
                }
            }
        } else {
            print("No need to show Authorization.")
        }
    }
}

