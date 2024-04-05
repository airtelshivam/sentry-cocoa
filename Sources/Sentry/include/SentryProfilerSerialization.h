#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import <Foundation/Foundation.h>
#import "SentryProfiler+Private.h" // for SentryProfilerTruncationReason

@class SentryDebugMeta;
@class SentryHub;
@class SentryEnvelopeItem;
@class SentryTransaction;
@class SentryId;
@class SentryProfilerState;
@class SentryDebugImageProvider;

#    if SENTRY_HAS_UIKIT
@class SentryScreenFrames;
#    endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

SentryEnvelopeItem *_Nullable profileEnvelopeItem(SentryTransaction *transaction, NSDate *startTimestamp, SentryId *traceId, SentryProfilerState *state, SentryProfilerTruncationReason truncationReason, SentryDebugImageProvider *debugImageProvider, SentryHub *hub, SentryScreenFrames *screenFrameData);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
