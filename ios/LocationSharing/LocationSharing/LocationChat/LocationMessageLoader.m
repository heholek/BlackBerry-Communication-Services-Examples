/* Copyright (c) 2019 BlackBerry Limited.  All Rights Reserved.
* 
* Licensed under the Apache License, Version 2.0 (the "License"); 
* you may not use this file except in compliance with the License. 
* You may obtain a copy of the License at 
* 
* http://www.apache.org/licenses/LICENSE-2.0 
* 
* Unless required by applicable law or agreed to in writing, software 
* distributed under the License is distributed on an "AS IS" BASIS, 
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
* See the License for the specific language governing permissions and 
* limitations under the License. 
  
* This sample code was created by BlackBerry using SDKs from Apple Inc. 
* and may contain code licensed for use only with Apple products. 
* Please review your Apple SDK Agreement for additional details. 
*/ 

#import "LocationMessageLoader.h"

#import <BBMEnterprise/BBMEnterprise.h>
#import "BBMChatMessage+Extensions.h"
#import "BBMAccess.h"
#import "BBMUtilities.h"
#import "LocationManager.h"

@interface LocationMessageLoader ()

@property (nonatomic, strong) ObservableMonitor *messageMonitor;
@property (nonatomic, strong) BBMChat *chat;
@property (nonatomic, copy) LocationMessageLoaderCallback callback;
@property (nonatomic, strong) BBMLiveList *filteredLocationChatMessages;

@end


@implementation LocationMessageLoader

+ (LocationMessageLoader*)messageLoaderForConversation:(BBMChat *)chat
                                      callback:(LocationMessageLoaderCallback)callback {

    return [[self alloc] initWithConversation:(BBMChat *)chat
                                     callback:callback];
}

- (id)initWithConversation:(BBMChat*)chat
                  callback:(LocationMessageLoaderCallback)callback
{
    self = [super init];
    if (self) {
        self.chat = chat;
        self.callback = callback;
        [self observeMessages];
    }
    return self;
}

- (void)observeMessages
{
    //We are only interested in messages whose tag is set to kMessageTag_Location. To fetch such
    //messages an instance of BBMChatMessageCriteria is created and the chatId and tag values are set.
    BBMChatMessageCriteria *chatMessageCriteria = [[BBMChatMessageCriteria alloc] init];
    chatMessageCriteria.tag = kMessageTag_Location;
    chatMessageCriteria.chatId = self.chat.chatId;

    self.filteredLocationChatMessages = [[[BBMEnterpriseService service] model] chatMessageWithCriteria:chatMessageCriteria];
    typeof(self) __weak weakSelf = self;
    self.messageMonitor = [ObservableMonitor monitorActivatedWithName:@"messageMonitor" block:^{
        [weakSelf sortMessagesByRegId];
     }];
}

- (void)sortMessagesByRegId
{
    NSMutableDictionary *locationMessagesByRegId = [[NSMutableDictionary alloc] init];
    //Wait for the list to be current to avoid unnecessary processing.
    if(self.filteredLocationChatMessages.bbmState == kBBMStatePending) {
        return;
    }
    for(BBMChatMessage *message in self.filteredLocationChatMessages ) {
        //Timed message that have expired are marked as deleted so they are still displayed as expired messages.
        if([message.tag isEqualToString:kMessageTag_Location]) {
            if(message.resolvedSenderUri.bbmState == kBBMStatePending) {
                return;
            }
            NSNumber *regId = message.resolvedSenderUri.regId;
            NSMutableArray *locationMessagesForRegid = locationMessagesByRegId[regId];
            if(!locationMessagesForRegid) {
                locationMessagesForRegid = [[NSMutableArray alloc] init];
            }
            //Add message to array
            [locationMessagesForRegid addObject:message];
            if(regId) {
                locationMessagesByRegId[regId] = locationMessagesForRegid;
            }
        }
    }
    if(self.callback) {
        self.callback(locationMessagesByRegId);
    }
}

@end
