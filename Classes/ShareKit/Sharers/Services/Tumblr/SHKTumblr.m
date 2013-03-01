//
//  SHKTumblr.m
//  ShareKit
//
//  Created by Vilem Kurz on 24. 2. 2013

//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "SHKTumblr.h"
#import "SHKConfiguration.h"
#import "JSONKit.h"
#import "NSMutableDictionary+NSNullsToEmptyStrings.h"

NSString * const kSHKTumblrUserInfo = @"kSHKTumblrUserInfo";

@interface SHKTumblr ()

@property (nonatomic, retain) id getUserBlogsObserver;

@end

@implementation SHKTumblr

@synthesize getUserBlogsObserver;

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:getUserBlogsObserver];
    [getUserBlogsObserver release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle { return @"Tumblr"; }

+ (BOOL)canShareURL { return YES; }
+ (BOOL)canShareImage { return YES; }
+ (BOOL)canShareText { return YES; }
+ (BOOL)canGetUserInfo { return YES; }

#pragma mark -
#pragma mark Authentication

- (id)init
{
	if (self = [super init])
	{		
		self.consumerKey = SHKCONFIG(tumblrConsumerKey);;		
		self.secretKey = SHKCONFIG(tumblrSecret);
 		self.authorizeCallbackURL = [NSURL URLWithString:SHKCONFIG(tumblrCallbackUrl)];
		
	    self.requestURL = [NSURL URLWithString:@"http://www.tumblr.com/oauth/request_token"];
	    self.authorizeURL = [NSURL URLWithString:@"http://www.tumblr.com/oauth/authorize"];
	    self.accessURL = [NSURL URLWithString:@"http://www.tumblr.com/oauth/access_token"];
		
		self.signatureProvider = [[[OAHMAC_SHA1SignatureProvider alloc] init] autorelease];
	}	
	return self;
}

- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest
{
	[oRequest setOAuthParameterName:@"oauth_verifier" withValue:[authorizeResponseQueryVars objectForKey:@"oauth_verifier"]];
}

+ (void)logout {
	
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKTumblrUserInfo];
    [[NSUserDefaults standardUserDefaults] synchronize];
	[super logout];
}


#pragma mark -
#pragma mark Share Form

- (NSArray *)shareFormFieldsForType:(SHKShareType)type
{
    if (type == SHKShareTypeUserInfo) return nil;
    
    //if there is user info saved already in defaults, show the first blog as default option, otherwise user must choose one.
    NSArray *userBlogURLs = [self userBlogURLs];
    NSString *defaultBlogURL = nil;
    NSString *defaultPickedIndex = @"-1";
    NSMutableArray *defaultItemsList = [NSMutableArray arrayWithCapacity:0];
    if ([userBlogURLs count] > 0) {
        defaultBlogURL = userBlogURLs[0];
        defaultPickedIndex = @"0";
        [defaultItemsList addObject:defaultBlogURL];
    }
    
    SHKFormFieldSettings *blogField = [SHKFormFieldSettings label:SHKLocalizedString(@"Blog")
                                                              key:@"blog"
                                                             type:SHKFormFieldTypeOptionPicker
                                                            start:defaultBlogURL
                                                 optionPickerInfo:[[@{@"title":SHKLocalizedString(@"Choose blog"),
                                                                    @"curIndexes":defaultPickedIndex,
                                                                    @"itemsList":defaultItemsList,
                                                                    @"static":[NSNumber numberWithBool:NO],
                                                                    @"allowMultiple":[NSNumber numberWithBool:NO],
                                                                    @"SHKFormOptionControllerOptionProvider":self} mutableCopy] autorelease]
                                         optionDetailLabelDefault:SHKLocalizedString(@"Select blog")];
    
    SHKFormFieldSettings *tagsField = [SHKFormFieldSettings label:SHKLocalizedString(@"Tag, tag")
                                                              key:@"tags"
                                                             type:SHKFormFieldTypeText
                                                            start:[self.item.tags componentsJoinedByString:@", "]];
    
    SHKFormFieldSettings *publishField = [SHKFormFieldSettings label:SHKLocalizedString(@"Publish")
                                                                 key:@"publish"
                                                                type:SHKFormFieldTypeOptionPicker
                                                               start:SHKLocalizedString(@"Publish now")
                                                    optionPickerInfo:[[@{@"title":SHKLocalizedString(@"Publish type"),
                                                                       @"curIndexes":@"0",
                                                                       @"itemsList":@[SHKLocalizedString(@"Publish now"), SHKLocalizedString(@"Draft"), SHKLocalizedString(@"Add to queue"), SHKLocalizedString(@"Private")],
                                                                       @"itemsValues":@[@"published", @"draft", @"queue", @"private"],
                                                                       @"static":[NSNumber numberWithBool:YES],
                                                                       @"allowMultiple":[NSNumber numberWithBool:NO]} mutableCopy] autorelease]
                                            optionDetailLabelDefault:nil];

    NSMutableArray *result = nil;
    switch (type) {
        case SHKShareTypeText:
        {
            SHKFormFieldSettings *bodyField = [SHKFormFieldSettings label:SHKLocalizedString(@"Body")
                                                                      key:@"text"
                                                                     type:SHKFormFieldTypeText
                                                                    start:self.item.text];
            result = [NSMutableArray arrayWithObjects:blogField, [self titleFieldWithLabel:SHKLocalizedString(@"Title")], bodyField, tagsField, publishField, nil];
            break;
        }
        case SHKShareTypeURL:
        {
            SHKFormFieldSettings *descriptionField = [SHKFormFieldSettings label:SHKLocalizedString(@"Description")
                                                                             key:@"text"
                                                                            type:SHKFormFieldTypeText
                                                                           start:self.item.text];
            result = [NSMutableArray arrayWithObjects:blogField, [self titleFieldWithLabel:SHKLocalizedString(@"Title")], descriptionField, tagsField, publishField, nil];
            break;
        }
        case SHKShareTypeImage:
        {
            result = [NSMutableArray arrayWithObjects:blogField, [self titleFieldWithLabel:SHKLocalizedString(@"Caption")], tagsField, publishField, nil];
        }
        default:
            break;
    }
    return result;
}

