//
//  FSUser.m
//  FSUser
//
//  Created by Adam Kirk on 8/2/12.
//  Copyright (c) 2012 FamilySearch.org. All rights reserved.
//

#import "FSUser.h"
#import "private.h"
#import <NSObject+MTJSONUtils.h>





@interface FSUser ()
@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSString *devKey;
@property (strong, nonatomic) FSPerson *treePerson;
@end







@implementation FSUser

static FSUser *__currentUser = nil;

+ (FSUser *)currentUser
{
    return __currentUser;
}

- (id)initWithUsername:(NSString *)username password:(NSString *)password developerKey:(NSString *)devKey
{
    self = [super init];
    if (self) {
        _username   = username;
        _password   = password;
        _devKey     = devKey;
        _loggedIn   = NO;
    }
    return self;
}

- (MTPocketResponse *)login
{
    _treePerson = nil;
    [FSURL setSessionID:nil];

	NSURL *url = [FSURL urlWithModule:@"identity"
                              version:2
                             resource:@"login"
                          identifiers:nil
                               params:0
                                 misc:[NSString stringWithFormat:@"key=%@", _devKey]];

    MTPocketResponse *response = [MTPocketRequest requestForURL:url method:MTPocketMethodGET format:MTPocketFormatJSON username:_username password:_password body:nil].send;

	if (response.success) {
        _loggedIn = YES;
        __currentUser = self;
		NSString *sessionID = NILL([response.body valueForKeyPath:@"session.id"]);
        [FSURL setSessionID:sessionID];
	}

	return response;
}

- (FSPerson *)treePerson
{
    if (!_treePerson) _treePerson = [FSPerson personWithIdentifier:@"me"];
    return _treePerson;
}

- (MTPocketResponse *)fetch
{
	NSURL *url = [FSURL urlWithModule:@"identity"
                              version:2
                             resource:@"user"
                          identifiers:nil
                               params:0
                                 misc:nil];

    MTPocketResponse *response = [MTPocketRequest requestForURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil].send;

	if (response.success) {
        NSDictionary *userDict                  = [response.body[@"users"] lastObject];
        NSMutableDictionary *infoDict           = [NSMutableDictionary dictionary];
        infoDict[FSUserInfoIDKey]               = userDict[FSUserInfoIDKey];
        infoDict[FSUserInfoMembershipIDKey]     = [userDict valueForKeyPath:FSUserInfoMembershipIDKey];
        infoDict[FSUserInfoStakeKey]            = [userDict valueForKeyPath:FSUserInfoStakeKey];
        infoDict[FSUserInfoTempleDistrictKey]   = [userDict valueForKeyPath:FSUserInfoTempleDistrictKey];
        infoDict[FSUserInfoWardKey]             = [userDict valueForKeyPath:FSUserInfoWardKey];
        infoDict[FSUserInfoNameKey]             = [userDict valueForComplexKeyPath:FSUserInfoNameKey];
        infoDict[FSUserInfoUsernameKey]         = userDict[FSUserInfoUsernameKey];
        _info                                   = [NSDictionary dictionaryWithDictionary:infoDict];
	}
    else return response;


	url = [FSURL urlWithModule:@"identity"
                       version:2
                      resource:@"permission"
                   identifiers:nil
                        params:0
                          misc:@"product=FamilyTree"];

    response = [MTPocketRequest requestForURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil].send;

	if (response.success) {
        NSArray *permissions = response.body[@"permissions"];
        NSMutableDictionary *permissionsDict = [NSMutableDictionary dictionary];
        permissionsDict[FSUserPermissionAccess]                 = @NO;
        permissionsDict[FSUserPermissionView]                   = @NO;
        permissionsDict[FSUserPermissionModify]                 = @NO;
        permissionsDict[FSUserPermissionViewLDSInformation]     = @NO;
        permissionsDict[FSUserPermissionModifyLDSInformation]   = @NO;
        permissionsDict[FSUserPermissionAccessLDSInterface]     = @NO;
        permissionsDict[FSUserPermissionAccessDiscussionForums] = @NO;
        for (NSDictionary *permission in permissions) {
            permissionsDict[permission[@"value"]] = @YES;
        }
        _permissions = [NSDictionary dictionaryWithDictionary:permissionsDict];
    }

	return response;
}

- (MTPocketResponse *)logout
{
	NSURL *url = [FSURL urlWithModule:@"identity" version:2 resource:@"logout" identifiers:nil params:0 misc:nil];
    MTPocketResponse *response = [MTPocketRequest requestForURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil].send;
    if (response.success) {
        _loggedIn       = NO;
        _username       = nil;
        _treePerson     = nil;
        _info           = nil;
        _permissions    = nil;
        [FSURL setSessionID:nil];
    }
    return response;
}

- (BOOL)LDSPermissions
{
    static NSArray *ldsPermissions = nil;
    if (!ldsPermissions) {
        ldsPermissions = @[ FSUserPermissionAccessLDSInterface, FSUserPermissionModifyLDSInformation, FSUserPermissionViewLDSInformation ];
    }
    BOOL allTrue = YES;
    for (NSString *permission in ldsPermissions) {
        if (![_permissions[permission] boolValue]) {
            allTrue = NO;
        }
    }
    return allTrue;
}



@end



NSString *const FSUserInfoIDKey                         = @"id";
NSString *const FSUserInfoMembershipIDKey               = @"member.id";
NSString *const FSUserInfoStakeKey                      = @"member.stake";
NSString *const FSUserInfoTempleDistrictKey             = @"member.templeDistrict";
NSString *const FSUserInfoWardKey                       = @"member.ward";
NSString *const FSUserInfoNameKey                       = @"names[first].value";
NSString *const FSUserInfoUsernameKey                   = @"username";

NSString *const FSUserPermissionAccess                  = @"Access";
NSString *const FSUserPermissionView                    = @"View";
NSString *const FSUserPermissionModify                  = @"Modify";
NSString *const FSUserPermissionViewLDSInformation      = @"View LDS Information";
NSString *const FSUserPermissionModifyLDSInformation    = @"Modify LDS Information";
NSString *const FSUserPermissionAccessLDSInterface      = @"Access LDS Interface";
NSString *const FSUserPermissionAccessDiscussionForums  = @"Access Discussion Forums";

