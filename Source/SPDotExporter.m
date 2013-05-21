//
//  $Id$
//
//  SPDotExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 17, 2010.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPDotExporter.h"
#import "SPFileHandle.h"
#import "SPTableData.h"
#import "SPExportUtilities.h"
#import "SPExportFile.h"

@implementation SPDotExporter

@synthesize delegate;
@synthesize dotExportTables;
@synthesize dotExportCurrentTable;
@synthesize dotForceLowerTableNames;
@synthesize dotTableData;
@synthesize dotDatabaseHost;
@synthesize dotDatabaseName;
@synthesize dotDatabaseVersion;

/**
 * Initialise an instance of SPDotExporter using the supplied delegate.
 *
 * @param exportDelegate The exporter delegate
 *
 * @return The initialised instance
 */
- (id)initWithDelegate:(NSObject<SPDotExporterProtocol> *)exportDelegate
{
	if ((self = [super init])) {
		SPExportDelegateConformsToProtocol(exportDelegate, @protocol(SPDotExporterProtocol));
		
		[self setDelegate:exportDelegate];
		[self setDotExportCurrentTable:nil];
	}
	
	return self;
}

/**
 * Start the Dot schema export process. This method is automatically called when an instance of this class
 * is placed on an NSOperationQueue. Do not call it directly as there is no manual multithreading.
 */
