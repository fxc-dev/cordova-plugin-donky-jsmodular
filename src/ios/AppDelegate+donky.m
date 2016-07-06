
#import "AppDelegate+donky.h"
#import <objc/runtime.h>
#import "DonkyPlugin.h"

#if _SWIZZLED_INIT_
static char launchNotificationKey;
static char coldstartKey;
#endif

@implementation AppDelegate (donky)

- (id) getCommandInstance:(NSString*)className
{
    return [self.viewController getCommandInstance:className];
}


#if _SWIZZLED_INIT_
// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
+ (void)load
{
    NSLog(@"AppDelegate(donky)::load");
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(init);
        SEL swizzledSelector = @selector(pushPluginSwizzledInit);
        
        Method original = class_getInstanceMethod(class, originalSelector);
        Method swizzled = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzled),
                        method_getTypeEncoding(swizzled));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(original),
                                method_getTypeEncoding(original));
        } else {
            method_exchangeImplementations(original, swizzled);
        }
    });
}

- (AppDelegate *)pushPluginSwizzledInit
{
    NSLog(@"AppDelegate(donky)::pushPluginSwizzledInit");
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(createNotificationChecker:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(pushPluginOnApplicationDidBecomeActive:)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    // This actually calls the original init method over in AppDelegate. Equivilent to calling super
    // on an overrided method, this is not recursive, although it appears that way. neat huh?
    return [self pushPluginSwizzledInit];
}

// This code will be called immediately after application:didFinishLaunchingWithOptions:. We need
// to process notifications in cold-start situations
- (void)createNotificationChecker:(NSNotification *)notification
{
    NSLog(@"AppDelegate(donky)::createNotificationChecker");
    if (notification)
    {
        NSDictionary *launchOptions = [notification userInfo];
        if (launchOptions) {
            NSLog(@"coldstart");
            self.launchNotification = [launchOptions objectForKey: @"UIApplicationLaunchOptionsRemoteNotificationKey"];
            self.coldstart = [NSNumber numberWithBool:YES];
        } else {
            NSLog(@"not coldstart");
            self.coldstart = [NSNumber numberWithBool:NO];
        }
    }
}

- (void)pushPluginOnApplicationDidBecomeActive:(NSNotification *)notification {
    
    NSLog(@"AppDelegate(donky)::pushPluginOnApplicationDidBecomeActive");
    
    UIApplication *application = notification.object;
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    
    if (self.launchNotification) {
        donkyPlugin.coldstart = [self.coldstart boolValue];
    }
}
#endif

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"AppDelegate(donky)::didRegisterForRemoteNotificationsWithDeviceToken");
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    [donkyPlugin didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"AppDelegate(donky)::didFailToRegisterForRemoteNotificationsWithError");

    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    [donkyPlugin didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication*)application didRegisterUserNotificationSettings:(nonnull UIUserNotificationSettings *)notificationSettings{
    NSLog(@"AppDelegate(donky)::didRegisterUserNotificationSettings");
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    [donkyPlugin didRegisterUserNotificationSettings:notificationSettings];
}


/**
 * This one is called if the notification is tapped (and app is backgrounded)
 * If app is not running and this fires, it all happens before cordova and donky are ready to process it
 */
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    NSLog(@"AppDelegate(donky)::didReceiveRemoteNotification");
    
    UIApplicationState state =[[UIApplication sharedApplication] applicationState];
    
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: userInfo, @"userInfo", @(state), @"applicationState", nil];
    
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive){
        //TODO: store somewhere that the plugin can access in pluginInitialize - it can then the client
    }
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    
    [donkyPlugin notificationReceived: dict];
    
    // [DonkyPlugin notify: @"pushNotification" withData: dict];
    
    completionHandler(UIBackgroundFetchResultNewData);
}

