//
//  LoadingOverlay.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit



public class BusyOverlay {
    
    var overlayView : UIView!
    var activityIndicator : UIActivityIndicatorView!
    
    class var shared: BusyOverlay {
        struct Static {
            static let instance: BusyOverlay = BusyOverlay()
        }
        return Static.instance
    }
    
    init() {
        
        let screenSize: CGRect = UIScreen.mainScreen().bounds
        
        self.overlayView = UIView(frame: CGRectMake(0, 0, screenSize.width, screenSize.height))
        self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        
//        overlayView.frame = CGRectMake(0, 0, 80, 80)
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        overlayView.clipsToBounds = true
//        overlayView.layer.cornerRadius = 10
        overlayView.layer.zPosition = 1
        
        activityIndicator.frame = CGRectMake(0, 0, 40, 40)
        activityIndicator.center = CGPointMake(overlayView.bounds.width / 2, overlayView.bounds.height / 2)
        activityIndicator.activityIndicatorViewStyle = .WhiteLarge

        overlayView.addSubview(activityIndicator)
    }
    
    public func showOverlay(view: UIView? = nil) {
        
        if let v = view {
            if overlayView.superview != v {
                overlayView.center = v.center
                overlayView.layer.cornerRadius = 10
                v.addSubview(overlayView)
            }
        } else {
            if let app = UIApplication.sharedApplication().delegate as? AppDelegate, let window = app.window {
                if overlayView.superview != window {
                    overlayView.center = window.center
                    overlayView.layer.cornerRadius = 0
                    
                    window.addSubview(overlayView)
                }
            } else {
                assertionFailure("You must specifiy the UIView that the activity indicator should be displayed in/over!")
            }
        }
        activityIndicator.startAnimating()
    }
    
    public func hideOverlayView() {
//        dispatch_async(dispatch_get_main_queue(), {
            self.activityIndicator.stopAnimating()
            self.overlayView.removeFromSuperview()
//        })
    }
}