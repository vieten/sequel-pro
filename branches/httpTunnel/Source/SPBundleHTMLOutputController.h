//
//  $Id: SPBundleHTMLOutputController.h 3745 2012-07-25 10:18:02Z stuart02 $
//
//  SPBundleHTMLOutputController.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 12, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import <WebKit/WebKit.h>

@interface SPBundleHTMLOutputController : NSWindowController 
{
	IBOutlet WebView *webView;

	NSString       *docTitle;
	NSString       *initHTMLSourceString;
	NSString       *windowUUID;
	NSString       *docUUID;
	BOOL           suppressExceptionAlerting;
	WebPreferences *webPreferences;
}

@property(readwrite,retain) NSString *docTitle;
@property(readwrite,retain) NSString *initHTMLSourceString;
@property(readwrite,retain) NSString *windowUUID;
@property(readwrite,retain) NSString *docUUID;
@property(assign) BOOL suppressExceptionAlerting;

- (IBAction)printDocument:(id)sender;

- (void)displayHTMLContent:(NSString *)content withOptions:(NSDictionary *)displayOptions;
- (void)displayURLString:(NSString *)url withOptions:(NSDictionary *)displayOptions;

- (void)showSourceCode;
- (void)saveDocument;

@end
