//
//  ADJThirdPartySharingResult.m
//  Adjust
//
//  Created by Aditi Agrawal on 10.04.26.
//  Copyright © 2026 Adjust GmbH. All rights reserved.
//

#import "ADJThirdPartySharingResult.h"

@implementation ADJThirdPartySharingResult

- (instancetype)initWithThirdPartySharingSettings:(NSString *)thirdPartySharingSettingsJson {
    self = [super init];

    if (self == nil) {
        return nil;
    }

    self.thirdPartySharingSettingsJson = [thirdPartySharingSettingsJson copy];

    return self;
}

- (BOOL)isEqualToThirdPartySharingResult:(ADJThirdPartySharingResult *)thirdPartySharingResult {
    if (thirdPartySharingResult == nil) {
        return NO;
    }

    if (self.thirdPartySharingSettingsJson == thirdPartySharingResult.thirdPartySharingSettingsJson) {
        return YES;
    }

    return [self.thirdPartySharingSettingsJson isEqualToString:thirdPartySharingResult.thirdPartySharingSettingsJson];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"thirdPartySharingSettings:%@", self.thirdPartySharingSettingsJson];
}

#pragma mark - NSObject protocol methods

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[ADJThirdPartySharingResult class]]) {
        return NO;
    }

    return [self isEqualToThirdPartySharingResult:(ADJThirdPartySharingResult *)object];
}

- (NSUInteger)hash {
    return [self.thirdPartySharingSettingsJson hash];
}

#pragma mark - NSCopying protocol methods

- (id)copyWithZone:(NSZone *)zone {
    ADJThirdPartySharingResult *copy = [[[self class] allocWithZone:zone] init];

    if (copy) {
        copy.thirdPartySharingSettingsJson = [self.thirdPartySharingSettingsJson copyWithZone:zone];
    }

    return copy;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    if (self.thirdPartySharingSettingsJson != nil) {
        [dictionary setObject:self.thirdPartySharingSettingsJson forKey:@"thirdPartySharingSettingsJson"];
    }

    return dictionary;
}

@end
