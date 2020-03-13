//
//  ALPushNotificationService.m
//  ChatApp
//
//  Created by devashish on 28/09/2015.
//  Copyright (c) 2015 AppLogic. All rights reserved.
//

#import "ALPushNotificationService.h"
#import "ALMessageDBService.h"
#import "ALUserDetail.h"
#import "ALUserDefaultsHandler.h"
#import "ALChatViewController.h"
#import "ALMessagesViewController.h"
#import "ALPushAssist.h"
#import "ALUserService.h"
#import "ALNotificationView.h"
#import "ALRegisterUserClientService.h"
#import "ALAppLocalNotifications.h"
#import <Applozic/ApplozicClient.h>

@implementation ALPushNotificationService


-(BOOL) isApplozicNotification:(NSDictionary *)dictionary
{
    NSString *type = (NSString *)[dictionary valueForKey:@"AL_KEY"];
    if (!type.length) {
        return NO;
    }
    ALSLog(ALLoggerSeverityInfo, @"APNs GOT NEW MESSAGE & NOTIFICATION TYPE :: %@", type);
    BOOL prefixCheck = ([type hasPrefix:APPLOZIC_PREFIX]) || ([type hasPrefix:@"MT_"]);
    return (type != nil && ([self.notificationTypes.allValues containsObject:type] || prefixCheck));
}

