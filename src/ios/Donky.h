#import <Cordova/CDV.h>

@interface Donky : CDVPlugin

- (void) greet:(CDVInvokedUrlCommand*)command;
- (void) deviceId:(CDVInvokedUrlCommand*)command;


@end