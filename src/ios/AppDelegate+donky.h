

#import "AppDelegate.h"


// Add category to AppDelegate to provid the following methods ...

@interface AppDelegate (donky)

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;

- (void)pushPluginOnApplicationDidBecomeActive:(UIApplication *)application;
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler;

#if _HANDLE_USER_ACTIVITY_
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler;
#endif

- (id) getCommandInstance:(NSString*)className;

#if _SWIZZLED_INIT_
@property (nonatomic, retain) NSDictionary  *launchNotification;
@property (nonatomic, retain) NSNumber  *coldstart;
#endif

@end
