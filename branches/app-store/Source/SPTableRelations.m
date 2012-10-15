//
//  $Id$
//
//  SPTableRelations.h
//  sequel-pro
//
//  Created by J Knight on 13/05/09.
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

#import "SPTableRelations.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPTableView.h"
#import "SPAlertSheets.h"
#import "RegexKitLite.h"
#import <SPMySQL/SPMySQL.h>

static NSString *SPRemoveRelation = @"SPRemoveRelation";

static NSString *SPRelationNameKey      = @"name";
static NSString *SPRelationColumnsKey   = @"columns";
static NSString *SPRelationFKTableKey   = @"fk_table";
static NSString *SPRelationFKColumnsKey = @"fk_columns";
static NSString *SPRelationOnUpdateKey  = @"on_update";
static NSString *SPRelationOnDeleteKey  = @"on_delete";

@interface SPTableRelations ()

- (void)_refreshRelationDataForcingCacheRefresh:(BOOL)clearAllCaches;
- (void)_updateAvailableTableColumns;
- (void)_reopenRelationSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

@implementation SPTableRelations

@synthesize connection;
@synthesize relationData;

/**
 * init
 */
- (id)init
{
	if ((self = [super init])) {
		relationData         = [[NSMutableArray alloc] init];
		prefs                = [NSUserDefaults standardUserDefaults];
		takenConstraintNames = [[NSMutableArray alloc] init];
	}

	return self;
}

/**
 * Register to listen for table selection changes upon nib awakening.
 */
