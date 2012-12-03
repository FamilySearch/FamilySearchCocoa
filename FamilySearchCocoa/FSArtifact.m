//
//  FSArtifact.m
//  FamilySearchCocoa
//
//  Created by Adam Kirk on 11/5/12.
//  Copyright (c) 2012 FamilySearch. All rights reserved.
//

#import "FSArtifact.h"
#import "private.h"
#import <NSObject+MTJSONUtils.h>





@interface FSArtifactTag ()
@property (unsafe_unretained, nonatomic)    FSArtifact  *artifact;
@property (strong, nonatomic)               NSString    *taggedPersonID;
@property (nonatomic)                       BOOL        deleted;
- (MTPocketResponse *)save;
- (MTPocketResponse *)destroy;
- (void)populateFromDictionary:(NSDictionary *)dictionary;
@end





@interface FSArtifact ()
@property (strong, nonatomic) NSString *sessionID;
@property (strong, nonatomic) FSURL *connectionURL;
@property (strong, nonatomic) NSArray *tags;
@end




@implementation FSArtifact


- (id)initWithIdentifier:(NSString *)identifier data:(NSData *)data MIMEType:(FSArtifactMIMEType)MIMEType sessionID:(NSString *)sessionID
{
    self = [super init];
    if (self) {
        _identifier = identifier;
		_data       = data;
		_MIMEType	= MIMEType;
        _sessionID  = sessionID;
        _tags       = [NSMutableArray array];
    }
    return self;
}

+ (FSArtifact *)artifactWithData:(NSData *)data MIMEType:(FSArtifactMIMEType)MIMEType sessionID:(NSString *)sessionID
{
	return [[FSArtifact alloc] initWithIdentifier:nil data:data MIMEType:MIMEType sessionID:sessionID];
}

+ (FSArtifact *)artifactWithIdentifier:(NSString *)identifier sessionID:(NSString *)sessiongID
{
    return [[FSArtifact alloc] initWithIdentifier:identifier data:nil MIMEType:FSArtifactMIMETypeImagePNG sessionID:sessiongID];
}

+ (NSArray *)artifactsForPerson:(FSPerson *)person category:(FSArtifactCategory)category response:(MTPocketResponse **)response
{
    if (!person || !person.identifier) raiseParamException(@"person");

    NSMutableArray *params = [NSMutableArray array];
    if (category) [params addObject:[NSString stringWithFormat:@"artifactCategory=%@", category]];

    FSURL *connectionURL = [[FSURL alloc] initWithSessionID:person.sessionID];
    NSURL *url = [connectionURL  urlWithModule:@"artifactmanager"
                                      version:0
                                     resource:[NSString stringWithFormat:@"persons/personsByTreePersonId/%@/artifacts", person.identifier]
                                  identifiers:nil
                                       params:0
                                         misc:[params componentsJoinedByString:@"&"]];

    MTPocketResponse *resp = *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil];

    if (resp.success) {
        NSMutableArray *artifactsArray = [NSMutableArray array];
        for (NSDictionary *artifactDict in resp.body[@"artifact"]) {
            FSArtifact *artifact = [FSArtifact artifactWithIdentifier:artifactDict[@"id"] sessionID:person.sessionID];
            [artifact populateFromDictionary:artifactDict];
            [artifactsArray addObject:artifact];
        }
        return artifactsArray;
    }

    return nil;
}

+ (FSArtifact *)portraitArtifactForPerson:(FSPerson *)person response:(MTPocketResponse **)response
{
    if (!person || !person.identifier) raiseParamException(@"person");

    FSURL *connectionURL = [[FSURL alloc] initWithSessionID:person.sessionID];
    NSURL *url = [connectionURL  urlWithModule:@"artifactmanager"
                                       version:0
                                      resource:[NSString stringWithFormat:@"persons/personsByTreePersonId/%@", person.identifier]
                                   identifiers:nil
                                        params:0
                                          misc:nil];

    MTPocketResponse *resp = *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil];

    if (resp.success) {

    }
    
    return nil;
}

