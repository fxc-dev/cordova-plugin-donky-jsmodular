#import <Cordova/CDV.h>

@interface DonkyPlugin : CDVPlugin

- (void) getPlatformInfo:(CDVInvokedUrlCommand*)command;
- (void) registerForPush:(CDVInvokedUrlCommand*)command;
- (void) setBadgeCount:(CDVInvokedUrlCommand*)command; 


+ (void) notify:(NSString *)event withData:(NSDictionary *)data;

@property BOOL coldstart;

@end