-(BOOL) processPushNotification:(NSDictionary *)dictionary updateUI:(NSNumber *)updateUI
{

    ALSLog(ALLoggerSeverityInfo, @"APNS_DICTIONARY :: %@",dictionary.description);
    ALSLog(ALLoggerSeverityInfo, @"UPDATE UI VALUE :: %@",updateUI);
    ALSLog(ALLoggerSeverityInfo, @"UPDATE UI :: %@", ([updateUI isEqualToNumber:[NSNumber numberWithInt:1]]) ? @"ACTIVE" : @"BACKGROUND/INACTIVE");

    UIApplicationState state = [[UIApplication sharedApplication] applicationState];

    if ([self isApplozicNotification:dictionary])
    {
        NSString * alertValue;
        ALMessageDBService *messageDBService = [[ALMessageDBService alloc] init];
        alertValue = ([ALUserDefaultsHandler getNotificationMode] == AL_NOTIFICATION_DISABLE ? @"" : [[dictionary valueForKey:@"aps"] valueForKey:@"alert"]);

        self.alSyncCallService = [[ALSyncCallService alloc] init];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:updateUI forKey:@"updateUI"];

        NSString *type = (NSString *)[dictionary valueForKey:@"AL_KEY"];
        NSString *alValueJson = (NSString *)[dictionary valueForKey:@"AL_VALUE"];

        NSData* data = [alValueJson dataUsingEncoding:NSUTF8StringEncoding];

        NSError *error = nil;
        NSDictionary *theMessageDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSString *notificationMsg = [theMessageDict valueForKey:@"message"];
        NSDictionary * metadataDictionary =  [theMessageDict valueForKey:@"messageMetaData"];

        //CHECK for any special messages...
        if ([self processMetaData:theMessageDict withAlert:alertValue withUpdateUI:updateUI])
        {
            return true;
        }

        NSString *notificationId = (NSString *)[theMessageDict valueForKey:@"id"];

        if(notificationId && [ALUserDefaultsHandler isNotificationProcessd:notificationId])
        {
            ALSLog(ALLoggerSeverityInfo, @"Returning from ALPUSH because notificationId is already processed... %@",notificationId);
            BOOL isInactive = ([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive);
            if(isInactive && ([type isEqualToString:self.notificationTypes[@(AL_SYNC)]] || [type isEqualToString:self.notificationTypes[@(AL_MESSAGE_SENT)]]))
            {
                ALSLog(ALLoggerSeverityInfo, @"ALAPNs : APP_IS_INACTIVE");
                if([type isEqualToString:self.notificationTypes[@(AL_MESSAGE_SENT)]] ){
                    if(([[notificationMsg componentsSeparatedByString:@":"][1] isEqualToString:[ALUserDefaultsHandler getDeviceKeyString]]))
                    {
                        ALSLog(ALLoggerSeverityInfo, @"APNS: Sent by self-device ignore");
                        return YES;
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self assitingNotificationMessage:notificationMsg andDictionary:dict withMetadata:metadataDictionary];
                });
            }
            else
            {
                ALSLog(ALLoggerSeverityInfo, @"ALAPNs : APP_IS_ACTIVE");
            }

            return true;
        }
        //TODO : check if notification is alreday received and processed...

        if ([type isEqualToString:self.notificationTypes[@(AL_SYNC)]]) // APPLOZIC_01 //
        {

            ALSLog(ALLoggerSeverityInfo, @"ALPushNotificationService's SYNC CALL");
            [dict setObject:(alertValue ? alertValue : @"") forKey:@"alertValue"];
            [self assitingNotificationMessage:notificationMsg andDictionary:dict withMetadata:metadataDictionary];
            if (state == UIApplicationStateActive) {
                [ALMessageService getLatestMessageForUser:[ALUserDefaultsHandler getDeviceKeyString] withDelegate:self.realTimeUpdate
                                           withCompletion:^(NSMutableArray *message, NSError *error) {

                }];
            }
        }
        else if ([type isEqualToString:@"MESSAGE_SENT"]||[type isEqualToString:self.notificationTypes[@(AL_MESSAGE_SENT)]])
        {

            if (state == UIApplicationStateActive) {

                ALSLog(ALLoggerSeverityInfo, @"APNS: APPLOZIC_02 ARRIVED");

                NSString *alValueJson = (NSString *)[dictionary valueForKey:@"AL_VALUE"];
                NSData* data = [alValueJson dataUsingEncoding:NSUTF8StringEncoding];

                NSError *error = nil;
                NSDictionary *theMessageDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                NSString*  notificationMsg = [theMessageDict valueForKey:@"message"];
                ALSLog(ALLoggerSeverityInfo, @"\nNotification Message:%@\n\nDeviceString:%@\n",notificationMsg,
                       [ALUserDefaultsHandler getDeviceKeyString]);

                if(([[notificationMsg componentsSeparatedByString:@":"][1] isEqualToString:[ALUserDefaultsHandler getDeviceKeyString]]))
                {
                    ALSLog(ALLoggerSeverityInfo, @"APNS: Sent by self-device");
                    return YES;
                }

                [ALMessageService getLatestMessageForUser:[ALUserDefaultsHandler getDeviceKeyString] withDelegate:self.realTimeUpdate  withCompletion:^(NSMutableArray *message, NSError *error) {
                    ALSLog(ALLoggerSeverityInfo, @"APPLOZIC_02 Sync Call Completed");
                }];

            }
        }
        else if ([type isEqualToString:@"MT_MESSAGE_DELIVERED"]||[type isEqualToString:self.notificationTypes[@(AL_DELIVERED)]]){

            NSArray *deliveryParts = [[theMessageDict objectForKey:@"message"] componentsSeparatedByString:@","];
            NSString * pairedKey = deliveryParts[0];
            [self.alSyncCallService updateMessageDeliveryReport:pairedKey withStatus:DELIVERED];
            if(self.realTimeUpdate){
                ALMessage *message = [messageDBService getMessageByKey:pairedKey];
                if(message){
                    [self.realTimeUpdate onMessageDelivered:message];
                }
            }
            [[ NSNotificationCenter defaultCenter] postNotificationName:@"report_DELIVERED" object:deliveryParts[0] userInfo:dictionary];
        }
        else if ([type isEqualToString:@"MT_MESSAGE_DELIVERED_READ"]||[type isEqualToString:self.notificationTypes[@(AL_MESSAGE_DELIVERED_AND_READ)]]){

            NSArray  * deliveryParts = [[theMessageDict objectForKey:@"message"] componentsSeparatedByString:@","];
            NSString * pairedKey = deliveryParts[0];
            NSString * contactId = deliveryParts.count>1 ? deliveryParts[1]:nil;

            [self.alSyncCallService updateMessageDeliveryReport:pairedKey withStatus:DELIVERED_AND_READ];
            [[ NSNotificationCenter defaultCenter] postNotificationName:@"report_DELIVERED_READ" object:deliveryParts[0] userInfo:dictionary];
            if(self.realTimeUpdate){
                ALMessageDBService *messageDbService = [[ALMessageDBService alloc]init];
                ALMessage* message = [messageDbService getMessageByKey:pairedKey];
                if(message){
                    [self.realTimeUpdate onMessageDeliveredAndRead:message withUserId:contactId];
                }
            }
        }

        else if ([type isEqualToString:self.notificationTypes[@(AL_CONVERSATION_DELETED)]]){

            [messageDBService deleteAllMessagesByContact:notificationMsg orChannelKey:nil];
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_DELETE_MESSAGE)]]){

            [messageDBService deleteMessageByKey: notificationMsg];
            if(self.realTimeUpdate){
                [self.realTimeUpdate onMessageDeleted:notificationMsg];
            }
            /*
             NSString * messageKey = [[theMessageDict valueForKey:@"message"] componentsSeparatedByString:@","][0];
             [[NSNotificationCenter defaultCenter] postNotificationName:@"NOTIFY_MESSAGE_DELETED" object:messageKey];
             */
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_CONVERSATION_DELIVERED_AND_READ)]]){

            [self.alSyncCallService updateDeliveryStatusForContact:notificationMsg withStatus:DELIVERED_AND_READ];
            [[ NSNotificationCenter defaultCenter] postNotificationName:@"report_CONVERSATION_DELIVERED_READ" object:notificationMsg];
            if(self.realTimeUpdate){
                [self.realTimeUpdate onAllMessagesRead:notificationMsg];
            }

        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_USER_CONNECTED)]]){

            ALUserDetail *alUserDetail = [[ALUserDetail alloc] init];
            alUserDetail.userId = notificationMsg;
            alUserDetail.lastSeenAtTime = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] * 1000];
            alUserDetail.connected = YES;
            [self.alSyncCallService updateConnectedStatus: alUserDetail];
            [[ NSNotificationCenter defaultCenter] postNotificationName:@"update_USER_STATUS" object:alUserDetail];
            if(self.realTimeUpdate){
                [self.realTimeUpdate onUpdateLastSeenAtStatus: alUserDetail];
            }
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_USER_DISCONNECTED)]]){

            NSArray *parts = [notificationMsg componentsSeparatedByString:@","];

            ALUserDetail *alUserDetail = [[ALUserDetail alloc] init];
            alUserDetail.userId = parts[0];
            alUserDetail.lastSeenAtTime = [NSNumber numberWithDouble:[parts[1] doubleValue]];
            alUserDetail.connected = NO;
            [self.alSyncCallService updateConnectedStatus: alUserDetail];
            [[ NSNotificationCenter defaultCenter] postNotificationName:@"update_USER_STATUS" object:alUserDetail];
            if(self.realTimeUpdate){
                [self.realTimeUpdate onUpdateLastSeenAtStatus: alUserDetail];
            }

        }
        else if ([type isEqualToString:@"APPLOZIC_15"]){
            ALChannelService *channelService = [[ALChannelService alloc] init];
            [channelService syncCallForChannel];
            // TODO HANDLE
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_CONVERSATION_DELETED_NEW)]] || [type isEqualToString:@"CONVERSATION_DELETED"]){

            NSArray *parts = [notificationMsg componentsSeparatedByString:@","];
            NSString * contactID = parts[0];
            NSString * conversationID = parts[1];

            [self.alSyncCallService updateTableAtConversationDeleteForContact:contactID
                                                               ConversationID:conversationID
                                                                   ChannelKey:nil];
            if(self.realTimeUpdate){
                [self.realTimeUpdate onConversationDelete:contactID withGroupId:0];
            }
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_GROUP_CONVERSATION_DELETED)]] || [type isEqualToString:@"GROUP_CONVERSATION_DELETED"]){

            NSNumber * groupID = [NSNumber numberWithInt:[notificationMsg intValue]];
            [self.alSyncCallService updateTableAtConversationDeleteForContact:nil
                                                               ConversationID:nil
                                                                   ChannelKey:groupID];
            if(self.realTimeUpdate){
                [self.realTimeUpdate onConversationDelete:nil withGroupId:groupID];
            }
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_USER_BLOCK)]]){
            //            NSLog(@"BLOCKED / BLOCKED BY");

            if([self processUserBlockNotification:theMessageDict andUserBlockFlag:YES])
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"USER_BLOCK_NOTIFICATION" object:nil];
            }


        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_USER_UNBLOCK)]])
        {
            //            NSLog(@"UNBLOCKED / UNBLOCKED BY");
            if([self processUserBlockNotification:theMessageDict andUserBlockFlag:NO])
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"USER_UNBLOCK_NOTIFICATION" object:nil];
            }

        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_TEST_NOTIFICATION)]])
        {
            ALSLog(ALLoggerSeverityInfo, @"Process Push Notification APPLOZIC_20");
        }
        else if ([type isEqualToString:self.notificationTypes[@(AL_USER_DETAIL_CHANGED)]] || [type isEqualToString:self.notificationTypes[@(AL_USER_DELETE_NOTIFICATION)]])
        {
            NSString * userId = notificationMsg;
            if(![userId isEqualToString:[ALUserDefaultsHandler getUserId]])
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"USER_DETAILS_UPDATE_CALL" object:userId];
            }
            if(self.realTimeUpdate){
                [ALUserService updateUserDetail:userId withCompletion:^(ALUserDetail *userDetail) {
                    [self.realTimeUpdate onUserDetailsUpdate:userDetail];
                }];
            }
        }
        else if([type isEqualToString:self.notificationTypes[@(AL_CONVERSATION_READ)]]){
            //Conversation read for user
            ALUserService *channelService = [[ALUserService alloc]init];
            NSString * userId = [theMessageDict objectForKey:@"message"];
            [channelService updateConversationReadWithUserId:userId withDelegate:self.realTimeUpdate];

        }
        else if([type isEqualToString:self.notificationTypes[@(AL_GROUP_CONVERSATION_READ)]]){
            //Conversation read for channel
            ALChannelService *channelService = [[ALChannelService alloc]init];
            NSNumber * channelKey  = [NSNumber numberWithInt:[[theMessageDict objectForKey:@"message"] intValue]];
            [channelService updateConversationReadWithGroupId:channelKey withDelegate:self.realTimeUpdate];
        } else if([type isEqualToString:self.notificationTypes[@(AL_USER_MUTE_NOTIFICATION)]]){

            NSArray *parts = [[theMessageDict objectForKey:@"message"] componentsSeparatedByString:@":"];
            NSString * userId = parts[0];
            NSString * flag = parts[1];

            ALContactDBService *contactDataBaseService = [[ALContactDBService alloc] init];

            if([flag isEqualToString:@"0"]){
                ALUserDetail *userDetail =  [contactDataBaseService updateMuteAfterTime:0 andUserId:userId];
                if(self.realTimeUpdate){
                    [self.realTimeUpdate onUserMuteStatus:userDetail];
                }
            }else if([flag isEqualToString:@"1"]) {
                ALUserService *userService = [[ALUserService alloc]init];

                [userService getMutedUserListWithDelegate:self.realTimeUpdate withCompletion:^(NSMutableArray *userDetailArray, NSError *error) {

                }];
            }

        }else if([type isEqualToString:self.notificationTypes[@(AL_MESSAGE_METADATA_UPDATE)]]){
            NSString* keyString;
            NSString* deviceKey;
            @try
            {
                NSDictionary * message = [theMessageDict objectForKey:@"message"];
                ALMessage *alMessage = [[ALMessage alloc] initWithDictonary:message];
                keyString = alMessage.key;
                deviceKey = alMessage.deviceKey;
            } @catch (NSException * exp) {
                ALSLog(ALLoggerSeverityError, @"Error while fetching message from dictionary : %@", exp.description);
                @try
                {
                    NSString * messageKey = [theMessageDict valueForKey:@"message"];
                    if(messageKey){
                        ALMessageDBService * messagedbService = [[ALMessageDBService alloc]init];
                        DB_Message * dbMessage  = (DB_Message *)[messagedbService getMessageByKey:@"key" value:messageKey];
                        if (dbMessage != nil) {
                            deviceKey = dbMessage.deviceKey;
                        }
                    }
                } @catch (NSException * exp) {
                    ALSLog(ALLoggerSeverityError, @"Error while fetching message from dictionary : %@", exp.description);
                }
            }
            if (deviceKey != nil && [deviceKey isEqualToString:[ALUserDefaultsHandler getDeviceKeyString]]) {
                return TRUE;
            }
            [ALMessageService syncMessageMetaData:[ALUserDefaultsHandler getDeviceKeyString] withCompletion:^(NSMutableArray *message, NSError *error) {
                ALSLog(ALLoggerSeverityInfo, @"Successfully updated message metadata");
            }];
        }
        else
        {
            ALSLog(ALLoggerSeverityInfo, @"APNs NOTIFICATION \"%@\" IS NOT HANDLED",type);
        }

        return TRUE;
    }

    return FALSE;
}

