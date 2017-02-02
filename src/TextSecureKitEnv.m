//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "TextSecureKitEnv.h"

NS_ASSUME_NONNULL_BEGIN

static TextSecureKitEnv *TextSecureKitEnvSharedInstance;

@implementation TextSecureKitEnv

@synthesize callMessageHandler = _callMessageHandler;
@synthesize contactsManager = _contactsManager;
@synthesize notificationsManager = _notificationsManager;

- (instancetype)initWithCallMessageHandler:(id<OWSCallMessageHandler>)callMessageHandler
                           contactsManager:(id<ContactsManagerProtocol>)contactsManager
                      notificationsManager:(id<NotificationsProtocol>)notificationsManager
{
    self = [super init];
    if (!self) {
        return self;
    }

    _callMessageHandler = callMessageHandler;
    _contactsManager = contactsManager;
    _notificationsManager = notificationsManager;

    return self;
}

+ (instancetype)sharedEnv
{
    NSAssert(TextSecureKitEnvSharedInstance, @"Trying to access shared TextSecureKitEnv before it's been set");
    return TextSecureKitEnvSharedInstance;
}

+ (void)setSharedEnv:(TextSecureKitEnv *)env
{
    @synchronized (self) {
        NSAssert(TextSecureKitEnvSharedInstance == nil, @"Trying to set shared TextSecureKitEnv which has already been set");
        TextSecureKitEnvSharedInstance = env;
    }
}

#pragma mark - getters

- (id<OWSCallMessageHandler>)callMessageHandler
{
    NSAssert(_callMessageHandler, @"Trying to access the callMessageHandler before it's set.");
    return _callMessageHandler;
}

- (id<ContactsManagerProtocol>)contactsManager
{
    NSAssert(_contactsManager, @"Trying to access the contactsManager before it's set.");

    return _contactsManager;
}


- (id<NotificationsProtocol>)notificationsManager
{
    NSAssert(_notificationsManager, @"Trying to access the notificationsManager before it's set.");
    return _notificationsManager;
}

@end

NS_ASSUME_NONNULL_END
