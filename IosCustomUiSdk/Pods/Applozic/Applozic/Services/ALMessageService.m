//
//  ALMessageService.m
//  ALChat
//
//  Copyright (c) 2015 AppLozic. All rights reserved.
//

#import "ALMessageService.h"
#import "ALRequestHandler.h"
#import "ALResponseHandler.h"
#import "ALUtilityClass.h"
#import "ALSyncMessageFeed.h"
#import "ALMessageDBService.h"
#import "ALMessageList.h"
#import "ALDBHandler.h"
#import "ALConnectionQueueHandler.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessageClientService.h"
#import "ALSendMessageResponse.h"
#import "ALUserService.h"
#import "ALUserDetail.h"
#import "ALContactDBService.h"
#import "ALContactService.h"
#import "ALConversationService.h"
#import "ALMessage.h"
#include <tgmath.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "ALApplozicSettings.h"
#import <objc/runtime.h>
#import "ALMQTTConversationService.h"
#import "ApplozicClient.h"
#import "ALHTTPManager.h"
#import "ALUploadTask.h"


@interface ALMessageService  ()<ApplozicAttachmentDelegate>

@end

@implementation ALMessageService

static ALMessageClientService *alMsgClientService;

+(ALMessageService *)sharedInstance
{
    static ALMessageService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ALMessageService alloc] init];
    });
    return sharedInstance;
}

+(void) processLatestMessagesGroupByContact
{
    [ALMessageService processLatestMessagesGroupByContactWithCompletion:nil];
}

+(void) processLatestMessagesGroupByContactWithCompletion:(void(^)(void))completion
{
    ALMessageClientService * almessageClientService = [[ALMessageClientService alloc] init];
    [almessageClientService getLatestMessageGroupByContact:[ALUserDefaultsHandler getFetchConversationPageSize] startTime:[ALUserDefaultsHandler getLastMessageListTime]  withCompletion:^( ALMessageList *alMessageListResponse,NSError *error) {

        if(alMessageListResponse)
        {
            ALMessageDBService *alMessageDBService = [[ALMessageDBService alloc] init];
            [alMessageDBService addMessageList:alMessageListResponse.messageList];
            ALContactDBService *alContactDBService = [[ALContactDBService alloc] init];
            [alContactDBService addUserDetails:alMessageListResponse.userDetailsList];
            [ALUserDefaultsHandler setBoolForKey_isConversationDbSynced:YES];

            [self getMessageListForUserIfLastIsHiddenMessageinMessageList:alMessageListResponse withCompletion:^(NSMutableArray * messages, NSError *error, NSMutableArray *userDetailArray) {
            }];

            [[NSNotificationCenter defaultCenter] postNotificationName:CONVERSATION_CALL_COMPLETED object:nil userInfo:nil];

//            if(alMessageListResponse.messageList.count){
//
//                 for(ALMessage *message in [alMessageListResponse.messageList subarrayWithRange:NSMakeRange(0, MIN(6, alMessageListResponse.messageList.count))] ){
//
//                    if(message.groupId != nil && message.groupId != 0){
//
//                        MessageListRequest * messageListRequest = [[MessageListRequest alloc] init];
//                        messageListRequest.userId = nil;
//                        messageListRequest.channelKey = message.groupId;
//                        messageListRequest.skipRead = YES;
//
//                        [[ALMessageService sharedInstance] getMessageListForUser:messageListRequest withCompletion:^(NSMutableArray *messages, NSError *error, NSMutableArray *userDetailArray) {
//
//                        }];
//                    }else{
//
//                        MessageListRequest * messageListRequest = [[MessageListRequest alloc] init];
//                        messageListRequest.userId = message.contactIds;
//                        messageListRequest.channelKey = nil;
//                        messageListRequest.skipRead = YES;
//
//                        [[ALMessageService sharedInstance] getMessageListForUser:messageListRequest withCompletion:^(NSMutableArray *messages, NSError *error, NSMutableArray *userDetailArray) {
//
//                        }];
//
//                    }
//                }
//            }
        }
        else{
            ALSLog(ALLoggerSeverityInfo, @"Message List Response Nil");
        }
        if (completion) {
            completion();
        }
    }];
}

+(void)getMessagesListGroupByContactswithCompletionService:(void(^)(NSMutableArray * messages, NSError * error))completion
{
    ALMessageClientService * almessageClientService = [[ALMessageClientService alloc] init];

    [almessageClientService getLatestMessageGroupByContact:[ALUserDefaultsHandler getFetchConversationPageSize]
                                                 startTime:[ALUserDefaultsHandler getLastMessageListTime]  withCompletion:^(ALMessageList *alMessageList, NSError *error) {

                                                     [self getMessageListForUserIfLastIsHiddenMessageinMessageList:alMessageList
                                                                                                    withCompletion:^(NSMutableArray *responseMessages, NSError *responseErrorH, NSMutableArray *userDetailArray) {

                                                                                                        completion(responseMessages, responseErrorH);

                                                                                                    }];
                                                 }];

}

