//
//  CustomQuery.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  Or mail to <lorenz@textor.ch>

#import "CustomQuery.h"
#import "SPSQLParser.h"
#import "SPGrowlController.h"
#import "SPStringAdditions.h"
#import "SPTextViewAdditions.h"
#import "TableDocument.h"

#define SP_MYSQL_DEV_SEARCH_URL   @"http://search.mysql.com/search?q=%@&site=refman-%@"
#define SP_HELP_SEARCH_IN_MYSQL   0
#define SP_HELP_SEARCH_IN_PAGE    1
#define SP_HELP_SEARCH_IN_WEB     2
#define SP_HELP_GOBACK_BUTTON     0
#define SP_HELP_SHOW_TOC_BUTTON   1
#define SP_HELP_GOFORWARD_BUTTON  2
#define SP_HELP_NOT_AVAILABLE     @"__no_help_available"


@implementation CustomQuery


#pragma mark IBAction methods


/*
 * Split all the queries in the text view, split them into individual queries,
 * and run sequentially.
 */
- (IBAction)runAllQueries:(id)sender
{
	SPSQLParser *queryParser;
	NSArray		*queries;

	// Fixes bug in key equivalents.
	if ([[NSApp currentEvent] type] == NSKeyUp) {
		return;
	}

	// Retrieve the custom query string and split it into separate SQL queries
	queryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	queries = [queryParser parseQueries];
	[queryParser release];

	NSRange curRange = [textView selectedRange];
	// Unselect a selection if given to avoid interferring with error highlighting
	[textView setSelectedRange:NSMakeRange(curRange.location, 0)];
	// Reset queryStartPosition
	queryStartPosition = 0;

	[self performQueries:queries];
	// If no error was selected reconstruct a given selection
	if([textView selectedRange].length == 0)
		[textView setSelectedRange:curRange];

	// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
	NSRange oldRange = [textView selectedRange];
	[textView setSelectedRange:NSMakeRange(oldRange.location,0)];
	[textView insertText:@""];
	[textView setSelectedRange:oldRange];
	

	// Select the text of the query textView for re-editing
	//[textView selectAll:self];
}

/*
 * Depending on selection, run either the query containing the selection caret (if the caret is
 * at a single point within the text view), or run the selected text (if a text range is selected).
 */
- (IBAction)runSelectedQueries:(id)sender
{
	NSArray *queries;
	NSString *query;
	NSRange selectedRange = [textView selectedRange];
	SPSQLParser *queryParser;

	// If the current selection is a single caret position, run the current query.
	if (selectedRange.length == 0) {
		BOOL doLookBehind = YES;
		query = [self queryAtPosition:selectedRange.location lookBehind:&doLookBehind];
		if (!query) {
			NSBeep();
			return;
		}
		queries = [NSArray arrayWithObject:query];

	// Otherwise, run the selected text.
	} else {
		queryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:selectedRange]];
		queries = [queryParser parseQueries];
		[queryParser release];
	}
	
	// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
	// and preserve the selection
	[textView setSelectedRange:NSMakeRange(selectedRange.location,0)];
	[textView insertText:@""];
	[textView setSelectedRange:selectedRange];

	[self performQueries:queries];
}


- (IBAction)chooseQueryFavorite:(id)sender
/*
insert the choosen favorite query in the query textView or save query to favorites or opens window to edit favorites
*/
{
	if ( [queryFavoritesButton indexOfSelectedItem] == 1) {
//save query to favorites
		//check if favorite doesn't exist
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:[textView string]] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Query already exists", @"query already exists message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"The query you are adding to your favorites already exists.", @"query already exists informative message"));
				return;
			}
		}
		if ( [[textView string] isEqualToString:@""] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Empty query", @"empty query message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"Cannot save an empty query.", @"empty query informative message"));
				return;
		}
		[queryFavorites addObject:[NSString stringWithString:[textView string]]];
		[queryFavoritesView reloadData];
		[prefs setObject:queryFavorites forKey:@"queryFavorites"];
		[self setFavorites];
	} else if ( [queryFavoritesButton indexOfSelectedItem] == 2) {
//edit favorites
		[NSApp beginSheet:queryFavoritesSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:queryFavoritesSheet];
	
		[NSApp endSheet:queryFavoritesSheet];
		[queryFavoritesSheet orderOut:nil];
	} else if ( [queryFavoritesButton indexOfSelectedItem] != 3) {
//choose favorite
		// Register the next action for undo
		[textView shouldChangeTextInRange:[textView selectedRange] replacementString:[queryFavoritesButton titleOfSelectedItem]];
		[textView replaceCharactersInRange:[textView selectedRange] withString:[queryFavoritesButton titleOfSelectedItem]];
		// invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
		[textView insertText:@""];
	}
}

- (IBAction)chooseQueryHistory:(id)sender
/*
insert the choosen history query in the query textView
*/
{
	// Register the next action for undo
	[textView shouldChangeTextInRange:NSMakeRange(0,[[textView string] length]) replacementString:[queryHistoryButton titleOfSelectedItem]];
	[textView setString:[queryHistoryButton titleOfSelectedItem]];
	// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
	[textView insertText:@""];
	[textView selectAll:self];
}

- (IBAction)closeSheet:(id)sender
/*
closes the sheet
*/
{
	[NSApp stopModal];
}

/*
 * Perform simple actions (which don't require their own method), triggered by selecting the appropriate menu item
 * in the "gear" action menu displayed beneath the cusotm query view.
 */
