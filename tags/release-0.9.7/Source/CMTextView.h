//
//  $Id$
//
//  CMTextView.h
//  sequel-pro
//
//  Created by Carsten Blüm.
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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>

#import "NoodleLineNumberView.h"
#import "CMCopyTable.h"
#import "CMTextView.h"

#define SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING 10000

static inline void NSMutableAttributedStringAddAttributeValueRange (NSMutableAttributedString* self, NSString* aStr, id aValue, NSRange aRange) {
	typedef void (*SPMutableAttributedStringAddAttributeValueRangeMethodPtr)(NSMutableAttributedString*, SEL, NSString*, id, NSRange);
	static SPMutableAttributedStringAddAttributeValueRangeMethodPtr SPMutableAttributedStringAddAttributeValueRange;
	if (!SPMutableAttributedStringAddAttributeValueRange) SPMutableAttributedStringAddAttributeValueRange = (SPMutableAttributedStringAddAttributeValueRangeMethodPtr)[self methodForSelector:@selector(addAttribute:value:range:)];
	SPMutableAttributedStringAddAttributeValueRange(self, @selector(addAttribute:value:range:), aStr, aValue, aRange);
	return;
}

@interface CMTextView : NSTextView {
	BOOL autoindentEnabled;
	BOOL autopairEnabled;
	BOOL autoindentIgnoresEnter;
	BOOL autouppercaseKeywordsEnabled;
	BOOL delBackwardsWasPressed;
	BOOL autohelpEnabled;
	NoodleLineNumberView *lineNumberView;
	
	BOOL startListeningToBoundChanges;
	
	NSString *showMySQLHelpFor;
	
	IBOutlet NSScrollView *scrollView;
	
	NSUserDefaults *prefs;

	MCPConnection *mySQLConnection;
	int mySQLmajorVersion;

}

- (IBAction)showMySQLHelpForCurrentWord:(id)sender;

- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue;
- (BOOL) areAdjacentCharsLinked;
- (BOOL) isCaretAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar;
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix;
- (BOOL) shiftSelectionRight;
- (BOOL) shiftSelectionLeft;
- (NSArray *) completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index;
- (NSArray *) keywords;
- (NSArray *) functions;
- (void) setAutoindent:(BOOL)enableAutoindent;
- (BOOL) autoindent;
- (void) setAutoindentIgnoresEnter:(BOOL)enableAutoindentIgnoresEnter;
- (BOOL) autoindentIgnoresEnter;
- (void) setAutopair:(BOOL)enableAutopair;
- (BOOL) autopair;
- (void) setAutouppercaseKeywords:(BOOL)enableAutouppercaseKeywords;
- (BOOL) autouppercaseKeywords;
- (void) setAutohelp:(BOOL)enableAutohelp;
- (BOOL) autohelp;
- (void) selectLineNumber:(unsigned int)lineNumber ignoreLeadingNewLines:(BOOL)ignLeadingNewLines;
- (unsigned int) getLineNumberForCharacterIndex:(unsigned int)anIndex;
- (void) autoHelp;
- (void) doSyntaxHighlighting;
- (void) setConnection:(MCPConnection *)theConnection withVersion:(int)majorVersion;
- (void) doCompletion;
- (NSArray *)suggestionsForSQLCompletionWith:(NSString *)currentWord dictMode:(BOOL)isDictMode;
- (void) selectCurrentQuery;

- (unsigned int)characterIndexOfPoint:(NSPoint)aPoint;
- (void)insertFileContentOfFile:(NSString *)aPath;

@end