+(void)getMessageListForUserIfLastIsHiddenMessageinMessageList:(ALMessageList*)alMessageList
                                                withCompletion:(void (^)(NSMutableArray *, NSError *, NSMutableArray *))completion
{

    /*____If latest_message of a contact is HIDDEN MESSAGE OR MESSSAGE HIDE = TRUE, then get MessageList of that user from server___*/

    /// Also handle reply messages
    NSMutableArray<NSString *>* replyMessageKeys = [[NSMutableArray alloc] init];

    for(ALMessage * alMessage in alMessageList.messageList)
    {
        if (alMessage.metadata) {
            NSString* key = [alMessage.metadata valueForKey: AL_MESSAGE_REPLY_KEY];
            if (key) {
                [replyMessageKeys addObject: key];
            }
        }
        if(![alMessage isHiddenMessage] && ![alMessage isMsgHidden])
        {
            continue;
        }

        NSNumber * time = alMessage.createdAtTime;

        MessageListRequest * messageListRequest = [[MessageListRequest alloc] init];
        messageListRequest.userId = alMessage.contactIds;
        messageListRequest.channelKey = alMessage.groupId;
        messageListRequest.endTimeStamp = time;
        messageListRequest.conversationId = alMessage.conversationId;

        [[ALMessageService sharedInstance] getMessageListForUser:messageListRequest withCompletion:^(NSMutableArray *messages, NSError *error, NSMutableArray *userDetailArray) {

            completion (messages,error,userDetailArray);
        }];
    }
    [[ALMessageService sharedInstance] fetchReplyMessages: replyMessageKeys withCompletion:^(NSMutableArray<ALMessage *> *messages) {
        ALSLog(ALLoggerSeverityInfo, @"reply message api called");
        completion(alMessageList.messageList, nil, nil);
    }];
}

-(void)getMessageListForUser:(MessageListRequest *)messageListRequest withCompletion:(void (^)(NSMutableArray *, NSError *, NSMutableArray *))completion
{
    //On Message List Cell Tap
    ALMessageDBService *almessageDBService =  [[ALMessageDBService alloc] init];
    NSMutableArray * messageList = [almessageDBService getMessageListForContactWithCreatedAt:messageListRequest];

    NSString *chatId;
    if (messageListRequest.conversationId) {
        chatId = [messageListRequest.conversationId stringValue];
    } else {
        chatId = messageListRequest.channelKey ? [messageListRequest.channelKey stringValue] : messageListRequest.userId;
    }
    //Found Record in DB itself ...if not make call to server
    if(messageList.count > 0 && [ALUserDefaultsHandler isServerCallDoneForMSGList:chatId])
    {
        // NSLog(@"the Message List::%@",messageList);
        completion(messageList, nil, nil);
        return;
    }
    else
    {
        ALSLog(ALLoggerSeverityInfo, @"message list is coming from DB %ld", (unsigned long)messageList.count);
    }


    ALChannelService *channelService = [[ALChannelService alloc] init];
    if(messageListRequest.channelKey)
    {

        [channelService getChannelInformation:messageListRequest.channelKey orClientChannelKey:nil withCompletion:^(ALChannel *alChannel) {
            if(alChannel){
                messageListRequest.channelType = alChannel.type;
            }

        }];

    }

    ALMessageClientService *alMessageClientService = [[ALMessageClientService alloc] init];
    ALContactDBService *alContactDBService = [[ALContactDBService alloc] init];

    [alMessageClientService getMessageListForUser:messageListRequest withOpenGroup:messageListRequest.channelType == OPEN
                   withCompletion:^(NSMutableArray *messages,
                                    NSError *error,
                                    NSMutableArray *userDetailArray) {
                       [alContactDBService addUserDetails:userDetailArray];

                       ALContactService *contactService = [ALContactService new];
                       NSMutableArray * userNotPresentIds = [NSMutableArray new];
                       NSMutableArray<NSString *>* replyMessageKeys = [[NSMutableArray alloc] init];

                       ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
                       for (int i = (int)messages.count - 1; i >= 0; i--) {
                           ALMessage * message = messages[i];
                           if ([message isHiddenMessage] && ![message isVOIPNotificationMessage]) {
                               [messages removeObjectAtIndex:i];
                           }
                           if (![contactService isContactExist:message.to]) {
                               [userNotPresentIds addObject:message.to];
                           }
                           /// If its a reply message add the reply message key to array
                           if (message.metadata) {
                               NSString* replyKey = [message.metadata valueForKey:AL_MESSAGE_REPLY_KEY];
                               if (replyKey && ![dbService getMessageByKey:@"key" value: replyKey] && ![replyMessageKeys containsObject: replyKey]) {
                                   [replyMessageKeys addObject: replyKey];
                               }
                           }
                       }
                       /// Check if the key in reply array is present in messages
                       for (int i = 0; i < messages.count; i++) {
                           ALMessage* message = messages[i];
                           if ([replyMessageKeys containsObject:message.key]) {
                               [replyMessageKeys removeObject:message.key];
                           }
                       }

                       /// Make server call for fetching reply messages
                       [self fetchReplyMessages: replyMessageKeys withCompletion:^(NSMutableArray<ALMessage *> *replyMessages) {
                           if (replyMessages && replyMessages.count > 0) {
                               for (int i = 0; i < replyMessages.count; i++) {
                                   if (![contactService isContactExist:replyMessages[i].to]) {
                                       [userNotPresentIds addObject: replyMessages[i].to];
                                   }
                               }
                           }
                           if(userNotPresentIds.count>0) {
                               ALSLog(ALLoggerSeverityInfo, @"Call userDetails...");
                               ALUserService *alUserService = [ALUserService new];
                               [alUserService fetchAndupdateUserDetails:userNotPresentIds withCompletion:^(NSMutableArray *userDetailArray, NSError *theError) {
                                   ALSLog(ALLoggerSeverityInfo, @"User detail response sucessfull.");
                                   [alContactDBService addUserDetails:userDetailArray];
                                   completion(messages, error,userDetailArray);
                               }];
                           } else {
                               completion(messages, error,userDetailArray);
                           }
                       }];
    }];
}



