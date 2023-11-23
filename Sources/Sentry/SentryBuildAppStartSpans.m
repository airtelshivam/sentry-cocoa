#import "SentryAppStartMeasurement.h"
#import "SentryBinaryImageCache.h"
#import "SentryDependencyContainer.h"
#import "SentryLog.h"
#import "SentrySpan.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanId.h"
#import "SentryTraceOrigins.h"
#import "SentryTracer.h"
#import <Foundation/Foundation.h>
#import <SentryBuildAppStartSpans.h>

#if SENTRY_HAS_UIKIT

id<SentrySpan>
sentryBuildAppStartSpan(
    SentryTracer *tracer, SentrySpanId *parentId, NSString *operation, NSString *description)
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:tracer.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                   spanDescription:description
                                            origin:SentryTraceOriginAutoAppStart
                                           sampled:tracer.sampled];

    return [[SentrySpan alloc] initWithTracer:tracer context:context];
}

NSArray<SentrySpan *> *
sentryBuildAppStartSpans(SentryTracer *tracer, SentryAppStartMeasurement *appStartMeasurement)
{

    if (appStartMeasurement == nil) {
        return @[];
    }

    NSString *operation;
    NSString *type;

    switch (appStartMeasurement.type) {
    case SentryAppStartTypeCold:
        operation = @"app.start.cold";
        type = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        operation = @"app.start.warm";
        type = @"Warm Start";
        break;
    default:
        return @[];
    }

    NSMutableArray<SentrySpan *> *appStartSpans = [NSMutableArray array];

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    SentrySpan *appStartSpan = sentryBuildAppStartSpan(tracer, tracer.spanId, operation, type);
    [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
    [appStartSpan setTimestamp:appStartEndTimestamp];

    [appStartSpans addObject:appStartSpan];

    if (!appStartMeasurement.isPreWarmed) {
        SentrySpan *premainSpan
            = sentryBuildAppStartSpan(tracer, appStartSpan.spanId, operation, @"Pre Runtime Init");
        [premainSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [premainSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [appStartSpans addObject:premainSpan];

        SentrySpan *runtimeInitSpan = sentryBuildAppStartSpan(
            tracer, appStartSpan.spanId, operation, @"Runtime Init to Pre Main Initializers");
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        [appStartSpans addObject:runtimeInitSpan];
    }

    SentrySpan *appInitSpan = sentryBuildAppStartSpan(
        tracer, appStartSpan.spanId, operation, @"UIKit and Application Init");
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [appStartSpans addObject:appInitSpan];

    SentrySpan *frameRenderSpan
        = sentryBuildAppStartSpan(tracer, appStartSpan.spanId, operation, @"Initial Frame Render");
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    [appStartSpans addObject:frameRenderSpan];

    NSArray<SentryBinaryImageInfo *> *images =
        [SentryDependencyContainer.sharedInstance.binaryImageCache imagesSortedByAddedDate];

    for (SentryBinaryImageInfo *imageInfo in images) {
        NSArray *systemLibraryPrefixes =
            @[ @"/System/Library/", @"/usr/lib/", @"/Library/Developer/" ];

        BOOL systemLib = NO;
        for (NSString *prefix in systemLibraryPrefixes) {
            if ([imageInfo.name hasPrefix:prefix]) {
                systemLib = YES;
                break;
            }
        }

        SentrySpan *imageSpan = nil;
        if (systemLib) {
            imageSpan = sentryBuildAppStartSpan(tracer, tracer.spanId, @"read.pages.system_binary",
                [imageInfo.name lastPathComponent]);
        } else {
            imageSpan = sentryBuildAppStartSpan(tracer, tracer.spanId, @"read.pages.app_binary",
                [imageInfo.name lastPathComponent]);
        }

        NSComparisonResult result = [imageInfo.startReadingPages compare:imageInfo.endReadingPages];
        if (result == NSOrderedAscending) {
            [imageSpan setStartTimestamp:imageInfo.startReadingPages];
            [imageSpan setTimestamp:imageInfo.endReadingPages];
            if (imageSpan) {
                [appStartSpans addObject:imageSpan];
            }
        }
    }

    return appStartSpans;
}

#endif // SENTRY_HAS_UIKIT