- (IBAction)gearMenuItemSelected:(id)sender
{
	// "Clear History" menu item - clear query history
	if (sender == clearHistoryMenuItem) {
		[queryHistoryButton removeAllItems];
		[queryHistoryButton addItemWithTitle:NSLocalizedString(@"Query History…",@"Title of query history popup button")];
		[prefs setObject:[NSArray array] forKey:@"queryHistory"];
	}

	// "Shift Right" menu item - indent the selection with an additional tab.
	if (sender == shiftRightMenuItem) {
		[textView shiftSelectionRight];
	}

	// "Shift Left" menu item - un-indent the selection by one tab if possible.
	if (sender == shiftLeftMenuItem) {
		[textView shiftSelectionLeft];
	}

	// "Completion List" menu item - used to autocomplete.  Uses a different shortcut to avoid the menu button flickering
	// on normal autocomplete usage.
	if (sender == completionListMenuItem) {
		[textView complete:self];
	}

	// "Editor font..." menu item to bring up the font panel
	if (sender == editorFontMenuItem) {
		[[NSFontPanel sharedFontPanel] setPanelFont:[textView font] isMultiple:NO];
		[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
	}

	// "Indent new lines" toggle
	if (sender == autoindentMenuItem) {
		BOOL enableAutoindent = !([autoindentMenuItem state] == NSOffState);
		[prefs setBool:enableAutoindent forKey:@"CustomQueryAutoindent"];
		[prefs synchronize];
		[autoindentMenuItem setState:enableAutoindent?NSOnState:NSOffState];
		[textView setAutoindent:enableAutoindent];
	}

	// "Auto-pair characters" toggle
	if (sender == autopairMenuItem) {
		BOOL enableAutopair = !([autopairMenuItem state] == NSOffState);
		[prefs setBool:enableAutopair forKey:@"CustomQueryAutopair"];
		[prefs synchronize];
		[autopairMenuItem setState:enableAutopair?NSOnState:NSOffState];
		[textView setAutopair:enableAutopair];
	}

	// "Auto-help" toggle
	if (sender == autohelpMenuItem) {
		BOOL enableAutohelp = !([autohelpMenuItem state] == NSOffState);
		[prefs setBool:enableAutohelp forKey:@"CustomQueryAutohelp"];
		[prefs synchronize];
		[autohelpMenuItem setState:enableAutohelp?NSOnState:NSOffState];
		[textView setAutohelp:enableAutohelp];
	}

	// "Auto-uppercase keywords" toggle
	if (sender == autouppercaseKeywordsMenuItem) {
		BOOL enableAutouppercaseKeywords = !([autouppercaseKeywordsMenuItem state] == NSOffState);
		[prefs setBool:enableAutouppercaseKeywords forKey:@"CustomQueryAutouppercaseKeywords"];
		[prefs synchronize];
		[autouppercaseKeywordsMenuItem setState:enableAutouppercaseKeywords?NSOnState:NSOffState];
		[textView setAutouppercaseKeywords:enableAutouppercaseKeywords];
	}
}


#pragma mark -
#pragma mark queryFavoritesSheet methods


- (IBAction)addQueryFavorite:(id)sender
/*
adds a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	[queryFavorites addObject:[NSString string]];
	[queryFavoritesView reloadData];
	[queryFavoritesView selectRow:[queryFavoritesView numberOfRows]-1 byExtendingSelection:NO];
	[queryFavoritesView editColumn:0 row:[queryFavoritesView numberOfRows]-1 withEvent:nil select:YES];
}

- (IBAction)removeQueryFavorite:(id)sender
/*
removes a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	if ( [queryFavoritesView numberOfSelectedRows] > 0 ) {
		[queryFavorites removeObjectAtIndex:[queryFavoritesView selectedRow]];
		[queryFavoritesView reloadData];
	}
}

- (IBAction)copyQueryFavorite:(id)sender
/*
copies a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	if ( [queryFavoritesView numberOfSelectedRows] > 0 ) {
		[queryFavorites insertObject:
					[NSString stringWithString:[queryFavorites objectAtIndex:[queryFavoritesView selectedRow]]]
					atIndex:[queryFavoritesView selectedRow]+1];
		[queryFavoritesView reloadData];
		[queryFavoritesView selectRow:[queryFavoritesView selectedRow]+1 byExtendingSelection:NO];
		[queryFavoritesView editColumn:0 row:[queryFavoritesView selectedRow] withEvent:nil select:YES];
	}
}

- (IBAction)closeQueryFavoritesSheet:(id)sender
/*
closes queryFavoritesSheet and saves favorites to preferences
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	[NSApp stopModal];
	[prefs setObject:queryFavorites forKey:@"queryFavorites"];
	[self setFavorites];
}


#pragma mark -
#pragma mark Query actions


- (void)performQueries:(NSArray *)queries;
/*
performs the mysql-query given by the user
sets the tableView columns corresponding to the mysql-result
*/
{	
	
	NSArray		*theColumns;
	NSTableColumn	*theCol;
	CMMCPResult	*theResult = nil;
	NSMutableArray	*menuItems = [NSMutableArray array];
	NSMutableArray	*tempResult = [NSMutableArray array];
	NSMutableString	*errors = [NSMutableString string];
	int i, totalQueriesRun = 0, totalAffectedRows = 0;
	float executionTime = 0;
	int firstErrorOccuredInQuery = -1;
	BOOL suppressErrorSheet = NO;

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// Reset the current table view as necessary to avoid redraw and reload issues.
	// Restore the view position to the top left to be within the results for all datasets.
	[customQueryView scrollRowToVisible:0];
	[customQueryView scrollColumnToVisible:0];

	// Remove all the columns
	theColumns = [customQueryView tableColumns];
	while ([theColumns count]) {
		[customQueryView removeTableColumn:[theColumns objectAtIndex:0]];
	}

	// Perform the supplied queries in series
	for ( i = 0 ; i < [queries count] ; i++ ) {
	
		// Don't run blank queries, or queries which only contain whitespace.
		if ([[[queries objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)
			continue;

		// Run the query, timing execution (note this also includes network and overhead)
		theResult = [mySQLConnection queryString:[queries objectAtIndex:i]];
		executionTime += [mySQLConnection lastQueryExecutionTime];
		totalQueriesRun++;

		// Record any affected rows
		if ( [mySQLConnection affectedRows] != -1 )
			totalAffectedRows += [mySQLConnection affectedRows];

		// Store any error messages
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			
			// If the query errored, append error to the error log for display at the end
			if ( [queries count] > 1 ) {
				if(firstErrorOccuredInQuery == -1)
					firstErrorOccuredInQuery = i+1;
				
				if(!suppressErrorSheet)
				{
					// Update error text for the user
					[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"),
										i+1,
										[mySQLConnection getLastErrorMessage]]];
					[errorText setStringValue:errors];
					// ask the user to continue after detecting an error
					NSAlert *alert = [[[NSAlert alloc] init] autorelease];
					[alert addButtonWithTitle:NSLocalizedString(@"Run All", @"run all button")];
					[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"continue button")];
					[alert addButtonWithTitle:NSLocalizedString(@"Stop", @"stop button")];
					[alert setMessageText:NSLocalizedString(@"MySQL Error", @"mysql error message")];
					[alert setInformativeText:[mySQLConnection getLastErrorMessage]];
					[alert setAlertStyle:NSWarningAlertStyle];
					int choice = [alert runModal];
					switch (choice){
						case NSAlertFirstButtonReturn:
							suppressErrorSheet = YES;
						case NSAlertSecondButtonReturn:
							break;
						default:
							if(i < [queries count]-1) // output that message only if it was not the last one
								[errors appendString:NSLocalizedString(@"Execution stopped!\n", @"execution stopped message")];
							i = [queries count]; // break for loop; for safety reasons stop the execution of the following queries
					}
				
				} else {
					[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"),
											i+1,
											[mySQLConnection getLastErrorMessage]]];
				}
			} else {
				[errors setString:[mySQLConnection getLastErrorMessage]];
			}
		}
	}
	
	if(usedQuery)
		[usedQuery release];
	usedQuery = [[NSString stringWithString:[queries componentsJoinedByString:@";\n"]] retain];
	
	//perform empty query if no query is given
	if ( [queries count] == 0 ) {
		theResult = [mySQLConnection queryString:@""];
		[errors setString:[mySQLConnection getLastErrorMessage]];
	}
	
	//put result in array
	[queryResult release];
	queryResult = nil;
	if ( nil != theResult )
	{
		int r = [theResult numOfRows];
		if (r) [theResult dataSeek:0];
		for ( i = 0 ; i < r ; i++ ) {
			[tempResult addObject:[theResult fetchRowAsArray]];
		}
		queryResult = [[NSArray arrayWithArray:tempResult] retain];
	}

	//add query to history
	[queryHistoryButton insertItemWithTitle:[queries componentsJoinedByString:@"; "] atIndex:1];
	while ( [queryHistoryButton numberOfItems] > [[prefs objectForKey:@"CustomQueryMaxHistoryItems"] intValue] + 1 ) {
		[queryHistoryButton removeItemAtIndex:[queryHistoryButton numberOfItems]-1];
	}
	for ( i = 1 ; i < [queryHistoryButton numberOfItems] ; i++ )
	{
		[menuItems addObject:[queryHistoryButton itemTitleAtIndex:i]];
	}
	[prefs setObject:menuItems forKey:@"queryHistory"];

	// Error checking
	if ( [errors length] ) {
		// set the error text
		[errorText setStringValue:errors];
		// select the line x of the first error if error message contains "at line x"
		NSError *err1 = NULL;
		NSRange errorLineNumberRange = [errors rangeOfRegex:@"([0-9]+)$" options:RKLNoOptions inRange:NSMakeRange(0, [errors length]) capture:1 error:&err1];
		if(errorLineNumberRange.length) // if a line number was found
		{
			// Get the line number
			unsigned int errorAtLine = [[errors substringWithRange:errorLineNumberRange] intValue];
			[textView selectLineNumber:errorAtLine ignoreLeadingNewLines:YES];

			// Check for near message
			NSRange errorNearMessageRange = [errors rangeOfRegex:@" '(.*?)' " options:(RKLMultiline|RKLDotAll) inRange:NSMakeRange(0, [errors length]) capture:1 error:&err1];
			if(errorNearMessageRange.length) // if a "near message" was found
			{
				// Build the range to search for nearMessage (beginning from queryStartPosition to try to avoid mismatching)
				NSRange theRange = NSMakeRange(queryStartPosition, [[textView string] length]-queryStartPosition);
				// Get the range in textView of the near message
				NSRange textNearMessageRange = [[[textView string] substringWithRange:theRange] rangeOfString:[errors substringWithRange:errorNearMessageRange] options:NSLiteralSearch];
				// Correct the near message range relative to queryStartPosition
				textNearMessageRange = NSMakeRange(textNearMessageRange.location+queryStartPosition, textNearMessageRange.length);
				// Select the near message and scroll to it
				[textView setSelectedRange:textNearMessageRange];
				[textView scrollRangeToVisible:textNearMessageRange];
			}
		} else { // Select first erroneous query entirely
			
			NSRange queryRange;
			if(firstErrorOccuredInQuery == -1) // for current or previous query
			{
				BOOL isLookBehind = YES;
				queryRange = [self queryTextRangeAtPosition:[textView selectedRange].location lookBehind:&isLookBehind];
				[textView setSelectedRange:queryRange];
			} else {
				// select the query for which the first error was detected
				queryRange = [self queryTextRangeForQuery:firstErrorOccuredInQuery startPosition:queryStartPosition];
				[textView setSelectedRange:queryRange];
			}

		}
		
	} else {
		[errorText setStringValue:NSLocalizedString(@"There were no errors.", @"text shown when query was successfull")];
	}
	
	// Set up the status string
	if ( totalQueriesRun > 1 ) {
		if (totalAffectedRows==1) {
			[affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"1 row affected in total, by %i queries taking %@", @"text showing one row has been affected by multiple queries"),
                                              totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];

		} else {
			[affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%i rows affected in total, by %i queries taking %@", @"text showing how many rows have been affected by multiple queries"),
                                              totalAffectedRows,
                                              totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];

		}
	} else {
		if (totalAffectedRows==1) {
			[affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"1 row affected, taking %@", @"text showing one row has been affected by a single query"),
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
		} else {
			[affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%i rows affected, taking %@", @"text showing how many rows have been affected by a single query"),
                                              totalAffectedRows,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];

		}
	}


	// If no results were returned, redraw the empty table and post notifications before returning.
	if ( !theResult || ![theResult numOfRows] ) {
		[customQueryView reloadData];

		// Notify any listeners that the query has completed
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

		// Perform the Growl notification for query completion
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                       description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                                  notificationName:@"Query Finished"];

		return;
	}


	// Otherwise add columns corresponding to the query result
	theColumns = [theResult fetchFieldNames];
	for ( i = 0 ; i < [theResult numOfFields] ; i++) {
		theCol = [[NSTableColumn alloc] initWithIdentifier:[NSNumber numberWithInt:i]];
		[theCol setResizingMask:NSTableColumnUserResizingMask];
		NSTextFieldCell *dataCell = [[[NSTextFieldCell alloc] initTextCell:@""] autorelease];
		[dataCell setEditable:NO];
		if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
			[dataCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[dataCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		[theCol setDataCell:dataCell];
		[[theCol headerCell] setStringValue:[theColumns objectAtIndex:i]];

		[customQueryView addTableColumn:theCol];
		[theCol release];
	}
	
	[customQueryView sizeLastColumnToFit];
	//tries to fix problem with last row (otherwise to small)
	//sets last column to width of the first if smaller than 30
	//problem not fixed for resizing window
	if ( [[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:[theColumns count]-1]] width] < 30 )
		[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:[theColumns count]-1]]
				setWidth:[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:0]] width]];
	[customQueryView reloadData];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	// Query finished Growl notification    
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                              notificationName:@"Query Finished"];
}

