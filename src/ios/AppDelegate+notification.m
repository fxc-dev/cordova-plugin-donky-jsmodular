
#import "AppDelegate+notification.h"
#import <objc/runtime.h>
#import "Donky.h"


@implementation AppDelegate (notification)


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *message = [NSString stringWithFormat:@"Device Token=%@",deviceToken];
    NSLog(@"%@",message);
    [Donky notify: @"donkyevent" withData: message];

}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSString *str = [NSString stringWithFormat: @"Error: %@", error];
    NSString *message = [NSString stringWithFormat:@"didFailToRegisterForRemoteNotificationsWithError - %@",str];
    NSLog(@"%@",message);
    [Donky notify: @"donkyevent" withData: message];

}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSString *message = [NSString stringWithFormat:@"didReceiveRemoteNotification with userInfo: %@", userInfo];
    NSLog(@"%@",message);
    [Donky notify: @"donkyevent" withData: message];

}


//For interactive notification only
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    NSString *message = [NSString stringWithFormat:@"handleActionWithIdentifier with userInfo: %@", userInfo];
    NSLog(@"%@",message);
    [Donky notify: @"donkyevent" withData: message];
}

@end
