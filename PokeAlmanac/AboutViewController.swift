//
//  AboutViewController.swift
//  PokeAlmanac
//
//  Created by 倉重ゴルプ　ダニエル on 2016/04/19.
//  Copyright © 2016年 Daniel Kurashige-Gollub. All rights reserved.
//

import Foundation
import UIKit
import TSMarkdownParser


class AboutViewController: UIViewController {
    
    @IBOutlet weak var markdownField: UITextView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log("AboutViewController")
        
        let markdown: String = fileContentsAsString("README.md")
        let attributedString = TSMarkdownParser.standardParser().attributedStringFromMarkdown(markdown)
        
        if let field: UITextView = markdownField! {
            field.attributedText = attributedString
            // scroll to top
            dispatch_async(dispatch_get_main_queue(), {
                let desiredOffset = CGPoint(x: 0, y: -self.markdownField!.contentInset.top)
                self.markdownField!.setContentOffset(desiredOffset, animated: false)
            })
        }
    }
    
}