-(void)assitingNotificationMessage:(NSString*)notificationMsg andDictionary:(NSMutableDictionary*)dict withMetadata:(NSDictionary *)messageMetaData
{

    if([self isNotificationDisabled:messageMetaData]){
        return;
    }

    ALPushAssist* assistant = [[ALPushAssist alloc] init];
    if(!assistant.isOurViewOnTop)
    {
        [dict setObject:@"apple push notification.." forKey:@"Calledfrom"];
        [assistant assist:notificationMsg and:dict ofUser:notificationMsg];
    }
    else
    {
        ALSLog(ALLoggerSeverityInfo, @"ASSISTING : OUR_VIEW_IS_IN_TOP");
        // Message View Controller
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pushNotification"
                                                            object:notificationMsg
                                                          userInfo:dict];
        //Chat View Controller
        [[NSNotificationCenter defaultCenter] postNotificationName:@"notificationIndividualChat"
                                                            object:notificationMsg
                                                          userInfo:dict];
    }

}

-(BOOL)isNotificationDisabled:(NSDictionary*)messageMetaData{

    if(!messageMetaData){
        return NO;
    }

    NSString * notificationFlag = [messageMetaData objectForKey:@"show"];
    return (messageMetaData && notificationFlag && [notificationFlag isEqualToString:@"false"]);
}