+ (NSArray *)artifactsUploadedByCurrentUserWithSessionID:(NSString *)sessionID response:(MTPocketResponse **)response
{
    FSURL *connectionURL = [[FSURL alloc] initWithSessionID:sessionID];
    NSURL *url = [connectionURL  urlWithModule:@"artifactmanager"
                                       version:0
                                      resource:@"users/unknown/artifacts"
                                   identifiers:nil
                                        params:0
                                          misc:@"includeTags=true"];

    MTPocketResponse *resp = *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil];

    if (resp.success) {
        NSMutableArray *artifacts = [NSMutableArray array];
        for (NSDictionary *artifactDict in resp.body[@"artifact"]) {
            FSArtifact *artifact = [FSArtifact artifactWithIdentifier:nil sessionID:sessionID];
            [artifact populateFromDictionary:artifactDict];
            [artifacts addObject:artifact];
        }
        return artifacts;
    }

    return nil;
}



#pragma mark - Syncing

- (MTPocketResponse *)fetch
{
	if (!_identifier) raiseException(@"Nil identifier", @"You must set the identifier before you can call fetch.");

    NSURL *url = [self.connectionURL urlWithModule:@"artifactmanager"
										   version:0
										  resource:[NSString stringWithFormat:@"artifacts/%@", _identifier]
									   identifiers:nil
											params:0
											  misc:nil];

	MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodGET format:MTPocketFormatJSON body:nil];

	if (response.success) {
        [self populateFromDictionary:response.body];
	}

	return response;
}

- (MTPocketResponse *)save
{
    if (_identifier) return [self update];

	NSMutableArray *params = [NSMutableArray array];
//	[params appendFormat:@"folderId=%@", _person.identifier];
	[params addObject:[NSString stringWithFormat:@"filename=%@", (_originalFilename ? _originalFilename : [[NSUUID UUID] UUIDString])]];
    if (_category) 	[params addObject:[NSString stringWithFormat:@"artifactCategory=%@", _category]];

	NSURL *url = [self.connectionURL urlWithModule:@"artifactmanager"
										   version:0
										  resource:@"artifacts/files"
									   identifiers:nil
											params:0
											  misc:[params componentsJoinedByString:@"&"]];

	MTPocketRequest *request = [[MTPocketRequest alloc] initWithURL:url];
	request.method		= MTPocketMethodPOST;
	request.format		= MTPocketFormatJSON;
	request.headers		= @{ @"Content-Type" : _MIMEType };
	request.body		= _data;
	MTPocketResponse *response = [request fetch];

	if (response.success) {
        [self populateFromDictionary:response.body[@"artifact"]];

        for (FSArtifactTag *tag in _tags) {
            if (!tag.identifier)
                [tag save];
        }
	}

	return response;
}

- (MTPocketResponse *)destroy
{
    if (!_identifier) raiseException(@"Nil identifier", @"You must set the identifier before you can call fetch.");

	NSURL *url = [self.connectionURL urlWithModule:@"artifactmanager"
										   version:0
										  resource:[NSString stringWithFormat:@"artifacts/%@", _identifier]
									   identifiers:nil
											params:0
											  misc:nil];

	MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodDELETE format:MTPocketFormatJSON body:nil];

	if (response.success) {
        [self populateFromDictionary:@{}];
	}

	return response;
}




#pragma mark - Tagging

- (NSArray *)tags
{
    return [_tags filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return !((FSArtifactTag *)evaluatedObject).deleted;
    }]];
}

- (void)addTag:(FSArtifactTag *)tag
{
    tag.artifact = self;
    [(NSMutableArray *)_tags addObject:tag];
}

- (void)removeTag:(FSArtifactTag *)tag
{
    tag.deleted = YES;
}





#pragma mark - Protected

- (MTPocketResponse *)fetchAsPortraitForPerson:(FSPerson *)person
{
	NSURL *url = [self.connectionURL urlWithModule:@"artifactmanager"
										   version:0
										  resource:[NSString stringWithFormat:@"artifacts/%@", _identifier]
									   identifiers:nil
											params:0
											  misc:nil];

	MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodDELETE format:MTPocketFormatJSON body:nil];

	if (response.success) {
        [self populateFromDictionary:@{}];
	}

	return response;
}





#pragma mark - Private

- (FSURL *)connectionURL
{
	if (!_connectionURL) _connectionURL = [[FSURL alloc] initWithSessionID:_sessionID];
	return _connectionURL;
}

