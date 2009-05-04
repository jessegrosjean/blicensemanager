//
//  BLicense.m
//  BLicenseManager
//
//  Created by Jesse Grosjean on 9/6/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//
#import "BLicense.h"

#import <openssl/evp.h>
#import <openssl/rand.h>
#import <openssl/rsa.h>
#import <openssl/engine.h>
#import <openssl/sha.h>
#import <openssl/pem.h>
#import <openssl/bio.h>
#import <openssl/err.h>
#import <openssl/ssl.h>

@interface BLicense (BPrivate)

- (NSData *)base64Decode:(NSString *)base64String;
- (NSData *)sha1Digest:(NSData *)data;
- (NSData *)decrypt:(NSData *)cipherTextData;

@end

@implementation BLicense

#pragma mark Init

- (id)initLicenseWithName:(NSString *)aName {
	if (self = [super initWithWindowNibName:@"BLicenseWindow"]) {
		name = aName;
	}
	return self;
}

#pragma mark awake from nib

- (void)validateUI {
	if ([self isValid]) {
		[registerButton setEnabled:YES];
		[purchaseButton setHidden:YES];
		[laterButton setHidden:YES];
	} else {
		[registerButton setEnabled:NO];
		[purchaseButton setHidden:NO];
		[laterButton setHidden:NO];
	}
}

- (void)windowDidLoad {
	[[self window] setTitle:[NSString stringWithFormat:BLocalizedString(@"%@ Registration", nil), name]];
	[keyTextView setFont:[NSFont userFixedPitchFontOfSize:10]];
	[self validateUI];
}

#pragma mark License

@synthesize name;
@synthesize publicKey;
@synthesize purchaseURL;
@synthesize recoverLostLicenseURL;

#pragma mark License Trial

- (NSDate *)trialStartDate {
	NSDate *trialStartDate = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@.%@", name, BLicenseTrialStartDateKey]];
	if (!trialStartDate) {
		trialStartDate = [NSDate date];
		[[NSUserDefaults standardUserDefaults] setObject:trialStartDate forKey:[NSString stringWithFormat:@"%@.%@", name, BLicenseTrialStartDateKey]];
	}
	return trialStartDate;
}

- (NSDate *)trialExpirationDate {
	return [[self trialStartDate] addTimeInterval:[self numberOfTrialDays] * 24 * 60 * 60];
}


@synthesize numberOfTrialDays;

- (NSInteger)trialDaysRemaining {
	return (NSInteger) ceil([[self trialExpirationDate] timeIntervalSinceDate:[NSDate date]] / 24 / 60 / 60);
}

#pragma mark License Owner

