//
//  $Id$
//
//  SPConnectionControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 29, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPConnectionControllerDelegate.h"
#ifndef SP_REFACTOR
#import "SPFavoritesController.h"
#import "SPTableTextFieldCell.h"
#import "SPPreferenceController.h"
#import "SPGeneralPreferencePane.h"
#import "SPAppController.h"
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"
#import "SPTreeNode.h"
#endif

static NSString *SPDatabaseImage = @"database-small";
static NSString *SPQuickConnectImage = @"quick-connect-icon.pdf";
static NSString *SPQuickConnectImageWhite = @"quick-connect-icon-white.pdf";

@interface SPConnectionController ()

// Privately redeclare as read/write to get the synthesized setter
@property (readwrite, assign) BOOL isEditingConnection;

- (void)_checkHost;
- (void)_sortFavorites;
- (void)_favoriteTypeDidChange;
- (void)_reloadFavoritesViewData;

- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject;

- (void)_startEditingConnection;
- (void)_stopEditingConnection;
- (void)_setNodeIsExpanded:(BOOL)expanded fromNotification:(NSNotification *)notification;

- (NSString *)_generateNameForConnection;

@end

@implementation SPConnectionController (SPConnectionControllerDelegate)

#pragma mark -
#pragma mark SplitView delegate methods

#ifndef SP_REFACTOR

/**
 * When the split view is resized, trigger a resize in the hidden table
 * width as well, to keep the connection view and connected view in sync.
 */
- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	if (initComplete) {
		[databaseConnectionView setPosition:[[[connectionSplitView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
	}
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	return 135.f;
}

#endif

#pragma mark -
#pragma mark Outline view delegate methods

#ifndef SP_REFACTOR

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{		
	return ([[(SPTreeNode *)item parentNode] parentNode] == nil);
}

- (void)outlineViewSelectionIsChanging:(NSNotification *)notification
{
	if (isEditingConnection) {
		[self _stopEditingConnection];
		[[notification object] setNeedsDisplay:YES];
	}
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger selected = [favoritesOutlineView numberOfSelectedRows];

	if (isEditingConnection) {
		[self _stopEditingConnection];
		[[notification object] setNeedsDisplay:YES];
	}

	if (selected == 1) {		
		[self updateFavoriteSelection:self];

		favoriteNameFieldWasAutogenerated = NO;
		[connectionResizeContainer setHidden:NO];
		[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Enter connection details below, or choose a favorite", @"enter connection details label")];
	}
	else if (selected > 1) {
		[connectionResizeContainer setHidden:YES];
		[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Please choose a favorite", @"please choose a favorite connection view label")];		
	}
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (item == quickConnectItem) {
		return (NSCell *)quickConnectCell;
	}

	return [tableColumn dataCellForRow:[outlineView rowForItem:item]];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	SPTreeNode *node = (SPTreeNode *)item;

	// Draw entries with the small system font by default
	[(SPTableTextFieldCell *)cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	// Set an image as appropriate; the quick connect image for that entry, no image for other
	// top-level items, the folder image for group nodes, or the database image for other nodes.
	if (![[node parentNode] parentNode]) {
		if (node == quickConnectItem) {
			if ([outlineView rowForItem:item] == [outlineView selectedRow]) {
				[(SPTableTextFieldCell *)cell setImage:[NSImage imageNamed:SPQuickConnectImageWhite]];
			} else {
				[(SPTableTextFieldCell *)cell setImage:[NSImage imageNamed:SPQuickConnectImage]];
			}
		} else {
			[(SPTableTextFieldCell *)cell setImage:nil];
		}
	} else {
		if ([node isGroup]) {
			[(SPTableTextFieldCell *)cell setImage:folderImage];
		} else {
			[(SPTableTextFieldCell *)cell setImage:[NSImage imageNamed:SPDatabaseImage]];
		}
	}

	// If a favourite item is being edited, draw the text in bold to show state
	if (isEditingConnection && ![node isGroup] && [outlineView rowForItem:item] == [outlineView selectedRow]) {
		NSMutableAttributedString *editedCellString = [[cell attributedStringValue] mutableCopy];
		[editedCellString addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithDeviceWhite:0.25f alpha:1.f] range:NSMakeRange(0, [editedCellString length])];
		[cell setAttributedStringValue:editedCellString];
		[editedCellString release];
	}
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if (item == quickConnectItem) {
		return 24.f;
	}

	return ([[item parentNode] parentNode]) ? 17.f : 22.f;
}

- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation
{
	NSString *toolTip = nil;
	
	SPTreeNode *node = (SPTreeNode *)item;
	
	if (![node isGroup]) {
		
		NSString *favoriteName = [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey];
		NSString *favoriteHostname = [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteHostKey];
		
		toolTip = ([favoriteHostname length]) ? [NSString stringWithFormat:@"%@ (%@)", favoriteName, favoriteHostname] : favoriteName;	
	}

	// Only display a tooltip for group nodes that are a descendant of the root node
	else if ([[node parentNode] parentNode]) {
		NSUInteger favCount = 0;
		NSUInteger groupCount = 0;
		for (SPTreeNode *eachNode in [node childNodes]) {
			if ([eachNode isGroup]) {
				groupCount++;
			} else {
				favCount++;
			}
		}

		NSMutableArray *tooltipParts = [NSMutableArray arrayWithCapacity:2];
		if (favCount || !groupCount) {
			[tooltipParts addObject:[NSString stringWithFormat:((favCount == 1) ? NSLocalizedString(@"%d favorite", @"favorite singular label (%d == 1)") : NSLocalizedString(@"%d favorites", @"favorites plural label (%d != 1)")), favCount]];
		}
		if (groupCount) {
			[tooltipParts addObject:[NSString stringWithFormat:((groupCount == 1) ? NSLocalizedString(@"%d group", @"favorite group singular label (%d == 1)") : NSLocalizedString(@"%d groups", @"favorite groups plural label (%d != 1)")), groupCount]];
		}

		toolTip = [NSString stringWithFormat:@"%@ - %@", [[node representedObject] nodeName], [tooltipParts componentsJoinedByString:@", "]];
	}
	
	return toolTip;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{

	// If this is a top level item, only allow the "Quick Connect" item to be selectable
	if (![[item parentNode] parentNode]) {
		if (item == quickConnectItem) {
			return YES;
		}
		return NO;
	}

	// Otherwise allow all items to be selectable
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return (item != quickConnectItem && ![item isLeaf]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
	return ([[item parentNode] parentNode] != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	return ([[item parentNode] parentNode] != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return (item != quickConnectItem);
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{	
	[self _setNodeIsExpanded:NO fromNotification:notification];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	[self _setNodeIsExpanded:YES fromNotification:notification];
}

#endif

#pragma mark -
#pragma mark Outline view drag & drop

#ifndef SP_REFACTOR

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{

	// Prevent a drag which includes the outline title group from taking place
	for (id item in items) {
		if (![[item parentNode] parentNode]) return NO;
	}

	// If the user is in the process of changing a node's name, trigger a save and prevent dragging.
	if (isEditingItemName) {
		[favoritesController saveFavorites];
		
		[self _reloadFavoritesViewData];
		
		isEditingItemName = NO;
		
		return NO;
	}
		
	[pboard declareTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType] owner:self];

	BOOL result = [pboard setData:[NSData data] forType:SPFavoritesPasteboardDragType];
	
	draggedNodes = items;
	
	return result;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)childIndex
{
	NSDragOperation result = NSDragOperationNone;

	// Prevent the top level or the quick connect item from being a target
	if (!item || item == quickConnectItem) return result;

	// Prevent dropping favorites on other favorites (non-groups)
	if ((childIndex == NSOutlineViewDropOnItemIndex) && (![item isGroup])) return result;

	// Ensure that none of the dragged nodes are being dragged into children of themselves; if they are,
	// prevent the drag.
	id itemToCheck = item;
	
	do {
		if ([draggedNodes containsObject:itemToCheck]) {
			return result;
		}
	} 
	while ((itemToCheck = [itemToCheck parentNode]));

	if ([info draggingSource] == outlineView) {
		[outlineView setDropItem:item dropChildIndex:childIndex];
		
		result = NSDragOperationMove;
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)childIndex
{
	BOOL acceptedDrop = NO;
	
	if ((!item) || ([info draggingSource] != outlineView)) return acceptedDrop;
	
	SPTreeNode *node = item ? item : [[[[favoritesRoot childNodes] objectAtIndex:0] childNodes] objectAtIndex:0];

	// Cache the selected nodes for selection restoration afterwards
	NSArray *preDragSelection = [self selectedFavoriteNodes];

	// Disable all automatic sorting
	currentSortItem = -1;
	reverseFavoritesSort = NO;
	
	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	[prefs setBool:NO forKey:SPFavoritesSortedInReverse];
	
	// Uncheck sort by menu items
	for (NSMenuItem *menuItem in [[favoritesSortByMenuItem submenu] itemArray])
	{
		[menuItem setState:NSOffState];
	}
	
	if (![draggedNodes count]) return acceptedDrop;
	
	if ([node isGroup]) {		
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			childIndex = 0;
		}
		[outlineView expandItem:node];
	}
	else {
		if (childIndex == NSOutlineViewDropOnItemIndex) {
			childIndex = 0;
		}
	}
	
	if (![[node representedObject] nodeName]) {
		node = [[favoritesRoot childNodes] objectAtIndex:0];
	}
			
	NSMutableArray *childNodeArray = [node mutableChildNodes];
	
    for (SPTreeNode *treeNode in draggedNodes) 
	{
        // Remove the node from its old location
        NSInteger oldIndex = [childNodeArray indexOfObject:treeNode];
        NSInteger newIndex = childIndex;
        
		if (oldIndex != NSNotFound) {
			
            [childNodeArray removeObjectAtIndex:oldIndex];
            
			if (childIndex > oldIndex) {
                newIndex--;
            }
        } 
		else {
            [[[treeNode parentNode] mutableChildNodes] removeObject:treeNode];
        }
				        
		[childNodeArray insertObject:treeNode atIndex:newIndex];
        
		newIndex++;
    }
		
	[favoritesController saveFavorites];
	
	[self _reloadFavoritesViewData];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPConnectionFavoritesChangedNotification object:self];

	[[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	// Update the selection to account for rearranged faourites
	NSMutableIndexSet *restoredSelection = [NSMutableIndexSet indexSet];
	for (SPTreeNode *eachNode in preDragSelection) {
		[restoredSelection addIndex:[favoritesOutlineView rowForItem:eachNode]];
	}
	[favoritesOutlineView selectRowIndexes:restoredSelection byExtendingSelection:NO];

	acceptedDrop = YES;
	
	return acceptedDrop;
}

#endif

#pragma mark -
#pragma mark Textfield delegate methods

#ifndef SP_REFACTOR

/**
 * React to control text changes in the connection interface
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id field = [notification object];

	// Ignore changes in the outline view edit fields
	if ([field isKindOfClass:[NSOutlineView class]]) {
		return;
	}

	// If a 'name' field was edited, and is now of zero length, trigger a replacement
	// with a standard suggestion
	if (((field == standardNameField) || (field == socketNameField) || (field == sshNameField)) && [self selectedFavoriteNode]) {
		if (![[self _stripInvalidCharactersFromString:[field stringValue]] length]) {
			[self controlTextDidEndEditing:notification];
		}
	}

	[self _startEditingConnection];

	if (favoriteNameFieldWasAutogenerated && (field != standardNameField && field != socketNameField && field != sshNameField)) {
		[self setName:[self _generateNameForConnection]];
	}
}

/**
 * React to the end of control text changes in the connection interface.
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id field = [notification object];

	// Handle updates to the 'name' field of the selected favourite.  The favourite name should
	// have leading or trailing spaces removed at the end of editing, and if it's left empty,
	// should have a default name set.
	if (((field == standardNameField) || (field == socketNameField) || (field == sshNameField)) && [self selectedFavoriteNode]) {

		NSString *favoriteName = [self _stripInvalidCharactersFromString:[field stringValue]];

		if (![favoriteName length]) {
			favoriteName = [self _generateNameForConnection];
			if (favoriteName) {
				[self setName:favoriteName];
			}
			
			// Enable user@host update in reaction to other UI changes
			favoriteNameFieldWasAutogenerated = YES;
		} else if (![[field stringValue] isEqualToString:[self _generateNameForConnection]]) {
			favoriteNameFieldWasAutogenerated = NO;
			[self setName:favoriteName];
		}
	}

	// When a host field finishes editing, ensure that it hasn't been set to "localhost" to
	// ensure that socket connections don't inadvertently occur.
	if (field == standardSQLHostField || field == sshSQLHostField) {
		[self _checkHost];
	}
}

#endif

#pragma mark -
#pragma mark Tab bar delegate methods

#ifndef SP_REFACTOR

/**
 * Trigger a resize action whenever the tab view changes. The connection
 * detail forms are held within container views, which are of a fixed width;
 * the tabview and buttons are contained within a resizable view which
 * is set to dimensions based on the container views, allowing the view
 * to be sized according to the detail type.
 */
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSInteger selectedTabView = [tabView indexOfTabViewItem:tabViewItem];
		
	if (selectedTabView == previousType) return;

	[self resizeTabViewToConnectionType:selectedTabView animating:YES];
	
	// Update the host as appropriate
	if ((selectedTabView != SPSocketConnection) && [[self host] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}

	previousType = selectedTabView;

	[self _startEditingConnection];

	[self _favoriteTypeDidChange];
}

#endif

#pragma mark -
#pragma mark Scroll view notifications

#ifndef SP_REFACTOR

/**
 * As the scrollview resizes, keep the details centered within it if
 * the detail frame is larger than the scrollview size; otherwise, pin
 * the detail frame to the top of the scrollview.
 */
- (void)scrollViewFrameChanged:(NSNotification *)aNotification
{
	NSRect scrollViewFrame = [connectionDetailsScrollView frame];
	NSRect scrollDocumentFrame = [[connectionDetailsScrollView documentView] frame];
	NSRect connectionDetailsFrame = [connectionResizeContainer frame];
	
	// Scroll view is smaller than contents - keep positioned at top.
	if (scrollViewFrame.size.height < connectionDetailsFrame.size.height + 10) {
		if (connectionDetailsFrame.origin.y != 0) {
			connectionDetailsFrame.origin.y = 0;
			[connectionResizeContainer setFrame:connectionDetailsFrame];
			scrollDocumentFrame.size.height = connectionDetailsFrame.size.height + 10;
			[[connectionDetailsScrollView documentView] setFrame:scrollDocumentFrame];
		}
	}
	// Otherwise, center
	else {
		connectionDetailsFrame.origin.y = (scrollViewFrame.size.height - connectionDetailsFrame.size.height)/3;
		[connectionResizeContainer setFrame:connectionDetailsFrame];
		scrollDocumentFrame.size.height = scrollViewFrame.size.height;
		[[connectionDetailsScrollView documentView] setFrame:scrollDocumentFrame];
	}
}

#endif

#pragma mark -
#pragma mark Menu Validation

#ifndef SP_REFACTOR

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	SPTreeNode *node = [self selectedFavoriteNode];
	NSInteger selectedRows = [favoritesOutlineView numberOfSelectedRows];

	if (node == quickConnectItem) {
		return NO;
	}

	if ((action == @selector(sortFavorites:)) || (action == @selector(reverseSortFavorites:))) {
		
		if ([[favoritesRoot allChildLeafs] count] < 2) return NO;
		
		// Loop all the items in the sort by menu only checking the currently selected one
		for (NSMenuItem *item in [[menuItem menu] itemArray])
		{
			[item setState:([[menuItem menu] indexOfItem:item] == currentSortItem)];
		}
		
		// Check or uncheck the reverse sort item
		if (action == @selector(reverseSortFavorites:)) {
			[menuItem setState:reverseFavoritesSort];
		}
	}
	
	// Remove/rename the selected node
	if (action == @selector(removeNode:) || action == @selector(renameNode:)) {
		return selectedRows == 1;
	}
	
	// Duplicate and make the selected favorite the default
	if (action == @selector(duplicateFavorite:)) {
		return ((selectedRows == 1) && (![node isGroup]));
	}
	
	// Make selected favorite the default
	if (action == @selector(makeSelectedFavoriteDefault:)) {
		NSInteger favoriteID = [[[self selectedFavorite] objectForKey:SPFavoriteIDKey] integerValue];
				
		return ((selectedRows == 1) && (![node isGroup]) && (favoriteID != [prefs integerForKey:SPDefaultFavorite]));
	}
	
	// Favorites export
	if (action == @selector(exportFavorites:)) {
				
		if ([[favoritesRoot allChildLeafs] count] == 0) {
			return NO;
		}
		else if (selectedRows == 1) {
			return (![[self selectedFavoriteNode] isGroup]);
		}
		else if (selectedRows > 1) {
			[menuItem setTitle:NSLocalizedString(@"Export Selected...", @"export selected favorites menu item")];
		}
	}
		
    return YES;
}

#endif

#pragma mark -
#pragma mark Favorites import/export delegate methods

#ifndef SP_REFACTOR

/**
 * Called by the favorites exporter when the export completes.
 */
- (void)favoritesExportCompletedWithError:(NSError *)error
{	
	if (error) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Favorites export error", @"favorites export error message")
										 defaultButton:NSLocalizedString(@"OK", @"OK")
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The following error occurred during the export process:\n\n%@", @"favorites export error informative message"), [error localizedDescription]]];
		
		[alert beginSheetModalForWindow:[dbDocument parentWindow] 
						  modalDelegate:self
						 didEndSelector:NULL
							contextInfo:NULL];			
	}
}

/**
 * Called by the favorites importer when the imported data is available.
 */
- (void)favoritesImportData:(NSArray *)data
{
	// Add each of the imported favorites to the root node
	for (NSMutableDictionary *favorite in data)
	{
		[favoritesController addFavoriteNodeWithData:favorite asChildOfNode:nil];
	}
	
	if (currentSortItem > SPFavoritesSortUnsorted) {
		[self _sortFavorites];
	}
	
	[self _reloadFavoritesViewData];
}

/**
 * Called by the favorites importer when the import completes.
 */
- (void)favoritesImportCompletedWithError:(NSError *)error
{	
	if (error) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Favorites import error", @"favorites import error message")
										 defaultButton:NSLocalizedString(@"OK", @"OK")
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The following error occurred during the import process:\n\n%@", @"favorites import error informative message"), [error localizedDescription]]];	
		
		[alert beginSheetModalForWindow:[dbDocument parentWindow] 
						  modalDelegate:self
						 didEndSelector:NULL
							contextInfo:NULL];
	}
}

#endif

#pragma mark -
#pragma mark Private API

#ifndef SP_REFACTOR

/**
 * Sets the expanded state of the node from the supplied outline view notification.
 *
 * @param expanded     The state of the node
 * @param notification The notification genrated from the state change
 */
- (void)_setNodeIsExpanded:(BOOL)expanded fromNotification:(NSNotification *)notification
{
	SPGroupNode *node = [[[notification userInfo] valueForKey:@"NSObject"] representedObject];
	
	[node setNodeIsExpanded:expanded];	
}

#endif

@end
