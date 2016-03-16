
#import "AppDelegate+notification.h"
#import <objc/runtime.h>


@implementation AppDelegate (notification)


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog([NSString stringWithFormat:@"Device Token=%@",deviceToken]);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSString *str = [NSString stringWithFormat: @"Error: %@", error];
    NSLog(@"didFailToRegisterForRemoteNotificationsWithError - %@",str);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSLog(@"didReceiveRemoteNotification with userInfo: %@", userInfo);
}


//For interactive notification only
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    NSLog(@"handleActionWithIdentifier with userInfo: %@", userInfo);
}

@end
