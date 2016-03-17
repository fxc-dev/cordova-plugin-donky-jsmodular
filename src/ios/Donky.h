#import <Cordova/CDV.h>

@interface Donky : CDVPlugin

- (void) getPlatformInfo:(CDVInvokedUrlCommand*)command;
- (void) registerForPush:(CDVInvokedUrlCommand*)command;

+ (void) notify:(NSString *)event withData:(NSDictionary *)data;

@end