- (NSString *)ownerName {
	return [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@.%@", name, BLicenseOwnerNameKey]];
}

- (NSString *)normalizedOwnerName {
	return [[self ownerName] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)setOwnerName:(NSString *)newOwnerName {
	[[NSUserDefaults standardUserDefaults] setObject:newOwnerName forKey:[NSString stringWithFormat:@"%@.%@", name, BLicenseOwnerNameKey]];
	[self validateUI];
}

- (BOOL)validateOwnerName:(id *)ioValue error:(NSError **)outError {
	NSString *newOwnerName = *ioValue;
	newOwnerName = [newOwnerName substringWithRange:[newOwnerName paragraphRangeForRange:NSMakeRange(0, 0)]];
	if ([newOwnerName length] > 0 && [newOwnerName characterAtIndex:[newOwnerName length] - 1] == NSNewlineCharacter) {
		newOwnerName = [newOwnerName substringWithRange:NSMakeRange(0, [newOwnerName length] - 1)];
	}
	*ioValue = newOwnerName;
    return YES;
}

- (NSString *)licenseKey {
	return [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@.%@", name, BLicenseKeyKey]];
}

- (NSMutableString *)formattedLicenseKey:(NSString *)aLicenseKey {
	NSMutableString *licenseKey = [aLicenseKey mutableCopy];
	NSMutableCharacterSet *alphanumericCharacterSet = [NSMutableCharacterSet alphanumericCharacterSet];
	
	[alphanumericCharacterSet addCharactersInString:@"+=/"];
	
//	NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSInteger i = [licenseKey length] - 1;
	
	while (i >= 0) {
		unichar c = [licenseKey characterAtIndex:i];
		
		if (![alphanumericCharacterSet characterIsMember:c]) {
			[licenseKey deleteCharactersInRange:NSMakeRange(i, 1)];
		}
		
//		if ([whitespaceAndNewlineCharacterSet characterIsMember:c]) {
//			[licenseKey deleteCharactersInRange:NSMakeRange(i, 1)];
//		}
		
		i--;
	}
	
	if ([licenseKey length] > 172) licenseKey = [[licenseKey substringToIndex:172] mutableCopy];	
	if ([licenseKey length] >= 172) [licenseKey insertString:@"\n" atIndex:172];	
	if ([licenseKey length] >= 120) [licenseKey insertString:@"\n" atIndex:120];	
	if ([licenseKey length] >= 60) [licenseKey insertString:@"\n" atIndex:60];
	
	return licenseKey;
}

- (NSData *)normalizedLicenseKeyData {
	NSMutableString *licenseKey = [self formattedLicenseKey:[self licenseKey]];
	if ([licenseKey length] != 175) return [NSData data];
	return [self base64Decode:licenseKey];
}

- (void)setLicenseKey:(NSString *)newLicenseKey {
	[[NSUserDefaults standardUserDefaults] setObject:newLicenseKey forKey:[NSString stringWithFormat:@"%@.%@", name, BLicenseKeyKey]];
	[self validateUI];
}

- (BOOL)validateLicenseKey:(id *)ioValue error:(NSError **)outError {
	NSString *newLicenseKey = *ioValue;
	newLicenseKey = [self formattedLicenseKey:newLicenseKey];
	if ([newLicenseKey length] > 0 && [newLicenseKey characterAtIndex:[newLicenseKey length] - 1] == NSNewlineCharacter) {
		newLicenseKey = [newLicenseKey substringWithRange:NSMakeRange(0, [newLicenseKey length] - 1)];
	}
	*ioValue = newLicenseKey;
    return YES;
}

#pragma mark Actions

- (IBAction)recoverLostLicense:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[self recoverLostLicenseURL]];
}

- (IBAction)close:(id)sender {
	[NSApp stopModalWithCode:NSCancelButton];
	[self close];
}

- (IBAction)purchaseLicense:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[self purchaseURL]];
}

- (IBAction)registerLicense:(id)sender {
	[NSApp stopModalWithCode:NSOKButton];
	[self close];
}

#pragma mark Alerts

- (void)runShowTrialAlert {
	NSString *title = [NSString stringWithFormat:BLocalizedString(@"This is a %lu day trial of %@", nil), (unsigned long) [self numberOfTrialDays], name];
	NSString *message = [NSString stringWithFormat:BLocalizedString(@"You have %lu days left in your trial. If you want to keep using %@ after your trial is over you must buy a license.", nil), (unsigned long) [self trialDaysRemaining], name];
	NSInteger choice = NSRunAlertPanel(title,
									   message,
									   BLocalizedString(@"Buy Now", nil),
									   BLocalizedString(@"Later", nil),
									   BLocalizedString(@"Register", nil));
	if (choice == NSAlertDefaultReturn) {
		[self purchaseLicense:nil];
	} else if (choice == NSAlertAlternateReturn) {
		// later
	} else {
		[self runRegistrationPanelModal];
	}
}

- (BOOL)runShowTrailExpiredAlert {
	NSString *title = [NSString stringWithFormat:BLocalizedString(@"Thanks for trying %@!", nil), name];
	NSString *message = [NSString stringWithFormat:BLocalizedString(@"Your %lu day trial of %@ has expired. If you want to continue to use %@ please buy a license and register your copy.", nil), (unsigned long) [self numberOfTrialDays], name, name];
	NSInteger choice = NSRunAlertPanel(title,
									   message,
									   BLocalizedString(@"Register", nil),
									   BLocalizedString(@"Buy Now", nil),
									   BLocalizedString(@"Quit", nil));
	if (choice == NSAlertDefaultReturn) {
		if (![self runRegistrationPanelModal]) {
			return [self runShowTrailExpiredAlert];
		}
	} else if (choice == NSAlertAlternateReturn) {
		[self purchaseLicense:nil];
		return [self runShowTrailExpiredAlert];
	} else {
	}
	
	return NO;
}

