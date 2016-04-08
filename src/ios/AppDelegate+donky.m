
#import "AppDelegate+donky.h"
#import <objc/runtime.h>
#import "Donky.h"


@implementation AppDelegate (donky)


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

/**
 * This one is called if the notification is tapped (and app is backgrounded)
 * If app is not running and this fires, it all happens before cordova and donky are ready to process it
 */
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    UIApplicationState state =[[UIApplication sharedApplication] applicationState];
    
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: userInfo, @"userInfo", @(state), @"applicationState", nil];
    
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive){
        
    }
    
    [Donky notify: @"pushNotification" withData: dict];
    completionHandler(UIBackgroundFetchResultNewData);
}

/**
 * This one is called if interactive button is tapped (and app is backgrounded)
 */
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    UIApplicationState state =[[UIApplication sharedApplication] applicationState];
    
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys: identifier, @"identifier", userInfo, @"userInfo", @(state), @"applicationState", nil];

    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive){
        
    }
    
    [Donky notify: @"handleButtonAction" withData: dict];
    completionHandler(UIBackgroundFetchResultNewData);
}

@end
