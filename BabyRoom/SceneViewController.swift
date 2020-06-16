//
//  SceneViewController.swift
//  BabyRoom
//
//  Created by Muhammad Fawwaz Mayda on 13/06/20.
//  Copyright © 2020 Muhammad Fawwaz Mayda. All rights reserved.
//

import UIKit
import ARKit

enum State {
    case ready
    case pointingToSurface
    case lookingForSurface
}
class SceneViewController: UIViewController, ARSCNViewDelegate  {
    
    var appState : State = .lookingForSurface
    var statusMessage = ""
    var trackingStatus = ""
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var statusLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        initSceneView()
        initSession()
        initGestureRecognizers()
        // Do any additional setup after loading the view.
    }
    
    
    //MARK: -Init
    func initSceneView() {
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.showsStatistics = true
        sceneView.preferredFramesPerSecond = 60
        sceneView.antialiasingMode = .multisampling2X
        sceneView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
    }
    
    func createARConfig() -> ARConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.horizontal]
        config.isLightEstimationEnabled = true
        return config
    }
    
    func initSession() {
        guard ARWorldTrackingConfiguration.isSupported else { return }
        let config = createARConfig()
        sceneView.session.run(config)
    }
    
    func resetARsession() {
      let config = createARConfig()
      sceneView.session.run(config,
                            options: [.resetTracking,
                                      .removeExistingAnchors])
      appState = .lookingForSurface
    }

    
    
    
    //MARK: - Sceene Status
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
      switch camera.trackingState {
      case .notAvailable:
        trackingStatus = "For some reason, augmented reality tracking isn’t available."
      case .normal:
        trackingStatus = ""
      case .limited(let reason):
        switch reason {
        case .excessiveMotion:
          trackingStatus = "You’re moving the device around too quickly. Slow down."
        case .insufficientFeatures:
          trackingStatus = "I can’t get a sense of the room. Is something blocking the rear camera?"
        case .initializing:
          trackingStatus = "Initializing — please wait a moment..."
        case .relocalizing:
          trackingStatus = "Relocalizing — please wait a moment..."
        }
      }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
      DispatchQueue.main.async {
        self.updateAppState()
        self.updateStatusText()
      }
    }

    // Updates the app status, based on whether any of the detected planes
    // are currently in view.
    func updateAppState() {
        guard appState == .pointingToSurface ||
        appState == .ready
        else {
          return
      }

      if isAnyPlaneInView() {
        appState = .ready
      } else {
        appState = .pointingToSurface
      }
    }
    
    func updateStatusText() {
      switch appState {
      case .lookingForSurface:
        statusMessage = "Scan the room with your device until the yellow dots appear."
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
      case .pointingToSurface:
        statusMessage = "Point your device towards one of the detected surfaces."
        sceneView.debugOptions = []
      case .ready:
        statusMessage = "Tap on the floor grid to place furniture; look at walls to place posters."
        sceneView.debugOptions = []
      }
      statusLabel.text = trackingStatus != "" ? "\(trackingStatus)" : "\(statusMessage)"
    }
    
    func isAnyPlaneInView() -> Bool {
       let screenDivisions = 5 - 1
       let viewWidth = view.bounds.size.width
       let viewHeight = view.bounds.size.height

       for y in 0...screenDivisions {
         let yCoord = CGFloat(y) / CGFloat(screenDivisions) * viewHeight
         for x in 0...screenDivisions {
           let xCoord = CGFloat(x) / CGFloat(screenDivisions) * viewWidth
           let point = CGPoint(x: xCoord, y: yCoord)
           
           // Perform hit test for planes.
           let hitTest = sceneView.hitTest(point, types: .estimatedHorizontalPlane)
           if !hitTest.isEmpty {
             return true
           }
         }
       }
       return false
     }
    //MARK: - IBAction
    @IBAction func clearButtonPressed(_ sender: Any) {
         clearAllFurniture()
       }

       func clearAllFurniture() {
         sceneView.scene.rootNode.enumerateChildNodes { (childNode, _) in
           guard let childNodeName = childNode.name, childNodeName != "horizontal"
             else { return }
           childNode.removeFromParentNode()
         }
       }
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        clearAllFurniture()
        resetARsession()
    }
    
    //MARK: - Plane Detection
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
       // We only want to deal with plane anchors, which encapsulate
       // the position, orientation, and size, of a detected surface.
       guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
       // Draw the appropriate plane over the detected surface.
       let planeType: String
       if planeAnchor.alignment == .horizontal {
         planeType = "Horizontal"
       } else {
         planeType = "Vertical"
       }
       
       print("Found :\(planeType) at \(planeAnchor.center.x) \(planeAnchor.center.y) \(planeAnchor.center.z)")
       drawPlaneNode(on: node, for: planeAnchor)

     }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        // Remove any children this node may have.
        node.enumerateChildNodes { (childNode, _) in
          childNode.removeFromParentNode()
        }
        // Update the plane over this surface.
        drawPlaneNode(on: node, for: planeAnchor)
    }

    
    func drawPlaneNode(on node: SCNNode, for planeAnchor: ARPlaneAnchor) {
        let planeNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z)))
        planeNode.position = SCNVector3(x: planeAnchor.center.x, y: planeAnchor.center.y, z: planeAnchor.center.z)
        planeNode.geometry?.firstMaterial?.isDoubleSided = true
        // Align the plane with the anchor.
        planeNode.eulerAngles = SCNVector3(x: Float(-Double.pi/2), y: 0, z: 0)
        // Give the plane node the appropriate surface.
        if planeAnchor.alignment == .horizontal {
          planeNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "grid")
          planeNode.name = "horizontal"
        }
        // Add the plane node to the scene.
        node.addChildNode(planeNode)
        appState = .ready
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
       // We only want to deal with plane anchors.
       guard anchor is ARPlaneAnchor else { return }
       // Remove any children this node may have.
       node.enumerateChildNodes { (childNode, _) in
         childNode.removeFromParentNode()
       }

     }
    // MARK: - Adding and removing furniture
    // =====================================

    func initGestureRecognizers() {
      let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap))
      sceneView.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
      // Find out where the user tapped on the screen.
      let tappedScene = sender.view as! ARSCNView
      let tapLocation = sender.location(in: tappedScene)
      // Find all the detected planes that would intersect with
      // a line extending from where the user tapped the screen.
      let planeIntersect = tappedScene.hitTest(tapLocation, types: [.estimatedHorizontalPlane])
      // If the closest of those planes is horizontal,
      // put the current furniture item on it.
      if !planeIntersect.isEmpty {
        addFurniture(hitTestResult: planeIntersect.first!)
      }

    }

    func addFurniture(hitTestResult: ARHitTestResult) {
      // Get the real-world position corresponding to
      // where the user tapped on the screen.
      let transform = hitTestResult.worldTransform
      let positionColumn = transform.columns.3
      // Get the current furniture item, correct its position if necessary,
      let initialPosition = SCNVector3(positionColumn.x, positionColumn.y, positionColumn.z)
      // and add it to the scene.
    
      let scene = SCNScene(named: "art.scnassets/Babycrib.scn")
      let node = (scene?.rootNode.childNode(withName: "mesh01_07", recursively: false))!
        node.scale = SCNVector3(0.8, 0.8, 0.8)
      node.position = initialPosition
      sceneView.scene.rootNode.addChildNode(node)

    }



    // MARK: - AR session error management
    // ===================================

    func session(_ session: ARSession, didFailWithError error: Error) {
      // Present an error message to the user
      trackingStatus = "AR session failure: \(error)"
    }

    func sessionWasInterrupted(_ session: ARSession) {
      // Inform the user that the session has been interrupted, for example, by presenting an overlay
      trackingStatus = "AR session was interrupted!"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
      // Reset tracking and/or remove existing anchors if consistent tracking is required
      trackingStatus = "AR session interruption ended."
      resetARsession()
    }
}


func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
  return SCNVector3(left.x + right.x,
                    left.y + right.y,
                    left.z + right.z)
}
