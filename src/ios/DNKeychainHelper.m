//  DNKeychainHelper.m
//  NAAS Core SDK Container
//
//  Created by Donky Networks on 19/02/2015.
//  Copyright (c) 2015 Donky Networks Ltd. All rights reserved.
//

#if !__has_feature(objc_arc)
#error Donky SDK must be built with ARC.
// You can turn on ARC for only Donky Class files by adding -fobjc-arc to the build phase for each of its files.
#endif

#import "DNKeychainHelper.h"
#import "DNKeychainItemWrapper.h"
//#import "DNConstants.h"

@implementation DNKeychainHelper

+ (void)saveObjectToKeychain:(id) object withKey:(NSString *) key {
    [DNKeychainItemWrapper setObject:object forKey:key];
}

+ (id)objectForKey:(NSString *) key {
    return [DNKeychainItemWrapper objectForKey:key];
}

@end