- (MTPocketResponse *)update
{
	NSURL *url = [self.connectionURL urlWithModule:@"artifactmanager"
										   version:0
										  resource:[NSString stringWithFormat:@"artifacts/%@", _identifier]
									   identifiers:nil
											params:0
											  misc:nil];

	NSDictionary *body = @{ @"title" : _title, @"description" : _description };
	MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodPOST format:MTPocketFormatJSON body:body];

    if (response.success) {
        [self populateFromDictionary:response.body];

        for (FSArtifactTag *tag in _tags) {
            if (!tag.identifier)
                [tag save];
            else if (tag.deleted) {
                if ([tag destroy].success) {
                    for (FSArtifactTag *t in _tags) {
                        if (t == tag || [t.identifier isEqualToString:tag.identifier]) {
                            tag.artifact = nil;
                            [(NSMutableArray *)_tags removeObject:tag];
                        }
                    }
                }
            }
        }
	}

	return response;
}

- (void)populateFromDictionary:(NSDictionary *)dictionary
{
    _apID					= dictionary[@"apid"];
    _category				= dictionary[@"category"];
    _description			= dictionary[@"description"];
    _folderID				= dictionary[@"folderId"];
    _size.height			= [dictionary[@"height"] floatValue];
    _identifier				= [dictionary[@"id"] stringValue];
    _MIMEType				= dictionary[@"mimeType"];
    _originalFilename		= dictionary[@"originalFilename"];
    _screeningStatus        = dictionary[@"screeningState"];
    _status					= dictionary[@"status"];
    if (dictionary[FSArtifactThumbnailStyleNormalKey]) {
        _thumbnails         = @{
                                    FSArtifactThumbnailStyleNormalKey   : dictionary[FSArtifactThumbnailStyleNormalKey],
                                    FSArtifactThumbnailStyleIconKey     : dictionary[FSArtifactThumbnailStyleIconKey],
                                    FSArtifactThumbnailStyleSquareKey   : dictionary[FSArtifactThumbnailStyleSquareKey]
                                };
    }
    _title					= dictionary[@"title"];
    _uploaderID				= dictionary[@"uploaderId"];
    _url					= dictionary[@"url"];
    _size.width				= [dictionary[@"width"] floatValue];

    // add tags
    if (NILL(dictionary[@"photoTags"]) && ((NSArray *)dictionary[@"photoTags"]).count > 0) {
        for (NSDictionary *tagDict in dictionary[@"photoTags"]) {
            FSArtifactTag *tag = [[FSArtifactTag alloc] init];
            [tag populateFromDictionary:tagDict];
            [self addTag:tag];
        }
    }
}

@end



















@implementation FSArtifactTag

- (id)initWithPerson:(FSPerson *)person title:(NSString *)title rect:(CGRect)rect
{
    self = [super init];
    if (self) {
        _person     = person;
        _title      = title;
		_rect       = rect;
        _deleted    = NO;
    }
    return self;
}

+ (FSArtifactTag *)tagWithPerson:(FSPerson *)person title:(NSString *)title rect:(CGRect)rect
{
    if (!person) raiseParamException(@"person");
    if (!title) raiseParamException(@"title");
	return [[FSArtifactTag alloc] initWithPerson:person title:title rect:rect];
}

- (MTPocketResponse *)save
{
    if (!_artifact) raiseException(@"No artifact", @"This tag must be added to an artifact before it can be saved");
    if (!_person) raiseException(@"No Person", @"You cannot save a tag until you've set the 'person' property");

    NSMutableArray *params = [NSMutableArray array];
    [params addObject:[NSString stringWithFormat:@"treePersonId=%@", _person.identifier]];

    NSURL *url = [_artifact.connectionURL urlWithModule:@"artifactmanager"
										   version:0
										  resource:[NSString stringWithFormat:@"artifacts/%@/tags", _artifact.identifier]
									   identifiers:nil
											params:0
											  misc:[params componentsJoinedByString:@"&"]];

    MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodPOST format:MTPocketFormatJSON body:[self dictionaryValue]];

    if (response.success) {
        [self populateFromDictionary:response.body];
        [self linkTaggedPersonToTreePerson];
    }

    return response;
}