/*
 * Retrieve the range of the query at a position specified 
 * within the custom query text view.
 */
- (NSRange)queryTextRangeAtPosition:(long)position lookBehind:(BOOL *)doLookBehind
{
	SPSQLParser *customQueryParser;
	NSArray *queries;
	NSString *query = nil;
	int i, j, lastQueryStartPosition, queryPosition = 0;

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return NSMakeRange(NSNotFound,0);

	// Split the current text into queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringByCharacter:';']];
	[customQueryParser release];

	// Walk along the array of queries to identify the current query - taking into account
	// the extra semicolon at the end of each query
	for (i = 0; i < [queries count]; i++ ) {
		lastQueryStartPosition = queryStartPosition;
		queryStartPosition = queryPosition;
		queryPosition += [[queries objectAtIndex:i] length];
		if (queryPosition >= position) {

			// If lookbehind is enabled, check whether the current position could be considered to
			// be within the previous query.  A position just after a semicolon is always considered
			// to be within the previous query; otherwise, if there is only whitespace *and newlines*
			// before the next character, also consider the position to belong to the previous query.
			if (*doLookBehind) {
				BOOL positionAssociatedWithPreviousQuery = NO;
				NSCharacterSet *newlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

				// If the caret is at the very start of the string, always associate
				if (position == queryStartPosition) positionAssociatedWithPreviousQuery = YES;

				// Otherwise associate if only whitespace since previous, and a newline before next.
				if (!positionAssociatedWithPreviousQuery) {
					NSString *stringToPrevious = [[textView string] substringWithRange:NSMakeRange(queryStartPosition, position - queryStartPosition)];
					NSString *stringToEnd = [[textView string] substringWithRange:NSMakeRange(position, queryPosition - position)];
					NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
					if (![[stringToPrevious stringByTrimmingCharactersInSet:newlineSet] length]) {
						for (j = 0; j < [stringToEnd length]; j++) {
							if ([whitespaceSet characterIsMember:[stringToEnd characterAtIndex:j]]) continue;
							if ([newlineSet characterIsMember:[stringToEnd characterAtIndex:j]]) {
								positionAssociatedWithPreviousQuery = YES;
							}
							break;
						}
					}
				}

				// If there is a previous query and the position should and can be associated with it, do so.
				if (i && positionAssociatedWithPreviousQuery && [[[queries objectAtIndex:i-1] stringByTrimmingCharactersInSet:newlineSet] length]) {
					query = [NSString stringWithString:[queries objectAtIndex:i-1]];
					queryStartPosition = lastQueryStartPosition;
					break;
				}

				// Lookbehind failed - set the pointer to NO so the parent knows.
				*doLookBehind = NO;
			}

			query = [NSString stringWithString:[queries objectAtIndex:i]];
			break;
		}
		queryPosition++;
	}

	// For lookbehinds catch position at the very end of a string ending in a semicolon
	if (*doLookBehind && position == [[textView string] length] && !query)
	{
		query = [queries lastObject];
	} 

	if(queryStartPosition < 0) queryStartPosition = 0;

	[queries release];

	// Remove all leading white spaces
	NSError *err;
	int offset = [query rangeOfRegex:@"^(\\s*)" options:RKLNoOptions inRange:NSMakeRange(0, [query length]) capture:1 error:&err].length;

	return NSMakeRange(queryStartPosition+offset, [query length]-offset);
}

/*
 * Retrieve the range of the query for the passed index seen from a start position
 * specified within the custom query text view.  
 */
