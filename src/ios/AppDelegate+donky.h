

#import "AppDelegate.h"


// Add category to AppDelegate to provid the following methods ...

@interface AppDelegate (donky)

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)application:(UIApplication*)application didRegisterUserNotificationSettings:(nonnull UIUserNotificationSettings *)notificationSettings;


- (void)pushPluginOnApplicationDidBecomeActive:(UIApplication *)application;
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler;


- (id) getCommandInstance:(NSString*)className;

@property (nonatomic, retain) NSDictionary  *launchNotification;
@property (nonatomic, retain) NSNumber  *coldstart;

@end
