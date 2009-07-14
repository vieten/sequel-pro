//
//  $Id$
//
//  TableDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
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
#import <MCPKit_bundled/MCPKit_bundled.h>
#import <WebKit/WebKit.h>

@class CMMCPConnection, CMMCPResult, SPConnectionController;

/**
 * The TableDocument class controls the primary database view window.
 */
@interface TableDocument : NSDocument
{
	// IBOutlets
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id tableRelationsInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id databaseDataInstance;
	IBOutlet id spExportControllerInstance;

	IBOutlet id tableWindow;
	
	IBOutlet id titleAccessoryView;
	IBOutlet id titleImageView;
	IBOutlet id titleStringView;
	
	IBOutlet id databaseSheet;
	IBOutlet id variablesSheet;

	IBOutlet id queryProgressBar;
	IBOutlet id favoritesButton;

	IBOutlet id databaseNameField;
	IBOutlet id databaseEncodingButton;
	IBOutlet id addDatabaseButton;
	IBOutlet id chooseDatabaseButton;
	IBOutlet id variablesTableView;
	IBOutlet NSTabView *tableTabView;
	
	IBOutlet NSTableView *tableInfoTable;
	IBOutlet NSSplitView *tableListSplitter;
	IBOutlet NSSplitView *contentViewSplitter;
	IBOutlet id sidebarGrabber;
	
	IBOutlet NSTextView *customQueryTextView;
	
	IBOutlet NSTableView *dbTablesTableView;

	IBOutlet id syntaxView;
	IBOutlet id syntaxViewContent;
	IBOutlet NSWindow *createTableSyntaxWindow;

	SPConnectionController *connectionController;

	CMMCPConnection *mySQLConnection;

	NSArray *variables;
	NSString *selectedDatabase;
	NSString *mySQLVersion;
	NSUserDefaults *prefs;

	NSMenu *selectEncodingMenu;
	BOOL _supportsEncoding;
	NSString *_encoding;
	BOOL _encodingViaLatin1;
	BOOL _shouldOpenConnectionAutomatically;
	BOOL _isConnected;

	NSToolbar *mainToolbar;
	NSToolbarItem *chooseDatabaseToolbarItem;
	
	WebView *printWebView;
	
	NSMutableArray *allDatabases;
}

- (NSString *)getHTMLforPrint;

// Connection callback and methods
- (void) setConnection:(CMMCPConnection *)theConnection;
- (void)setShouldAutomaticallyConnect:(BOOL)shouldAutomaticallyConnect;
- (BOOL)shouldAutomaticallyConnect;

//database methods
- (IBAction)setDatabases:(id)sender;
- (IBAction)chooseDatabase:(id)sender;
- (IBAction)addDatabase:(id)sender;
- (IBAction)closeDatabaseSheet:(id)sender;
- (IBAction)removeDatabase:(id)sender;
- (IBAction)showMySQLHelp:(id)sender;
- (IBAction)saveServerVariables:(id)sender;
- (NSArray *)allDatabaseNames;

//encoding methods
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews;
- (NSString *)databaseEncoding;
- (NSString *)connectionEncoding;
- (BOOL)connectionEncodingViaLatin1;
- (IBAction)chooseEncoding:(id)sender;
- (BOOL)supportsEncoding;
- (void)updateEncodingMenuWithSelectedEncoding:(NSString *)encoding;
- (NSString *)encodingNameFromMySQLEncoding:(NSString *)mysqlEncoding;
- (NSString *)mysqlEncodingFromDisplayEncoding:(NSString *)encodingName;

//table methods
- (IBAction)showCreateTableSyntax:(id)sender;
- (IBAction)copyCreateTableSyntax:(id)sender;
- (NSArray *)columnNames;
- (IBAction)checkTable:(id)sender;
- (IBAction)analyzeTable:(id)sender;
- (IBAction)optimizeTable:(id)sender;
- (IBAction)repairTable:(id)sender;
- (IBAction)flushTable:(id)sender;
- (IBAction)checksumTable:(id)sender;

//other methods
- (NSString *)host;
- (void)doPerformQueryService:(NSString *)query;
- (void)flushPrivileges:(id)sender;
- (void)showVariables:(id)sender;
- (void)closeConnection;
- (NSWindow *)getCreateTableSyntaxWindow;
- (void) refreshCurrentDatabase;

//getter methods
- (NSString *)name;
- (NSString *)database;
- (NSString *)table;
- (NSString *)mySQLVersion;
- (NSString *)user;

//notification center methods
- (void)willPerformQuery:(NSNotification *)notification;
- (void)hasPerformedQuery:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;

//menu methods
- (BOOL)validateMenuItem:(NSMenuItem *)anItem;
- (IBAction)import:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)exportTable:(id)sender;
- (IBAction)exportMultipleTables:(id)sender;
- (IBAction)viewStructure:(id)sender;
- (IBAction)viewContent:(id)sender;
- (IBAction)viewQuery:(id)sender;
- (IBAction)viewStatus:(id)sender;
- (IBAction)viewRelations:(id)sender;
- (IBAction)addConnectionToFavorites:(id)sender;

// titlebar methods
- (void)setStatusIconToImageWithName:(NSString *)imagePath;
- (void)setTitlebarStatus:(NSString *)status;
- (void)clearStatusIcon;

//toolbar methods
- (void)setupToolbar;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
- (void)updateChooseDatabaseToolbarItemWidth;

//SMySQL delegate methods
- (void)willQueryString:(NSString *)query;
- (void)queryGaveError:(NSString *)error;

- (IBAction)closeSheet:(id)sender;

@end
