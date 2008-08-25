//
//  BLicenseManagerController.h
//  BLicenseManager
//
//  Created by Jesse Grosjean on 9/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Blocks/Blocks.h>


@class BLicense;

@interface BLicenseManagerController : NSObject {
	NSString *applicationLicenseName;
	NSMutableDictionary *licenseNamesToLicenses;
}

#pragma mark class methods

+ (id)sharedInstance;

#pragma mark Specify License

@property(retain) NSString *applicationLicenseName;
- (BLicense *)licenseForLicenseName:(NSString *)licenseName;

#pragma mark Actions

- (IBAction)showRegistration:(id)sender;
- (IBAction)orderFrontStandardAboutPanel:(id)sender;

#pragma mark License Registration

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

@end