-(BOOL)processMetaData:(NSDictionary*)dict withAlert:alertValue withUpdateUI:(NSNumber *)updateUI
{

    NSDictionary * metadataDictionary =  [dict valueForKey:@"messageMetaData"];

    if( metadataDictionary && [metadataDictionary valueForKey:APPLOZIC_CATEGORY_KEY] && [[metadataDictionary valueForKey:APPLOZIC_CATEGORY_KEY] isEqualToString:AL_CATEGORY_PUSHNNOTIFICATION])
    {
        ALSLog(ALLoggerSeverityInfo, @" Puhs notification with category, just open app %@",[metadataDictionary valueForKey:APPLOZIC_CATEGORY_KEY]);
        if([updateUI intValue] == APP_STATE_ACTIVE)
        {
            [ALNotificationView showPromotionalNotifications:alertValue];
        }

        return true;
    }
    return false;
}

-(BOOL)processUserBlockNotification:(NSDictionary *)theMessageDict andUserBlockFlag:(BOOL)flag
{
    NSArray *mqttMSGArray = [[theMessageDict valueForKey:@"message"] componentsSeparatedByString:@":"];
    NSString *BlockType = mqttMSGArray[0];
    NSString *userId = mqttMSGArray[1];
    ALContactDBService *dbService = [ALContactDBService new];
    if([BlockType isEqualToString:@"BLOCKED_BY"] || [BlockType isEqualToString:@"UNBLOCKED_BY"])
    {
        [dbService setBlockByUser:userId andBlockedByState:flag];
    } else if([BlockType isEqualToString:@"BLOCKED_TO"] || [BlockType isEqualToString:@"UNBLOCKED_TO"])
    {
        [dbService setBlockUser:userId andBlockedState:flag];
    } else {
        return NO;
    }

    if(self.realTimeUpdate){
        [self.realTimeUpdate onUserBlockedOrUnBlocked:userId andBlockFlag:flag];
    }
    return  YES;
}

