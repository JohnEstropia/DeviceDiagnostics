//
//  ViewController.m
//  DeviceDiagnostics
//
//  Created by John Estropia on 2015/05/18.
//  Copyright (c) 2015年 John Rommel Estropia. All rights reserved.
//

#import "ViewController.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreLocation/CoreLocation.h>
#import "JEToolkit.h"


@interface ViewController () <CLLocationManagerDelegate>

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicatorView;
@property (nonatomic, weak) IBOutlet UILabel *label;
@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, weak) IBOutlet UIButton *button;
@property (nonatomic, strong) dispatch_group_t dispatchGroup;
@property (nonatomic, strong) NSMutableDictionary *diagnostics;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *geocoder;

@end

@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    UIColor *backgroundColor = [UIColor colorWithInt:0x34495e alpha:1.0];
    UIColor *foregroundColor = [UIColor colorWithInt:0xecf0f1 alpha:1.0];
    
    self.view.backgroundColor = backgroundColor;
    self.label.backgroundColor = backgroundColor;
    self.textView.backgroundColor = backgroundColor;
    self.indicatorView.backgroundColor = backgroundColor;
    
    self.indicatorView.color = foregroundColor;
    self.label.textColor = foregroundColor;
    self.textView.textColor = foregroundColor;
    
    UIColor *buttonBackgroundColor = [UIColor colorWithInt:0xf1c40f alpha:1.0];
    UIColor *buttonForegroundColor = [UIColor colorWithInt:0x2c3e50 alpha:1.0];
    
    [self.button setBackgroundImage:[UIImage imageFromColor:buttonBackgroundColor size:CGSizeMake(1.0, 1.0)] forState:UIControlStateNormal];
    [self.button setTitleColor:buttonForegroundColor forState:UIControlStateNormal];
    
    self.diagnostics = [JEOrderedDictionary new];
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    self.dispatchGroup = dispatchGroup;
    
    [self loadDeviceInfo];
    [self loadLocationInfo];
    
    JEScopeWeak(self);
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        
        JEScopeStrong(self);
        self.textView.text = [self.diagnostics loggingDescriptionIncludeClass:NO includeAddress:NO];
        self.textView.hidden = NO;
        self.button.hidden = NO;
        [self.view.layer addAnimation:[CATransition new] forKey:nil];
    });
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    
    return UIStatusBarStyleLightContent;
}


#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    
    manager.delegate = nil;
    [manager stopUpdatingLocation];
    
    CLLocation *location = locations.firstObject;
    NSDictionary *locationInfo = location ? @{ @"coordinate": @{ @"latitude": @(location.coordinate.latitude),
                                                                    @"longitude": @(location.coordinate.longitude) },
                                                  
                                                  @"altitude": @(location.altitude),
                                                  @"horizontalAccuracy": @(location.horizontalAccuracy),
                                                  @"verticalAccuracy": @(location.verticalAccuracy),
                                                  @"course": @(location.course),
                                                  @"speed": @(location.speed),
                                                  @"timestamp": location.timestamp ?: [NSNull null] } : nil;
    self.diagnostics[@"[CLLocationManager new].location"] = locationInfo ?: [NSNull null];
    
    if (location) {
        
        [self loadPlacemarkInfoWithLocation:location];
    }
    
    dispatch_group_leave(self.dispatchGroup);
    self.locationManager = nil;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    
    manager.delegate = nil;
    [manager stopUpdatingLocation];
    
    dispatch_group_leave(self.dispatchGroup);
    self.locationManager = nil;
}


#pragma mark - Private

