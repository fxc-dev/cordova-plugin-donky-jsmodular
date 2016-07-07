#import <Cordova/CDV.h>



@interface DonkyPlugin : CDVPlugin

@property (nonatomic, copy) NSString *callbackId;

- (void) initialise:(CDVInvokedUrlCommand*)command;
- (void) hasPermission:(CDVInvokedUrlCommand *)command; 
- (void) registerForPush:(CDVInvokedUrlCommand*)command;
- (void) unregisterForPush:(CDVInvokedUrlCommand*)command;
- (void) setBadgeCount:(CDVInvokedUrlCommand*)command; 
- (void) openDeepLink:(CDVInvokedUrlCommand*)command;
+ (Boolean)openDeepLink:(NSURL*)url;
+ (NSString*) getCurrentTimestamp;

- (void) notificationReceived:(NSDictionary *)notificationMessage;
- (void) handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)didRegisterUserNotificationSettings:(nonnull UIUserNotificationSettings *)notificationSettings;


+ (void) notify:(NSString *)event withData:(NSDictionary *)data;

@property BOOL coldstart;
@property NSDictionary *launchNotification;

@end