- (NSRange)queryTextRangeForQuery:(int)anIndex startPosition:(long)position
{
	SPSQLParser *customQueryParser;
	NSArray *queries;
	int i;

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return NSMakeRange(NSNotFound,0);

	// Split the current text into queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:NSMakeRange(position, [[textView string] length]-position)]];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringByCharacter:';']];
	[customQueryParser release];
	anIndex--;
	if(anIndex < 0 || anIndex >= [queries count])
	{
		[queries release];
		return NSMakeRange(NSNotFound, 0);
	}

	NSString * theQuery = [queries objectAtIndex:anIndex];

	// Calculate the text length before that query at index anIndex
	long prevQueriesLength = 0;
	for (i = 0; i < anIndex; i++ ) {
		prevQueriesLength += [[queries objectAtIndex:i] length] + 1;
	}

	[queries release];
	
	// Remove all leading white spaces
	NSError *err;
	int offset = [theQuery rangeOfRegex:@"^(\\s*)" options:RKLNoOptions inRange:NSMakeRange(0, [theQuery length]) capture:1 error:&err].length;

	return NSMakeRange(position+offset+prevQueriesLength, [theQuery length] - offset);
}

/*
 * Retrieve the query at a position specified within the custom query
 * text view.  This will return nil if the position specified is beyond
 * the available string or if an empty query would be returned.
 * If lookBehind is set, returns the *previous* query, but only if the
 * caret should be associated with the previous query based on whitespace.
 */
- (NSString *)queryAtPosition:(long)position lookBehind:(BOOL *)doLookBehind
{
	SPSQLParser *customQueryParser;
	NSArray *queries;
	NSString *query = nil;
	int i, j, lastQueryStartPosition, queryPosition = 0;

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return nil;

	// Split the current text into queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringByCharacter:';']];
	[customQueryParser release];

	// Walk along the array of queries to identify the current query - taking into account
	// the extra semicolon at the end of each query
	for (i = 0; i < [queries count]; i++ ) {
		lastQueryStartPosition = queryStartPosition;
		queryStartPosition = queryPosition;
		queryPosition += [[queries objectAtIndex:i] length];
		if (queryPosition >= position) {
		
			// If lookbehind is enabled, check whether the current position could be considered to
			// be within the previous query.  A position just after a semicolon is always considered
			// to be within the previous query; otherwise, if there is only whitespace *and newlines*
			// before the next character, also consider the position to belong to the previous query.
			if (*doLookBehind) {
				BOOL positionAssociatedWithPreviousQuery = NO;
				NSCharacterSet *newlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

				// If the caret is at the very start of the string, always associate
				if (position == queryStartPosition) positionAssociatedWithPreviousQuery = YES;

				// Otherwise associate if only whitespace since previous, and a newline before next.
				if (!positionAssociatedWithPreviousQuery) {
					NSString *stringToPrevious = [[textView string] substringWithRange:NSMakeRange(queryStartPosition, position - queryStartPosition)];
					NSString *stringToEnd = [[textView string] substringWithRange:NSMakeRange(position, queryPosition - position)];
					NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
					if (![[stringToPrevious stringByTrimmingCharactersInSet:newlineSet] length]) {
						for (j = 0; j < [stringToEnd length]; j++) {
							if ([whitespaceSet characterIsMember:[stringToEnd characterAtIndex:j]]) continue;
							if ([newlineSet characterIsMember:[stringToEnd characterAtIndex:j]]) {
								positionAssociatedWithPreviousQuery = YES;
							}
							break;
						}
					}
				}

				// If there is a previous query and the position should be associated with it, do so.
				if (i && positionAssociatedWithPreviousQuery && [[[queries objectAtIndex:i-1] stringByTrimmingCharactersInSet:newlineSet] length]) {
					query = [NSString stringWithString:[queries objectAtIndex:i-1]];
					queryStartPosition = lastQueryStartPosition;
					break;
				}

				// Lookbehind failed - set the pointer to NO so the parent knows.
				*doLookBehind = NO;
			}
			
			query = [NSString stringWithString:[queries objectAtIndex:i]];
			break;
		}
		queryPosition++;
	}

	// For lookbehinds catch position at the very end of a string ending in a semicolon
	if (*doLookBehind && position == [[textView string] length] && !query)
	{
		query = [queries lastObject];
	} 

	[queries release];

	// Ensure the string isn't empty.
	// (We could also strip comments for this check, but that prevents use of conditional comments)
	if ([[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)
		return nil;

	// Return the located string.
	return query;
}


#pragma mark -
#pragma mark Accessors


- (NSArray *)currentResult
/*
returns the current result (as shown in custom result view) as array, the first object containing the field names as array, the following objects containing the rows as array
*/
{
	NSArray *tableColumns = [customQueryView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id tableColumn;
	NSMutableArray *currentResult = [NSMutableArray array];
	NSMutableArray *tempRow = [NSMutableArray array];
	int i;
	
	//set field names as first line
	while ( (tableColumn = [enumerator nextObject]) ) {
		[tempRow addObject:[[tableColumn headerCell] stringValue]];
	}
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	
	//add rows
	for ( i = 0 ; i < [self numberOfRowsInTableView:customQueryView] ; i++) {
		[tempRow removeAllObjects];
		enumerator = [tableColumns objectEnumerator];
		while ( (tableColumn = [enumerator nextObject]) ) {
			[tempRow addObject:[self tableView:customQueryView objectValueForTableColumn:tableColumn row:i]];
		}
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	return currentResult;
}


#pragma mark -
#pragma mark Additional methods


- (void)setConnection:(CMMCPConnection *)theConnection
/*
sets the connection (received from TableDocument) and makes things that have to be done only once 
*/
{
	NSArray *tableColumns = [queryFavoritesView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id column;

	mySQLConnection = theConnection;

	prefs = [[NSUserDefaults standardUserDefaults] retain];
	if ( [prefs objectForKey:@"queryFavorites"] ) {
		queryFavorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"queryFavorites"]];
	} else {
		queryFavorites = [[NSMutableArray array] retain];
	}

	// Set up the interface
	// Bind backgroundColor
	[textView setAllowsDocumentBackgroundColorChange:YES];
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	[bindingOptions setObject:NSUnarchiveFromDataTransformerName
		forKey:@"NSValueTransformerName"];
	[textView bind: @"backgroundColor"
		toObject: [NSUserDefaultsController sharedUserDefaultsController]
		withKeyPath:@"values.CustomQueryEditorBackgroundColor"
		options:bindingOptions];
	[textView setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorFont"]]];
	[textView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorBackgroundColor"]]];
	[textView setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorTextColor"]]];

	[customQueryView setVerticalMotionCanBeginDrag:NO];
	[textView setContinuousSpellCheckingEnabled:NO];
	[autoindentMenuItem setState:([prefs boolForKey:@"CustomQueryAutoindent"]?NSOnState:NSOffState)];
	[textView setAutoindent:[prefs boolForKey:@"CustomQueryAutoindent"]];
	[textView setAutoindentIgnoresEnter:YES];
	[autopairMenuItem setState:([prefs boolForKey:@"CustomQueryAutopair"]?NSOnState:NSOffState)];
	[textView setAutopair:[prefs boolForKey:@"CustomQueryAutopair"]];
	[autohelpMenuItem setState:([prefs boolForKey:@"CustomQueryAutohelp"]?NSOnState:NSOffState)];
	[textView setAutohelp:[prefs boolForKey:@"CustomQueryAutohelp"]];
	[autouppercaseKeywordsMenuItem setState:([prefs boolForKey:@"CustomQueryAutouppercaseKeywords"]?NSOnState:NSOffState)];
	[textView setAutouppercaseKeywords:[prefs boolForKey:@"CustomQueryAutouppercaseKeywords"]];
	[queryFavoritesView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];
	while ( (column = [enumerator nextObject]) )
	{
		if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
			[[column dataCell] setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[[column dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}
	if ( [prefs objectForKey:@"queryHistory"] )
	{
		[queryHistoryButton addItemsWithTitles:[prefs objectForKey:@"queryHistory"]];
	}
	[self setFavorites];
	
	// Disable runSelectionMenuItem in the gear menu
	[runSelectionMenuItem setEnabled:NO];
	
}

- (void)setFavorites
/*
set up the favorites popUpButton
*/
{
	int i;

//remove all menuItems and add favorites from preferences
	for ( i = 4 ; i < [queryFavoritesButton numberOfItems] ; i++ ) {
		[queryFavoritesButton removeItemAtIndex:i];
	}
	[queryFavoritesButton addItemsWithTitles:queryFavorites];
}

- (void)doPerformQueryService:(NSString *)query
/*
inserts the query in the textView and performs query
*/
{
	[textView setString:query];
	[self runAllQueries:self];
}

- (NSString *)usedQuery
{
	return usedQuery;
}

#pragma mark -
#pragma mark TableView datasource methods


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( aTableView == customQueryView ) {
		if ( nil == queryResult ) {
			return 0;
		} else {
			return [queryResult count];
		}
	} else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites count];
	} else {
		return 0;
	}
}

- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSArray	*theRow;
	NSNumber *theIdentifier = [aTableColumn identifier];

	if ( aTableView == customQueryView ) {
		theRow = [queryResult objectAtIndex:rowIndex];
		
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isKindOfClass:[NSData class]] ) {
			NSString *tmp = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
												  encoding:[mySQLConnection encoding]];
			if (tmp == nil) {
				tmp = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
											encoding:NSASCIIStringEncoding];
			}
			return [tmp autorelease];
		}
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isMemberOfClass:[NSNull class]] )
			return [prefs objectForKey:@"NullValue"];
	
		return [theRow objectAtIndex:[theIdentifier intValue]];
	} else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites objectAtIndex:rowIndex];
	} else {
		return @"";
	}
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ( aTableView == queryFavoritesView ) {
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		int i = 0;

		if ( [anObject isEqualToString:@""] ) {
			[queryFavoritesView deselectAll:self];
			[queryFavorites removeObjectAtIndex:rowIndex];
			[queryFavoritesView reloadData];
			return;
		}

		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:anObject] && i != rowIndex) {
				NSRunAlertPanel(@"Query already exists", @"The query you are adding to your favorites already exists.", @"OK", nil, nil);
				
				//remove row if it was a (blank) new row or a copied row
				if ( [[queryFavorites objectAtIndex:rowIndex] isEqualToString:@""] ||
						[[queryFavorites objectAtIndex:rowIndex] isEqualToString:anObject] ) {
					[queryFavoritesView deselectAll:self];
					[queryFavorites removeObjectAtIndex:rowIndex];
					[queryFavoritesView reloadData];
				}
				return;
			}
			i++;
		}
		[queryFavorites replaceObjectAtIndex:rowIndex withObject:anObject];
		[queryFavoritesView reloadData];
	}
}


