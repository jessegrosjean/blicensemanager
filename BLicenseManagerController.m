//
//  BLicenseManagerController.m
//  BLicenseManager
//
//  Created by Jesse Grosjean on 9/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BLicenseManagerController.h"
#import "BLicense.h"


@implementation BLicenseManagerController

#pragma mark Class Methods

+ (id)sharedInstance {
    static id sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

#pragma mark Init

- (id)init {
	if (self = [super init]) {
		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"BLicenseManagerDisableAppleEventHandling"]) {
			[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
		}
	}
	return self;
}

#pragma mark Finalize

- (void)finalize {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"BLicenseManagerDisableAppleEventHandling"]) {
		[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
	}
	[super finalize];
}

#pragma mark Specify License

- (NSMutableDictionary *)licenseNamesToLicenses {
	if (!licenseNamesToLicenses) {
		licenseNamesToLicenses = [NSMutableDictionary dictionary];
		BExtensionPoint *extensionPoint = [[BExtensionRegistry sharedInstance] extensionPointFor:@"com.blocks.BLicenseManager.licenses"];
		NSArray *selectors = [NSArray arrayWithObject:[NSValue valueWithPointer:@selector(declareLicenses)]];
		
		for (BConfigurationElement *each in [extensionPoint configurationElements]) {
			id eachObserver = [each createExecutableExtensionFromAttribute:@"class" conformingToClass:nil conformingToProtocol:nil respondingToSelectors:selectors];
			if (eachObserver) {
				[eachObserver performSelector:@selector(declareLicenses)];
			}
		}		
	}
	return licenseNamesToLicenses;
}

- (NSString *)applicationLicenseName {
	if (!applicationLicenseName) {
		return [[[[[self licenseNamesToLicenses] keyEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)] lastObject];
	}
	return applicationLicenseName;
}

- (void)setApplicationLicenseName:(NSString *)newApplicationLicenseName {
	applicationLicenseName = newApplicationLicenseName;
}

- (BLicense *)licenseForLicenseName:(NSString *)licenseName {
	BLicense *license = [[self licenseNamesToLicenses] objectForKey:[licenseName uppercaseString]];
	if (!license) {
		license = [[BLicense alloc] initLicenseWithName:licenseName];
		[licenseNamesToLicenses setObject:license forKey:[licenseName uppercaseString]];
	}
	return license;
}

#pragma mark Actions

- (IBAction)showRegistration:(id)sender {
	[[self licenseForLicenseName:[self applicationLicenseName]] runRegistrationPanelModal];
}

- (IBAction)orderFrontStandardAboutPanel:(id)sender {
	NSMutableDictionary *optionsDictionary = [NSMutableDictionary dictionary];
	NSMutableAttributedString *credits = [[NSMutableAttributedString alloc] init];
	BLicense *license = [self licenseForLicenseName:applicationLicenseName];
	
	if ([license isValid]) {
		[credits replaceCharactersInRange:NSMakeRange(0, 0) withString:[NSString stringWithFormat:@"%@\n%@", BLocalizedString(@"Registered", nil), [license ownerName]]];
	} else {
		[credits replaceCharactersInRange:NSMakeRange(0, 0) withString:BLocalizedString(@"Unregistered Copy", nil)];
	}
	
	[optionsDictionary setObject:credits forKey:@"Credits"];
	
	[NSApp orderFrontStandardAboutPanelWithOptions:optionsDictionary];
}

#pragma mark License Registration

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
	
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	
	if ([[url scheme] rangeOfString:@"register-"].location == 0) {
		NSString *licenseName = [[url scheme] substringFromIndex:9];
		NSString *licenseKey = [url host];
		NSString *ownerName = [[[url path] lastPathComponent] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		BLicense *license = [self licenseForLicenseName:licenseName];
		
		if (!license) {
			NSString *title = [NSString stringWithFormat:BLocalizedString(@"Sorry the license %@ wasn't recognized", nil), [license name]];
			NSString *message = BLocalizedString(@"Please contact this applications developer for help.", nil);
			NSRunAlertPanel(title, message, BLocalizedString(@"OK", nil), nil, nil);
		} else {
			[license setOwnerName:ownerName];
			[license setLicenseKey:licenseKey];
			
			if ([license isValid]) {
				NSString *title = [NSString stringWithFormat:BLocalizedString(@"Thanks for registering %@!", nil), [license name]];
				NSString *message = BLocalizedString(@"You can review your regisration information by choosing the \"Registration...\" menu item. Thanks for your support of this software.", nil);
				NSRunAlertPanel(title, message, BLocalizedString(@"OK", nil), nil, nil);
			} else {
				[license runRegistrationPanelModal];
			}
		}
	} else {
		// how to pass on the handling?
	}
}

@end

