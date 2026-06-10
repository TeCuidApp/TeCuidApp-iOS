//
//  ContentView.swift
//  TeCuidApp IOS
//
//  Created by Alejandro Barrera Arias on 5/02/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        ZStack {
            if appData.isAuthenticated {
                MainTabView()
                    .environmentObject(appData)
                    .environmentObject(locationManager)
            } else {
                AuthView()
                    .environmentObject(appData)
                    .environmentObject(locationManager)
            }
        }
        .onAppear {
            locationManager.requestPermissionIfNeeded()
        }
    }
}

#Preview {
    let appData = AppData()
    let locationManager = LocationManager()

    return ContentView()
        .environmentObject(appData)
        .environmentObject(locationManager)
}