/**
 * This one is called if interactive button is tapped (and app is backgrounded)
 */
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    NSLog(@"AppDelegate(donky)::handleActionWithIdentifier");
    
    UIApplicationState state =[[UIApplication sharedApplication] applicationState];
    
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: identifier, @"identifier", userInfo, @"userInfo", @(state), @"applicationState", [DonkyPlugin getCurrentTimestamp], @"clicked", nil];

    /**
     * Need 3 different behaviours here
     */
    
    switch([[UIApplication sharedApplication] applicationState]){
        case UIApplicationStateActive:
            break;

        case UIApplicationStateInactive:
            // dismissedNotifications can be passed back when init is called
            break;
        
        case UIApplicationStateBackground:
            // dismissedNotifications can be passed when app resumes ?
            // not sure I need to do anything here as the JS handleButtonAction code simply sends the analytics result (doesn't display anything)
            break;
    }
    
    if([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive){

        NSString* action;
        NSString* link;
        NSString* label;
        
        NSString *inttype = [userInfo objectForKey:@"inttype"];
        
        NSString *notificationId = [userInfo objectForKey:@"notificationId"];
        
        if([inttype isEqualToString:@"TwoButton"])
        {
            NSString *act1 = [userInfo objectForKey:@"act1"];
            NSString *act2 = [userInfo objectForKey:@"act2"];
            
            NSString *lbl1 =[userInfo objectForKey:@"lbl1"];
            NSString *lbl2 = [userInfo objectForKey:@"lbl2"];

            NSString *link1 =[userInfo objectForKey:@"link1"];
            NSString *link2 = [userInfo objectForKey:@"link2"];
            
            
            if([identifier isEqualToString:lbl1]){
                // button 1 clicked
                NSLog(@"%@ => %@", lbl1, act1);
                action = act1;
                link = link1;
                label = lbl1;
                
            }else{
                // button 2 clicked
                NSLog(@"%@ => %@", lbl2, act2);
                action = act2;
                link = link2;
                label = lbl2;
            }
        }
        
        
        // Coldstart analytics ...
        // if a button is clicked, how do we report analytics ?
        // Can store notificationId, action, buttonText and handle in client
        //  client can download the message
        
        // pipe separated JSON ?
        // {"notificationId": "", "label": "dismiss", "action": "D"}|
        
        NSString *savedColdstartNotifications = [[NSUserDefaults standardUserDefaults] stringForKey:@"coldstartNotifications"];
        
        NSString *json = [NSString stringWithFormat:@"{\"notificationId\":\"%@\",\"label\":\"%@\",\"action\":\"%@\", \"clicked\":\"%@\"}", notificationId, label, action, [DonkyPlugin getCurrentTimestamp]];
        
        NSString *valueToSave;
        
        if(savedColdstartNotifications != nil && ![savedColdstartNotifications isEqualToString:@""]){
            valueToSave = [NSString stringWithFormat:@"%@%@|", savedColdstartNotifications, json];
        }else{
            valueToSave = [NSString stringWithFormat:@"%@|", json];
        }
        
        NSLog(@"coldstartNotifications: %@", valueToSave);

        [[NSUserDefaults standardUserDefaults] setObject:valueToSave forKey:@"coldstartNotifications"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        
        // If a dismiss button is clicked (can be either button), need to add to dismissedNotifications and pass back during initialisatiom so client can
        // ignore the notification when syncing ...
        if([action isEqualToString:@"Dismiss"])
        {
            NSString *savedDismissedNotifications = [[NSUserDefaults standardUserDefaults] stringForKey:@"dismissedNotifications"];
            
            NSString *valueToSave;
            
            if(savedDismissedNotifications!=nil){
                valueToSave = [NSString stringWithFormat:@"%@%@,", savedDismissedNotifications, notificationId];
            }else{
                valueToSave = [NSString stringWithFormat:@"%@,", notificationId];
            }
            
            [[NSUserDefaults standardUserDefaults] setObject:valueToSave forKey:@"dismissedNotifications"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        else if([action isEqualToString:@"DeepLink"]){
        
            // dismissedNotifications needs to be renamed to processedNotifications as we want the same behaviour for
            
            if(link != nil && ![link isKindOfClass:[NSNull class]])
            {
                NSURL *url = [NSURL URLWithString:link];
                
                [DonkyPlugin openDeepLink: url];
            }
            
        }
        else if([action isEqualToString:@"Open"]){
        
            // TODO:
            
        }
        
    }
    
    // NOTE: if I call this when the app is in state UIApplicationStateBackground, it fires when resumed ...
    
    if([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground){
        [DonkyPlugin notify: @"handleButtonAction" withData: dict];
    }

    completionHandler(UIBackgroundFetchResultNewData);
}


#if _SWIZZLED_INIT_
// The accessors use an Associative Reference since you can't define a iVar in a category
// http://developer.apple.com/library/ios/#documentation/cocoa/conceptual/objectivec/Chapters/ocAssociativeReferences.html
- (NSMutableArray *)launchNotification
{
    return objc_getAssociatedObject(self, &launchNotificationKey);
}

- (void)setLaunchNotification:(NSDictionary *)aDictionary
{
    objc_setAssociatedObject(self, &launchNotificationKey, aDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)coldstart
{
    return objc_getAssociatedObject(self, &coldstartKey);
}

- (void)setColdstart:(NSNumber *)aNumber
{
    objc_setAssociatedObject(self, &coldstartKey, aNumber, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dealloc
{
    self.launchNotification = nil; // clear the association and release the object
    self.coldstart = nil;
}
#endif

@end