+(void) getMessageListForContactId:(NSString *)contactIds isGroup:(BOOL )isGroup channelKey:(NSNumber *)channelKey conversationId:(NSNumber *)conversationId startIndex:(NSInteger)startIndex withCompletion:(void (^)(NSMutableArray *))completion {
    int rp = 200;

    ALDBHandler * theDbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest * theRequest = [NSFetchRequest fetchRequestWithEntityName:@"DB_Message"];
    [theRequest setFetchLimit:rp];
    NSPredicate* predicate1;
    if(conversationId && [ALApplozicSettings getContextualChatOption])
    {
        predicate1 = [NSPredicate predicateWithFormat:@"conversationId = %d", [conversationId intValue]];
    }
    else if(isGroup)
    {
        predicate1 = [NSPredicate predicateWithFormat:@"groupId = %d", [channelKey intValue]];
    }
    else
    {
        predicate1 = [NSPredicate predicateWithFormat:@"contactId = %@ && groupId = nil", contactIds];
    }

    //    NSUInteger* mTotalCount = [theDbHandler.managedObjectContext countForFetchRequest:theRequest error:nil];

    NSPredicate* predicate2 = [NSPredicate predicateWithFormat:@"deletedFlag == NO AND msgHidden == %@",@(NO)];
    NSPredicate* predicate3 = [NSPredicate predicateWithFormat:@"contentType != %i",ALMESSAGE_CONTENT_HIDDEN];
    NSPredicate* compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1,predicate2,predicate3]];
    [theRequest setPredicate:compoundPredicate];
    [theRequest setFetchOffset:startIndex];
    [theRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]]];

    NSArray * theArray = [theDbHandler.managedObjectContext executeFetchRequest:theRequest error:nil];
    ALMessageDBService* messageDBService = [[ALMessageDBService alloc]init];

    NSMutableArray *tempArray = [[NSMutableArray alloc] init];

    for (DB_Message * theEntity in theArray)
    {
        ALMessage * theMessage = [messageDBService createMessageEntity:theEntity];
        [tempArray insertObject:theMessage atIndex:0];
        //[self.mMessageListArrayKeyStrings insertObject:theMessage.key atIndex:0];
    }
    completion(tempArray);
}


-(void) sendMessages:(ALMessage *)alMessage withCompletion:(void(^)(NSString * message, NSError * error)) completion {

    //DB insert if objectID is null
    DB_Message* dbMessage;
    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    NSError *theError=nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateConversationTableNotification" object:alMessage userInfo:nil];

    ALChannel *channel;
    if(alMessage.groupId){
        ALChannelService *channelService = [[ALChannelService alloc]init];
        channel  = [channelService getChannelByKey:alMessage.groupId];

    }

    if (alMessage.msgDBObjectId == nil)
    {
        ALSLog(ALLoggerSeverityInfo, @"message not in DB new insertion.");
        if(channel ){
            if(channel.type != OPEN){
                dbMessage = [dbService addMessage:alMessage];
            }
        }else{
            dbMessage = [dbService addMessage:alMessage];
        }
    }
    else
    {
        ALSLog(ALLoggerSeverityInfo, @"message found in DB just getting it not inserting new one...");
        dbMessage = (DB_Message*)[dbService getMeesageById:alMessage.msgDBObjectId error:&theError];
    }
    //convert to dic
    NSDictionary * messageDict = [alMessage dictionary];
    ALMessageClientService * alMessageClientService = [[ALMessageClientService alloc]init];
    [alMessageClientService sendMessage:messageDict WithCompletionHandler:^(id theJson, NSError *theError) {

        NSString *statusStr=nil;

        if(!theError)
        {
            ALAPIResponse  *apiResponse = [[ALAPIResponse alloc] initWithJSONString:theJson ];
            ALSendMessageResponse  *response = [[ALSendMessageResponse alloc] initWithJSONString:apiResponse.response];

            if(!response.isSuccess){
                theError = [NSError errorWithDomain:@"Applozic" code:1
                                           userInfo:[NSDictionary
                                                     dictionaryWithObject:@"error sedning message"
                                                     forKey:NSLocalizedDescriptionKey]];

            }else{


                if(channel){
                    if (channel.type != OPEN || (dbMessage != nil && dbMessage.fileMetaInfo != nil)) {
                        alMessage.msgDBObjectId = dbMessage.objectID;
                        [dbService updateMessageSentDetails:response.messageKey withCreatedAtTime:response.createdAt withDbMessage:dbMessage];

                    }
                }else{
                    alMessage.msgDBObjectId = dbMessage.objectID;
                    [dbService updateMessageSentDetails:response.messageKey withCreatedAtTime:response.createdAt withDbMessage:dbMessage];
                }

                alMessage.key = response.messageKey;
                alMessage.sentToServer = YES;
                alMessage.inProgress = NO;
                alMessage.isUploadFailed= NO;
                alMessage.status = [NSNumber numberWithInt:SENT];

            }

            if(self.delegate){
                [self.delegate onMessageSent:alMessage];
            }

        }else{
            ALSLog(ALLoggerSeverityError, @" got error while sending messages");
        }
        completion(statusStr,theError);
    }];

}

