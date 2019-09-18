//
//  ViewController.swift
//  VideoOverlay
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var procceed_btn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func procceed_btn_clicked(_ sender: UIButton) {
        
        guard let url1 = Bundle.main.url(forResource: "back", withExtension: "mov") else {
            print("Impossible to find the video.")
            return
        }
        
        let layout_back = DBVideoLayout()
        layout_back.width = 800
        layout_back.height = 450
        
        layout_back.originX = 400
        layout_back.originY = 300
        
        
        guard let url2 = Bundle.main.url(forResource: "front", withExtension: "mov") else {
            print("Impossible to find the video.")
            return
        }
        
        let layout_front = DBVideoLayout()
        layout_front.width = 640
        layout_front.height = 360
        
        layout_front.originX = 1300
        layout_front.originY = 400
        
        // Export to file
        let dirPaths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        let docsURL = dirPaths[0]
        
        let path = docsURL.path.appending("/mergedVideo.mp4")
        let exportURL = URL.init(fileURLWithPath: path)
        
        let videoMerger = VideoMerger(url1: url1, url2: url2, layout1: layout_back, layout2: layout_front, export: exportURL, vc: self)
        
        procceed_btn.isEnabled = false
        
        videoMerger.startRendering()
    }
    
    func openPreviewScreen(_ videoURL:URL) -> Void {
        DispatchQueue.main.async {
            self.procceed_btn.isEnabled = true
            
            let player = AVPlayer(url: videoURL)
            let playerController = AVPlayerViewController()
            playerController.player = player
            
            self.present(playerController, animated: true, completion: {
                player.play()
            })
        }
        
    }
}

