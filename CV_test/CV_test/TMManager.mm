//
//  TemplateMatchingManager.m
//  CV_test
//
//  Created by Daniil Lobanov on 22.07.16.
//  Copyright © 2016 Daniil Lobanov. All rights reserved.
//

#import "TMManager.h"

@implementation TMManager

+ (TMManager *) sharedInstance
{
    static TMManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TMManager alloc] init];
    });
    
    return instance;
}


@end