+(void) getLatestMessageForUser:(NSString *)deviceKeyString withDelegate : (id<ApplozicUpdatesDelegate>)delegate withCompletion:(void (^)( NSMutableArray *, NSError *))completion
{
    if(!alMsgClientService)
    {
        alMsgClientService = [[ALMessageClientService alloc] init];
    }

    @synchronized(alMsgClientService) {

        [alMsgClientService getLatestMessageForUser:deviceKeyString withCompletion:^(ALSyncMessageFeed * syncResponse , NSError *error) {
            NSMutableArray *messageArray = nil;

            if(!error)
            {
                if (syncResponse.deliveredMessageKeys.count > 0)
                {
                    [ALMessageService updateDeliveredReport:syncResponse.deliveredMessageKeys withStatus:DELIVERED];
                }
                if(syncResponse.messagesList.count > 0)
                {
                    messageArray = [[NSMutableArray alloc] init];
                    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
                    messageArray = [dbService addMessageList:syncResponse.messagesList];

                    NSMutableArray<NSString *>* messageKeys = [[NSMutableArray alloc] init];
                    for (ALMessage* message in syncResponse.messagesList) {
                        if (message.metadata) {
                            NSString *replyMessageKey = [message.metadata valueForKey: AL_MESSAGE_REPLY_KEY];
                            if (replyMessageKey && ![dbService getMessageByKey:@"key" value:replyMessageKey]) {
                                [messageKeys addObject:replyMessageKey];
                            }
                        }
                    }
                    if (messageKeys.count > 0) {
                        [[ALMessageService sharedInstance] fetchReplyMessages:messageKeys withCompletion:^(NSMutableArray<ALMessage *> *messages) {
                            if (messages) {
                                [messageArray addObjectsFromArray:messages];
                            }
                            [self processMessages:messageArray delegate:delegate withCompletion:^(NSMutableArray *list) {
                                [ALUserDefaultsHandler setLastSyncTime:syncResponse.lastSyncTime];
                                completion(list, nil);
                            }];
                        }];
                    } else {
                        [self processMessages:messageArray delegate:delegate withCompletion:^(NSMutableArray * list) {
                            [ALUserDefaultsHandler setLastSyncTime:syncResponse.lastSyncTime];
                            completion(list, nil);
                        }];
                    }
                } else {
                    [ALUserDefaultsHandler setLastSyncTime:syncResponse.lastSyncTime];
                    completion(messageArray,error);
                }
            } else {
                completion(messageArray,error);
            }
        }];
    }
}

