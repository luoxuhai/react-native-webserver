#import <React/RCTBridgeModule.h>
#import "GCDWebServer.h"
#import "RCTEventEmitter.h"

@interface RCTHttpServer: RCTEventEmitter<RCTBridgeModule> {
    GCDWebServer* _webServer;
    NSMutableDictionary* _completionBlocks;
}
@end
