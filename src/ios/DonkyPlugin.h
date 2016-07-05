#import <Cordova/CDV.h>




@interface DonkyPlugin : CDVPlugin

@property (nonatomic, copy) NSString *callbackId;

- (void) initialise:(CDVInvokedUrlCommand*)command;
- (void) registerForPush:(CDVInvokedUrlCommand*)command;
- (void) unregisterForPush:(CDVInvokedUrlCommand*)command;
- (void) setBadgeCount:(CDVInvokedUrlCommand*)command; 
- (void) openDeepLink:(CDVInvokedUrlCommand*)command;
+ (Boolean)openDeepLink:(NSURL*)url;
+ (NSString*) getCurrentTimestamp;

- (void) notificationReceived:(NSDictionary *)notificationMessage;

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

+ (void) notify:(NSString *)event withData:(NSDictionary *)data;

#if _HANDLE_USER_ACTIVITY_
/**
 *  Try to hanlde application launch when user clicked on the link.
 *
 *  @param userActivity object with information about the application launch
 *
 *  @return <code>true</code> - if this is a universal link and it is defined in config.xml; otherwise - <code>false</code>
 */
- (BOOL)handleUserActivity:(NSUserActivity *)userActivity;
#endif


#if _SWIZZLED_INIT_
@property BOOL coldstart;
#endif

@end