+(void) processMessages:(NSMutableArray* )messageArray
               delegate:(id<ApplozicUpdatesDelegate>)delegate
         withCompletion:(void(^)(NSMutableArray *))completion {
    [ALUserService processContactFromMessages:messageArray withCompletion:^{
        for (int i = (int)messageArray.count - 1; i>=0; i--) {
            ALMessage * message = messageArray[i];
            if([message isHiddenMessage] && ![message isVOIPNotificationMessage]) {
                [messageArray removeObjectAtIndex:i];
            }else if(![message isToIgnoreUnreadCountIncrement]) {
                [self incrementContactUnreadCount:message];
            }

            if (message.groupId != nil && message.contentType == ALMESSAGE_CHANNEL_NOTIFICATION) {
                if ([message.metadata[@"action"] isEqual: @"4"]) {
                    [[NSNotificationCenter defaultCenter]
                     postNotificationName:@"CONVERSATION_DELETION"
                     object:message.groupId];
                }
                [[ALChannelService sharedInstance] syncCallForChannelWithDelegate:delegate];
            }

            [self resetUnreadCountAndUpdate:message];

            if(![message isHiddenMessage] && ![message isVOIPNotificationMessage] && delegate) {
                if([message.type isEqual: AL_OUT_BOX]){
                    [delegate onMessageSent: message];
                }else {
                    [delegate onMessageReceived: message];
                }
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:NEW_MESSAGE_NOTIFICATION object:messageArray userInfo:nil];
        completion(messageArray);
    }];
}

+(void) getLatestMessageForUser:(NSString *)deviceKeyString withCompletion:(void (^)( NSMutableArray *, NSError *))completion
{
    [self getLatestMessageForUser:deviceKeyString withDelegate:nil withCompletion:^(NSMutableArray *messageArray, NSError *error) {
        completion(messageArray,error);
    }];

}

+(BOOL)incrementContactUnreadCount:(ALMessage*)message{

    if(![ALMessageService isIncrementRequired:message]) {
        return NO;
    }

    if(message.groupId) {

        NSNumber * groupId = message.groupId;
        ALChannelDBService * channelDBService =[[ALChannelDBService alloc] init];
        ALChannel * channel = [channelDBService loadChannelByKey:groupId];
        if(![message isResetUnreadCountMessage]) {
            channel.unreadCount = [NSNumber numberWithInt:channel.unreadCount.intValue+1];
            [channelDBService updateUnreadCountChannel:message.groupId unreadCount:channel.unreadCount];
        }
    }else {

        NSString * contactId = message.contactIds;
        ALContactService * contactService=[[ALContactService alloc] init];
        ALContact * contact = [contactService loadContactByKey:@"userId" value:contactId];
        contact.unreadCount = [NSNumber numberWithInt:[contact.unreadCount intValue] + 1];
        [contactService addContact:contact];
        [contactService updateContact:contact];
    }

    if(message.conversationId) {
        ALConversationService * alConversationService = [[ALConversationService alloc] init];
        [alConversationService fetchTopicDetails:message.conversationId withCompletion:^(NSError *error, ALConversationProxy *proxy) {
        }];
    }

    return YES;
}

+(BOOL)resetUnreadCountAndUpdate:(ALMessage*)message {

    if([message isResetUnreadCountMessage]) {
        ALChannelDBService * channelDBService = [[ALChannelDBService alloc] init];
        [channelDBService updateUnreadCountChannel:message.groupId unreadCount:[NSNumber numberWithInt:0]];
        return YES;
    }
    return NO;
}

+(BOOL)isIncrementRequired:(ALMessage *)message{

    if([message.status isEqualToNumber:[NSNumber numberWithInt:DELIVERED_AND_READ]]
       || (message.groupId && message.contentType == ALMESSAGE_CHANNEL_NOTIFICATION)
       || [message.type isEqualToString:@"5"]
       || [message isHiddenMessage]
       || [message isVOIPNotificationMessage]
       || [message.status isEqualToNumber:[NSNumber numberWithInt:READ]]) {

        return NO;

    }else{
        return YES;
    }
}


+(void) updateDeliveredReport: (NSArray *) deliveredMessageKeys withStatus:(int)status
{
    for (id key in deliveredMessageKeys)
    {
        ALMessageDBService* messageDBService = [[ALMessageDBService alloc] init];
        [messageDBService updateMessageDeliveryReport:key withStatus:status];
    }
}

+(void )deleteMessage:( NSString * ) keyString andContactId:( NSString * )contactId withCompletion:(void (^)(NSString *, NSError *))completion{

    //db
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    DB_Message* dbMessage=(DB_Message*)[dbService getMessageByKey:@"key" value:keyString];
    [dbMessage setDeletedFlag:[NSNumber numberWithBool:YES]];
    ALMessage * message =  [dbService createMessageEntity:dbMessage];
    bool isUsedForReply = (message.getReplyType == AL_A_REPLY);

    if(isUsedForReply)
    {
        dbMessage.replyMessageType = [NSNumber numberWithInt:AL_REPLY_BUT_HIDDEN];

    }

    NSError *error;
    if (![[dbMessage managedObjectContext] save:&error])
    {
        ALSLog(ALLoggerSeverityInfo, @"Delete Flag Not Set");
    }

    ALMessageDBService * dbService2 = [[ALMessageDBService alloc]init];
    DB_Message* dbMessage2=(DB_Message*)[dbService2 getMessageByKey:@"key" value:keyString];
    NSArray *keys = [[[dbMessage2 entity] attributesByName] allKeys];
    NSDictionary *dict = [dbMessage2 dictionaryWithValuesForKeys:keys];
    ALSLog(ALLoggerSeverityInfo, @"DB Message In Del: %@",dict);


    ALMessageClientService *alMessageClientService =  [[ALMessageClientService alloc]init];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){

        [alMessageClientService deleteMessage:keyString andContactId:contactId
                               withCompletion:^(NSString * response, NSError *error) {
                                   if(!error){
                                       //none error then delete from DB.
                                       if(!isUsedForReply)
                                       {
                                           [dbService deleteMessageByKey:keyString];
                                       }
                                   }
                                   completion(response,error);
                               }];

    });


}


+(void)deleteMessageThread:(NSString *)contactId orChannelKey:(NSNumber *)channelKey withCompletion:(void (^)(NSString *, NSError *))completion
{
    ALMessageClientService *alMessageClientService = [[ALMessageClientService alloc] init];
    [alMessageClientService deleteMessageThread:contactId orChannelKey:channelKey withCompletion:^(NSString * response, NSError *error) {

        if (!error)
        {
             //delete sucessfull
             ALSLog(ALLoggerSeverityInfo, @"sucessfully deleted !");
             ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
             [dbService deleteAllMessagesByContact:contactId orChannelKey:channelKey];

             if(channelKey)
             {
                 [ALChannelService setUnreadCountZeroForGroupID:channelKey];
             }
             else
             {
                 [ALUserService setUnreadCountZeroForContactId:contactId];
             }
         }
         completion(response, error);
         }];
}

