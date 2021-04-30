//
//  ViewController.swift
//  LivenessCheck-MLKIT
//
//  Created by Abdul Basit on 17/06/2020.
//  Copyright © 2020 Abdul Basit. All rights reserved.
//

import UIKit
import CoreMedia
import MLKit

class LivenessViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak private var videoPreview: UIView!
    @IBOutlet weak private var tableView: UITableView!
    
    //MARK: - Internal Properties
    private var videoCapture: CameraPreview?
    
    // MARK: - Data
    let options = FaceDetectorOptions()
    private var faceDetector: FaceDetector?
    private var countBlink: Int = 0
    private var isStartCountBlink: Bool = false
    
    private var detectionOptions = [" 👱🏻‍♂️ Single Face Detection",
                                    " 👀 Count Blinking",
                                    " 🙂 Smile :)"]
    private var completedSteps =  [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        options.performanceMode = .accurate
        options.landmarkMode = .all
        options.classificationMode = .all
        options.minFaceSize = CGFloat(0.1)
        faceDetector = FaceDetector.faceDetector(options: options)
        //Camera Setup
        setUpCamera()
    }
    
    
    // MARK: - SetUp Video
    private func setUpCamera() {
        videoCapture = CameraPreview()
        videoCapture?.delegate = self
        videoCapture?.fps = 15
        videoCapture?.setUp(sessionPreset: .vga640x480) { success in
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture?.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                // start video preview when setup is done
                self.videoCapture?.start()
            }
        }
    }
    
    
    private func resizePreviewLayer() {
        videoCapture?.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Update Step
    
    private func updateValidStep(number: Int, isCorrect: Bool) {
        if(isCorrect){
            completedSteps.append(number)
        } else {
            if let index = completedSteps.firstIndex(of: number) {
                completedSteps.remove(at: index)
            }
        }
        
        tableView.reloadData()
    }
    
}

// MARK: - Video Delegate

extension LivenessViewController: CameraPreviewDelegate {
    
    func videoCapture(_ capture: CameraPreview, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        
        if let pixelBuffer = pixelBuffer {
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
    
    private func predictUsingVision (pixelBuffer: CVPixelBuffer)
    {
        let ciimage : CIImage = CIImage (cvImageBuffer: pixelBuffer)
        let ciContext = CIContext ()
        guard let cgImage : CGImage = ciContext.createCGImage (ciimage, from:          ciimage.extent)
        else {
            // end of measure
            return
        }
        let uiImage : UIImage = UIImage (cgImage: cgImage)

        // predict!
        detectFace (uiImage)
    }
    
    private func detectFace (_ pickedImage: UIImage)
    {
        // 1
        let visionImage = VisionImage (image: pickedImage)
        // 2
        faceDetector?.process (visionImage) { [weak self] (faces, error) in


            guard let self = self, error == nil else { return }


            // 3
            guard let faces = faces,
                  !faces.isEmpty,
                  faces.count == 1,
                  let face = faces.first else {
                    self.updateValidStep(number: 1, isCorrect: false)
            
                    return
            
            }

            self.validateLiveness (face)

        }
    }
    
    private func validateLiveness(_ face: Face) {

        //1

        updateValidStep(number: 1, isCorrect: true)
        
        if face.leftEyeOpenProbability < 0.01 && face.rightEyeOpenProbability < 0.01 && countBlink < 3 && !isStartCountBlink {
           isStartCountBlink = true
           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change `2.0` to the desired number of seconds.
               self.countBlink = self.countBlink + 1
               self.updateValidStep(number: 2, isCorrect: true)
               self.isStartCountBlink = false
           }
       }
       
       
       
       if face.smilingProbability > 0.3 {
           updateValidStep(number: 3, isCorrect: true)
       } else {
           updateValidStep(number: 3, isCorrect: false)
       }

    }
    
}

// MARK: - TableView Delegates

extension LivenessViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectionOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
                ?? (UITableViewCell(style: .default, reuseIdentifier: "cell"))
            cell.textLabel?.text = "\(detectionOptions[indexPath.row])"
            if(indexPath.row == 1){
                cell.textLabel?.text! += " \(self.countBlink)"
            }
            cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
            if completedSteps.contains(indexPath.row + 1) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            return cell
    }
    
}