- (IBAction)buttonTouchUpInside:(UIButton *)sender {
    
    NSString *diagnostics = self.textView.text;
    if ([NSString isNilOrEmptyString:diagnostics]) {
        
        return;
    }
    
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[diagnostics] applicationActivities:nil];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)loadDeviceInfo {
    
    dispatch_group_async(self.dispatchGroup, dispatch_get_main_queue(), ^{
        
        NSMutableDictionary *diagnostics = self.diagnostics;
        
        UIDevice *device = [UIDevice currentDevice];
        diagnostics[@"UIDevice"] = @{ @"systemVersion": device.systemVersion ?: [NSNull null],
                                      @"platform": device.platform ?: [NSNull null],
                                      @"hardwareName": device.hardwareName ?: [NSNull null],
                                      @"name": device.name ?: [NSNull null],
                                      @"model": device.model ?: [NSNull null],
                                      @"localizedModel": device.localizedModel ?: [NSNull null],
                                      @"systemName": device.systemName ?: [NSNull null] };
        
        NSTimeZone *timeZone = [NSTimeZone systemTimeZone];
        diagnostics[@"NSTimeZone"] = @{ @"name": timeZone.name ?: [NSNull null],
                                        @"secondsFromGMT": @(timeZone.secondsFromGMT),
                                        @"abbreviation": timeZone.abbreviation ?: [NSNull null],
                                        @"daylightSavingTime": @(timeZone.daylightSavingTime),
                                        @"daylightSavingTimeOffset": @(timeZone.daylightSavingTimeOffset) };
        
        CTTelephonyNetworkInfo *networkInfo = [CTTelephonyNetworkInfo new];
        CTCarrier *carrier = networkInfo.subscriberCellularProvider;
        NSDictionary *cellularProviderInfo = carrier ? @{ @"carrierName": carrier.carrierName ?: [NSNull null],
                                                          @"mobileCountryCode": carrier.mobileCountryCode ?: [NSNull null],
                                                          @"mobileNetworkCode": carrier.mobileNetworkCode ?: [NSNull null],
                                                          @"isoCountryCode": carrier.isoCountryCode ?: [NSNull null],
                                                          @"allowsVOIP": @(carrier.allowsVOIP) } : nil;
        
        diagnostics[@"CTTelephonyNetworkInfo"] = @{ @"currentRadioAccessTechnology": networkInfo.currentRadioAccessTechnology ?: [NSNull null],
                                                    @"subscriberCellularProvider": cellularProviderInfo ?: [NSNull null] };
        
        NSLocale *locale = [NSLocale currentLocale];
        NSCalendar *localeCalendar = [locale objectForKey:NSLocaleCalendar];
        
        NSTimeZone *localeCalendarTimeZone = localeCalendar.timeZone;
        NSDictionary *localeCalendarTimeZoneInfo = localeCalendarTimeZone ? @{ @"name": localeCalendarTimeZone.name ?: [NSNull null],
                                                                               @"secondsFromGMT": @(localeCalendarTimeZone.secondsFromGMT),
                                                                               @"abbreviation": localeCalendarTimeZone.abbreviation ?: [NSNull null],
                                                                               @"daylightSavingTime": @(localeCalendarTimeZone.daylightSavingTime),
                                                                               @"daylightSavingTimeOffset": @(localeCalendarTimeZone.daylightSavingTimeOffset) } : nil;
        
        NSDictionary *localeCalendarInfo = localeCalendar ? @{ @"calendarIdentifier": localeCalendar.calendarIdentifier ?: [NSNull null],
                                                               @"timeZone": localeCalendarTimeZoneInfo ?: [NSNull null],
                                                               @"firstWeekday": @(localeCalendar.firstWeekday),
                                                               @"minimumDaysInFirstWeek": @(localeCalendar.minimumDaysInFirstWeek),
                                                               @"eraSymbols": localeCalendar.eraSymbols ?: [NSNull null],
                                                               @"longEraSymbols": localeCalendar.longEraSymbols ?: [NSNull null],
                                                               @"monthSymbols": localeCalendar.monthSymbols ?: [NSNull null],
                                                               @"shortMonthSymbols": localeCalendar.shortMonthSymbols ?: [NSNull null],
                                                               @"veryShortMonthSymbols": localeCalendar.veryShortMonthSymbols ?: [NSNull null],
                                                               @"standaloneMonthSymbols": localeCalendar.standaloneMonthSymbols ?: [NSNull null],
                                                               @"shortStandaloneMonthSymbols": localeCalendar.shortStandaloneMonthSymbols ?: [NSNull null],
                                                               @"veryShortStandaloneMonthSymbols": localeCalendar.veryShortStandaloneMonthSymbols ?: [NSNull null],
                                                               @"weekdaySymbols": localeCalendar.weekdaySymbols ?: [NSNull null],
                                                               @"shortWeekdaySymbols": localeCalendar.shortWeekdaySymbols ?: [NSNull null],
                                                               @"veryShortWeekdaySymbols": localeCalendar.veryShortWeekdaySymbols ?: [NSNull null],
                                                               @"standaloneWeekdaySymbols": localeCalendar.standaloneWeekdaySymbols ?: [NSNull null],
                                                               @"shortStandaloneWeekdaySymbols": localeCalendar.shortStandaloneWeekdaySymbols ?: [NSNull null],
                                                               @"veryShortStandaloneWeekdaySymbols": localeCalendar.veryShortStandaloneWeekdaySymbols ?: [NSNull null],
                                                               @"quarterSymbols": localeCalendar.quarterSymbols ?: [NSNull null],
                                                               @"shortQuarterSymbols": localeCalendar.shortQuarterSymbols ?: [NSNull null],
                                                               @"standaloneQuarterSymbols": localeCalendar.standaloneQuarterSymbols ?: [NSNull null],
                                                               @"shortStandaloneQuarterSymbols": localeCalendar.shortStandaloneQuarterSymbols ?: [NSNull null],
                                                               @"AMSymbol": localeCalendar.AMSymbol ?: [NSNull null],
                                                               @"PMSymbol": localeCalendar.PMSymbol ?: [NSNull null] } : nil;
        
        
        diagnostics[@"NSLocale"] = @{ @"localeIdentifier": locale.localeIdentifier ?: [NSNull null],
                                      @"NSLocaleIdentifier": [locale objectForKey:NSLocaleIdentifier] ?: [NSNull null],
                                      @"NSLocaleLanguageCode": [locale objectForKey:NSLocaleLanguageCode] ?: [NSNull null],
                                      @"NSLocaleCountryCode": [locale objectForKey:NSLocaleCountryCode] ?: [NSNull null],
                                      @"NSLocaleScriptCode": [locale objectForKey:NSLocaleScriptCode] ?: [NSNull null],
                                      @"NSLocaleVariantCode": [locale objectForKey:NSLocaleVariantCode] ?: [NSNull null],
                                      @"NSLocaleExemplarCharacterSet": [locale objectForKey:NSLocaleExemplarCharacterSet] ?: [NSNull null],
                                      @"NSLocaleCalendar": localeCalendarInfo ?: [NSNull null],
                                      @"NSLocaleCollationIdentifier": [locale objectForKey:NSLocaleCollationIdentifier] ?: [NSNull null],
                                      @"NSLocaleUsesMetricSystem": [locale objectForKey:NSLocaleUsesMetricSystem] ?: [NSNull null],
                                      @"NSLocaleMeasurementSystem": [locale objectForKey:NSLocaleMeasurementSystem] ?: [NSNull null],
                                      @"NSLocaleDecimalSeparator": [locale objectForKey:NSLocaleDecimalSeparator] ?: [NSNull null],
                                      @"NSLocaleGroupingSeparator": [locale objectForKey:NSLocaleGroupingSeparator] ?: [NSNull null],
                                      @"NSLocaleCurrencySymbol": [locale objectForKey:NSLocaleCurrencySymbol] ?: [NSNull null],
                                      @"NSLocaleCurrencyCode": [locale objectForKey:NSLocaleCurrencyCode] ?: [NSNull null],
                                      @"NSLocaleCollatorIdentifier": [locale objectForKey:NSLocaleCollatorIdentifier] ?: [NSNull null],
                                      @"NSLocaleQuotationBeginDelimiterKey": [locale objectForKey:NSLocaleQuotationBeginDelimiterKey] ?: [NSNull null],
                                      @"NSLocaleQuotationEndDelimiterKey": [locale objectForKey:NSLocaleQuotationEndDelimiterKey] ?: [NSNull null],
                                      @"NSLocaleAlternateQuotationBeginDelimiterKey": [locale objectForKey:NSLocaleAlternateQuotationBeginDelimiterKey] ?: [NSNull null],
                                      @"NSLocaleAlternateQuotationEndDelimiterKey": [locale objectForKey:NSLocaleAlternateQuotationEndDelimiterKey] ?: [NSNull null] };
    });
}