- (FSArtifact *)artficactFromSavingTagAsPortraitWithResponse:(MTPocketResponse **)response
{
    if (!_artifact) raiseException(@"No artifact", @"This tag must be added to an artifact before it can be saved");
    if (!_person) raiseException(@"No Person", @"You cannot save a tag until you've set the 'person' property");

    NSURL *url = [_artifact.connectionURL urlWithModule:@"artifactmanager"
                                                version:0
                                               resource:[NSString stringWithFormat:@"artifacts/%@/tags/%@/portrait", _artifact.identifier, _identifier]
                                            identifiers:nil
                                                 params:0
                                                   misc:nil];

    MTPocketResponse *resp = *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodPOST format:MTPocketFormatJSON body:nil];
    
    if (resp.success) {
        FSArtifact *createdArtifact = [FSArtifact artifactWithIdentifier:nil sessionID:_artifact.sessionID];
        [createdArtifact populateFromDictionary:resp.body[@"artifact"]];
        return createdArtifact;
    }
    
    return nil;
}

- (MTPocketResponse *)destroy
{
    if (!_artifact) raiseException(@"No artifact", @"This tag must be added to an artifact before it can be deleted from the server.");
    if (!_identifier) raiseException(@"No identifier", @"You cannot delete a tag with no identifier");

    NSURL *url = [_artifact.connectionURL urlWithModule:@"artifactmanager"
                                                version:0
                                               resource:[NSString stringWithFormat:@"artifacts/%@/tags/%@", _artifact.identifier, _identifier]
                                            identifiers:nil
                                                 params:0
                                                   misc:nil];

    MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodDELETE format:MTPocketFormatJSON body:nil];
    
    if (response.success) {
        [self populateFromDictionary:@{}];
    }
    
    return response;
}





#pragma mark - Protected

- (MTPocketResponse *)saveAsPortrait
{
    if (!_artifact) raiseException(@"No artifact", @"This tag must be added to an artifact before it can be saved");
    if (!_person) raiseException(@"No Person", @"You cannot save a tag until you've set the 'person' property");

    NSMutableArray *params = [NSMutableArray array];
    [params addObject:[NSString stringWithFormat:@"treePersonId=%@", _person.identifier]];

    NSURL *url = [_artifact.connectionURL urlWithModule:@"artifactmanager"
                                                version:0
                                               resource:[NSString stringWithFormat:@"artifacts/%@/tags", _artifact.identifier]
                                            identifiers:nil
                                                 params:0
                                                   misc:[params componentsJoinedByString:@"&"]];

    MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodPOST format:MTPocketFormatJSON body:[self dictionaryValue]];
    
    if (response.success) {
        [self populateFromDictionary:response.body];
        [self linkTaggedPersonToTreePerson];
    }
    
    return response;
}



#pragma mark - Private

- (void)populateFromDictionary:(NSDictionary *)dictionary
{
    _identifier         = [dictionary[@"id"] stringValue];
    _taggedPersonID     = [dictionary[@"taggedPersonId"] stringValue];
    _rect.size.height   = [dictionary[@"height"] floatValue];
    _rect.size.width    = [dictionary[@"width"] floatValue];
    _rect.origin.x      = [dictionary[@"x"] floatValue];
    _rect.origin.y      = [dictionary[@"y"] floatValue];
    _title              = dictionary[@"title"];
}

- (NSDictionary *)dictionaryValue
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	dict[@"artifactId"]	= _artifact.identifier;
	dict[@"title"]      = _title;
	dict[@"x"]          = @(_rect.origin.x);
	dict[@"y"]          = @(_rect.origin.y);
	dict[@"width"]      = @(_rect.size.width);
	dict[@"height"]     = @(_rect.size.height);
	return dict;
}

- (MTPocketResponse *)linkTaggedPersonToTreePerson
{
    NSMutableArray *params = [NSMutableArray array];
    [params addObject:[NSString stringWithFormat:@"treePersonId=%@", _person.identifier]];

    NSURL *url = [_artifact.connectionURL urlWithModule:@"artifactmanager"
                                                version:0
                                               resource:[NSString stringWithFormat:@"persons/%@/treePerson/%@", _taggedPersonID, _person.identifier]
                                            identifiers:nil
                                                 params:0
                                                   misc:[params componentsJoinedByString:@"&"]];

    MTPocketResponse *response = [MTPocketRequest objectAtURL:url method:MTPocketMethodPUT format:MTPocketFormatJSON body:nil];
    
    return response;
}


@end











NSString *const FSArtifactThumbnailStyleNormalKey   = @"thumbUrl";
NSString *const FSArtifactThumbnailStyleIconKey     = @"thumbIconUrl";
NSString *const FSArtifactThumbnailStyleSquareKey   = @"thumbSquareUrl";