- (void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];		
	
	NSMutableString *metaString = [NSMutableString string];
	
	// Check that we have all the required info before starting the export
	if ((![self dotExportTables]) || (![self dotTableData]) || ([[self dotExportTables] count] == 0)) {
		[pool release];
		return;
	}

	// Inform the delegate that the export process is about to begin
	[delegate performSelectorOnMainThread:@selector(dotExportProcessWillBegin:) withObject:self waitUntilDone:NO];
	
	// Mark the process as running
	[self setExportProcessIsRunning:YES];
	
	[metaString setString:@"// ************************************************************\n"];
	[metaString appendString:@"// Generated by: Sequel Pro\n"];
	[metaString appendFormat:@"// Version %@\n//\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[metaString appendFormat:@"// %@\n// %@\n//\n", SPLOCALIZEDURL_HOMEPAGE, SPDevURL];
	[metaString appendFormat:@"// Host: %@ (MySQL %@)\n", [self dotDatabaseHost], [self dotDatabaseVersion]];
	[metaString appendFormat:@"// Database: %@\n", [self dotDatabaseName]];
	[metaString appendFormat:@"// Generation Time: %@\n", [NSDate date]];
	[metaString appendString:@"// ************************************************************\n\n"];
	
	[metaString appendString:@"digraph \"Database Structure\" {\n"];
	[metaString appendFormat:@"\tlabel = \"ER Diagram: %@\";\n", [self dotDatabaseName]];
	[metaString appendString:@"\tlabelloc = t;\n"];
	[metaString appendString:@"\tcompound = true;\n"];
	[metaString appendString:@"\tnode [ shape = record ];\n"];
	[metaString appendString:@"\tfontname = \"Helvetica\";\n"];
	[metaString appendString:@"\tranksep = 1.25;\n"];
	[metaString appendString:@"\tratio = 0.7;\n"];
	[metaString appendString:@"\trankdir = LR;\n"];
	
	// Write information to the file
	[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
			
	NSMutableArray *fkInfo = [[NSMutableArray alloc] init];
	
	// Process the tables
	for (NSUInteger i = 0; i < [[self dotExportTables] count]; i++) 
	{
		// Check for cancellation flag
		if ([self isCancelled]) {
			[fkInfo release];
			[pool release];
			
			return;
		}
					
		NSString *tableName = NSArrayObjectAtIndex([self dotExportTables], i);
		NSString *tableLinkName = [self dotForceLowerTableNames] ? [tableName lowercaseString] : tableName;
		NSDictionary *tableInfo = [[self dotTableData] informationForTable:tableName];
					
		// Set the current table
		[self setDotExportCurrentTable:tableName];
		
		// Inform the delegate that we are about to start fetcihing data for the current table
		[[delegate onMainThread] dotExportProcessWillBeginFetchingData:self forTableWithIndex:i];
		
		NSString *hdrColor = @"#DDDDDD";
					
		if ([[tableInfo objectForKey:@"type"] isEqualToString:@"View"]) {
			hdrColor = @"#DDDDFF";
		}
		
		[metaString setString:[NSString stringWithFormat:@"\tsubgraph \"table_%@\" {\n", tableName]];
		[metaString appendString:@"\t\tnode [ shape = \"plaintext\" ];\n"];
		[metaString appendFormat:@"\t\t\"%@\" [ label=<\n", tableLinkName];
		[metaString appendString:@"\t\t\t<TABLE BORDER=\"0\" CELLSPACING=\"0\" CELLBORDER=\"1\">\n"];
		[metaString appendFormat:@"\t\t\t<TR><TD COLSPAN=\"3\" BGCOLOR=\"%@\">%@</TD></TR>\n", hdrColor, tableName];
		
		// Retrieve the column definitions for the current table
		NSArray *tableColumns = [tableInfo objectForKey:@"columns"];
		
		for (NSDictionary *aColumn in tableColumns) 
		{
			[metaString appendFormat:@"\t\t\t<TR><TD COLSPAN=\"3\" PORT=\"%@\">%@:<FONT FACE=\"Helvetica-Oblique\" POINT-SIZE=\"10\">%@</FONT></TD></TR>\n", [aColumn objectForKey:@"name"], [aColumn objectForKey:@"name"], [aColumn objectForKey:@"type"]];
		}
		
		[metaString appendString:@"\t\t\t</TABLE>>\n"];
		[metaString appendString:@"\t\t];\n"];
		[metaString appendString:@"\t}\n"];
		
		[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
		
		// Check if any relations are available for the table
		NSArray *tableConstraints = [tableInfo objectForKey:@"constraints"];
		
		if ([tableConstraints count]) {
			
			for (NSDictionary* constraint in tableConstraints) 
			{
				// Check for cancellation flag
				if ([self isCancelled]) {
					[fkInfo release];
					[pool release];
					
					return;
				}
				
				// Get the column references. Currently the columns themselves are an array,
				// while tables are comma separated if there are more than
				// one.  Only use the first of each for the time being.
				NSArray *originColumns = [constraint objectForKey:@"columns"];
				NSArray *referenceColumns = [constraint objectForKey:@"ref_columns"];
				
				NSString *extra = @"";
				
				if ([originColumns count] > 1) {
					extra = @" [ arrowhead=crow, arrowtail=odiamond ]";
				}
				
				[fkInfo addObject:[NSString stringWithFormat:@"%@:%@ -> %@:%@ %@", tableLinkName, [originColumns objectAtIndex:0], [constraint objectForKey:@"ref_table"], [[referenceColumns objectAtIndex:0] lowercaseString], extra]];
			}
		}

		// Update progress
		double progress = (i * ([self exportMaxProgress] / [[self dotExportTables] count]));
		
		[self setExportProgressValue:progress];
		[delegate performSelectorOnMainThread:@selector(dotExportProcessProgressUpdated:) withObject:self waitUntilDone:NO];
	}
	
	// Inform the delegate that we are about to start fetching relations data for the current table
	[delegate performSelectorOnMainThread:@selector(dotExportProcessWillBeginFetchingRelationsData:) withObject:self waitUntilDone:NO];
	
	[metaString setString:@"edge [ arrowhead=inv, arrowtail=normal, style=dashed, color=\"#444444\" ];\n"];
	
	// Get the relations
	for (id item in fkInfo) 
	{
		[metaString appendFormat:@"%@;\n", item];
	}
	
	[fkInfo release];
	
	[metaString appendString:@"}\n"];
	
	// Write information to the file
	[[self exportOutputFile] writeData:[metaString dataUsingEncoding:NSUTF8StringEncoding]];
			
	// Write data to disk
	[[self exportOutputFile] close];
	
	// Mark the process as not running
	[self setExportProcessIsRunning:NO];
	
	// Inform the delegate that the export process is complete
	[delegate performSelectorOnMainThread:@selector(dotExportProcessComplete:) withObject:self waitUntilDone:NO];
	
	[pool release];
}

#pragma mark -

- (void)dealloc
{
	delegate = nil;
	
	[dotExportTables release], dotExportTables = nil;
	[dotExportCurrentTable release], dotExportCurrentTable = nil;
	[dotTableData release], dotTableData = nil;
	[dotDatabaseHost release], dotDatabaseHost = nil;
	[dotDatabaseName release], dotDatabaseName = nil;
	[dotDatabaseVersion release], dotDatabaseVersion = nil;
	
	[super dealloc];
}

@end
