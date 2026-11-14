#import <dlfcn.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static AVAssetReader *reader;
static AVAssetReaderTrackOutput *vout;
static NSMutableSet *hooked;
static IMP origSet;

static void resetReader(void) {
  NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/meme.mp4"];
  AVAsset *a = [AVAsset assetWithURL:[NSURL fileURLWithPath:p]];
  AVAssetTrack *t = [a tracksWithMediaType:AVMediaTypeVideo].firstObject;
  reader = nil; vout = nil;
  if (!t) return;
  reader = [AVAssetReader assetReaderWithAsset:a error:nil];
  vout = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:t
    outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
  [reader addOutput:vout];
  [reader startReading];
}

static CMSampleBufferRef nextFrame(CMSampleBufferRef orig) {
  @synchronized (hooked) {
    if (!reader) resetReader();
    CMSampleBufferRef f = [vout copyNextSampleBuffer];
    if (!f) { resetReader(); f = [vout copyNextSampleBuffer]; }
    if (!f) return NULL;
    CMSampleTimingInfo ti;
    CMSampleBufferGetSampleTimingInfo(orig, 0, &ti);
    CMSampleBufferRef n = NULL;
    CMSampleBufferCreateCopyWithNewTiming(NULL, f, 1, &ti, &n);
    CFRelease(f);
    return n;
  }
}

static void hookDelegate(Class c) {
  SEL s = @selector(captureOutput:didOutputSampleBuffer:fromConnection:);
  @synchronized (hooked) { if ([hooked containsObject:c]) return; [hooked addObject:c]; }
  Method m = class_getInstanceMethod(c, s);
  if (!m) return;
  IMP orig = method_getImplementation(m);
  method_setImplementation(m, imp_implementationWithBlock(
    ^(id me, AVCaptureOutput *o, CMSampleBufferRef sb, AVCaptureConnection *cn) {
      CMSampleBufferRef r = nextFrame(sb);
      ((void(*)(id,SEL,id,CMSampleBufferRef,id))orig)(me, s, o, r ?: sb, cn);
      if (r) CFRelease(r);
    }));
}

static void newSet(id self, SEL _cmd, id delegate, dispatch_queue_t q) {
  if (delegate) hookDelegate([delegate class]);
  ((void(*)(id,SEL,id,dispatch_queue_t))origSet)(self, _cmd, delegate, q);
}

__attribute__((constructor)) static void init(void) {
  hooked = [NSMutableSet set];
  NSLog(@"[VCam] loaded, home=%@", NSHomeDirectory());
  Method m = class_getInstanceMethod([AVCaptureVideoDataOutput class],
    @selector(setSampleBufferDelegate:queue:));
  origSet = method_setImplementation(m, (IMP)newSet);
}