- (SHKFormFieldSettings *)titleFieldWithLabel:(NSString *)label {
    
    return [SHKFormFieldSettings label:label key:@"title" type:SHKFormFieldTypeText start:self.item.title];
}


// If you have a share form the user will have the option to skip it in the future.
// If your form has required information and should never be skipped, uncomment this section.

/*
+ (BOOL)canAutoShare
{
	return NO;
}
 */

// Optionally validate the user input on the share form. You should override (uncomment) this only if you need to validate any data before sending.
/*
 - (void)shareFormValidate:(SHKCustomFormController *)form
 {
 You can get a dictionary of the field values from [form formValues]
 
 You should perform one of the following actions:
 
 1.	Save the form - If everything is correct call
 
 [form saveForm]
 
 2.	Display an error - If the user input was incorrect, display an error to the user and tell them what to do to fix it
 }
 */


#pragma mark -
#pragma mark Implementation


- (BOOL)validateItem
{
    if (self.item.shareType == SHKShareTypeUserInfo) return [super validateItem];
	
    NSString *blog = [self.item customValueForKey:@"blog"];
    BOOL isBlogFilled = ![blog isEqualToString:@""] && ![blog isEqualToString:@"-1"];
    BOOL itemValid = isBlogFilled && [super validateItem];
    
	return itemValid;
}

// Send the share item to the server
- (BOOL)send
{	
	if (![self validateItem])
		return NO;
	
    OAMutableURLRequest *oRequest = nil;
    NSMutableArray *params = [@[] mutableCopy];
    
    switch (item.shareType) {
            
        case SHKShareTypeUserInfo:
        {
            [self setQuiet:YES];
            oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://api.tumblr.com/v2/user/info"]
                                                                          consumer:consumer // this is a consumer object already made available to us
                                                                             token:accessToken // this is our accessToken already made available to us
                                                                             realm:nil
                                                                 signatureProvider:signatureProvider];
            [oRequest setHTTPMethod:@"GET"];
            break;
        }
        case SHKShareTypeText:
        {
            oRequest = [self setupPostRequest];
            
            OARequestParameter *typeParam = [[OARequestParameter alloc] initWithName:@"type" value:@"text"];
            OARequestParameter *titleParam = [[OARequestParameter alloc] initWithName:@"title" value:item.title];
            OARequestParameter *bodyParam = [[OARequestParameter alloc] initWithName:@"body" value:item.text];
            [params addObjectsFromArray:@[typeParam, titleParam, bodyParam]];
            [typeParam release];
            [titleParam release];
            [bodyParam release];
            break;
        }
        case SHKShareTypeURL:
        {
            oRequest = [self setupPostRequest];
            
            OARequestParameter *typeParam = [[OARequestParameter alloc] initWithName:@"type" value:@"link"];
            OARequestParameter *titleParam = [[OARequestParameter alloc] initWithName:@"title" value:item.title];
            OARequestParameter *urlParam = [[OARequestParameter alloc] initWithName:@"url" value:[item.URL absoluteString]];
            [params addObjectsFromArray:@[typeParam, titleParam, urlParam]];
            [typeParam release];
            [titleParam release];
            [urlParam release];
            
            if (item.text) {
                OARequestParameter *descriptionParam = [[OARequestParameter alloc] initWithName:@"description" value:item.text];
                [params addObject:descriptionParam];
                [descriptionParam release];
            }
            break;
        }
        default:
            break;
    }
    
    NSCharacterSet *allowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@","] invertedSet];
	NSString *tags = [self tagStringJoinedBy:@"," allowedCharacters:allowedCharacters tagPrefix:nil tagSuffix:nil];
    OARequestParameter *tagsParam = [[OARequestParameter alloc] initWithName:@"tags" value:tags];
    OARequestParameter *publishParam = [[OARequestParameter alloc] initWithName:@"state" value:[self.item customValueForKey:@"publish"]];
    [params addObjectsFromArray:@[tagsParam, publishParam]];
    [tagsParam release];
    [publishParam release];
    [oRequest setParameters:params];
    
    // Start the request
    OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
                                                                                          delegate:self
                                                                                 didFinishSelector:@selector(sendTicket:didFinishWithData:)
                                                                                   didFailSelector:@selector(sendTicket:didFailWithError:)];
    
    [fetcher start];
    [oRequest release];
    
    // Notify delegate
    [self sendDidStart];
    
    return YES;
}

