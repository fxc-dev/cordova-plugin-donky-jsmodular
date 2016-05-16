
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

#if 0
    NSMutableString *hexString = nil;
    if (deviceToken) {
        const unsigned char *dataBuffer = (const unsigned char *) [deviceToken bytes];
        
        NSUInteger dataLength = [deviceToken length];
        hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
        
        for (int i = 0; i < dataLength; ++i) {
            [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long) dataBuffer[i]]];
        }
    }

    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: hexString, @"deviceToken", nil];
    [DonkyPlugin notify: @"pushRegistrationSucceeded" withData: dict];
#endif    
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    [donkyPlugin didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: [error localizedDescription], @"error", nil];
    [DonkyPlugin notify: @"pushRegistrationFailed" withData: dict];
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
    
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: identifier, @"identifier", userInfo, @"userInfo", @(state), @"applicationState", nil];

    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive){
        //TODO: store somewhere that the plugin can access in pluginInitialize - it can then the client
    }
    
    [DonkyPlugin notify: @"handleButtonAction" withData: dict];
    completionHandler(UIBackgroundFetchResultNewData);
}

#if _HANDLE_USER_ACTIVITY_
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    // ignore activities that are not for Universal Links
    if (![userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] || userActivity.webpageURL == nil) {
        return NO;
    }
    
    // get instance of the plugin and let it handle the userActivity object
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    
    if (donkyPlugin == nil) {
        return NO;
    }
    
    return [donkyPlugin handleUserActivity:userActivity];
}
#endif


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
