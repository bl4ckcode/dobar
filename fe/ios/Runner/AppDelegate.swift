import Flutter
import UIKit
import Firebase
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      FirebaseApp.configure()
      if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let xml = FileManager.default.contents(atPath: path),
         let plist = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any],
         let apiKey = plist["GOOGLE_MAPS_API_KEY"] as? String {
          GMSServices.provideAPIKey(apiKey)
      } else {
          print("Google Maps API key not found.")
      }
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