- (OAMutableURLRequest *)setupPostRequest {
    
    NSString *urlString = [[NSString alloc] initWithFormat:@"http://api.tumblr.com/v2/blog/%@/post", [self.item customValueForKey:@"blog"]];
    OAMutableURLRequest *result = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]
                                               consumer:consumer // this is a consumer object already made available to us
                                                  token:accessToken // this is our accessToken already made available to us
                                                  realm:nil
                                      signatureProvider:signatureProvider];
    [urlString release];
    [result setHTTPMethod:@"POST"];
    return result;
}

- (void)sendTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data
{	
	if (ticket.didSucceed) {
		
		switch (self.item.shareType) {
            case SHKShareTypeUserInfo:
            {
                NSError *error = nil;
                NSMutableDictionary *userInfo;
                Class serializator = NSClassFromString(@"NSJSONSerialization");
                if (serializator) {
                    userInfo = [serializator JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                } else {
                    userInfo = [[JSONDecoder decoder] mutableObjectWithData:data error:&error];
                }
                
                if (error) {
                    SHKLog(@"Error when parsing json user info request:%@", [error description]);
                }
                
                [userInfo convertNSNullsToEmptyStrings];
                [[NSUserDefaults standardUserDefaults] setObject:userInfo forKey:kSHKTumblrUserInfo];
            
                break;
            }
            default:
                break;
        }
        
		[self sendDidFinish];
		
	} else {
		
        if (ticket.response.statusCode == 401) {
            
            //user revoked acces, ask access again
            [self shouldReloginWithPendingAction:SHKPendingSend];
            
        } else {
            
            SHKLog(@"Tumblr send finished with error:%@", [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]);
            [self sendShowSimpleErrorAlert];
        }

	}
}
- (void)sendTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	SHKLog(@"Tumblr send failed with error:%@", [error description]);
    [self sendShowSimpleErrorAlert];
}

#pragma mark - SHKFormOptionControllerOptionProvider delegate methods

- (void)SHKFormOptionControllerEnumerateOptions:(SHKFormOptionController *)optionController {
    
    NSAssert(curOptionController == nil, @"there should never be more than one picker open.");
	curOptionController = optionController;
    
    SHKTumblr *infoSharer = [SHKTumblr getUserInfo];
    
    __block SHKTumblr *weakSelf = self;
    self.getUserBlogsObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SHKSendDidFinishNotification
                                                      object:infoSharer
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *notification) {
                                                      
                                                      NSArray *userBlogURLs = [self userBlogURLs];
                                                      [weakSelf blogsEnumerated:userBlogURLs];
                                                      
                                                      [[NSNotificationCenter defaultCenter] removeObserver:weakSelf.getUserBlogsObserver];
                                                      weakSelf.getUserBlogsObserver = nil;
                                                  }];
}

- (void)SHKFormOptionControllerCancelEnumerateOptions:(SHKFormOptionController *)optionController
{
	[[NSNotificationCenter defaultCenter] removeObserver:self.getUserBlogsObserver];
    self.getUserBlogsObserver = nil;
    NSAssert(curOptionController == optionController, @"there should never be more than one picker open.");
	curOptionController = nil;
}

#pragma mark - 

- (void)blogsEnumerated:(NSArray *)blogs{
    
	NSAssert(curOptionController != nil, @"Any pending requests should have been canceled in SHKFormOptionControllerCancelEnumerateOptions");
	[curOptionController optionsEnumerated:blogs];
	curOptionController = nil;
}

- (NSArray *)userBlogURLs {
    
    NSDictionary *userInfo = [[NSUserDefaults standardUserDefaults] objectForKey:kSHKTumblrUserInfo];
    NSArray *usersBlogs = [[[userInfo objectForKey:@"response"] objectForKey:@"user"] objectForKey:@"blogs"];
    NSMutableArray *result = [[@[] mutableCopy] autorelease];
    for (NSDictionary *blog in usersBlogs) {
        NSURL *blogURL = [NSURL URLWithString:[blog objectForKey:@"url"]];
        [result addObject:blogURL.host];
    }
    return result;
}

@end
