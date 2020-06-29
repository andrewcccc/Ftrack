//
//  ViewController.swift
//  FaceDataRecorder
//
//  Created by Elisha Hung on 2017/11/12.
//  Copyright © 2017 Elisha Hung. All rights reserved.
//
//  http://www.elishahung.com/

import UIKit
import ARKit
import SceneKit
import Foundation
import AVFoundation

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!  // Main view
    @IBOutlet weak var Start: UIButton!
    @IBOutlet weak var Change: UIButton!
    @IBOutlet weak var Stop: UIButton!
    @IBOutlet weak var Textfield: UITextView!
    
    private let ini = UserDefaults.standard  // Store user setting
    
    var session: ARSession {
        return sceneView.session
    }

    var contentControllers: [VirtualContentType: VirtualContentController] = [:]
    var currentFaceAnchor: ARFaceAnchor?
    var selectedVirtualContent: VirtualContentType! {
        didSet {
            guard oldValue != nil, oldValue != selectedVirtualContent
                else { return }
            // Remove existing content when switching types.
            contentControllers[oldValue]?.contentNode?.removeFromParentNode()
            // If there's an anchor already (switching content), get the content controller to place initial content.
            // Otherwise, the content controller will place it in `renderer(_:didAdd:for:)`.
            if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
                let newContent = selectedContentController.renderer(sceneView, nodeFor: anchor) {
                node.addChildNode(newContent)
            }
        }
    }
    var selectedContentController: VirtualContentController {
        if let controller = contentControllers[selectedVirtualContent] {
            return controller
        } else {
            let controller = selectedVirtualContent.makeController()
            contentControllers[selectedVirtualContent] = controller
            return controller
        }
    }

    var outputStream: OutputStream!
    
    // Record mode's properties
    var fps = 30.0 {
        didSet {
            fps = min(max(fps, 1.0), 60.0)
            ini.set(fps, forKey: "fps")
        }
    }
    var fpsTimer: Timer!
    var captureData: [CaptureData]!
    var currentCaptureFrame = 0
    var folderPath : URL!
    
    // Queue varibales
    private let saveQueue = DispatchQueue.init(label: "com.eliWorks.faceCaptureX")
    private let dispatchGroup = DispatchGroup()
    
    // Init
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true  // true for performance
        selectedVirtualContent = VirtualContentType.texture
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // View actions and initialize tracking here
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initARFaceTracking()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // AR session delegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
        }
    }
    func sessionWasInterrupted(_ session: ARSession) {
        return
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
    self.initARFaceTracking()
        }
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    }
    func initARFaceTracking() {
          guard ARFaceTrackingConfiguration.isSupported else { return }
          let configuration = ARFaceTrackingConfiguration()
          configuration.isLightEstimationEnabled = false
          sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
      }
    // UI Actions

    @IBAction func StartTapped(_ sender: Any) {
       guard let data = getFrameData() else {return}
        captureData = []        //create empty array
        currentCaptureFrame = 0 //inital capture frame
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1/fps, repeats: true, block: {(timer) -> Void in self.recordData()})
    }
    var x = 0
     var instance = CaptureData(vertices: [
         SIMD3<Float>(x: 0, y: 0, z: 0),
         SIMD3<Float>(x: 0.5, y: 1, z: 0),
         SIMD3<Float>(x: 1, y: 0, z: 0)
     ])
    @IBAction func ChangeTapped(_ sender: Any) {
        instance.nextCase()
        //print(a.mode)
        x = (x == 2) ? 0 : (x + 1)
        Textfield.text = "Method \(x+1)"
    }
    @IBAction func StopTapped(_ sender: Any) {
        guard let data = getFrameData() else {return}
             do {
                 fpsTimer.invalidate() //turn off the timer
                 var capdata = captureData.map{$0.verticeformatted}.joined(separator:"")
                 let dir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last! as URL
                 let url = dir.appendingPathComponent("testing.txt")
                 try capdata.appendLineToURL(fileURL: url as URL)
                 let result = try String(contentsOf: url as URL, encoding: String.Encoding.utf8)
             }
             catch {
                 print("Could not write to file")
             }
    }

    // Capture Process
    func recordData() { // Every frame's process in record mode
        guard let data = getFrameData() else {return}
        captureData.append(data)
        currentCaptureFrame += 1
    }

    func getFrameData() -> CaptureData? { // Organize arkit's data
             let arFrame = sceneView.session.currentFrame!
             guard let anchor = arFrame.anchors[0] as? ARFaceAnchor else {return nil}
             let vertices = anchor.geometry.vertices
             let data = CaptureData(vertices: vertices)
             return data
         }
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor
        // If this is the first time with this anchor, get the controller to create content.
        // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
        if node.childNodes.isEmpty, let contentNode = selectedContentController.renderer(renderer, nodeFor: faceAnchor) {
            node.addChildNode(contentNode)
        }
        // Get the currernt frame for AprilTag detection
        selectedContentController.session = sceneView.session
        selectedContentController.sceneView = sceneView
    }
    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
            let contentNode = selectedContentController.contentNode,
            contentNode.parent == node
            else { return }
        selectedContentController.session = sceneView.session
        selectedContentController.sceneView = sceneView
        selectedContentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }
}

extension String {
   func appendLineToURL(fileURL: URL) throws {
        try (self).appendToURL(fileURL: fileURL)
    }

    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
    func trim() -> String
      {
       return self.trimmingCharacters(in: CharacterSet.whitespaces)
      }
}
extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

