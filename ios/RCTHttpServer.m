#import "RCTHttpServer.h"
#import "React/RCTBridge.h"
#import "React/RCTLog.h"
#import "React/RCTEventDispatcher.h"

#import "GCDWebServerPrivate.h"
#import "GCDWebServerDataRequest.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerFileResponse.h"
#import "GCDWebServerMultiPartFormRequest.h"
#include <stdlib.h>

static NSString *HTTP_SERVER_RESPONSE_RECEIVED = @"httpServerResponseReceived";
static RCTBridge *bridge;

@implementation RCTHttpServer

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents
{
  return @[HTTP_SERVER_RESPONSE_RECEIVED];
}

- (NSDictionary *)constantsToExport
{
 return @{ @"HTTP_SERVER_RESPONSE_RECEIVED": HTTP_SERVER_RESPONSE_RECEIVED };
}

- (void)initResponseReceivedFor:(GCDWebServer *)server method:(NSString*)method {
    [server addDefaultHandlerForMethod:method
                          requestClass:[GCDWebServerMultiPartFormRequest class]
                     asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock) {
        
        long long milliseconds = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
        int random = arc4random_uniform(1000000);
        NSString *requestId = [NSString stringWithFormat:@"%lld-%d", milliseconds, random];

         @synchronized (self) {
             [self->_completionBlocks setObject:completionBlock forKey:requestId];
         }

        @try {
            if ([GCDWebServerTruncateHeaderValue(request.contentType) isEqualToString:@"application/json"]) {
                GCDWebServerDataRequest* dataRequest = (GCDWebServerDataRequest*) request;
                [self sendEventWithName:HTTP_SERVER_RESPONSE_RECEIVED
                                                             body:@{@"requestId": requestId,
                                                                    @"body": dataRequest.jsonObject,
                                                                    @"method": method,
                                                                    @"query": request.query,
                                                                    @"url": request.URL.relativeString,
                                                                    @"headers": request.headers}];
            // 上传文件
            } else if ([GCDWebServerTruncateHeaderValue(request.contentType) hasPrefix:@"multipart/form-data"]) {
                GCDWebServerMultiPartFormRequest* fileRequest = (GCDWebServerMultiPartFormRequest*) request;
                [self sendEventWithName:HTTP_SERVER_RESPONSE_RECEIVED
                                                             body:@{@"requestId": requestId,
                                                                    @"file": @{
                                                                        @"filename": fileRequest.files[0].fileName,
                                                                        @"mimeType": fileRequest.files[0].mimeType,
                                                                        @"path": fileRequest.files[0].temporaryPath
                                                                    },
                                                                    @"method": method,
                                                                    @"url": request.URL.relativeString,
                                                                    @"query": request.query,
                                                                    @"headers": request.headers}];
                
            } else {
                [self sendEventWithName:HTTP_SERVER_RESPONSE_RECEIVED
                                                             body:@{@"requestId": requestId,
                                                                    @"method": method,
                                                                    @"url": request.URL.relativeString,
                                                                    @"query": request.query,
                                                                    @"headers": request.headers}];
            }
        } @catch (NSException *exception) {
            [self sendEventWithName:HTTP_SERVER_RESPONSE_RECEIVED
                                                         body:@{@"requestId": requestId,
                                                                @"method": method,
                                                                @"url": request.URL.relativeString,
                                                                @"query": request.query,
                                                                @"headers": request.headers}];
        }
    }];
}

RCT_EXPORT_METHOD(start:(NSInteger) port
                  serviceName:(NSString *) serviceName
                  resolver:(RCTPromiseResolveBlock) resolve
                  rejecter:(RCTPromiseRejectBlock) reject)
{
    RCTLogInfo(@"Running HTTP bridge server: %ld", port);
    _completionBlocks = [[NSMutableDictionary alloc] init];

    dispatch_sync(dispatch_get_main_queue(), ^{
        @try {
            _webServer = [[GCDWebServer alloc] init];
            
            [self initResponseReceivedFor:_webServer method:@"POST"];
            [self initResponseReceivedFor:_webServer method:@"PUT"];
            [self initResponseReceivedFor:_webServer method:@"GET"];
            [self initResponseReceivedFor:_webServer method:@"DELETE"];
            [self initResponseReceivedFor:_webServer method:@"OPTIONS"];
            [self initResponseReceivedFor:_webServer method:@"HEAD"];
            [self initResponseReceivedFor:_webServer method:@"PATCH"];
            
            [_webServer startWithPort:port bonjourName:serviceName];
            resolve(@{@"serverName": _webServer.serverName,
                      @"serverURL": _webServer.serverURL.absoluteURL});
        } @catch (NSException *exception) {
            reject(exception.name, exception.description, nil);
        }

    });
}

RCT_EXPORT_METHOD(stop: (RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject)
{
    RCTLogInfo(@"Stopping HTTP bridge server");

    if (_webServer != nil) {
        [_webServer stop];
        [_webServer removeAllHandlers];
        _webServer = nil;
    }
    
    resolve(nil);
}

RCT_EXPORT_METHOD(respond: (NSString *) requestId
                  code: (NSInteger) code
                  type: (NSString *) type
                  body: (NSString *) body)
{
    NSData* data = [body dataUsingEncoding:NSUTF8StringEncoding];
    GCDWebServerDataResponse* response = [[GCDWebServerDataResponse alloc] initWithData:data contentType:type];
    response.statusCode = code;
    [response setValue:@"*" forAdditionalHeader:(@"Access-Control-Allow-Origin")];
    [response setValue:@"*" forAdditionalHeader:(@"Access-Control-Allow-Headers")];
    [response setValue:@"*" forAdditionalHeader:(@"Access-Control-Allow-`Methods`")];
    response.gzipContentEncodingEnabled = NO;

    GCDWebServerCompletionBlock completionBlock = nil;
    @synchronized (self) {
        completionBlock = [_completionBlocks objectForKey:requestId];
        [_completionBlocks removeObjectForKey:requestId];
    }

    completionBlock(response);
}

RCT_EXPORT_METHOD(responseFile: (NSString *) requestId
                  path: (NSString *) path)
{
    GCDWebServerFileResponse* response = [[GCDWebServerFileResponse alloc] initWithFile:path];
    response.gzipContentEncodingEnabled = NO;

    GCDWebServerCompletionBlock completionBlock = nil;
    @synchronized (self) {
        completionBlock = [_completionBlocks objectForKey:requestId];
        [_completionBlocks removeObjectForKey:requestId];
    }

    completionBlock(response);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isRunning)
{
    return _webServer.isRunning ? @"1" : @"0";
}

@end
