import SwiftUI
import WebKit
import CoreLocation

struct GoogleMapsView: UIViewRepresentable {
    let reports: [Report]
    let selectedRoutePolyline: String?
    let userLocation: CLLocationCoordinate2D?
    let showHeatmap: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Allow JS (on by default, but explicit is safer)
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false  // map uses its own gesture handling
        webView.navigationDelegate = context.coordinator
        webView.isInspectable = true               // enables Safari Web Inspector for debugging
        context.coordinator.webView = webView

        // Write to a temp file so WKWebView can load external scripts
        // (loadHTMLString with a remote baseURL is restricted on iOS 14+)
        loadMap(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.evaluateJavaScript("typeof window.tcMapReady !== 'undefined' && window.tcMapReady") { value, _ in
            if (value as? Bool) == true {
                context.coordinator.push(reports: reports,
                                         routePolyline: selectedRoutePolyline,
                                         userLocation: userLocation,
                                         showHeatmap: showHeatmap)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.updateUIView(webView, context: context)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func loadMap(in webView: WKWebView) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tcmap_\(Int(Date().timeIntervalSince1970)).html")
        do {
            try Self.htmlTemplate.write(to: tmpURL, atomically: true, encoding: .utf8)
            webView.loadFileURL(tmpURL, allowingReadAccessTo: FileManager.default.temporaryDirectory)
        } catch {
            print("⚠️ GoogleMapsView: could not write temp HTML — \(error)")
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("⚠️ GoogleMapsView navigation failed: \(error)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            print("⚠️ GoogleMapsView provisional navigation failed: \(error)")
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ GoogleMapsView HTML loaded — waiting for Maps API callback")
        }

        func push(reports: [Report],
                  routePolyline: String?,
                  userLocation: CLLocationCoordinate2D?,
                  showHeatmap: Bool) {
            guard let webView else { return }

            let markerPayload: [[String: Any]] = reports.compactMap { r in
                guard let c = r.coordinate else { return nil }
                var entry: [String: Any] = [
                    "lat": c.latitude,
                    "lng": c.longitude,
                    "type": r.type.rawValue,
                    "severity": r.severity.rawValue,
                    "description": r.description,
                    "address": r.address,
                ]
                if let name = r.reportedName, !name.isEmpty {
                    entry["reportedName"] = name
                }
                return entry
            }

            var root: [String: Any] = [
                "markers": markerPayload,
                "showHeatmap": showHeatmap,
                "polyline": routePolyline ?? "",
            ]
            if let user = userLocation {
                root["user"] = ["lat": user.latitude, "lng": user.longitude]
            }

            guard let data = try? JSONSerialization.data(withJSONObject: root),
                  let json = String(data: data, encoding: .utf8) else { return }

            webView.evaluateJavaScript("window.tcRender(\(json));") { _, error in
                if let error { print("⚠️ tcRender JS error: \(error)") }
            }
        }
    }

    // MARK: - HTML template

    private static var htmlTemplate: String {
        """
        <!DOCTYPE html>
        <html><head>
          <meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
          <style>
            html, body, #map { height: 100%; width: 100%; margin: 0; padding: 0; }
          </style>
          <script>
            var map, heatmap, userMarker, routeLine;
            var reportMarkers  = [];
            var allHeatmapData = [];

            function colorForSeverity(s) {
              if (s === 'Crítica') return '#D32F2F';
              if (s === 'Alta')    return '#F57C00';
              if (s === 'Media')   return '#FBC02D';
              return '#388E3C';
            }
            function severityWeight(s) {
              if (s === 'Crítica') return 5;
              if (s === 'Alta')    return 3;
              if (s === 'Media')   return 2;
              return 1;
            }
            function typeWeight(t) {
              if (t === 'Homicidio') return 5;
              if (t === 'Agresión')  return 4;
              if (t === 'Robo')      return 3;
              if (t === 'Acoso')     return 2;
              return 1;
            }
            function refreshHeatmap() {
              var bounds = map.getBounds();
              if (!bounds || allHeatmapData.length === 0) { heatmap.setData([]); return; }
              heatmap.setData(allHeatmapData.filter(function(d) { return bounds.contains(d.location); }));
            }

            function initMap() {
              map = new google.maps.Map(document.getElementById('map'), {
                center: { lat: 4.6097, lng: -74.0817 },
                zoom: 13,
                disableDefaultUI: true,
                zoomControl: true,
                gestureHandling: 'greedy'
              });
              map.addListener('idle', function() { if (heatmap) refreshHeatmap(); });
              window.tcMapReady = true;
            }

            window.tcRender = function(data) {
              if (!window.tcMapReady) return;

              reportMarkers.forEach(function(m) { m.setMap(null); });
              reportMarkers = [];
              (data.markers || []).forEach(function(r) {
                var marker = new google.maps.Marker({
                  position: { lat: r.lat, lng: r.lng },
                  map: map,
                  title: r.type + ' · ' + r.severity,
                  icon: {
                    path: google.maps.SymbolPath.CIRCLE,
                    scale: 9,
                    fillColor: colorForSeverity(r.severity),
                    fillOpacity: 0.9,
                    strokeColor: '#ffffff',
                    strokeWeight: 2
                  }
                });
                var html = '<strong>' + r.type + ' (' + r.severity + ')</strong><br>'
                         + (r.address || '') + '<br>' + (r.description || '');
                if (r.reportedName) html += '<br><em>Reportado por: ' + r.reportedName + '</em>';
                var info = new google.maps.InfoWindow({ content: html });
                marker.addListener('click', function() { info.open(map, marker); });
                reportMarkers.push(marker);
              });

              if (heatmap) { heatmap.setMap(null); heatmap = null; }
              allHeatmapData = [];
              if (data.showHeatmap && (data.markers || []).length > 0) {
                allHeatmapData = (data.markers || []).map(function(r) {
                  return { location: new google.maps.LatLng(r.lat, r.lng),
                           weight: severityWeight(r.severity) * typeWeight(r.type) };
                });
                heatmap = new google.maps.visualization.HeatmapLayer({ data: [], radius: 40, opacity: 0.65 });
                heatmap.setMap(map);
                refreshHeatmap();
              }

              if (routeLine) { routeLine.setMap(null); routeLine = null; }
              if (data.polyline) {
                var path = google.maps.geometry.encoding.decodePath(data.polyline);
                routeLine = new google.maps.Polyline({ path: path, strokeColor: '#F22A7D', strokeOpacity: 0.95, strokeWeight: 5 });
                routeLine.setMap(map);
                var b = new google.maps.LatLngBounds();
                path.forEach(function(p) { b.extend(p); });
                map.fitBounds(b);
              }

              if (data.user) {
                var pos = { lat: data.user.lat, lng: data.user.lng };
                if (!userMarker) {
                  userMarker = new google.maps.Marker({
                    position: pos, map: map, title: 'Tu ubicación',
                    icon: { path: google.maps.SymbolPath.CIRCLE, scale: 7,
                            fillColor: '#1A73E8', fillOpacity: 1,
                            strokeColor: '#ffffff', strokeWeight: 3 }
                  });
                  map.setCenter(pos);
                } else { userMarker.setPosition(pos); }
              }
            };
          </script>
          <script src="https://maps.googleapis.com/maps/api/js?key=\(GoogleMaps.apiKey)&libraries=visualization,geometry&callback=initMap" async defer></script>
        </head><body>
          <div id="map"></div>
        </body></html>
        """
    }
}

