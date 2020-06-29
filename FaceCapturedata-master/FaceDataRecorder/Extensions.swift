//
//  Extensions.swift
//  FaceDataRecorder
//
//  Created by Elisha Hung on 2017/11/13.
//  Copyright © 2017 Elisha Hung. All rights reserved.
//
//  http://www.elishahung.com/

import SceneKit
import ARKit
import simd
// Capture mode
enum CaptureMode {
    case record
    case stream
}
enum Mode: String, CaseIterable {
    case one , two, three
}

// Every frame's capture data for streaming or save to text file later.
struct CaptureData {
    var vertices: [SIMD3<Float>]
    var mode: Mode = .one
    mutating func nextCase(){
    mode = mode.next()
    }
    
//    mutating func verticeformatted () -> String {
//        let verticesDescribed = vertices.map({ "\($0.x):\($0.y):\($0.z)" }).joined(separator: "~")
//        return "<\(verticesDescribed) ~method:\(self.mode) >"
//    }
    var verticeformatted : String {
    let verticesDescribed = vertices.map({ "\($0.x):\($0.y):\($0.z)" }).joined(separator: "~")
       // return "<\(verticesDescribed)~method:\(self.mode)>"
        return "<~method:\(self.mode)>"
    }
}


extension CaseIterable where Self: Equatable {
    var allCases: AllCases { Self.allCases }
    var nextCase: Self {
        let index = allCases.index(after: allCases.firstIndex(of: self)!)
        guard index != allCases.endIndex
        else { return allCases.first! }
        return allCases[index]
    }
    @discardableResult
     func next() -> Self {
        return self.nextCase
    }

}

// Matrix
extension simd_float4 {
    var str : String {
        return "\(self.x):\(self.y):\(self.z):\(self.w)"
    }
}

