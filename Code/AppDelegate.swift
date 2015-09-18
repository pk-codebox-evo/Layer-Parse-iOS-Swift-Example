import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var layerClient: LYRClient!
    var controller: ViewController!
    
    // MARK TODO: Before first launch, update LayerAppIDString, ParseAppIDString or ParseClientKeyString values
    // TODO:If LayerAppIDString, ParseAppIDString or ParseClientKeyString are not set, this app will crash"
    let LayerAppIDString: NSURL! = NSURL(string: "")
    let ParseAppIDString: String = ""
    let ParseClientKeyString: String = ""
    
    //Please note, You must set `LYRConversation *conversation` as a property of the ViewController.
    var conversation: LYRConversation!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        setupParse()
        setupLayer()
    
        // Show View Controller
        controller = ViewController()
        controller.layerClient = layerClient
        
        // Register for push
        self.registerApplicationForPushNotifications(application)

        self.window!.rootViewController = UINavigationController(rootViewController: controller)
        self.window!.backgroundColor = UIColor.whiteColor()
        self.window!.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK:- Push Notification Registration
    
    func registerApplicationForPushNotifications(application: UIApplication) {
        // Set up push notifications
        // For more information about Push, check out:
        // https://developer.layer.com/docs/guides/ios#push-notification
    
        if #available(iOS 8.0, *) {
            // Register device for iOS8
            let notificationSettings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: [UIUserNotificationType.Alert, UIUserNotificationType.Badge, UIUserNotificationType.Sound], categories: nil)
            application.registerUserNotificationSettings(notificationSettings)
            application.registerForRemoteNotifications()
        } else {
            // Fallback on earlier versions
            // Register device for iOS7
            application.registerForRemoteNotificationTypes([UIRemoteNotificationType.Alert, UIRemoteNotificationType.Sound, UIRemoteNotificationType.Badge])
        }
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // Store the deviceToken in the current installation and save it to Parse.
        let currentInstallation: PFInstallation = PFInstallation.currentInstallation()
        currentInstallation.setDeviceTokenFromData(deviceToken)
        currentInstallation.saveInBackground()
    
        // Send device token to Layer so Layer can send pushes to this device.
        // For more information about Push, check out:
        // https://developer.layer.com/docs/ios/guides#push-notification
        assert(self.layerClient != nil, "The Layer client has not been initialized!")
        do {
            try self.layerClient.updateRemoteNotificationDeviceToken(deviceToken)
            print("Application did register for remote notifications: \(deviceToken)")
        } catch let error as NSError {
            print("Failed updating device token with error: \(error)")
        }
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        switch application.applicationState {
        case UIApplicationState.Inactive:
            print("Inactive state")
            if userInfo["layer"] == nil {
                print("userInfo['layer'] == nil: navigateToViewConversation")
                PFPush.handlePush(userInfo)
                completionHandler(UIBackgroundFetchResult.NewData)
                return
            }
            
            SVProgressHUD.show()
            var conversation: LYRConversation? = self.conversationFromRemoteNotification(userInfo)
            if conversation != nil {
                print("conversation != nil: navigateToViewConversation")
                self.navigateToViewForConversation(conversation!)
            }

            let success: Bool = self.layerClient.synchronizeWithRemoteNotification(userInfo, completion: { (changes, error) in
                if changes?.count > 0 {
                    print("changes.count > 0: Fetch result")
                    completionHandler(UIBackgroundFetchResult.NewData)
                } else {
                    print("changes.count <= 0: failed or no data")
                    completionHandler(error != nil ? UIBackgroundFetchResult.Failed : UIBackgroundFetchResult.NoData)
                }

                // Try navigating once the synchronization completed
                if conversation == nil {
                    print("conversation == nil: navigateToViewForConversation")
                    conversation = self.conversationFromRemoteNotification(userInfo)
                    self.navigateToViewForConversation(conversation!)
                }
            })

            if !success {
                print("!success: no data")
                SVProgressHUD.dismiss()
                completionHandler(UIBackgroundFetchResult.NoData)
            }
        case UIApplicationState.Background:
            print("Background state")
            let success: Bool = self.layerClient.synchronizeWithRemoteNotification(userInfo, completion: { (changes, error) in
                if changes?.count > 0 {
                    print("changes.count > 0: Fetch result")
                    completionHandler(UIBackgroundFetchResult.NewData)
                } else {
                    print("changes.count <= 0: failed or no data")
                    completionHandler(error != nil ? UIBackgroundFetchResult.Failed : UIBackgroundFetchResult.NoData)
                }
            })

            if !success {
                print("!success: no data")
                completionHandler(UIBackgroundFetchResult.NoData)
            }
        case UIApplicationState.Active:
            print("Active state")
            let success: Bool = self.layerClient.synchronizeWithRemoteNotification(userInfo, completion: { (changes, error) in
                if changes?.count > 0 {
                    print("changes.count > 0: Fetch result")
                    completionHandler(UIBackgroundFetchResult.NewData)
                } else {
                    print("changes.count <= 0: failed or no data")
                    completionHandler(error != nil ? UIBackgroundFetchResult.Failed : UIBackgroundFetchResult.NoData)
                }
            })

            if !success {
                print("!success: no data")
                completionHandler(UIBackgroundFetchResult.NoData)
            }
        }
    }
    
    func conversationFromRemoteNotification(remoteNotification: [NSObject : AnyObject]) -> LYRConversation {
        let layerMap = remoteNotification["layer"] as! [String: String]
        let conversationIdentifier = NSURL(string: layerMap["conversation_identifier"]!)
        return self.existingConversationForIdentifier(conversationIdentifier!)!
    }
    
    func navigateToViewForConversation(conversation: LYRConversation) {
        if self.controller.conversationListViewController != nil {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), {
                SVProgressHUD.dismiss()
                self.controller.conversationListViewController.presentConversation(conversation)
            });
        } else {
                SVProgressHUD.dismiss()
        }
    }
    
    func existingConversationForIdentifier(identifier: NSURL) -> LYRConversation? {
        let query: LYRQuery = LYRQuery(queryableClass: LYRConversation.self)
        query.predicate = LYRPredicate(property: "identifier", predicateOperator: LYRPredicateOperator.IsEqualTo, value: identifier)
        query.limit = 1
        do {
            return try self.layerClient.executeQuery(query).firstObject as? LYRConversation
        } catch {
            // This should never happen?
            return nil
        }
    }
    
    func setupParse() {
        // Enable Parse local data store for user persistence
        Parse.enableLocalDatastore()
        Parse.setApplicationId(ParseAppIDString, clientKey: ParseClientKeyString)
        
        // Set default ACLs
        let defaultACL: PFACL = PFACL()
        defaultACL.setPublicReadAccess(true)
        PFACL.setDefaultACL(defaultACL, withAccessForCurrentUser: true)
    }
    
    func setupLayer() {
        layerClient = LYRClient(appID: LayerAppIDString)
        layerClient.autodownloadMIMETypes = NSSet(objects: ATLMIMETypeImagePNG, ATLMIMETypeImageJPEG, ATLMIMETypeImageJPEGPreview, ATLMIMETypeImageGIF, ATLMIMETypeImageGIFPreview, ATLMIMETypeLocation) as! Set<NSObject>
    }
}

