//
//  FSEventTests.m
//  FamilySearchCocoa
//
//  Created by Adam Kirk on 8/23/12.
//  Copyright (c) 2012 FamilySearch. All rights reserved.
//

#import <NSDate+MTDates.h>
#import "FSEventTests.h"
#import "FSAuth.h"
#import "FSPerson.h"
#import "FSEvent.h"
#import "FSURL.h"
#import "constants.h"

@interface FSEventTests ()
@property (strong, nonatomic) NSString *sessionID;
@property (strong, nonatomic) FSPerson *person;
@end

@implementation FSEventTests

- (void)setUp
{
	[FSURL setSandboxed:YES];

	FSAuth *auth = [[FSAuth alloc] initWithDeveloperKey:SANDBOXED_DEV_KEY];
	[auth loginWithUsername:SANDBOXED_USERNAME password:SANDBOXED_PASSWORD];
	_sessionID = auth.sessionID;

	_person = [FSPerson personWithSessionID:_sessionID identifier:nil];
	_person.name = @"Adam Kirk";
	_person.gender = @"Male";
	MTPocketResponse *response = [_person save];
	STAssertTrue(response.success, nil);
}

- (void)testAddAndRemoveEvent
{
	MTPocketResponse *response = nil;

	// assert person has no events to start with
	STAssertTrue(_person.events.count == 0, nil);

	// add a death event so the sytem acknowledges they are dead
	FSEvent *death = [FSEvent eventWithType:FSPersonEventTypeDeath identifier:nil];
	death.date = [NSDate dateFromYear:1995 month:8 day:11 hour:10 minute:0];
	death.place = @"Kennewick, WA";
	[_person addEvent:death];


	// create and add event to person
	FSEvent *event = [FSEvent eventWithType:FSPersonEventTypeBaptism identifier:nil];
	event.date = [NSDate dateFromYear:1994 month:8 day:11 hour:10 minute:0];
	event.place = @"Kennewick, WA";
	[_person addEvent:event];
	response = [_person save];
	STAssertTrue(response.success, nil);

	// fetch the person and assert the events were added
	FSPerson *person = [FSPerson personWithSessionID:_sessionID identifier:_person.identifier];
	response = [person fetch];
	STAssertTrue(response.success, nil);
	STAssertTrue(person.events.count == 2, nil);

	// remove the event
	[person removeEvent:event];
	response = [person save];
	STAssertTrue(response.success, nil);

	// assert event was removed
	person = [FSPerson personWithSessionID:_sessionID identifier:person.identifier];
	response = [person fetch];
	STAssertTrue(response.success, nil);
	STAssertTrue(person.events.count == 1, nil);
}

- (void)testConvenienceEventMethods
{
	MTPocketResponse *response = nil;

	// assert person has no events to start with
	STAssertTrue(_person.events.count == 0, nil);

	NSDate		*birthDate	= [NSDate dateFromYear:1995 month:8 day:11 hour:0 minute:0];
	NSString	*birthPlace	= @"Kennewick, Benton, Washington, United States";
	NSDate		*deathDate	= [NSDate dateFromYear:1994 month:8 day:11 hour:0 minute:0];
	NSString	*deathPlace	= @"Pasco, Franklin, Washington, United States";

	// create and add event to person
	_person.birthDate	= birthDate;
	_person.birthPlace	= birthPlace;

	// add a death event so the sytem acknowledges they are dead
	_person.deathDate	= deathDate;
	_person.deathPlace	= deathPlace;

	response = [_person save];
	STAssertTrue(response.success, nil);

	// fetch the person and assert the events were added
	FSPerson *person = [FSPerson personWithSessionID:_sessionID identifier:_person.identifier];
	response = [person fetch];
	STAssertTrue(response.success, nil);
	STAssertTrue(person.events.count == 2, nil);

	// read the values
	STAssertTrue([person.birthDate	isEqualToDate:birthDate],		nil);
	STAssertTrue([person.birthPlace isEqualToString:birthPlace],	nil);
	STAssertTrue([person.deathDate	isEqualToDate:deathDate],		nil);
	STAssertTrue([person.deathPlace	isEqualToString:deathPlace],	nil);
}

@end