//tableView drag&drop datasource methods
- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	int originalRow;
	NSArray *pboardTypes;

	if ( aTableView == queryFavoritesView ) 
	{
		if ( [rows count] == 1 ) 
		{
			pboardTypes = [NSArray arrayWithObjects:@"SequelProPasteboard", nil];
			originalRow = [[rows objectAtIndex:0] intValue];
	
			[pboard declareTypes:pboardTypes owner:nil];
			[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:@"SequelProPasteboard"];
			
			return YES;
		} 
		else 
		{
			return NO;
		}
	} else if ( aTableView == customQueryView ) {
		NSString *tmp = [customQueryView draggedRowsAsTabString:rows];
		if ( nil != tmp )
		{
			[pboard declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType, 
				NSStringPboardType, nil]
						   owner:nil];
			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];
			return YES;
		}
		return NO;
	} else {
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	int originalRow;

	if ( aTableView == queryFavoritesView ) {
		if ([pboardTypes count] == 1 && row != -1)
		{
			if ([[pboardTypes objectAtIndex:0] isEqualToString:@"SequelProPasteboard"]==YES && operation==NSTableViewDropAbove)
			{
				originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
	
				if (row != originalRow && row != (originalRow+1))
				{
					return NSDragOperationMove;
				}
			}
		}
		return NSDragOperationNone;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView*)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	int originalRow;
	int destinationRow;
	NSMutableDictionary *draggedRow;

	if ( aTableView == queryFavoritesView ) {
		originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
		destinationRow = row;
	
		if ( destinationRow > originalRow )
			destinationRow--;
	
		draggedRow = [queryFavorites objectAtIndex:originalRow];
		[queryFavorites removeObjectAtIndex:originalRow];
		[queryFavorites insertObject:draggedRow atIndex:destinationRow];
		
		[queryFavoritesView reloadData];
		[queryFavoritesView selectRow:destinationRow byExtendingSelection:NO];
	
		return YES;
	} else {
		return NO;
	}
}


//tableView delegate methods
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
/*
opens sheet with value when double clicking on a field
*/
{
	if ( aTableView == customQueryView ) {
		NSArray *theRow;
		NSString *theValue;
		NSNumber *theIdentifier = [aTableColumn identifier];
	
	//get the value
		theRow = [queryResult objectAtIndex:rowIndex];
	
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isKindOfClass:[NSData class]] ) {
			theValue = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
								encoding:[mySQLConnection encoding]];
			if (theValue == nil) {
				theValue = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
												 encoding:NSASCIIStringEncoding];
			}
			[theValue autorelease];
		} else if ( [[theRow objectAtIndex:[theIdentifier intValue]] isMemberOfClass:[NSNull class]] ) {
			theValue = [prefs objectForKey:@"NullValue"];
		} else {
			theValue = [theRow objectAtIndex:[theIdentifier intValue]];
		}
	
		[valueTextField setString:[theValue description]];
		[valueTextField selectAll:self];
		[NSApp beginSheet:valueSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:valueSheet];
	
		[NSApp endSheet:valueSheet];
		[valueSheet orderOut:nil];
	
		return NO;
	} else {
		return YES;
	}
}


#pragma mark -
#pragma mark SplitView delegate methods


- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
/*
tells the splitView that it can collapse views
*/
{
	return YES;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
/*
defines max position of splitView
*/
{
	if ( offset == 0 ) {
		return proposedMax - 100;
	} else {
		return proposedMax - 73;
	}
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
/*
defines min position of splitView
*/
{
	if ( offset == 0 ) {
		return proposedMin + 100;
	} else {
		return proposedMin + 100;
	}
}


#pragma mark -
#pragma mark TextView delegate methods


- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
/*
traps enter key and
	performs query instead of inserting a line break if aTextView == textView
	closes valueSheet if aTextView == valueTextField
*/
{
	if ( aTextView == textView ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] &&
				[[[NSApp currentEvent] characters] isEqualToString:@"\003"] )
		{
			[self runAllQueries:self];
			return YES;
		} else {
			return NO;
		}
		
	} else if ( aTextView == valueTextField ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] )
		{
			[self closeSheet:self];
			return YES;
		} else {
			return NO;
		}
	}
	return NO;
}

