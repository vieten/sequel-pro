//---------------------------------------------------------------------------------------
//  $Id: OCMockObject.h 2208 2010-05-03 19:18:20Z agnoeo $
//  Copyright (c) 2004-2008 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMockObject : NSProxy
{
	BOOL			isNice;
	BOOL			expectationOrderMatters;
	NSMutableArray	*recorders;
	NSMutableArray	*expectations;
	NSMutableArray	*exceptions;
}

+ (id)mockForClass:(Class)aClass;
+ (id)mockForProtocol:(Protocol *)aProtocol;
+ (id)partialMockForObject:(NSObject *)anObject;

+ (id)niceMockForClass:(Class)aClass;
+ (id)niceMockForProtocol:(Protocol *)aProtocol;

+ (id)observerMock;

- (id)init;

- (void)setExpectationOrderMatters:(BOOL)flag;

- (id)stub;
- (id)expect;

- (void)verify;

// internal use only

- (id)getNewRecorder;
- (BOOL)handleInvocation:(NSInvocation *)anInvocation;
- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation;

@end