-(void)notificationArrivedToApplication:(UIApplication*)application withDictionary:(NSDictionary *)userInfo
{
    if(application.applicationState == UIApplicationStateInactive)
    {
        /* 
         # App is transitioning from background to foreground (user taps notification), do what you need when user taps here!

         # SYNC AND PUSH DETAIL VIEW CONTROLLER
         ALSLog(ALLoggerSeverityInfo, @"APP_STATE_INACTIVE APP_DELEGATE");
         */
        [self processPushNotification:userInfo updateUI:[NSNumber numberWithInt:APP_STATE_INACTIVE]];
    }
    else if(application.applicationState == UIApplicationStateActive)
    {
        /*
         # App is currently active, can update badges count here

         # SYNC AND PUSH DETAIL VIEW CONTROLLER
         ALSLog(ALLoggerSeverityInfo, @"APP_STATE_ACTIVE APP_DELEGATE");
         */
        [self processPushNotification:userInfo updateUI:[NSNumber numberWithInt:APP_STATE_ACTIVE]];
    }
    else if(application.applicationState == UIApplicationStateBackground)
    {
        /* # App is in background, if content-available key of your notification is set to 1, poll to your backend to retrieve data and update your interface here

         # SYNC ONLY
         ALSLog(ALLoggerSeverityInfo, @"APP_STATE_BACKGROUND APP_DELEGATE");
         */
        [self processPushNotification:userInfo updateUI:[NSNumber numberWithInt:APP_STATE_BACKGROUND]];
    }
}

