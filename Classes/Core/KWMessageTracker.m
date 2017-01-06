//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWMessageTracker.h"
#import "KWMessagePattern.h"
#import "NSObject+KiwiStubAdditions.h"

static dispatch_queue_t receive_count_queue() {
    static dispatch_queue_t receive_count_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        receive_count_queue = dispatch_queue_create("com.kiwi.receive_count_queue", DISPATCH_QUEUE_SERIAL);
    });
    return receive_count_queue;
}

@interface KWMessageTracker()

#pragma mark - Properties

@property (nonatomic, assign) NSUInteger protectedReceivedCount; // access only via `receive_count_queue()`

@end

@implementation KWMessageTracker

#pragma mark - Initializing

- (id)initWithSubject:(id)anObject messagePattern:(KWMessagePattern *)aMessagePattern countType:(KWCountType)aCountType count:(NSUInteger)aCount {
    self = [super init];
    if (self) {
        _subject = anObject;
        _messagePattern = aMessagePattern;
        _countType = aCountType;
        _count = aCount;
        [anObject addMessageSpy:self forMessagePattern:aMessagePattern];
    }

    return self;
}

+ (id)messageTrackerWithSubject:(id)anObject messagePattern:(KWMessagePattern *)aMessagePattern countType:(KWCountType)aCountType count:(NSUInteger)aCount {
    return [[self alloc] initWithSubject:anObject messagePattern:aMessagePattern countType:aCountType count:aCount];
}

#pragma mark - Spying on Messages

- (void)object:(id)anObject didReceiveInvocation:(NSInvocation *)anInvocation {
    if (![self.messagePattern matchesInvocation:anInvocation])
        return;

    ++self.receivedCount;
}

#pragma mark - Stopping Tracking

- (void)stopTracking {
    [self.subject removeMessageSpy:self forMessagePattern:self.messagePattern];
}

#pragma mark - Getting Message Tracker Status

- (BOOL)succeeded {
    switch (self.countType) {
        case KWCountTypeExact:
            return self.receivedCount == self.count;
        case KWCountTypeAtLeast:
            return self.receivedCount >= self.count;
        case KWCountTypeAtMost:
            return self.receivedCount <= self.count;
        default:
            break;
    }

    assert(0 && "should never reach here");
    return NO;
}

#pragma mark - Getting Phrases

- (NSString *)phraseForCount:(NSUInteger)aCount {
    if (aCount == 1)
        return @"1 time";

    return [NSString stringWithFormat:@"%d times", (int)aCount];
}

- (NSString *)expectedCountPhrase {
    NSString *countPhrase = [self phraseForCount:self.count];

    switch (self.countType) {
        case KWCountTypeExact:
            return [NSString stringWithFormat:@"exactly %@", countPhrase];
        case KWCountTypeAtLeast:
            return [NSString stringWithFormat:@"at least %@", countPhrase];
        case KWCountTypeAtMost:
            return [NSString stringWithFormat:@"at most %@", countPhrase];
        default:
            break;
    }

    assert(0 && "should never reach here");
    return nil;
}

- (NSString *)receivedCountPhrase {
    return [self phraseForCount:self.receivedCount];
}

#pragma mark - Protected Access

- (NSUInteger)receivedCount {
    __block NSUInteger count;
    dispatch_sync(receive_count_queue(), ^{
        count = self.protectedReceivedCount;
    });
    return count;
}

- (void)setReceivedCount:(NSUInteger)receivedCount {
    dispatch_sync(receive_count_queue(), ^{
        self.protectedReceivedCount = receivedCount;
    });
}

#pragma mark - Debugging

- (NSString *)modeString {
    switch (self.countType) {
        case KWCountTypeExact:
            return @"KWCountTypeExact";
        case KWCountTypeAtLeast:
            return @"KWCountTypeAtLeast";
        case KWCountTypeAtMost:
            return @"KWCountTypeAtMost";
        default:
            break;
    }

    assert(0 && "should never reach here");
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"messagePattern: %@\nmode: %@\ncount: %d\nreceiveCount: %d",
                                      self.messagePattern,
                                      self.modeString,
                                      (int)self.count,
                                      (int)self.receivedCount];
}

@end
