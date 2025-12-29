//
//  ContentView.swift
//  Practice_Metal_v1
//
//  Created by Ivan Voznyi on 12/24/25.
//

import SwiftUI

struct ContentView: View {
    @State var isSmoothPointer: Bool = true
    @State var angle: Double = 0.0
    var body: some View {
        VStack {
            Toggle("Smooth Pointer", isOn: $isSmoothPointer)
            GeometryReader { proxy in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                ZStack {
                    Rectangle()
                        .colorEffect(
                            ShaderLibrary.radialTicks(
                                .float(angle),
                                .float2(proxy.size.width, proxy.size.height),
                                .float(isSmoothPointer ? 1.0 : 0.0)
                            )
                        )
                }
                .gesture(
                    DragGesture()
                        .onChanged({ value in
                            let dx = value.location.x  - center.x
                            let dy = value.location.y  - center.y
                            let radians = atan2(dx, dy)
                            
                            // 2. Convert to degrees (0 to 360)
                            // atan2 returns -π to π. Adding π makes it 0 to 2π.
                            let degrees = (radians + .pi) * (180.0 / .pi)
                            
                            // 3. Update the state
                            angle = degrees
                        })
                )
            }
        }.padding()
    }
}

#Preview {
    ContentView()
}
