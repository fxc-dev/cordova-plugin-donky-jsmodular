
#import "AppDelegate+donky.h"
#import <objc/runtime.h>
#import "DonkyPlugin.h"

static char launchNotificationKey;
static char coldstartKey;

@implementation AppDelegate (donky)

- (id) getCommandInstance:(NSString*)className
{
    return [self.viewController getCommandInstance:className];
}


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
            self.launchNotification = [launchOptions objectForKey: @"UIApplicationLaunchOptionsRemoteNotificationKey"];
            self.coldstart = [NSNumber numberWithBool:YES];
            NSLog(@"coldstart: %@", self.launchNotification);
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
        NSLog(@"setting donkyPlugin.launchNotification to %@", donkyPlugin.launchNotification);
        donkyPlugin.launchNotification = self.launchNotification;

        self.coldstart = [NSNumber numberWithBool:NO];
        self.launchNotification = nil;
    }
}

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
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    
    [donkyPlugin notificationReceived: dict];
    
    completionHandler(UIBackgroundFetchResultNewData);
}

/**
 * This one is called if interactive button is tapped (and app is backgrounded)
 */
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    NSLog(@"AppDelegate(donky)::handleActionWithIdentifier");
    
    DonkyPlugin *donkyPlugin = [self getCommandInstance:@"donky"];
    
    [donkyPlugin handleActionWithIdentifier: identifier forRemoteNotification: userInfo];
    
    completionHandler(UIBackgroundFetchResultNewData);
}


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

@end
