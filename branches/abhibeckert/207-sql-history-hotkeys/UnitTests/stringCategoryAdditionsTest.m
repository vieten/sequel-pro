//
//  stringCategoryAdditionsTest.m
//  sequel-pro
//
//  Created by J Knight on 17/05/09.
//  Copyright 2009 J Knight. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>
//


#import "stringCategoryAdditionsTest.h"
#import "SPStringAdditions.h"

@implementation stringCategoryAdditionsTest

- (void)setUp
{
	
}

- (void)tearDown
{
	
}

- (void)testStringByRemovingCharactersInSet
{
	NSCharacterSet *junk = [NSCharacterSet characterSetWithCharactersInString:@"abc',ü"];
	NSString *s = @"this is  big, crazy st'ring";
	NSString *expect = @"this is  ig rzy string";
	STAssertEqualObjects( [s stringByRemovingCharactersInSet:junk], expect, @"stringByRemovingCharactersInSet" );
	
	// check UTF
	s = @"In der Kürze liegt die Würz";
	expect = @"In der Krze liegt die Wrz";
	STAssertEqualObjects( [s stringByRemovingCharactersInSet:junk], expect, @"stringByRemovingCharactersInSet" );
}

@end