+(ALMessage*) processFileUploadSucess: (ALMessage *) message{

    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    DB_Message *dbMessage =  (DB_Message*)[dbService getMessageByKey:@"key" value:message.key];

    dbMessage.fileMetaInfo.blobKeyString = message.fileMeta.blobKey;
    dbMessage.fileMetaInfo.thumbnailBlobKeyString = message.fileMeta.thumbnailBlobKey;
    dbMessage.fileMetaInfo.contentType = message.fileMeta.contentType;
    dbMessage.fileMetaInfo.createdAtTime = message.fileMeta.createdAtTime;
    dbMessage.fileMetaInfo.key = message.fileMeta.key;
    dbMessage.fileMetaInfo.name = message.fileMeta.name;
    dbMessage.fileMetaInfo.size = message.fileMeta.size;
    dbMessage.fileMetaInfo.suUserKeyString = message.fileMeta.userKey;
    message.fileMetaKey = message.fileMeta.key;
    message.msgDBObjectId = [dbMessage objectID];

    [[ALDBHandler sharedInstance].managedObjectContext save:nil];
    return message;
}

-(void)processPendingMessages
{
    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    NSMutableArray * pendingMessageArray = [dbService getPendingMessages];
    ALSLog(ALLoggerSeverityInfo, @"service called....%lu",(unsigned long)pendingMessageArray.count);

    for(ALMessage *msg  in pendingMessageArray )
    {

        if((!msg.fileMeta && !msg.pairedMessageKey))
        {
            ALSLog(ALLoggerSeverityInfo, @"RESENDING_MESSAGE : %@", msg.message);
            [[ALMessageService sharedInstance] sendMessages:msg withCompletion:^(NSString *message, NSError *error) {
                if(error)
                {
                    ALSLog(ALLoggerSeverityError, @"PENDING_MESSAGES_NO_SENT : %@", error);
                    return;
                }
                ALSLog(ALLoggerSeverityInfo, @"SENT_SUCCESSFULLY....MARKED_AS_DELIVERED : %@", message);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"UPDATE_MESSAGE_SEND_STATUS" object:msg];
            }];
        }
        else if(msg.contentType == ALMESSAGE_CONTENT_VCARD)
        {
            ALSLog(ALLoggerSeverityInfo, @"REACH_PRESENT");
            DB_Message *dbMessage = (DB_Message*)[dbService getMessageByKey:@"key" value:msg.key];
            dbMessage.inProgress = [NSNumber numberWithBool:YES];
            dbMessage.isUploadFailed = [NSNumber numberWithBool:NO];
            [[ALDBHandler sharedInstance].managedObjectContext save:nil];

            ALHTTPManager *httpManager = [[ALHTTPManager alloc]init];
            httpManager.attachmentProgressDelegate = self;

            ALMessageClientService * clientService = [ALMessageClientService new];
            NSDictionary *info = [msg dictionary];
            [clientService sendPhotoForUserInfo:info withCompletion:^(NSString *responseUrl, NSError *error) {

                if(!error)
                {

                    ALHTTPManager *httpManager = [[ALHTTPManager alloc]init];
                    httpManager.attachmentProgressDelegate = self;
                    [httpManager processUploadFileForMessage:[dbService createMessageEntity:dbMessage] uploadURL:responseUrl];

                }
            }];
        }
        else
        {
            ALSLog(ALLoggerSeverityInfo, @"FILE_META_PRESENT : %@",msg.fileMeta );
        }
    }
}

+(void)syncMessages{

    if([ALUserDefaultsHandler isLoggedIn])
    {
        [ALMessageService getLatestMessageForUser:[ALUserDefaultsHandler getDeviceKeyString] withCompletion:^(NSMutableArray *messageArray, NSError *error) {

            if(error)
            {
                ALSLog(ALLoggerSeverityError, @"ERROR IN LATEST MSG APNs CLASS : %@",error);
            }
        }];
    }
}

+(ALMessage*)getMessagefromKeyValuePair:(NSString*)key andValue:(NSString*)value
{
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    DB_Message *dbMessage =  (DB_Message*)[dbService getMessageByKey:key value:value];
    return [dbService createMessageEntity:dbMessage];
}

-(void)getMessageInformationWithMessageKey:(NSString *)messageKey withCompletionHandler:(void(^)(ALMessageInfoResponse *msgInfo, NSError *theError))completion
{
    ALMessageClientService *msgClient = [ALMessageClientService new];
    [msgClient getCurrentMessageInformation:messageKey withCompletionHandler:^(ALMessageInfoResponse *msgInfo, NSError *theError) {

        if(theError)
        {
            ALSLog(ALLoggerSeverityError, @"ERROR IN MSG INFO RESPONSE : %@", theError);
        }
        else
        {
            completion(msgInfo, theError);
        }
    }];
}


+(void)getMessageSENT:(ALMessage*)alMessage withDelegate : (id<ApplozicUpdatesDelegate>)theDelegate  withCompletion:(void (^)( NSMutableArray *, NSError *))completion{

    ALMessage * localMessage = [ALMessageService getMessagefromKeyValuePair:@"key" andValue:alMessage.key];
    if(localMessage.key ==  nil){
        [self getLatestMessageForUser:[ALUserDefaultsHandler getDeviceKeyString] withDelegate:theDelegate withCompletion:^(NSMutableArray *messageArray, NSError *error) {
            completion(messageArray,error);
        }];
    }
}

