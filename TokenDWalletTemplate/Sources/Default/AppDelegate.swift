import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    var appController: AppController!
    var rootNavigationController: RootNavigationViewController!
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
        ) -> Bool {
        
        self.rootNavigationController = RootNavigationViewController()
        
        let apiConfiguration: APIConfigurationModel
        do {
            apiConfiguration = try APIConfigurationFetcher.fetchApiConfigurationFromPlist("APIConfiguration")
        } catch let error {
            fatalError("Failed to fetch apiConfiguration: \(error.localizedDescription)")
        }
        
        self.appController = AppController(
            rootNavigation: self.rootNavigationController,
            apiConfigurationModel: apiConfiguration,
            launchOptions: launchOptions
        )
        self.rootNavigationController.appController = self.appController
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = self.rootNavigationController
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]?) -> Void
        ) -> Bool {
        
        return self.appController.applicationContinue(
            userActivity: userActivity,
            restorationHandler: restorationHandler
        )
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        self.appController.applicationDidEnterBackground()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        self.appController.applicationWillEnterForeground()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        self.appController.applicationDidBecomeActive()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        self.appController.applicationWillResignActive()
    }
}