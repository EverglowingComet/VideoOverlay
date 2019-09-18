//
//  VideoMerger.swift
//  VideoTrasition
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//

import Foundation
import AVFoundation

class VideoMerger {
    var backURL : URL
    var frontURL : URL
    
    var backLayout : DBVideoLayout
    var frontLayout : DBVideoLayout
    
    let video_width = 1920
    let video_height = 1080
    
    var exportURL : URL
    
    var callback : ViewController
    
    var transtionSecondes : Double = 5
    
    init(url1: URL, url2: URL, layout1: DBVideoLayout, layout2: DBVideoLayout, export: URL, vc : ViewController) {
        backURL = url1
        frontURL = url2
        
        backLayout = layout1
        frontLayout = layout2
        
        exportURL = export
        callback = vc
    }
    
    func startRendering() {
        let videoSize = CGSize(width: video_width, height: video_height)
        var transition : OverlayRenderer
        transition = OverlayRenderer(asset: AVAsset(url: backURL), asset1: AVAsset(url: frontURL), layout1: backLayout, layout2: frontLayout, videoSize: videoSize)
        
        transition.transtionSecondes = transtionSecondes
        
        let writer : VideoSeqWriter = VideoSeqWriter(outputFileURL: exportURL, render: transition, videoSize: videoSize)
        
        writer.startRender(vc: callback, url: exportURL)
    }
}