- (void)awakeFromNib
{
	// Set the table relation view's vertical gridlines if required
	[relationsTableView setGridStyleMask:([[NSUserDefaults standardUserDefaults] boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	
	// Set the double-click action in blank areas of the table to create new rows
	[relationsTableView setEmptyDoubleClickAction:@selector(addRelation:)];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [[NSUserDefaults standardUserDefaults] boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *column in [relationsTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
	// Register as an observer for the when the UseMonospacedFonts preference changes
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableSelectionChanged:) 
												 name:SPTableChangedNotification 
											   object:tableDocumentInstance];

	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Opens the relation sheet, in its current state (without any reset of fields)
 */
- (IBAction)openRelationSheet:(id)sender
{
	[NSApp beginSheet:addRelationPanel
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
}

/**
 * Closes the relation sheet.
 */
- (IBAction)closeRelationSheet:(id)sender
{
	[NSApp endSheet:addRelationPanel returnCode:0];
	[addRelationPanel orderOut:self];
}

/**
 * Add a new relation using the selected values.
 */
- (IBAction)confirmAddRelation:(id)sender
{
	[dataProgressIndicator startAnimation:self];
	[dataProgressIndicator setHidden:NO];
	
	NSString *thisTable  = [tablesListInstance tableName];
	NSString *thisColumn = [columnPopUpButton titleOfSelectedItem];
	NSString *thatTable  = [refTablePopUpButton titleOfSelectedItem];
	NSString *thatColumn = [refColumnPopUpButton titleOfSelectedItem];
	
	NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD ",[thisTable backtickQuotedString]];
	
	// Set constraint name?
	if ([[constraintName stringValue] length] > 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@"CONSTRAINT %@ ", [[constraintName stringValue] backtickQuotedString]]];
	}
	
	query = [query stringByAppendingString:[NSString stringWithFormat:@"FOREIGN KEY (%@) REFERENCES %@ (%@)",
												[thisColumn backtickQuotedString],
												[thatTable backtickQuotedString],
												[thatColumn backtickQuotedString]]];
	
	NSArray *onActions = [NSArray arrayWithObjects:@"RESTRICT", @"CASCADE", @"SET NULL", @"NO ACTION", nil];
	
	// If required add ON DELETE
	if ([onDeletePopUpButton selectedTag] >= 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON DELETE %@", [onActions objectAtIndex:[onDeletePopUpButton selectedTag]]]];
	}
	
	// If required add ON UPDATE
	if ([onUpdatePopUpButton selectedTag] >= 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON UPDATE %@", [onActions objectAtIndex:[onUpdatePopUpButton selectedTag]]]];
	}
	
	// Execute query
	[connection queryString:query];

	[dataProgressIndicator setHidden:YES];
	[dataProgressIndicator stopAnimation:self];

	[self closeRelationSheet:self];

	if ([connection queryErrored]) {

		// Retrieve the last connection error message.
		NSString *errorText = [connection lastErrorMessage];

		// An error ID of 1005 indicates a foreign key error.  These are thrown for many reasons, but the two
		// most common are 121 (name probably in use) and 150 (types don't exactly match).
		// Retrieve the InnoDB status and extract the most recent error for more helpful text.
		if ([connection lastErrorID] == 1005) {
			NSString *statusText = [connection getFirstFieldFromQuery:@"SHOW INNODB STATUS"];
			NSString *detailErrorString = [statusText stringByMatching:@"latest foreign key error\\s+-----*\\s+[0-9: ]*(.*?)\\s+-----" options:(RKLCaseless | RKLDotAll) inRange:NSMakeRange(0, [statusText length]) capture:1L error:NULL];
			if (detailErrorString) {
				errorText = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nDetail: %@", @"Add relation error detail intro"), errorText, [detailErrorString stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
			}

			// Detect name duplication if appropriate
			if ([errorText isMatchedByRegex:@"errno: 121"] && [errorText isMatchedByRegex:@"already exists"]) {
				[takenConstraintNames addObject:[[constraintName stringValue] lowercaseString]];
				[self controlTextDidChange:[NSNotification notificationWithName:@"dummy" object:constraintName]];
			}
		}

		SPBeginAlertSheet(NSLocalizedString(@"Error creating relation", @"error creating relation message"), 
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], self, @selector(_reopenRelationSheet:returnCode:contextInfo:), nil,
						  [NSString stringWithFormat:NSLocalizedString(@"The specified relation was unable to be created.\n\nMySQL said: %@", @"error creating relation informative message"), errorText]);
	} 
	else {
		[self _refreshRelationDataForcingCacheRefresh:YES];
	}
}

/**
 * Updates the available columns when the user selects a table.
 */
- (IBAction)selectTableColumn:(id)sender
{
	[self _updateAvailableTableColumns];
}

/**
 * Updates the available columns when the user selects a table.
 */
- (IBAction)selectReferenceTable:(id)sender
{
	[self _updateAvailableTableColumns];
}

/**
 * Called whenever the user selected to add a new relation. 
 */
- (IBAction)addRelation:(id)sender
{
	// Check whether table editing is permitted (necessary as some actions - eg table double-click - bypass validation)
	if ([tableDocumentInstance isWorking] || [tablesListInstance tableType] != SPTableTypeTable) return;

	// Set up the controls
	[addRelationTableBox setTitle:[NSString stringWithFormat:NSLocalizedString(@"Table: %@", @"Add Relation sheet title, showing table name"), [tablesListInstance tableName]]];

	[columnPopUpButton removeAllItems];
	NSArray *columnTitles = ([prefs boolForKey:SPAlphabeticalTableSorting])? [[tableDataInstance columnNames] sortedArrayUsingSelector:@selector(compare:)] : [tableDataInstance columnNames];
	[columnPopUpButton addItemsWithTitles:columnTitles];

	[refTablePopUpButton removeAllItems];

	BOOL changeEncoding = ![[connection encoding] isEqualToString:@"utf8"];

	// Use UTF8 for identifier-based queries
	if (changeEncoding) {
		[connection storeEncodingForRestoration];
		[connection setEncoding:@"utf8"];
	}

	// Get all InnoDB tables in the current database
	// TODO: MySQL 4 compatibility
	SPMySQLResult *result = [connection queryString:[NSString stringWithFormat:@"SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND engine = 'InnoDB' AND table_schema = %@", [[tableDocumentInstance database] tickQuotedString]]];
	[result setDefaultRowReturnType:SPMySQLResultRowAsArray];
	for (NSArray *eachRow in result) {
		[refTablePopUpButton addItemWithTitle:[eachRow objectAtIndex:0]];
	}

	// Reset other fields
	[constraintName setStringValue:@""];
	[onDeletePopUpButton selectItemAtIndex:0];
	[onUpdatePopUpButton selectItemAtIndex:0];

	// Restore encoding if appropriate
	if (changeEncoding) [connection restoreStoredEncoding];

	[self selectReferenceTable:nil];
	[self openRelationSheet:self];
}

/**
 * Removes the selected relations.
 */
- (IBAction)removeRelation:(id)sender
{
	if ([relationsTableView numberOfSelectedRows] > 0) {

		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Delete relation", @"delete relation message") 
										 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected relations? This action cannot be undone.", @"delete selected relation informative message")];

		[alert setAlertStyle:NSCriticalAlertStyle];

		NSArray *buttons = [alert buttons];

		// Change the alert's cancel button to have the key equivalent of return
		[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
		[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
		[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

		[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:SPRemoveRelation];
	}
}

/**
 * Trigger a refresh of the displayed relations via the interface.
 */
- (IBAction)refreshRelations:(id)sender
{
	[self _refreshRelationDataForcingCacheRefresh:YES];
}

/**
 * Called whenever the user selects a different table.
 */
- (void)tableSelectionChanged:(NSNotification *)notification
{
	BOOL enableInteraction = ![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableRelations] || ![tableDocumentInstance isWorking];

	// To begin enable all interface elements
	[addRelationButton setEnabled:enableInteraction];
	[refreshRelationsButton setEnabled:enableInteraction];
	[relationsTableView setEnabled:YES];
	
	// Get the current table's storage engine
	NSString *engine = [tableDataInstance statusValueForKey:@"Engine"];

	if (([tablesListInstance tableType] == SPTableTypeTable) && ([[engine lowercaseString] isEqualToString:@"innodb"])) {

		// Update the text label
		[labelTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Relations for table: %@", @"Relations tab subtitle showing table name"), [tablesListInstance tableName]]];

		[addRelationButton setEnabled:enableInteraction];
		[refreshRelationsButton setEnabled:enableInteraction];
		[relationsTableView setEnabled:YES];
	} 
	else {
		[addRelationButton setEnabled:NO];
		[refreshRelationsButton setEnabled:NO];
		[relationsTableView setEnabled:NO];

		[labelTextField setStringValue:([tablesListInstance tableType] == SPTableTypeTable) ? NSLocalizedString(@"This table currently does not support relations. Only tables that use the InnoDB storage engine support them.", @"This table currently does not support relations. Only tables that use the InnoDB storage engine support them.") : @""];
	}

	[self _refreshRelationDataForcingCacheRefresh:NO];
}

#pragma mark -
#pragma mark TextField delegate methods

- (void)controlTextDidChange:(NSNotification *)notification
{	
	// Make sure the user does not enter a taken name, using the quickly-generated incomplete list
	if ([notification object] == constraintName) {		
		NSString *userValue = [[constraintName stringValue] lowercaseString];
		
		// Make field red and disable add button
		if ([takenConstraintNames containsObject:userValue]) {
			[constraintName setTextColor:[NSColor redColor]];
			[confirmAddRelationButton setEnabled:NO];
		}
		else {
			[constraintName setTextColor:[NSColor controlTextColor]];
			[confirmAddRelationButton setEnabled:YES];
		}
	}
}

#pragma mark -
#pragma mark Tableview datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [relationData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return [[relationData objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Called whenever the relations table view selection changes.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[removeRelationButton setEnabled:([relationsTableView numberOfSelectedRows] > 0)];
}

/*
 * Double-click action on table cells - for the time being, return
 * NO to disable editing.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return ![tableDocumentInstance isWorking];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)aNotification
{

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableRelations]) return;

	[addRelationButton setEnabled:NO];
	[refreshRelationsButton setEnabled:NO];
	[removeRelationButton setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)aNotification
{

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableRelations]) return;

	if ([relationsTableView isEnabled]) {
		[addRelationButton setEnabled:YES];
		[refreshRelationsButton setEnabled:YES];
	}
	
	[removeRelationButton setEnabled:([relationsTableView numberOfSelectedRows] > 0)];
}

#pragma mark -
#pragma mark Other

/**
 * Returns an array of relation data to be used for printing purposes. The first element in the array is always
 * an array of the columns and each subsequent element is an array of relation data.
 */
- (NSArray *)relationDataForPrinting
{
	NSMutableArray *headings = [[NSMutableArray alloc] init];
	NSMutableArray *data     = [NSMutableArray array];
	
	// Get the relations table view's columns
	for (NSTableColumn *column in [relationsTableView tableColumns])
	{
		[headings addObject:[[column headerCell] stringValue]];
	}
	
	[data addObject:headings];
	
	[headings release];

	// Get the relation data
	for (NSDictionary *eachRelation in relationData)
	{
		NSMutableArray *temp = [[NSMutableArray alloc] init];

		[temp addObject:[eachRelation objectForKey:SPRelationNameKey]];
		[temp addObject:[eachRelation objectForKey:SPRelationColumnsKey]];
		[temp addObject:[eachRelation objectForKey:SPRelationFKTableKey]];
		[temp addObject:[eachRelation objectForKey:SPRelationFKColumnsKey]];
		[temp addObject:([eachRelation objectForKey:SPRelationOnUpdateKey]) ? [eachRelation objectForKey:SPRelationOnUpdateKey] : @""];
		[temp addObject:([eachRelation objectForKey:SPRelationOnDeleteKey]) ? [eachRelation objectForKey:SPRelationOnDeleteKey] : @""];

		[data addObject:temp];

		[temp release];
	}
	
	return data; 
}

/**
 * NSAlert didEnd method.
 */
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:SPRemoveRelation]) {

		if (returnCode == NSAlertDefaultReturn) {

			NSString *thisTable = [tablesListInstance tableName];
			NSIndexSet *selectedSet = [relationsTableView selectedRowIndexes];

			NSUInteger row = [selectedSet lastIndex];

			while (row != NSNotFound) 
			{
				NSString *relationName = [[relationData objectAtIndex:row] objectForKey:SPRelationNameKey];
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [thisTable backtickQuotedString], [relationName backtickQuotedString]];

				[connection queryString:query];

				if ([connection queryErrored]) {

					SPBeginAlertSheet(NSLocalizedString(@"Unable to delete relation", @"error deleting relation message"), 
									  NSLocalizedString(@"OK", @"OK button"),
									  nil, nil, [NSApp mainWindow], nil, nil, nil, 
									  [NSString stringWithFormat:NSLocalizedString(@"The selected relation couldn't be deleted.\n\nMySQL said: %@", @"error deleting relation informative message"), [connection lastErrorMessage]]);

					// Abort loop
					break;
				} 

				row = [selectedSet indexLessThanIndex:row];
			}

			[self _refreshRelationDataForcingCacheRefresh:YES];
		}
	} 
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [relationsTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {

		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

		for (NSTableColumn *column in [relationsTableView tableColumns])
		{
			[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}

		[relationsTableView reloadData];
	}
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove row
	if ([menuItem action] == @selector(removeRelation:)) {
		[menuItem setTitle:([relationsTableView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Delete Relations", @"delete relations menu item") : NSLocalizedString(@"Delete Relation", @"delete relation menu item")];

		return ([relationsTableView numberOfSelectedRows] > 0);
	}
	
	return YES;
}

#pragma mark -
#pragma mark Private API

/**
 * Refresh the displayed relations, optionally forcing a refresh of the underlying cache.
 */
- (void)_refreshRelationDataForcingCacheRefresh:(BOOL)clearAllCaches
{
	[relationData removeAllObjects];

	// Prepare the list of the used constraint names for this table.  Ideally this would include all the used names
	// in the database, but the MySQL-provided method of requesting that information (table_constraints in
	// information_schema) is generated live from db file scans, which cannot be cheaply done on servers with
	// many databases.
	[takenConstraintNames removeAllObjects];
	
	if ([tablesListInstance tableType] == SPTableTypeTable) {
		
		if (clearAllCaches) [tableDataInstance updateInformationForCurrentTable];
		
		NSArray *constraints = [tableDataInstance getConstraints];
		
		for (NSDictionary *constraint in constraints) 
		{
			[relationData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									 [constraint objectForKey:SPRelationNameKey], SPRelationNameKey,
									 [[constraint objectForKey:SPRelationColumnsKey] objectAtIndex:0], SPRelationColumnsKey,
									 [constraint objectForKey:@"ref_table"], SPRelationFKTableKey,
									 [constraint objectForKey:@"ref_columns"], SPRelationFKColumnsKey,
									 ([constraint objectForKey:@"update"] ? [constraint objectForKey:@"update"] : @""), SPRelationOnUpdateKey,
									 ([constraint objectForKey:@"delete"] ? [constraint objectForKey:@"delete"] : @""), SPRelationOnDeleteKey,
									 nil]];
			[takenConstraintNames addObject:[[constraint objectForKey:SPRelationNameKey] lowercaseString]];			
		}
	} 
	
	[relationsTableView reloadData];
}

/**
 * Updates the available table columns that the reference is pointing to. Available columns are those that are
 * within the selected table and are of the same data type as the column the reference is from.
 */
- (void)_updateAvailableTableColumns
{
	NSString *column = [columnPopUpButton titleOfSelectedItem];
	NSString *table = [refTablePopUpButton titleOfSelectedItem];
	
	[tableDataInstance resetAllData];
	[tableDataInstance updateInformationForCurrentTable];
	
	NSDictionary *columnInfo = [[tableDataInstance columnWithName:column] copy];
	
	[refColumnPopUpButton setEnabled:NO];
	[confirmAddRelationButton setEnabled:NO];
	
	[refColumnPopUpButton removeAllItems];
	
	[tableDataInstance resetAllData];
	NSDictionary *tableInfo = [tableDataInstance informationForTable:table];
	
	NSArray *columns = [tableInfo objectForKey:SPRelationColumnsKey];
	
	NSMutableArray *validColumns = [NSMutableArray array];
	
	// Only add columns of the same data type
	for (NSDictionary *aColumn in columns) 
	{
		if ([[columnInfo objectForKey:@"type"] isEqualToString:[aColumn objectForKey:@"type"]]) {
			[validColumns addObject:[aColumn objectForKey:SPRelationNameKey]];
		}
	}
	
	// Add the valid columns
	if ([validColumns count] > 0) {
		NSArray *columnTitles = ([prefs boolForKey:SPAlphabeticalTableSorting])? [validColumns sortedArrayUsingSelector:@selector(compare:)] : validColumns;
		
		[refColumnPopUpButton addItemsWithTitles:columnTitles];
		
		[refColumnPopUpButton setEnabled:YES];
		[confirmAddRelationButton setEnabled:YES];
	}
	
	[columnInfo release];
}

/**
 * Reopen the add relation sheet, usually after an error message, with the previous content.
 */
- (void)_reopenRelationSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self performSelector:@selector(openRelationSheet:) withObject:self afterDelay:0.0];
}

#pragma mark -

/*
 * Dealloc.
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:SPUseMonospacedFonts];

	[relationData release], relationData = nil;
	[takenConstraintNames release], takenConstraintNames = nil;

	[super dealloc];
}

@end