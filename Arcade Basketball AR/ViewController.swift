//
//  ViewController.swift
//  Arcade Basketball AR
//
//  Created by 徐为伯 on 8/15/20.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var playImage: UIImageView!
    @IBOutlet var titleImage: UIImageView!
    @IBOutlet var blurView: UIVisualEffectView!
    @IBOutlet var tipLabel: UILabel!
    
    var hoopAdded = false
    var tmpNode: SCNNode = SCNNode()
    var count = 0
    var remainingTime = 60
    var rounds = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene.physicsWorld.speed = 0.6
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        tipLabel.isHidden = true
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    func newRound(_ isSuccess: Bool) {
        blurView.isHidden = false
        playButton.isHidden = false
        playImage.isHidden = false
        titleImage.isHidden = false
        if isSuccess {
            titleImage.image = UIImage(named: "success")
        } else {
            titleImage.image = UIImage(named: "fail")
        }

        tipLabel.isHidden = true
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        playButton.isHidden = true
        playImage.isHidden = true
        titleImage.isHidden = true
        blurView.isHidden = true
        if rounds == 0 {
            tipLabel.isHidden = false
            tipLabel.text = "请扫描您附近的水平面，\n点击屏幕显示的半透明\n水平面来放置篮框"
        } else {
            tipLabel.isHidden = true
        }
        
        count = 0
        remainingTime = 60
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        sceneView.session.run(configuration)
        
    }
    
    @IBAction func playButtonDown(_ sender: UIButton) {
        playImage.image = UIImage(named: "play_dark")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        if !hoopAdded {
            let touchLocation = sender.location(in: sceneView)
            let hitTestResult = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent)
            if let result = hitTestResult.first {
                addHoop(result: result)
                hoopAdded = true
                tipLabel.isHidden = true
                //倒计时
                _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(update), userInfo: nil, repeats: true)
                suspendPlaneDetection()
                tmpNode.removeFromParentNode()
                hideARPlaneNodes()
            }
        } else {
            createBasketball()
        }
    }
    
    //根据HitTest结果，向场景中添加篮筐
    func addHoop(result: ARHitTestResult) {
        let hoopScene = SCNScene(named: "art.scnassets/hoop.scn")
        guard let hoopNode = hoopScene?.rootNode.childNode(withName: "Hoop", recursively: false) else { return }
        
        let planePosition = result.worldTransform.columns.3
        hoopNode.position = SCNVector3(planePosition.x, planePosition.y + 0.25, planePosition.z - 0.85)
        hoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoopNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron, SCNPhysicsShape.Option.collisionMargin: 0.01]))
        sceneView.scene.rootNode.addChildNode(hoopNode)
        
        let hitCheckScene = SCNScene(named: "art.scnassets/hitCheck.scn")
        guard let hitCheckNode = hitCheckScene?.rootNode.childNode(withName: "hitCheck", recursively: false) else { return }
        hitCheckNode.position = SCNVector3(hoopNode.position.x, hoopNode.position.y - 0.41, hoopNode.position.z + 0.2)
        hitCheckNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hitCheckNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron, SCNPhysicsShape.Option.collisionMargin: 0.01]))
        sceneView.scene.rootNode.addChildNode(hitCheckNode)
    }
    
    
    //显示检测到的水平面
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if !hoopAdded {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            let floor = createFloor(planeAnchor: planeAnchor)
            node.addChildNode(floor)
            tmpNode = node
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        tmpNode = node
        for node in node.childNodes {
            node.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
            if let plane = node.geometry as? SCNPlane {
                plane.width = CGFloat(planeAnchor.extent.x)
                plane.height = CGFloat(planeAnchor.extent.z)
            }
        }
    }
    
    //创建可视化检测到的平面的图形
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let node = SCNNode()
        let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        node.eulerAngles.x = -.pi / 2
        node.geometry = geometry
        node.opacity = 0.45
        return node
    }
    
    func createBasketball() {
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        let ball = SCNNode(geometry: SCNSphere(radius: 0.08))
        ball.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "basketball")
        
        let cameraTransform = SCNMatrix4(currentFrame.camera.transform)
        ball.transform = cameraTransform
        
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball, options: [SCNPhysicsShape.Option.collisionMargin: 0.0]))
        physicsBody.restitution = 0.3
        ball.physicsBody = physicsBody
        
        let power = Float(7.5)
        let force = SCNVector3(-cameraTransform.m31*power, -cameraTransform.m32*power, -cameraTransform.m33*power)
        ball.physicsBody?.applyForce(force, asImpulse: true)
        //设置碰撞检测
        ball.physicsBody?.contactTestBitMask = Int(SCNPhysicsCollisionCategory.static.rawValue)
                                                             
        sceneView.scene.rootNode.addChildNode(ball)
    }
    
    func suspendPlaneDetection() {
        let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
        config.planeDetection = []
        sceneView.session.run(config)
    }
    
    func hideARPlaneNodes() {
        for anchor in (self.sceneView.session.currentFrame?.anchors)! {
            if let node = self.sceneView.node(for: anchor) {
                for child in node.childNodes {
                    let material = child.geometry?.materials.first!
                    material?.colorBufferWriteMask = []
                }
            }
        }
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        if contact.nodeA.categoryBitMask != 0 {
            if contact.nodeB.name! == "hitCheck" {
                count += 1
                
                contact.nodeA.categoryBitMask = 0
                contact.nodeA.removeFromParentNode()
                let node = sceneView.scene.rootNode.childNode(withName: "hitNum", recursively: true)!
                if let text = node.geometry as? SCNText {
                    text.string = hitText(of: count)
                }
            }
        }
    }
    
    func hitText(of i: Int) -> String {
        if i <= 9 {
            return "00" + String(i)
        } else if i <= 99 {
            return "0" + String(i)
        } else {
            return String(i)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    @objc func update() {
        if remainingTime > 0 {
            if count >= 30 {
                sceneView.session.pause()
                newRound(true)
            }
            remainingTime -= 1
            let node = sceneView.scene.rootNode.childNode(withName: "timeNum", recursively: true)!
            if let text = node.geometry as? SCNText {
                text.string = hitText(of: remainingTime)
            }
        }
        else {
            rounds += 1
            sceneView.session.pause()
            newRound(false)
        }
    }
}