+(void)getMessageSENT:(ALMessage*)alMessage  withCompletion:(void (^)( NSMutableArray *, NSError *))completion{

    [self getMessageSENT:alMessage withDelegate:nil  withCompletion:^(NSMutableArray *messageArray, NSError *error) {
        completion(messageArray,error);
    }];

}
#pragma mark - Multi Receiver API
//================================

+(void)multiUserSendMessage:(ALMessage *)alMessage toContacts:(NSMutableArray*)contactIdsArray toGroups:(NSMutableArray*)channelKeysArray withCompletion:(void(^)(NSString * json, NSError * error)) completion{

    [ALUserClientService multiUserSendMessage:[alMessage dictionary] toContacts:contactIdsArray
                                     toGroups:channelKeysArray withCompletion:^(NSString *json, NSError *error) {

        if(error)
        {
            ALSLog(ALLoggerSeverityError, @"SERVICE_ERROR: Multi User Send Message : %@", error);
        }

        completion(json, error);
    }];
}

+(ALMessage *)createCustomTextMessageEntitySendTo:(NSString *)to withText:(NSString*)text
{
    return [self createMessageEntityOfContentType:ALMESSAGE_CONTENT_CUSTOM toSendTo:to withText:text];;
}

+(ALMessage *)createHiddenMessageEntitySentTo:(NSString*)to withText:(NSString*)text
{
    return [self createMessageEntityOfContentType:ALMESSAGE_CONTENT_HIDDEN toSendTo:to withText:text];
}

+(ALMessage *)createMessageEntityOfContentType:(int)contentType
                                      toSendTo:(NSString*)to
                                      withText:(NSString*)text{

    ALMessage * theMessage = [ALMessage new];

    theMessage.contactIds = to;//1
    theMessage.to = to;//2
    theMessage.message = text;//3
    theMessage.contentType = contentType;//4

    theMessage.type = @"5";
    theMessage.createdAtTime = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] * 1000];
    theMessage.deviceKey = [ALUserDefaultsHandler getDeviceKeyString ];
    theMessage.sendToDevice = NO;
    theMessage.shared = NO;
    theMessage.fileMeta = nil;
    theMessage.storeOnDevice = NO;
    theMessage.key = [[NSUUID UUID] UUIDString];
    theMessage.delivered = NO;
    theMessage.fileMetaKey = nil;

    return theMessage;
}

+(ALMessage *)createMessageWithMetaData:(NSMutableDictionary *)metaData andContentType:(short)contentType
                          andReceiverId:(NSString *)receiverId andMessageText:(NSString *)msgTxt
{
    ALMessage * theMessage = [self createMessageEntityOfContentType:contentType toSendTo:receiverId withText:msgTxt];

    theMessage.metadata = metaData;
    return theMessage;
}

-(NSUInteger)getMessagsCountForUser:(NSString *)userId
{
    ALMessageDBService * dbService = [ALMessageDBService new];
    return [dbService getMessagesCountFromDBForUser:userId];
}

//============================================================================================================
#pragma mark ADD BROADCAST MESSAGE TO DB
//============================================================================================================

+(void)addBroadcastMessageToDB:(ALMessage *)alMessage {
    [ALMessageDBService addBroadcastMessageToDB:alMessage];
}

//============================================================================================================
#pragma mark GET LATEST MESSAGE FOR USER/CHANNEL
//============================================================================================================

-(ALMessage *)getLatestMessageForUser:(NSString *)userId
{
    ALMessageDBService *alMsgDBService = [[ALMessageDBService alloc] init];
    return [alMsgDBService getLatestMessageForUser:userId];
}

-(ALMessage *)getLatestMessageForChannel:(NSNumber *)channelKey excludeChannelOperations:(BOOL)flag
{
    ALMessageDBService *alMsgDBService = [[ALMessageDBService alloc] init];
    return [alMsgDBService getLatestMessageForChannel:channelKey excludeChannelOperations:flag];
}

-(ALMessage *)getALMessageByKey:(NSString*)messageReplyId
{
    //GET Message From Server if not present on Server
    ALMessageDBService *alMsgDBService = [[ALMessageDBService alloc] init];
    DB_Message * dbMessage = (DB_Message*) [alMsgDBService getMessageByKey:@"key" value:messageReplyId];
    return [alMsgDBService createMessageEntity:dbMessage];
}

+(void)addOpenGroupMessage:(ALMessage*)alMessage withDelegate:(id<ApplozicUpdatesDelegate>)delegate{
    {

        if(!alMessage){
            return;
        }

        NSMutableArray * singlemessageArray = [[NSMutableArray alloc] init];
        [singlemessageArray addObject:alMessage];
        for (int i=0; i<singlemessageArray.count; i++) {
            ALMessage * message = singlemessageArray[i];
            if (message.groupId != nil && message.contentType == ALMESSAGE_CHANNEL_NOTIFICATION) {
                ALChannelService *channelService = [[ALChannelService alloc] init];
                [channelService syncCallForChannelWithDelegate:delegate];
                if([message isMsgHidden]) {
                    [singlemessageArray removeObjectAtIndex:i];
                }
            }
            if(delegate){
                if([message.type  isEqual: AL_OUT_BOX]){
                    [delegate onMessageSent: message];
                }else{
                    [delegate onMessageReceived: message];
                }
            }
        }

        [ALUserService processContactFromMessages:singlemessageArray withCompletion:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NEW_MESSAGE_NOTIFICATION object:singlemessageArray userInfo:nil];

        }];

    }
}