- (BOOL)runRegistrationPanelModal {
	[NSApp runModalForWindow:[self window]];
	return [self isValid];
}

#pragma mark Validation

- (BOOL)isValid {
	NSData *encryptedKeyData = [self normalizedLicenseKeyData];
	if ([encryptedKeyData length] == 0) return NO;
	
	NSData *keyData = [self decrypt:encryptedKeyData];
	if (!keyData) return NO;
	
	NSString *licenseInfo = [NSString stringWithFormat:@"%@.%@", [self normalizedOwnerName], name]; 
	NSData *licenseInfoData = [licenseInfo dataUsingEncoding:NSUTF8StringEncoding];
    NSData *licenseInfoDataDigest = [self sha1Digest:licenseInfoData];
	
	if ([keyData isEqualToData:licenseInfoDataDigest]) {
		return YES;
	} else {
		// for backwards compatibilty try uppercases... this was happening on the server, but it cause problems with non asci characters so I dumpted it.
		licenseInfo = [NSString stringWithFormat:@"%@.%@", [[self normalizedOwnerName] uppercaseString], name]; 
		licenseInfoData = [licenseInfo dataUsingEncoding:NSUTF8StringEncoding];
		licenseInfoDataDigest = [self sha1Digest:licenseInfoData];
		return [keyData isEqualToData:licenseInfoDataDigest];
	}
}

@end

@implementation BLicense (BPrivate)

- (NSData *)base64Decode:(NSString *)base64String {
    BIO * mem = BIO_new_mem_buf((void *) [base64String cStringUsingEncoding:NSUTF8StringEncoding], [base64String lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    BIO * b64 = BIO_new(BIO_f_base64());
	
    mem = BIO_push(b64, mem);
    
    NSMutableData * data = [NSMutableData data];
    char inbuf[512];
    NSUInteger inlen;

    while ((inlen = BIO_read(mem, inbuf, sizeof(inbuf))) > 0)
        [data appendBytes: inbuf length: inlen];

    BIO_free_all(mem);
    return data;
}

- (NSData *)sha1Digest:(NSData *)data {
    unsigned char *digest = SHA1([data bytes], [data length], NULL);
    
    if (!digest) {
		return nil;
    }
	
    return [NSData dataWithBytes:digest length:SHA_DIGEST_LENGTH];
}

- (NSData *)decrypt:(NSData *)cipherTextData {
    unsigned char *outbuf;
    NSInteger outlen, inlen;
    inlen = [cipherTextData length];
    unsigned char *input = (unsigned char *)[cipherTextData bytes];
    
    BIO *publicBIO = NULL;
    RSA *publicRSA = NULL;
    
    if (!(publicBIO = BIO_new_mem_buf((unsigned char *)[[[self publicKey] dataUsingEncoding:NSUTF8StringEncoding] bytes], -1))) {
		BLogWarning(@"BIO_new_mem_buf() failed!");
		return nil;
    }
    
    if (!PEM_read_bio_RSA_PUBKEY(publicBIO, &publicRSA, NULL, NULL)) {
		BLogWarning(@"PEM_read_bio_RSA_PUBKEY() failed!");
		return nil;
    }			
    
    outbuf = (unsigned char *)malloc(RSA_size(publicRSA));
    
    if (!(outlen = RSA_public_decrypt(inlen,
									  input,
									  outbuf,
									  publicRSA,
									  RSA_PKCS1_PADDING))) {
		BLogWarning(@"RSA_public_decrypt() failed!");
		return nil;
    }
    
    if (outlen == -1) {
		NSString *error = [NSString stringWithFormat:@"Decrypt error: %s (%s)",
			ERR_error_string(ERR_get_error(), NULL),
			ERR_reason_error_string(ERR_get_error())];
		BLogWarning(error);
		return nil;
    }
    
    if (publicBIO) BIO_free(publicBIO);
    if (publicRSA) RSA_free(publicRSA);
    
    NSData *clearTextData = [NSData dataWithBytes:outbuf length:outlen];
    
    if (outbuf) {
		free(outbuf);
    }
    
    return clearTextData;
}

@end

NSString *BLicenseOwnerNameKey = @"BLicenseOwnerNameKey";
NSString *BLicenseKeyKey = @"BLicenseKeyKey";
NSString *BLicenseTrialStartDateKey = @"BLicenseTrialStartDateKey";