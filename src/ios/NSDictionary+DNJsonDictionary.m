//
//  NSDictionary+DNJsonDictionary.m
//  cordovaPlayground
//
//  Created by Stevan Lepojevic on 17/03/2016.
//
//

#import "NSDictionary+DNJsonDictionary.h"

@implementation NSDictionary (DNJsonDictionary)

- (NSString *)jsonString {
    
    NSError *error;
    
    // serialize data to json
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    if (!error) {
        return jsonString;
    }
    
    else {
        NSLog(@"Error %@:", [error localizedDescription]);
    }
    
    return nil;
}

@end
