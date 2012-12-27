//
//  FSBugFixes.m
//  FamilySearchCocoa
//
//  Created by Adam Kirk on 11/2/12.
//  Copyright (c) 2012 FamilySearch. All rights reserved.
//

#import "FSBugFixes.h"
#import <NSDateComponents+MTDates.h>
#import "private.h"
#import "FSSearch.h"
#import "constants.h"


@interface FSBugFixes ()
@property (strong, nonatomic) FSPerson *person;
@end



@implementation FSBugFixes


- (void)setUp
{
	[FSURL setSandboxed:YES];

	FSUser *user = [[FSUser alloc] initWithUsername:SANDBOXED_USERNAME password:SANDBOXED_PASSWORD developerKey:SANDBOXED_DEV_KEY];
	[user login];

	_person = [FSPerson personWithIdentifier:nil];
	_person.name = @"Adam Kirk";
	_person.gender = @"Male";
	MTPocketResponse *response = [_person save];
	STAssertTrue(response.success, nil);
}

- (void)testAddedMotherAndFatherAreReturnedInPedigree
{
	MTPocketResponse *response = nil;

	FSPerson *father = [FSPerson personWithIdentifier:nil];
	father.name = @"Nathan Kirk";
	father.gender = @"Male";
	response = [father save];
	STAssertTrue(response.success, nil);

	[_person addParent:father withLineage:FSLineageTypeBiological];
	response = [_person save];
	STAssertTrue(response.success, nil);

	FSPerson *mother = [FSPerson personWithIdentifier:nil];
	mother.name = @"Jackie Taylor";
	mother.gender = @"Female";
	response = [mother save];
	STAssertTrue(response.success, nil);

	[_person addParent:mother withLineage:FSLineageTypeBiological];
	response = [_person save];
	STAssertTrue(response.success, nil);

	FSPerson *person = [FSPerson personWithIdentifier:_person.identifier];
	response = [person fetchAncestors:2];
	STAssertTrue(response.success, nil);
	STAssertTrue(person.parents.count == 2, nil);
}

- (void)testSaveAPersonMultipleTimes
{
    MTPocketResponse *response = nil;

    // create and add event to person
	FSEvent *event = [FSEvent eventWithType:FSPersonEventTypeBirth identifier:nil];
	event.date = [NSDateComponents componentsFromString:@"11 August 1994"];
	event.place = @"Kennewick, WA";
	[_person addEvent:event];
	response = [_person save];
	STAssertTrue(response.success, nil);

    response = [_person fetch];
    STAssertTrue(response.success, nil);

    event = [_person.events lastObject];
    event.place = @"Farmington, UT";

    response = [_person save];
    STAssertTrue(response.success, nil);

	event.date = [NSDateComponents componentsFromString:@"11 July 1994"];

    response = [_person save];
    STAssertTrue(response.success, nil);

    response = [_person save];
    STAssertTrue(response.success, nil);

    response = [_person save];
    STAssertTrue(response.success, nil);
}

@end