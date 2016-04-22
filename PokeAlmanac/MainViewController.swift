//
//  ViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/16.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import UIKit
import ReachabilitySwift


class MainViewController: UITabBarController {
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        log("MainViewController")
        
        // NOTE(dkg): before starting any downloads check reachability and inform user
        //            if we are not on WiFi or 3/4G!

        let reachability: Reachability
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
            let current: Reachability.NetworkStatus = reachability.currentReachabilityStatus
            log("current \(current) reachability")
            
            if current == Reachability.NetworkStatus.NotReachable {
                showErrorAlert(self, message: "Please make sure you have an online connection either through WiFi or 3G/4G.", title: "No connectivity!")
            }
        } catch {
            logWarn("Unable to create Reachability: \(error)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // TODO(dkg): handle this case!
        log("Memory Warning!")
    }

}