-(void) getLatestMessages:(BOOL)isNextPage withOnlyGroups:(BOOL)isGroup withCompletionHandler: (void(^)(NSMutableArray * messageList, NSError *error)) completion{

    ALMessageDBService *messageDbService = [[ALMessageDBService alloc] init];

    [messageDbService getLatestMessages:isNextPage withOnlyGroups:isGroup withCompletionHandler:^(NSMutableArray *messageList, NSError *error) {


        completion(messageList,error);

    }];
}

-(ALMessage *)handleMessageFailedStatus:(ALMessage *)message{
    ALMessageDBService *messageDBServce = [[ALMessageDBService alloc]init];
    return [messageDBServce handleMessageFailedStatus:message];
}

-(ALMessage*) getMessageByKey:(NSString*)messageKey{
    if(!messageKey){
        return nil;
    }

    ALMessageDBService *messageDBServce = [[ALMessageDBService alloc]init];
    return [messageDBServce getMessageByKey:messageKey];
}

+ (void) syncMessageMetaData:(NSString *)deviceKeyString withCompletion:(void (^)( NSMutableArray *, NSError *))completion
{
    if(!alMsgClientService)
    {
        alMsgClientService = [[ALMessageClientService alloc] init];
    }
    @synchronized(alMsgClientService) {
        [alMsgClientService getLatestMessageForUser:deviceKeyString withMetaDataSync:YES withCompletion:^(ALSyncMessageFeed * syncResponse , NSError *error) {
            NSMutableArray *messageArray = nil;

            if(!error)
            {
                if(syncResponse.messagesList.count > 0)
                {
                    messageArray = [[NSMutableArray alloc] init];
                    ALMessageDBService *messageDatabase  = [[ALMessageDBService alloc]init];
                    for(ALMessage * message in syncResponse.messagesList)
                    {
                        [messageDatabase updateMessageMetadataOfKey:message.key withMetadata:message.metadata];
                        [[NSNotificationCenter defaultCenter] postNotificationName:AL_MESSAGE_META_DATA_UPDATE object:message userInfo:nil];
                    }
                }
                [ALUserDefaultsHandler setLastSyncTimeForMetaData:syncResponse.lastSyncTime];
                completion(syncResponse.messagesList,error);
            }
            else
            {
                completion(messageArray,error);
            }
        }];
    }
}

- (void)updateMessageMetadataOfKey:(NSString *)messageKey withMetadata:(NSMutableDictionary *)metadata withCompletion:(void (^)(ALAPIResponse *, NSError *))completion
{
    ALMessageClientService *messageService = [[ALMessageClientService alloc] init];
    [messageService updateMessageMetadataOfKey:messageKey withMetadata:metadata withCompletion:^(id theJson, NSError *theError) {
        ALAPIResponse * alAPIResponse;
        if(!theError) {
            ALMessageDBService *messagedb = [[ALMessageDBService alloc] init];
            [messagedb updateMessageMetadataOfKey:messageKey withMetadata:metadata];
            alAPIResponse = [[ALAPIResponse alloc] initWithJSONString:theJson];
        }
        completion(alAPIResponse,theError);
    }];
}

- (void) fetchReplyMessages:(NSMutableArray<NSString *> *) keys withCompletion: (void(^)(NSMutableArray<ALMessage *>* messages))completion{
    if (!keys || keys.count < 1) {
        completion(nil);
        return;
    }
    ALMessageClientService *messageService = [[ALMessageClientService alloc] init];
    [messageService getMessagesWithkeys:keys withCompletion:^(ALAPIResponse *response, NSError *error) {
        if (error || ![response.status isEqualToString:@"success"]) {
            completion(nil);
            return;
        }
        NSDictionary* messageDict = [response.response valueForKey:@"message"];
        NSMutableArray<ALMessage *>* messageList = [[NSMutableArray alloc] init];
        for (NSDictionary* dict in messageDict) {
            ALMessage *message = [[ALMessage alloc] initWithDictonary: dict];
            message.messageReplyType = [NSNumber numberWithInt:AL_REPLY_BUT_HIDDEN];
            [[[ALMessageDBService alloc] init] addMessage: message];
            [messageList addObject:message];
        }
        completion(messageList);
    }];
}

- (void)onDownloadCompleted:(ALMessage *)alMessage {

}

- (void)onDownloadFailed:(ALMessage *)alMessage {

}

- (void)onUpdateBytesDownloaded:(int64_t)bytesReceived withMessage:(ALMessage *)alMessage {

}

- (void)onUpdateBytesUploaded:(int64_t)bytesSent withMessage:(ALMessage *)alMessage {

}

- (void)onUploadCompleted:(ALMessage *)alMessage withOldMessageKey:(NSString *)oldMessageKey {
   [[NSNotificationCenter defaultCenter] postNotificationName:@"UPDATE_MESSAGE_SEND_STATUS" object:alMessage];
}

- (void)onUploadFailed:(ALMessage *)alMessage {

}

@end
