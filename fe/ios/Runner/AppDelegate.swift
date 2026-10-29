import Flutter
import UIKit
import Firebase
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
    lazy var flutterEngine = FlutterEngine(name: "main_engine")

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      flutterEngine.run()
      FirebaseApp.configure()
      if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let xml = FileManager.default.contents(atPath: path),
         let plist = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String: Any],
         let apiKey = plist["GOOGLE_MAPS_API_KEY"] as? String {
          GMSServices.provideAPIKey(apiKey)
      } else {
          print("Google Maps API key not found.")
      }
      GeneratedPluginRegistrant.register(with: flutterEngine)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Modern UIScene Lifecycle Delegate
    @objc class SceneDelegate: UIResponder, UIWindowSceneDelegate {
        var window: UIWindow?
        
        func scene(
            _ scene: UIScene,
            willConnectTo session: UISceneSession,
            options connectionOptions: UIScene.ConnectionOptions
        ) {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            
            let window = UIWindow(windowScene: windowScene)
            self.window = window
            
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            appDelegate.window = window
            
            // Bind FlutterViewController to the pre-warmed engine
            let controller = FlutterViewController(engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            
            // Forward OAuth & Deep Link callbacks from cold launch
            for context in connectionOptions.urlContexts {
                appDelegate.application(UIApplication.shared, open: context.url, options: [:])
            }
        }
        
        func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            for context in URLContexts {
                appDelegate.application(UIApplication.shared, open: context.url, options: [:])
            }
        }
    }
}