- (void)loadLocationInfo {
    
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted
        || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        
        return;
    }
    
    CLLocationManager *locationManager = [CLLocationManager new];
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    [locationManager requestWhenInUseAuthorization];
    
    self.locationManager = locationManager;
    locationManager.delegate = self;
    
    dispatch_group_enter(self.dispatchGroup);
    [locationManager startUpdatingLocation];
}

- (void)loadPlacemarkInfoWithLocation:(CLLocation *)location {
    
    CLGeocoder *geocoder = [CLGeocoder new];
    self.geocoder = geocoder;
    
    dispatch_group_enter(self.dispatchGroup);
    
    JEScopeWeak(self);
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        
        JEScopeStrong(self);
        CLPlacemark *placemark = placemarks.firstObject;
        if (placemark) {
            
            self.diagnostics[@"CLPlacemark"] = @{ @"addressDictionary": placemark.addressDictionary ?: [NSNull null],
                                                  @"name": placemark.name ?: [NSNull null],
                                                  @"thoroughfare": placemark.thoroughfare ?: [NSNull null],
                                                  @"subThoroughfare": placemark.subThoroughfare ?: [NSNull null],
                                                  @"locality": placemark.locality ?: [NSNull null],
                                                  @"subLocality": placemark.subLocality ?: [NSNull null],
                                                  @"administrativeArea": placemark.administrativeArea ?: [NSNull null],
                                                  @"subAdministrativeArea": placemark.subAdministrativeArea ?: [NSNull null],
                                                  @"postalCode": placemark.postalCode ?: [NSNull null],
                                                  @"ISOcountryCode": placemark.ISOcountryCode ?: [NSNull null],
                                                  @"country": placemark.country ?: [NSNull null],
                                                  @"inlandWater": placemark.inlandWater ?: [NSNull null],
                                                  @"ocean": placemark.ocean ?: [NSNull null],
                                                  @"areasOfInterest": placemark.areasOfInterest ?: [NSNull null] };
        }
        
        dispatch_group_leave(self.dispatchGroup);
        self.geocoder = nil;
    }];
}

@end
