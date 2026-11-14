#import <Foundation/Foundation.h>

__attribute__((constructor))
static void tweak_loaded(void) {
    NSLog(@"[CameraDemo] Tweak loaded successfully");
}
