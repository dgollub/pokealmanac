//
//  Utils.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit


private var logDateFormatter: NSDateFormatter? = nil

func log(message: String, function: String = #function, file: String = #file, line: Int = #line, isWarning: Bool = false) {
    if logDateFormatter == nil {
        logDateFormatter = NSDateFormatter()
        logDateFormatter!.dateFormat = "yyyyMMdd HH:mm:ss:SSS"
    }
    let className = (file as NSString).lastPathComponent.componentsSeparatedByString(".")
    let now = logDateFormatter!.stringFromDate(NSDate())
    let prefix = isWarning ? "[WARNING] " : ""
    print("\(prefix)\(now) | \(className[0]):\(function):\(line) | \(message)")
}

func logWarn(message: String, function: String = #function, file: String = #file, line: Int = #line){
    log(message, function: function, file: file, line: line, isWarning: true)
}
// TODO(dkg): add logError as well


func versionNumber() -> String {
    // let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
    // let build = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as! String
    if let version = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String {
        return version
    }
    return "unknown"
}

func showErrorAlert(parentVC: UIViewController, message: String, title: String = "Error", completion: (() -> Void)? = nil) {
    let vc = UIAlertController(title: title, message: message, preferredStyle: .Alert)
//    UIAlertAction(title: "Ok", style: UIAlertActionStyle.Cancel, handler: nil));
    vc.addAction(UIAlertAction(title: "Ok", style: .Cancel) { (action) in
        completion?()
    })
    parentVC.presentViewController(vc, animated: true, completion: nil)
}

func randomInt(range: Range<Int> = 1...6) -> Int {
    let min = range.startIndex
    let max = range.endIndex
    return Int(arc4random_uniform(UInt32(max - min))) + min
    
}

func mainScreenScale() -> CGFloat {
    let scale = UIScreen.mainScreen().scale
    return scale
}


public enum RobotoFontType: String {
    case Regular = "Regular"
    case Thin = "Thin"
    case Medium = "Medium"
    case Light = "Light"
    case Bold = "Bold"
}
func fontRobotoRegular(size: CGFloat) -> UIFont {
    return fontRobotoFont(.Regular, size: size)
}
func fontRobotoFont(type: RobotoFontType, size: CGFloat) -> UIFont {
    return UIFont(name: "Roboto-\(type.rawValue)", size: size)!
}

//Noto Emoji
//    == NotoEmoji
func fontNotoEmoji(size: CGFloat) -> UIFont {
    return UIFont(name: "NotoEmoji", size: size)!
}

func isOrientationIsLandscape() -> Bool {
    return UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication().statusBarOrientation)
}

func applicationDocumentsFolder() -> String {
    let path: String = NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)[0]

    createFolderIfNotExists(path)

    return path
}

func addSkipBackupAttributeToItemAtURL(URL: NSURL) -> Bool {

    if !NSFileManager.defaultManager().fileExistsAtPath(URL.path!) {
        return false
    }
    
    do {
        try URL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
    } catch _ {
        log("Failed to set resource skipbackup attribute for \(URL)")
        return false
    }

    return true
}

func createFolderIfNotExists(folderName: String) -> Bool {
    var isDir : ObjCBool = false
    
    if !NSFileManager.defaultManager().fileExistsAtPath(folderName, isDirectory:&isDir) {
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(folderName, withIntermediateDirectories:true, attributes: nil)
        } catch _ {
            log("Could not create folder \(folderName)")
            return false
        }
    }
    return true
}

func fileExists(fileName: String) -> Bool {
    return NSFileManager.defaultManager().fileExistsAtPath(fileName)
}

func fileContentsAsNSData(fileName: String) -> NSData {
    let file = NSURL(fileURLWithPath: (fileName as NSString).stringByDeletingPathExtension).lastPathComponent
    let ext = NSURL(fileURLWithPath: fileName).pathExtension
    let path = NSBundle.mainBundle().pathForResource(file, ofType: ext)
    let data = NSData(contentsOfFile: path!)
    return data!
}

func fileContentsAsString(fileName: String) -> String {
    let data: NSData = fileContentsAsNSData(fileName)
    return NSString(data: data, encoding: NSUTF8StringEncoding) as! String
}

// TODO(dkg): maybe put extensions into a new file?

extension String {
    public func substring(from:Int = 0, to:Int = -1) -> String {
        var too = to
        if too < 0 {
            too = (self as NSString).length + too
        }

        let start = self.startIndex
        let end = self.startIndex.advancedBy(too)

        return self[start..<end]
    }

    var nsValue: NSString {
        return self
    }
}


extension UINavigationController {
    // The default pushViewController method does not offer a completion handler, which we need for certain
    // actions!
    // from http://stackoverflow.com/a/25230169/193165
    func pushViewController(viewController: UIViewController,
                            animated: Bool, completion: Void -> Void) {
        
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        pushViewController(viewController, animated: animated)
        CATransaction.commit()
    }
    
}
