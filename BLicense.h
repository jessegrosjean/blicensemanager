//
//  BLicense.h
//  BLicenseManager
//
//  Created by Jesse Grosjean on 10/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Blocks/Blocks.h>


@interface BLicense : NSWindowController {
	IBOutlet NSObjectController *objectController;
	IBOutlet NSTextField *nameTextField;
	IBOutlet NSTextView *keyTextView;
	IBOutlet NSButton *registerButton;
	IBOutlet NSButton *purchaseButton;
	IBOutlet NSButton *laterButton;
	
	NSString *name;
	NSString *publicKey;
	NSInteger numberOfTrialDays;
	NSURL *purchaseURL;
	NSURL *recoverLostLicenseURL;
}

#pragma mark Init

- (id)initLicenseWithName:(NSString *)aName;

#pragma mark License

@property(readonly) NSString *name;
@property(retain) NSString *publicKey;
@property(retain) NSURL *purchaseURL;
@property(retain) NSURL *recoverLostLicenseURL;

#pragma mark License Trial

@property(readonly) NSDate *trialStartDate;
@property(readonly) NSDate *trialExpirationDate;
@property(assign) NSInteger numberOfTrialDays;
@property(readonly) NSInteger trialDaysRemaining;

#pragma mark License Owner

@property(retain) NSString *ownerName;
@property(retain) NSString *licenseKey;

#pragma mark Actions

- (IBAction)recoverLostLicense:(id)sender;
- (IBAction)close:(id)sender;
- (IBAction)purchaseLicense:(id)sender;
- (IBAction)registerLicense:(id)sender;

#pragma mark Alerts

- (void)runShowTrialAlert;
- (BOOL)runShowTrailExpiredAlert;
- (BOOL)runRegistrationPanelModal;

#pragma mark Validation

@property(readonly) BOOL isValid;

@end

APPKIT_EXTERN NSString *BLicenseOwnerNameKey;
APPKIT_EXTERN NSString *BLicenseKeyKey;
APPKIT_EXTERN NSString *BLicenseTrialStartDateKey;