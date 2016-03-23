//
//  DNKeychainItemWrapper.m
//  NAAS Core SDK Container
//
//  Created by Donky Networks on 19/02/2015.
//  Copyright (c) 2015 Donky Networks Ltd. All rights reserved.
//

#if !__has_feature(objc_arc)
#error Donky SDK must be built with ARC.
// You can turn on ARC for only Donky Class files by adding -fobjc-arc to the build phase for each of its files.
#endif

#import "DNKeychainItemWrapper.h"

@interface DNKeychainItemWrapper ()

@end

@implementation DNKeychainItemWrapper

+ (void)setObject:(id)inObject forKey:(id)key {
    
    if (!inObject || !key) {
        NSLog(@"can't save an item with no inObject or no Key");
        return;
    }

    NSMutableDictionary *keychainQuery = [DNKeychainItemWrapper getKeychainQuery:key];

    SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    keychainQuery[(__bridge id) kSecValueData] = [NSKeyedArchiver archivedDataWithRootObject:inObject];
    keychainQuery[(__bridge id) kSecAttrAccessible] = (__bridge id) kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);

    if (status != noErr) {
        NSLog(@"Status error: %d", (int)status);
    }
}

+ (id)objectForKey:(id)key {
    
    if (!key) {
        NSLog(@"Can't find keychain item with a nil key...");
        return nil;
    }
    
    id ret = nil;
    
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    
    keychainQuery[(__bridge id) kSecReturnData] = (id) kCFBooleanTrue;
    keychainQuery[(__bridge id) kSecMatchLimit] = (__bridge id) kSecMatchLimitOne;

    CFDataRef keyData = NULL;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData);
    
    keychainQuery[(__bridge id) kSecAttrAccessible] = (__bridge id) kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;

    if (status == noErr) {
        @try {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
        }
        @catch (NSException *e) {
            NSLog(@"exception from keychain: %@", [e reason]);
        }
    }
    else if (!ret && status == noErr) {
        NSLog(@"Status error: %d", (int)status);
    }
    
    if (keyData) {
        CFRelease(keyData);
    }
    
    return ret;
}

+ (void)keyChainDeleteKey:(NSString *)key {
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    if (status != noErr) {
        NSLog(@"Error deleting item %@ : %d", key, (int)status);
    }
}

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)key {
    return [@{(__bridge id) kSecClass : (__bridge id) kSecClassGenericPassword,
              (__bridge id) kSecAttrService : key,
              (__bridge id) kSecAttrAccount : key
              } mutableCopy];
}

@end