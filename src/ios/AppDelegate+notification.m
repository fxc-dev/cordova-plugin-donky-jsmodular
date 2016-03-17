
#import "AppDelegate+notification.h"
#import <objc/runtime.h>
#import "Donky.h"


@implementation AppDelegate (notification)


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {    

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
    [Donky notify: @"pushRegistrationSucceeded" withData: dict];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: [error localizedDescription], @"error", nil];
    [Donky notify: @"pushRegistrationFailed" withData: dict];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: userInfo, @"userInfo", nil];
    [Donky notify: @"pushNotification" withData: dict];
    completionHandler(UIBackgroundFetchResultNewData);
}

//For interactive notification only
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: identifier, @"identifier", userInfo, @"userInfo", nil];
    [Donky notify: @"handleButtonAction" withData: dict];
    completionHandler(UIBackgroundFetchResultNewData);
}

@end