+(void)applicationEntersForeground {}

+(void)userSync
{
    ALUserService *userService = [ALUserService new];
    [userService blockUserSync: [ALUserDefaultsHandler getUserBlockLastTimeStamp]];
}

-(BOOL) checkForLaunchNotification:(NSDictionary *)dictionary
{
    [ALRegisterUserClientService isAppUpdated];

    ALAppLocalNotifications *localNotification = [ALAppLocalNotifications appLocalNotificationHandler];
    [localNotification dataConnectionNotificationHandler];

    if(dictionary != nil){

        NSDictionary *notification = [dictionary objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];

        if(notification ){
            [self processPushNotification:notification updateUI:[NSNumber numberWithInt:APP_STATE_INACTIVE]];

        }

    }
    return false;
}

-(NSDictionary *)notificationTypes {
    static  NSDictionary * dictionary;
    if (!dictionary)
    {
        dictionary = @{@(AL_SYNC):@"APPLOZIC_01",
                       @(AL_MESSAGE_SENT):@"APPLOZIC_02",
                       @(AL_DELIVERED):@"APPLOZIC_04",
                       @(AL_DELETE_MESSAGE):@"APPLOZIC_05",
                       @(AL_CONVERSATION_DELETED):@"APPLOZIC_06",
                       @(AL_MESSAGE_READ):@"APPLOZIC_07",
                       @(AL_MESSAGE_DELIVERED_AND_READ):@"APPLOZIC_08",
                       @(AL_CONVERSATION_READ):@"APPLOZIC_09",
                       @(AL_CONVERSATION_DELIVERED_AND_READ):@"APPLOZIC_10",
                       @(AL_USER_CONNECTED): @"APPLOZIC_11",
                       @(AL_USER_DISCONNECTED):@"APPLOZIC_12",
                       @(AL_USER_BLOCK):@"APPLOZIC_16",
                       @(AL_USER_UNBLOCK):@"APPLOZIC_17",
                       @(AL_TEST_NOTIFICATION):@"APPLOZIC_20",
                       @(AL_GROUP_CONVERSATION_READ):@"APPLOZIC_21",
                       @(AL_USER_MUTE_NOTIFICATION):@"APPLOZIC_37",
                       @(AL_USER_DETAIL_CHANGED):@"APPLOZIC_30",
                       @(AL_USER_DELETE_NOTIFICATION):@"APPLOZIC_34",
                       @(AL_GROUP_CONVERSATION_DELETED):@"APPLOZIC_23",
                       @(AL_CONVERSATION_DELETED_NEW):@"APPLOZIC_27",
                       @(AL_MESSAGE_METADATA_UPDATE):@"APPLOZIC_33",
                       @(AL_MTEXTER_USER):@"MTEXTER_USER",
                       @(AL_CONTACT_VERIFIED):@"MT_CONTACT_VERIFIED",
                       @(AL_DEVICE_CONTACT_SYNC):@"MT_DEVICE_CONTACT_SYNC",
                       @(AL_MT_EMAIL_VERIFIED):@"MT_EMAIL_VERIFIED",
                       @(AL_DEVICE_CONTACT_MESSAGE):@"MT_DEVICE_CONTACT_MESSAGE",
                       @(AL_CANCEL_CALL):@"MT_CANCEL_CALL",
                       @(AL_MESSAGE):@"MT_MESSAGE",
                       @(AL_DELETE_MULTIPLE_MESSAGE):@"MT_DELETE_MULTIPLE_MESSAGE",
                       @(AL_SYNC_PENDING):@"MT_SYNC_PENDING"
        };
    }
    return  dictionary;
}

@end
