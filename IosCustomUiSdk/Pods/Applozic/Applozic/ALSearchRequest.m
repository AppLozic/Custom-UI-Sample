//
//  ALSearchRequest.m
//  Applozic
//
//  Created by Sunil on 05/09/19.
//  Copyright © 2019 applozic Inc. All rights reserved.
//

#import "ALSearchRequest.h"
#import "NSString+Encode.h"

@implementation ALSearchRequest

-(NSString*)getParamString {
    NSString * paramString;
    if(self.channelKey) {
        paramString = [NSString stringWithFormat:@"groupId=%@&content=%@",self.channelKey,[self.searchText urlEncodeUsingNSUTF8StringEncoding]];
    }else if (self.userId) {
        paramString = [NSString stringWithFormat:@"userId=%@&content=%@",[self.userId urlEncodeUsingNSUTF8StringEncoding],[self.searchText urlEncodeUsingNSUTF8StringEncoding]];
    }

    if(self.channelKey == nil && self.userId == nil && self.searchText && self.searchText.length > 0) {
        paramString = [NSString stringWithFormat:@"content=%@",[self.searchText urlEncodeUsingNSUTF8StringEncoding]];
    }
    return paramString;
}

@end