/*
 * A notification posted when the selection changes within the text view;
 * used to control the run-currentrun-selection button state and action.
 */
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	// Ensure that the notification is from the custom query text view
	if ( [aNotification object] != textView ) return;

	// If no text is selected, disable the button and action menu.
	if ( [textView selectedRange].location == NSNotFound ) {
		[runSelectionButton setEnabled:NO];
		[runSelectionMenuItem setEnabled:NO];
		return;
	}

	// If the current selection is a single caret position, update the button based on
	// whether the caret is inside a valid query.
	if ([textView selectedRange].length == 0) {
		int selectionPosition = [textView selectedRange].location;
		int movedRangeStart, movedRangeLength;
		BOOL updateQueryButtons = FALSE;
		NSRange oldSelection;
		NSCharacterSet *whitespaceAndNewlineCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];

		// Retrieve the old selection position
        [[[aNotification userInfo] objectForKey:@"NSOldSelectedCharacterRange"] getValue:&oldSelection];

		// Only process the query text if the selection previously had length, or moved more than 100 characters,
		// or the intervening space contained a semicolon, or typing has been performed with no current query.
		// This adds more checks to every keypress, but ensures the majority of the actions don't incur a
		// parsing overhead - which is cheap on small text strings but heavy of large queries.
		movedRangeStart = (selectionPosition < oldSelection.location)?selectionPosition:oldSelection.location;
		movedRangeLength = abs(selectionPosition - oldSelection.location);
		if (oldSelection.length > 0) updateQueryButtons = TRUE;
		if (!updateQueryButtons && movedRangeLength > 100) updateQueryButtons = TRUE;
		if (!updateQueryButtons && oldSelection.location > [[textView string] length]) updateQueryButtons = TRUE;
		if (!updateQueryButtons && [[textView string] rangeOfString:@";" options:0 range:NSMakeRange(movedRangeStart, movedRangeLength)].location != NSNotFound) updateQueryButtons = TRUE;
		if (!updateQueryButtons && ![runSelectionButton isEnabled] && selectionPosition > oldSelection.location
				&& [[[[textView string] substringWithRange:NSMakeRange(movedRangeStart, movedRangeLength)] stringByTrimmingCharactersInSet:whitespaceAndNewlineCharset] length]) updateQueryButtons = TRUE;
		if (!updateQueryButtons && [[runSelectionButton title] isEqualToString:NSLocalizedString(@"Run Current", @"Title of button to run current query in custom query view")]) {
			int charPosition;
			unichar theChar;
			for (charPosition = selectionPosition; charPosition > 0; charPosition--) {
				theChar = [[textView string] characterAtIndex:charPosition-1];
				if (theChar == ';') {
					updateQueryButtons = TRUE;
					break;
				}
				if (![whitespaceAndNewlineCharset characterIsMember:theChar]) break;
			}
		}
		if (!updateQueryButtons && [[runSelectionButton title] isEqualToString:NSLocalizedString(@"Run Previous", @"Title of button to run query just before text caret in custom query view")]) {
			updateQueryButtons = TRUE;
		}
		
		if (updateQueryButtons) {
			[runSelectionButton setTitle:NSLocalizedString(@"Run Current", @"Title of button to run current query in custom query view")];
			[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Current Query", @"Title of action menu item to run current query in custom query view")];

			// If a valid query is present at the cursor position, enable the button
			BOOL isLookBehind = YES;
			if ([self queryAtPosition:selectionPosition lookBehind:&isLookBehind]) {
				if (isLookBehind) {
					[runSelectionButton setTitle:NSLocalizedString(@"Run Previous", @"Title of button to run query just before text caret in custom query view")];
					[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Previous Query", @"Title of action menu item to run query just before text caret in custom query view")];
				}
				[runSelectionButton setEnabled:YES];
				[runSelectionMenuItem setEnabled:YES];
			} else {
				[runSelectionButton setEnabled:NO];
				[runSelectionMenuItem setEnabled:NO];
			}
		}

	// For selection ranges, enable the button.
	} else {
		[runSelectionButton setTitle:NSLocalizedString(@"Run Selection", @"Title of button to run selected text in custom query view")];
		[runSelectionButton setEnabled:YES];
		[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Selected Text", @"Title of action menu item to run selected text in custom query view")];
		[runSelectionMenuItem setEnabled:YES];
	}

}

#pragma mark -
#pragma mark TableView notifications


/*
 * Updates various interface elements based on the current table view selection.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{	
	if ([notification object] == queryFavoritesView) {
		
		// Enable/disable buttons
		[removeQueryFavoriteButton setEnabled:([queryFavoritesView numberOfSelectedRows] == 1)];
		[copyQueryFavoriteButton setEnabled:([queryFavoritesView numberOfSelectedRows] == 1)];
	}
}

/*
 * Save the custom query editor font if it is changed.
 */
- (void)textViewDidChangeTypingAttributes:(NSNotification *)aNotification
{

	// Only save the font if prefs have been loaded, ensuring the saved font has been applied once.
	if (prefs)
		[prefs setObject:[NSArchiver archivedDataWithRootObject:[textView font]] forKey:@"CustomQueryEditorFont"];
}


#pragma mark -
#pragma mark MySQL Help

/*
 * Set the MySQL version as X.Y for Help window title and online search
 */
- (void)setMySQLversion:(NSString *)theVersion
{
	mySQLversion = [[theVersion substringToIndex:3] retain];
}

/*
 * Return the Help window.
 */
- (NSWindow *)helpWebViewWindow
{
	return helpWebViewWindow;
}

/*
 * Show the data for "HELP 'searchString'".
 */
- (void)showHelpFor:(NSString *)searchString addToHistory:(BOOL)addToHistory
{
	
	NSString * helpString = [self getHTMLformattedMySQLHelpFor:searchString];

	// Order out resp. init the Help window if not visible
	if(![helpWebViewWindow isVisible])
	{
		// set title of the Help window
		[helpWebViewWindow setTitle:[NSString stringWithFormat:@"%@ (%@ %@)", NSLocalizedString(@"MySQL Help", @"mysql help"), NSLocalizedString(@"version", @"version"), mySQLversion]];
	
		// init goback/forward buttons
		if([[helpWebView backForwardList] backListCount] < 1)
		{
			[helpNavigator setEnabled:NO forSegment:SP_HELP_GOBACK_BUTTON];
			[helpNavigator setEnabled:NO forSegment:SP_HELP_GOFORWARD_BUTTON];
		} else {
			[helpNavigator setEnabled:[[helpWebView backForwardList] backListCount] forSegment:SP_HELP_GOBACK_BUTTON];
			[helpNavigator setEnabled:[[helpWebView backForwardList] forwardListCount] forSegment:SP_HELP_GOFORWARD_BUTTON];
		}

		// set default to search in MySQL help
		helpTarget = SP_HELP_SEARCH_IN_MYSQL;
		[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_MYSQL];
		[self helpTargetValidation];

		// order out Help window if Help is available
		if(![helpString isEqualToString:SP_HELP_NOT_AVAILABLE])
			[helpWebViewWindow orderFront:helpWebView];
			
	}

	// close Help window if no Help avaiable
	if([helpString isEqualToString:SP_HELP_NOT_AVAILABLE])
		[helpWebViewWindow close];
	
	if(![helpString length]) return;
	
	// add searchString to history list
	if(addToHistory)
	{
		WebHistoryItem *aWebHistoryItem = [[WebHistoryItem alloc] initWithURLString:[NSString stringWithFormat:@"applewebdata://%@", searchString] title:searchString lastVisitedTimeInterval:[[NSDate date] timeIntervalSinceDate:[NSDate distantFuture]]];
		[[helpWebView backForwardList] addItem:aWebHistoryItem];
	}

	// validate goback/forward buttons
	[helpNavigator setEnabled:[[helpWebView backForwardList] backListCount] forSegment:SP_HELP_GOBACK_BUTTON];
	[helpNavigator setEnabled:[[helpWebView backForwardList] forwardListCount] forSegment:SP_HELP_GOFORWARD_BUTTON];
	
	// load HTML formatted help into the webview
	[[helpWebView mainFrame] loadHTMLString:helpString baseURL:nil];
	
}


/*
 * Show the data for "HELP 'search word'" according to helpTarget
 */
- (IBAction)showHelpForSearchString:(id)sender
{
	NSString *searchString = [[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	switch(helpTarget)
	{
		case SP_HELP_SEARCH_IN_PAGE:
			if(![helpWebView searchFor:searchString direction:YES caseSensitive:NO wrap:YES])
				if([searchString length]) NSBeep();
			break;
		case SP_HELP_SEARCH_IN_WEB:
			if(![searchString length])
				break;
			[self openMySQLonlineDocumentationWithString:searchString];
			break;
		case SP_HELP_SEARCH_IN_MYSQL:
			[self showHelpFor:searchString addToHistory:YES];
			break;
	}
}

/*
 * Show the Help for the selected text in the webview
 */
- (IBAction)showHelpForWebViewSelection:(id)sender
{
	[self showHelpFor:[[helpWebView selectedDOMRange] text] addToHistory:YES];
}

/*
 * Show MySQL's online documentation for the selected text in the webview
 */
- (IBAction)searchInDocForWebViewSelection:(id)sender
{
	NSString *searchString = [[[helpWebView selectedDOMRange] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(![searchString length])
	{
		NSBeep();
		return;
	}
	[self openMySQLonlineDocumentationWithString:searchString];
}


/*
 * Show the data for "HELP 'currentWord'"
 */
- (IBAction)showHelpForCurrentWord:(id)sender
{
	NSString *searchString = [[textView string] substringWithRange:[textView getRangeForCurrentWord]];
	[self showHelpFor:searchString addToHistory:YES];
}

/*
 * Find Next/Previous in current page
 */
- (IBAction)helpSearchFindNextInPage:(id)sender
{
	if(helpTarget == SP_HELP_SEARCH_IN_PAGE)
		if(![helpWebView searchFor:[[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] direction:YES caseSensitive:NO wrap:YES])
			NSBeep();
}
- (IBAction)helpSearchFindPreviousInPage:(id)sender
{
	if(helpTarget == SP_HELP_SEARCH_IN_PAGE)
		if(![helpWebView searchFor:[[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] direction:NO caseSensitive:NO wrap:YES])
			NSBeep();
}

/*
 * Navigation for back/TOC/forward
 */
- (IBAction)helpSegmentDispatcher:(id)sender
{
	switch([helpNavigator selectedSegment])
	{
		case SP_HELP_GOBACK_BUTTON:
			[helpWebView goBack];
			break;
		case SP_HELP_SHOW_TOC_BUTTON:
			[self showHelpFor:SP_HELP_TOC_SEARCH_STRING addToHistory:YES];
			break;
		case SP_HELP_GOFORWARD_BUTTON:
			[helpWebView goForward];
			break;
	}
	// validate goback and goforward buttons according history
	[helpNavigator setEnabled:[[helpWebView backForwardList] backListCount] forSegment:SP_HELP_GOBACK_BUTTON];
	[helpNavigator setEnabled:[[helpWebView backForwardList] forwardListCount] forSegment:SP_HELP_GOFORWARD_BUTTON];
	
}

/*
 * Set helpTarget according user choice via mouse and keyboard short-cuts.
 */
- (IBAction)helpSelectHelpTargetMySQL:(id)sender
{
	helpTarget = SP_HELP_SEARCH_IN_MYSQL;
	[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_MYSQL];
	[self helpTargetValidation];
}
- (IBAction)helpSelectHelpTargetPage:(id)sender
{
	helpTarget = SP_HELP_SEARCH_IN_PAGE;
	[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_PAGE];
	[self helpTargetValidation];
}
- (IBAction)helpSelectHelpTargetWeb:(id)sender
{
	helpTarget = SP_HELP_SEARCH_IN_WEB;
	[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_WEB];
	[self helpTargetValidation];
}
- (IBAction)helpTargetDispatcher:(id)sender
{
	helpTarget = [helpTargetSelector selectedSegment];
	[self helpTargetValidation];
}

/*
 * Control the help search field behaviour.
 */
- (void)helpTargetValidation
{
	switch(helpTarget)
	{
		case SP_HELP_SEARCH_IN_PAGE:
		case SP_HELP_SEARCH_IN_WEB:
		[helpSearchFieldCell setSendsWholeSearchString:YES];
		break;
		case SP_HELP_SEARCH_IN_MYSQL:
		[helpSearchFieldCell setSendsWholeSearchString:NO];
		break;
	}
}

- (void)openMySQLonlineDocumentationWithString:(NSString *)searchString
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:
		[[NSString stringWithFormat:
			SP_MYSQL_DEV_SEARCH_URL,
			searchString,
			[mySQLversion stringByReplacingOccurrencesOfString:@"." withString:@""]]
		stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]]];
}

/*
 * Return the help string HTML formatted from executing "HELP 'searchString'".
 * If more than one help topic was found return a link list.
 */
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)searchString
{

	if(![searchString length]) return @"";
	
	NSRange         aRange;
	CMMCPResult     *theResult = nil;
	NSDictionary    *tableDetails;
	NSMutableString *theHelp = [NSMutableString string];

	[theHelp setString:@""];
	
	// search via: HELP 'searchString'
	theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP '%@'", [searchString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
	if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""])
	{
		// if an error or HELP is not supported fall back to online search
		NSLog(@"Error in HELP statement for '%@'", searchString);
		[self openMySQLonlineDocumentationWithString:searchString];
		return SP_HELP_NOT_AVAILABLE;
	}
	// nothing found?
	if(![theResult numOfRows]) {
		// try to search via: HELP 'searchString%'
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP '%@%%'", [searchString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
		// really nothing found?
		if(![theResult numOfRows])
			return @"";
	}
	tableDetails = [[NSDictionary alloc] initWithDictionary:[theResult fetchRowAsDictionary]];

	if ([tableDetails objectForKey:@"description"]) { // one single help topic found
		if ([tableDetails objectForKey:@"name"]) {
			[theHelp appendString:@"<h2 class='header'>"];
			[theHelp appendString:[[[tableDetails objectForKey:@"name"] copy] autorelease]];
			[theHelp appendString:@"</h2>"];

		}
		if ([tableDetails objectForKey:@"description"]) {
			NSMutableString *desc = [NSMutableString string];
			NSError *err1 = NULL;
			NSString *aUrl;
			
			[desc setString:[[[tableDetails objectForKey:@"description"] copy] autorelease]];

			//[desc replaceOccurrencesOfString:[searchString uppercaseString] withString:[NSString stringWithFormat:@"<span class='searchstring'>%@</span>", [searchString uppercaseString]] options:NSLiteralSearch range:NSMakeRange(0,[desc length])];

			// detect and generate http links
			aRange = NSMakeRange(0,0);
			int safeCnt = 0; // safety counter - not more than 200 loops allowed
			while(1){
				aRange = [desc rangeOfRegex:@"\\s((https?|ftp|file)://.*?html)" options:RKLNoOptions inRange:NSMakeRange(aRange.location+aRange.length, [desc length]-aRange.location-aRange.length) capture:1 error:&err1];
				if(aRange.location != NSNotFound) {
					aUrl = [desc substringWithRange:aRange];
					[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a href='%@'>%@</a>", aUrl, aUrl]];
				}
				else
					break;
				safeCnt++;
				if(safeCnt > 200)
					break;
			}
			// detect and generate mysql links for "[HELP keyword]"
			aRange = NSMakeRange(0,0);
			safeCnt = 0;
			while(1){
				// TODO how to catch in HELP 'grant' last see [HELP SHOW GRANTS] ?? it's ridiculous
				aRange = [desc rangeOfRegex:@"\\[HELP ([^ ]*?)\\]" options:RKLNoOptions inRange:NSMakeRange(aRange.location+aRange.length+53, [desc length]-53-aRange.location-aRange.length) capture:1 error:&err1];
				if(aRange.location != NSNotFound) {
					aUrl = [[desc substringWithRange:aRange] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
					[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a title='%@ “%@”' href='%@' class='internallink'>%@</a>", NSLocalizedString(@"Show MySQL help for", @"show mysql help for"), aUrl, aUrl, aUrl]];
				}
				else
					break;
				safeCnt++;
				if(safeCnt > 200)
					break;
			}
			// detect and generate mysql links for capitalzed letters
			// aRange = NSMakeRange(0,0);
			// safeCnt = 0;
			// while(1){
			// 	aRange = [desc rangeOfRegex:@"(?<!\\w)([A-Z_]{2,}( [A-Z_]{2,})?)" options:RKLNoOptions inRange:NSMakeRange(aRange.location+aRange.length, [desc length]-aRange.location-aRange.length) capture:1 error:&err1];
			// 	if(aRange.location != NSNotFound) {
			// 		aUrl = [desc substringWithRange:aRange];
			// 		[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a title='%@ “%@”' href='%@' class='internallink'>%@</a>", NSLocalizedString(@"Show MySQL help for", @"show mysql help for"), aUrl, aUrl, aUrl]];
			// 	}
			// 	else
			// 		break;
			// 	safeCnt++;
			// 	if(safeCnt > 200)
			// 		break;
			// }

			[theHelp appendString:@"<pre class='description'>"];
			[theHelp appendString:desc];
			[theHelp appendString:@"</pre>"];
		}
		// are examples available?
		if([tableDetails objectForKey:@"example"]){
			NSString *examples = [[[tableDetails objectForKey:@"example"] copy] autorelease];
			if([examples length]){
				[theHelp appendString:@"<br><i><b>Example:</b></i><br><pre class='example'>"];
				[theHelp appendString:examples];
				[theHelp appendString:@"</pre>"];
			}
		}
	} else { // list all found topics
		int i;
		int r = [theResult numOfRows];
		if (r) [theResult dataSeek:0];
		// check if HELP 'contents' is called
		if(![searchString isEqualToString:SP_HELP_TOC_SEARCH_STRING])
			[theHelp appendString:[NSString stringWithFormat:@"<br><i>%@ “%@”</i><br>", NSLocalizedString(@"Help topics for", @"help topics for"), searchString]];
		else
			[theHelp appendString:[NSString stringWithFormat:@"<br><b>%@:</b><br>", NSLocalizedString(@"MySQL Help – Categories", @"mysql help categories"), searchString]];

		// iterate through all found rows and print them as HTML ul/li list
		[theHelp appendString:@"<ul>"];
		for ( i = 0 ; i < r ; i++ ) {
			NSArray *anArray = [theResult fetchRowAsArray];
			NSString *topic = [anArray objectAtIndex:[anArray count]-2];
			[theHelp appendString:
				[NSString stringWithFormat:@"<li><a title='%@ “%@”' href='%@' class='internallink'>%@</a></li>", NSLocalizedString(@"Show MySQL help for", @"show mysql help for"), topic, topic, topic]];
		}
		[theHelp appendString:@"</ul>"];
	}

	[tableDetails release];
	
	return [NSString stringWithFormat:helpHTMLTemplate, theHelp];

}

//////////////////////////////
// WebView delegate methods //
//////////////////////////////

/*
 * Link detector: If user clicked at an http link open it in the default browser,
 * otherwise search for it in the MySQL help. Additionally handle back/forward events from
 * keyboard and context menu.
 */
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue];

	if([[[request URL] scheme] isEqualToString:@"applewebdata"] && navigationType == WebNavigationTypeLinkClicked){
		[self showHelpFor:[[[request URL] path] lastPathComponent] addToHistory:YES];
		[listener ignore];
	} else {
		if (navigationType == WebNavigationTypeOther) {
			// catch reload event
			// if([[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] isEqualToString:@"about:blank"])
			// 	[listener use];
			// else
			[listener use];
		} else if (navigationType == WebNavigationTypeLinkClicked) {
			// show http in browser
			[[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];
			[listener ignore];
		} else if (navigationType == WebNavigationTypeBackForward) {
			// catch back/forward events from contextual menu
			[self showHelpFor:[[[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding] addToHistory:NO];
			[listener ignore];
		} else if (navigationType == WebNavigationTypeReload) {
			// just in case
			[listener ignore];
		} else {
			// Ignore WebNavigationTypeFormSubmitted, WebNavigationTypeFormResubmitted.
			[listener ignore];
		}
	}
}


/*
 * Manage contextual menu in helpWebView
 * Ignore "Reload", "Open Link", "Open Link in new Window", "Download link" etc.
 */
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{

	NSMutableArray *webViewMenuItems = [[defaultMenuItems mutableCopy] autorelease];
	
	if (webViewMenuItems)
	{
		// Remove all needless default menu items 
		NSEnumerator *itemEnumerator = [defaultMenuItems objectEnumerator];
		NSMenuItem *menuItem = nil;
		while (menuItem = [itemEnumerator nextObject])
		{
			int tag = [menuItem tag];
			switch (tag)
			{
				case 2000: // WebMenuItemTagOpenLink
				case WebMenuItemTagOpenLinkInNewWindow:
				case WebMenuItemTagDownloadLinkToDisk:
				case WebMenuItemTagOpenImageInNewWindow:
				case WebMenuItemTagDownloadImageToDisk:
				case WebMenuItemTagCopyImageToClipboard:
				case WebMenuItemTagOpenFrameInNewWindow:
				case WebMenuItemTagStop:
				case WebMenuItemTagReload:
				case WebMenuItemTagCut:
				case WebMenuItemTagPaste:
				case WebMenuItemTagSpellingGuess:
				case WebMenuItemTagNoGuessesFound:
				case WebMenuItemTagIgnoreSpelling:
				case WebMenuItemTagLearnSpelling:
				case WebMenuItemTagOther:
				case WebMenuItemTagOpenWithDefaultApplication:
				[webViewMenuItems removeObjectIdenticalTo: menuItem];
				break;
			}
		}
	}

	// Add two menu items for a selection if no link is given
	if(webViewMenuItems 
		&& [[element objectForKey:@"WebElementIsSelected"] boolValue] 
		&& ![[element objectForKey:@"WebElementLinkIsLive"] boolValue])
	{

		NSMenuItem *searchInMySQL;
		NSMenuItem *searchInMySQLonline;

		[webViewMenuItems insertObject:[NSMenuItem separatorItem] atIndex:0];

		searchInMySQLonline = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search in MySQL Documentation", @"Search in MySQL Documentation") action:@selector(searchInDocForWebViewSelection:) keyEquivalent:@""];
		[searchInMySQLonline setEnabled:YES];
		[searchInMySQLonline setTarget:self];
		[webViewMenuItems insertObject:searchInMySQLonline atIndex:0];

		searchInMySQL = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search in MySQL Help", @"Search in MySQL Help") action:@selector(showHelpForWebViewSelection:) keyEquivalent:@""];
		[searchInMySQL setEnabled:YES];
		[searchInMySQL setTarget:self];
		[webViewMenuItems insertObject:searchInMySQL atIndex:0];

	}

	return webViewMenuItems;

}


#pragma mark -

// Last but not least
- (id)init;
{
	self = [super init];
	prefs = nil;
	usedQuery = [[NSString stringWithString:@""] retain];

	// init helpHTMLTemplate
	NSError *error;
	helpHTMLTemplate = [[NSString alloc]
			initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sequel-pro-mysql-help-template" ofType:@"html"]
			encoding:NSUTF8StringEncoding
			error:&error];
	// an error occurred while reading
	if (helpHTMLTemplate == nil)
	{
		NSLog(@"%@", [NSString stringWithFormat:@"Error reading “sequel-pro-mysql-help-template.html”!<br>%@", [error localizedFailureReason]]);
		NSBeep();
	}

	// init search history
	[helpWebView setMaintainsBackForwardList:YES];
	[[helpWebView backForwardList] setCapacity:20];

	return self;
}

- (void)dealloc
{
	[queryResult release];
	[prefs release];
	[queryFavorites release];
	[usedQuery release];
	[super dealloc];

}
	
@end
