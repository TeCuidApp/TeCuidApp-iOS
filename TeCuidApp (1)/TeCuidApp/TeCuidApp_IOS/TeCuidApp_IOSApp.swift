//
//  TeCuidApp_IOSApp.swift
//  TeCuidApp IOS
//
//  Created by Juanita Durán Ardila on 5/02/26.
//

import SwiftUI

@main
struct TeCuidApp_IOSApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(locationManager)
        }
    }
}
