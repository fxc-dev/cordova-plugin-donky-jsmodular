#import <Cordova/CDV.h>

@interface Donky : CDVPlugin

- (void) getDeviceId:(CDVInvokedUrlCommand*)command;
- (void) registerForPush:(CDVInvokedUrlCommand*)command;

+ (void) notify:(NSString *)event withData:(NSDictionary *)data;

@end