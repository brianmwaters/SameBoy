#import "GBSettingsViewController.h"
#import "GBTemperatureSlider.h"
#import "GBViewBase.h"
#import <objc/runtime.h>

static NSString const *typeSubmenu = @"submenu";
static NSString const *typeOptionSubmenu = @"optionSubmenu";
static NSString const *typeRadio = @"radio";
static NSString const *typeCheck = @"check";
static NSString const *typeDisabled = @"disabled";
static NSString const *typeSeparator = @"separator";
static NSString const *typeSlider = @"slider";
static NSString const *typeLightTemp = @"typeLightTemp";

@implementation GBSettingsViewController
{
    NSArray<NSDictionary *> *_structure;
    UINavigationController *_detailsNavigation;
}

+ (const GB_palette_t *)paletteForTheme:(NSString *)theme
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([theme isEqualToString:@"Greyscale"]) {
        return &GB_PALETTE_GREY;
    }
    if ([theme isEqualToString:@"Lime (Game Boy)"]) {
        return &GB_PALETTE_DMG;
    }
    if ([theme isEqualToString:@"Olive (Pocket)"]) {
        return &GB_PALETTE_MGB;
    }
    if ([theme isEqualToString:@"Teal (Light)"]) {
        return &GB_PALETTE_GBL;
    }
    static GB_palette_t customPalette;
    NSArray *colors = [defaults dictionaryForKey:@"GBThemes"][theme][@"Colors"];
    if (colors.count != 5) return &GB_PALETTE_DMG;
    unsigned i = 0;
    for (NSNumber *color in colors) {
        uint32_t c = [color unsignedIntValue];
        customPalette.colors[i++] = (struct GB_color_s) {c, c >> 8, c >> 16};
    }
    return &customPalette;
}

+ (UIColor *) colorFromGBColor:(const struct GB_color_s *)color
{
    return [UIColor colorWithRed:color->r / 255.0
                           green:color->g / 255.0
                            blue:color->b / 255.0
                           alpha:1.0];
}

+ (UIImage *)previewImageForTheme:(NSString *)theme
{
    const GB_palette_t *palette = [self paletteForTheme:theme];
    UIGraphicsBeginImageContextWithOptions((CGSize){29, 29}, false, [UIScreen mainScreen].scale);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 29, 29) cornerRadius:7];
    [[self colorFromGBColor:&palette->colors[4]] set];
    [path fill];
    
    path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 4, 9, 9) cornerRadius:2];
    [[self colorFromGBColor:&palette->colors[0]] set];
    [path fill];
    
    path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(16, 4, 9, 9) cornerRadius:2];
    [[self colorFromGBColor:&palette->colors[1]] set];
    [path fill];
    
    path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 16, 9, 9) cornerRadius:2];
    [[self colorFromGBColor:&palette->colors[2]] set];
    [path fill];
    
    path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(16, 16, 9, 9) cornerRadius:2];
    [[self colorFromGBColor:&palette->colors[3]] set];
    [path fill];
    
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return ret;
}

+ (NSArray<NSDictionary *> *)paletteMenu
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *themes = [@[
        @"Greyscale",
        @"Lime (Game Boy)",
        @"Olive (Pocket)",
        @"Teal (Light)",
    ] arrayByAddingObjectsFromArray:[[defaults dictionaryForKey:@"GBThemes"] allKeys]];
    NSMutableArray<NSDictionary *> *themeItems = [NSMutableArray arrayWithCapacity:themes.count];
    for (NSString *theme in themes) {
        [themeItems addObject: @{@"type": typeRadio, @"pref": @"GBCurrentTheme",
                                 @"title": theme, @"value": theme,
                                 @"image": [self previewImageForTheme:theme]}];
    }
    return @[
        @{
            @"items": [themeItems subarrayWithRange:(NSRange){0, 4}]
        },
        @{
            @"items": [themeItems subarrayWithRange:(NSRange){4, themeItems.count - 4}]
        }
    ];
}

+ (NSArray<NSDictionary *> *)rootStructure
{
#define QUICK_SUBMENU(title, ...) @{@"type": typeOptionSubmenu, @"title": title, @"submenu": @[@{@"items": __VA_ARGS__}]}
    NSArray<NSDictionary *> *emulationMenu = @[
        @{
            @"header": @"Rewind Duration",
            @"items": @[
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"Disabled",   @"value": @0,},
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"10 Seconds", @"value": @10,},
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"30 Seconds", @"value": @30,},
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"1 Minute",   @"value": @60,},
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"2 Minutes",  @"value": @120,},
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"5 Minutes",  @"value": @300,},
                @{@"type": typeRadio, @"pref": @"GBRewindLength", @"title": @"10 Minutes", @"value": @600,},
            ]
        },
        @{
            @"header": @"Real Time Clock Emulation",
            @"items": @[
                @{@"type": typeRadio, @"pref": @"GBRTCMode", @"title": @"Accurate",   @"value": @(GB_RTC_MODE_ACCURATE),},
                @{@"type": typeRadio, @"pref": @"GBRTCMode", @"title": @"Sync to System Clock", @"value": @(GB_RTC_MODE_SYNC_TO_HOST),},
            ]
        },
        @{
            @"header": @"Turbo Speed",
            @"items": @[
                    @{@"type": typeRadio, @"pref": @"GBTurboSpeed", @"title": @"200%",     @"value": @2,},
                    @{@"type": typeRadio, @"pref": @"GBTurboSpeed", @"title": @"400%",     @"value": @4,},
                    @{@"type": typeRadio, @"pref": @"GBTurboSpeed", @"title": @"Uncapped", @"value": @1,},
            ],
            @"footer": ^NSString *(){
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBDynamicSpeed"]) {
                    return @"This setting will have no effect because horizontal swipes are configured to dynamically control speed in the “Controls” settings";
                }
                return @"";
            },
        },
        @{
            @"header": @"Rewind Speed",
            @"items": @[
                    @{@"type": typeRadio, @"pref": @"GBRewindSpeed", @"title": @"100%", @"value": @1,},
                    @{@"type": typeRadio, @"pref": @"GBRewindSpeed", @"title": @"200%", @"value": @2,},
                    @{@"type": typeRadio, @"pref": @"GBRewindSpeed", @"title": @"400%", @"value": @4,},
            ],
            @"footer": ^NSString *(){
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBDynamicSpeed"]) {
                    return @"This setting will have no effect because horizontal swipes are configured to dynamically control speed in the “Controls” settings";
                }
                return @"";
            }
        },
        @{
            @"header": @"Emulated Revisions",
            @"items": @[
                QUICK_SUBMENU(@"Game Boy", @[
                    @{@"type": typeDisabled, @"title": @"DMG-CPU 0"},
                    @{@"type": typeDisabled, @"title": @"DMG-CPU A"},
                    @{@"type": typeRadio, @"pref": @"GBDMGModel", @"title": @"DMG-CPU B", @"value": @(GB_MODEL_DMG_B),},
                    @{@"type": typeDisabled, @"title": @"DMG-CPU C"},
                ]),
                QUICK_SUBMENU(@"Super Game Boy", @[
                    @{@"type": typeRadio, @"pref": @"GBSGBModel", @"title": @"Super Game Boy (NTSC)", @"value": @(GB_MODEL_SGB_NTSC),},
                    @{@"type": typeRadio, @"pref": @"GBSGBModel", @"title": @"Super Game Boy (PAL)",  @"value": @(GB_MODEL_SGB_PAL),},
                    @{@"type": typeRadio, @"pref": @"GBSGBModel", @"title": @"Super Game Boy 2",      @"value": @(GB_MODEL_SGB2),},
                ]),
                QUICK_SUBMENU(@"Game Boy Color", @[
                    @{@"type": typeRadio, @"pref": @"GBCGBModel", @"title": @"CPU CGB 0 (Experimental)", @"value": @(GB_MODEL_CGB_0),},
                    @{@"type": typeRadio, @"pref": @"GBCGBModel", @"title": @"CPU CGB A (Experimental)", @"value": @(GB_MODEL_CGB_A),},
                    @{@"type": typeRadio, @"pref": @"GBCGBModel", @"title": @"CPU CGB B (Experimental)", @"value": @(GB_MODEL_CGB_B),},
                    @{@"type": typeRadio, @"pref": @"GBCGBModel", @"title": @"CPU CGB C (Experimental)", @"value": @(GB_MODEL_CGB_C),},
                    @{@"type": typeRadio, @"pref": @"GBCGBModel", @"title": @"CPU CGB D",                @"value": @(GB_MODEL_CGB_D),},
                    @{@"type": typeRadio, @"pref": @"GBCGBModel", @"title": @"CPU CGB E",                @"value": @(GB_MODEL_CGB_E),},
                ]),
                QUICK_SUBMENU(@"Game Boy Advance", @[
                    @{@"type": typeDisabled, @"title": @"CPU AGB 0 (Early GBA)",},
                    @{@"type": typeRadio, @"pref": @"GBAGBModel", @"title": @"CPU AGB A (GBA)",             @"value": @(GB_MODEL_AGB_A),},
                    @{@"type": typeRadio, @"pref": @"GBAGBModel", @"title": @"CPU AGB A (Game Boy Player)", @"value": @(GB_MODEL_GBP_A),},
                    @{@"type": typeDisabled, @"title": @"CPU AGB B (GBA SP)",},
                    @{@"type": typeDisabled, @"title": @"CPU AGB E (Late GBA SP)",},
                    @{@"type": typeDisabled, @"title": @"CPU AGB E (Late Game Boy Player)",},
                ]),
            ],
            @"footer": @"Changing the emulated revision on active ROMs will take effect after selecting Reset from the menu or changing the emulated model.",
        },
    ];
    
    NSArray<NSDictionary *> *videoMenu = @[
        @{
            @"items": @[
                @{
                    @"title": @"Graphics Filter",
                    @"type": typeOptionSubmenu,
                    @"submenu": @[
                        @{
                            @"header": @"Standard Filters",
                            @"items": @[
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Nearest Neighbor (Pixelated)", @"value": @"NearestNeighbor",},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Bilinear (Blurry)", @"value": @"Bilinear",},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Smooth Bilinear (Less blurry)", @"value": @"SmoothBilinear",},
                            ]
                        },
                        @{
                            @"header": @"Screen Filters",
                            @"items": @[
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Monochrome LCD Display", @"value": @"MonoLCD",},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"LCD Display", @"value": @"LCD",},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"CRT Display", @"value": @"CRT",},
                            ]
                        },
                        @{
                            @"header": @"Upscaling Filters",
                            @"items": @[
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Scale2x", @"value": @"Scale2x"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Scale4x", @"value": @"Scale4x"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Anti-aliased Scale2x", @"value": @"AAScale2x"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"Anti-aliased Scale4x", @"value": @"AAScale4x"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"HQ2x", @"value": @"HQ2x"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"OmniScale", @"value": @"OmniScale"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"OmniScale Legacy", @"value": @"OmniScaleLegacy"},
                                @{@"type": typeRadio, @"pref": @"GBFilter", @"title": @"AA OmniScale Legacy", @"value": @"AAOmniScaleLegacy"},
                            ]
                        },
                    ]
                },
            ]
        },
        @{
            @"header": @"Color Correction",
            @"items": @[
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Disabled",                     @"value": @(GB_COLOR_CORRECTION_DISABLED),},
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Correct Color Curves",         @"value": @(GB_COLOR_CORRECTION_CORRECT_CURVES),},
                @{@"type": typeSeparator},
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Modern – Balanced",            @"value": @(GB_COLOR_CORRECTION_MODERN_BALANCED),},
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Modern – Accurate",            @"value": @(GB_COLOR_CORRECTION_MODERN_ACCURATE),},
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Modern – Boost contrast",      @"value": @(GB_COLOR_CORRECTION_MODERN_BOOST_CONTRAST),},
                @{@"type": typeSeparator},
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Reduce Contrast",              @"value": @(GB_COLOR_CORRECTION_REDUCE_CONTRAST),},
                @{@"type": typeRadio, @"pref": @"GBColorCorrection", @"title": @"Harsh Reality (Low Contrast)", @"value": @(GB_COLOR_CORRECTION_LOW_CONTRAST),},
            ],
            @"footer": ^NSString *(){
                return (NSString * const[]){
                    [GB_COLOR_CORRECTION_DISABLED] = @"Colors are directly interpreted as sRGB, resulting in unbalanced colors and inaccurate hues.",
                    [GB_COLOR_CORRECTION_CORRECT_CURVES] = @"Colors have their brightness corrected, but hues remain unbalanced.",
                    [GB_COLOR_CORRECTION_MODERN_BALANCED] = @"Emulates a modern display. Blue contrast is moderately enhanced at the cost of slight hue inaccuracy.",
                    [GB_COLOR_CORRECTION_MODERN_BOOST_CONTRAST] = @"Like Modern – Balanced, but further boosts the contrast of greens and magentas that is lacking on the original hardware.",
                    [GB_COLOR_CORRECTION_REDUCE_CONTRAST] = @"Slightly reduce the contrast to better represent the tint and contrast of the original display.",
                    [GB_COLOR_CORRECTION_LOW_CONTRAST] = @"Harshly reduce the contrast to accurately represent the tint low constrast of the original display.",
                    [GB_COLOR_CORRECTION_MODERN_ACCURATE] = @"Emulates a modern display. Colors have their hues and brightness corrected.",
                }[MIN(GB_COLOR_CORRECTION_MODERN_ACCURATE, [[NSUserDefaults standardUserDefaults] integerForKey:@"GBColorCorrection"])];
            },
        },
        @{
            @"header": @"Ambient Light Temperature",
            @"items": @[
                @{@"type": typeLightTemp, @"pref": @"GBLightTemperature", @"min": @-1, @"max": @1}
            ],
        },
        @{
            @"header": @"Frame Blending",
            @"items": @[
                @{@"type": typeRadio, @"pref": @"GBFrameBlendingMode", @"title": @"Disabled", @"value": @(GB_FRAME_BLENDING_MODE_DISABLED),},
                @{@"type": typeRadio, @"pref": @"GBFrameBlendingMode", @"title": @"Simple",   @"value": @(GB_FRAME_BLENDING_MODE_SIMPLE),},
                @{@"type": typeRadio, @"pref": @"GBFrameBlendingMode", @"title": @"Accurate", @"value": @(GB_FRAME_BLENDING_MODE_ACCURATE),},
            ]
        },
        @{
            @"items": @[@{
                @"title": @"Monochrome Palette",
                @"type": typeOptionSubmenu,
                @"submenu": [self paletteMenu]
            }],
            @"footer": @"This palette will be used when emulating a monochrome model such as the original Game Boy."
        }
    ];
    
    NSArray<NSDictionary *> *audioMenu = @[
        @{
            @"header": @"High-pass Filter",
            @"items": @[
                @{@"type": typeRadio, @"pref": @"GBHighpassFilter", @"title": @"Disabled (Keep DC Offset)",   @"value": @(GB_HIGHPASS_OFF),},
                @{@"type": typeRadio, @"pref": @"GBHighpassFilter", @"title": @"Accurate (Emulate Hardware)", @"value": @(GB_HIGHPASS_ACCURATE),},
                @{@"type": typeRadio, @"pref": @"GBHighpassFilter", @"title": @"Preserve Waveform",           @"value": @(GB_HIGHPASS_REMOVE_DC_OFFSET),},
            ],
            @"footer": ^NSString *(){
                return (NSString * const[]){
                    [GB_HIGHPASS_OFF] = @"No high-pass filter will be applied. DC offset will be kept, pausing and resuming will trigger audio pops.",
                    [GB_HIGHPASS_ACCURATE] = @"An accurate high-pass filter will be applied, removing the DC offset while somewhat attenuating the bass.",
                    [GB_HIGHPASS_REMOVE_DC_OFFSET] = @"A high-pass filter will be applied to the DC offset itself, removing the DC offset while preserving the waveform.",
                }[MIN(GB_HIGHPASS_REMOVE_DC_OFFSET, [[NSUserDefaults standardUserDefaults] integerForKey:@"GBHighpassFilter"])];
            },
        },
        @{
            @"header": @"Interference volume",
            @"items": @[
                @{@"type": typeSlider, @"pref": @"GBInterferenceVolume", @"min": @0, @"max": @1, @"minImage": @"speaker.fill", @"maxImage": @"speaker.3.fill"}
            ],
        },
    ];
    
    NSArray<NSDictionary *> *controlsMenu = @[
        @{
            @"header": @"D-pad Style",
            @"items": @[
                // TODO: Convert to enum when implemented
                @{@"type": typeRadio, @"pref": @"GBSwipeDpad", @"title": @"Standard", @"value": @NO,},
                @{@"type": typeRadio, @"pref": @"GBSwipeDpad", @"title": @"Swipe",    @"value": @YES,},
            ],
            @"footer": ^NSString *(){
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBSwipeDpad"]) {
                    return @"Directional input is determined by the swipe direction.";
                }
                return @"Directional input is determined by the touch position.";
            },
        },
        @{
            @"header": @"Horizontal Swipe Behavior",
            @"items": @[
                @{@"type": typeCheck, @"pref": @"GBDynamicSpeed", @"title": @"Dynamically Control Speed"},
                @{@"type": typeCheck, @"pref": @"GBSwipeLock", @"title": @"Lock After Swiping"},
            ],
            @"footer": ^NSString *(){
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBSwipeLock"]) {
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBDynamicSpeed"]) {
                        return @"Swipe right on the Game Boy screen to play forward, and swipe left to rewind. Tap on the Game Boy screen to return to normal. The forward and rewind speeds are determinied by the swipe distance.";
                    }
                    return @"Swipe right on the Game Boy screen to fast-forward, and swipe left to rewind. Tap on the Game Boy screen to return to normal. The turbo and rewind speeds can be configured under “Emulation” settings.";
                }
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBDynamicSpeed"]) {
                    return @"Swipe right on the Game Boy screen to play forward, and swipe left to rewind. Raise the touch to return to normal. The forward and rewind speeds are determinied by the swipe distance.";
                }
                return @"Swipe right on the Game Boy screen to fast-forward, and swipe left to rewind. Raise the touch to return to normal. The turbo and rewind speeds can be configured under “Emulation” settings.";
            },
        },
        @{
            @"header": @"Quick Save and Load",
            @"items": @[
                @{@"type": typeCheck, @"pref": @"GBSwipeState", @"title": @"Swipe to Save and Load from Slot 1"},
            ],
            @"footer": ^NSString *(){
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GBSwipeState"]) {
                    return @"Swipe down on the Game Boy to save the state into state slot 1. Swipe up to load the state from state slot 1";
                }
                return @" "; // This space is needed, otherwise UITableView spacing breaks
            },
        },
        @{
            @"header": @"Enable Rumble",
            @"items": @[
                @{@"type": typeRadio, @"pref": @"GBRumbleMode", @"title": @"Never",                        @"value": @(GB_RUMBLE_DISABLED),},
                @{@"type": typeRadio, @"pref": @"GBRumbleMode", @"title": @"For Rumble-Enabled Game Paks", @"value": @(GB_RUMBLE_CARTRIDGE_ONLY),},
                @{@"type": typeRadio, @"pref": @"GBRumbleMode", @"title": @"Always",                       @"value": @(GB_RUMBLE_ALL_GAMES),},
            ],
        },
        @{
            @"items": @[
                @{@"type": typeCheck, @"pref": @"GBButtonHaptics", @"title": @"Enable Button Haptics"},
            ],
        },
    ];
    
    return @[
        @{
            @"items": @[
                    @{
                        @"title": @"Emulation",
                        @"type": typeSubmenu,
                        @"submenu": emulationMenu,
                        @"image": [UIImage imageNamed:@"emulationSettings"],
                    },
                    @{
                        @"title": @"Video",
                        @"type": typeSubmenu,
                        @"submenu": videoMenu,
                        @"image": [UIImage imageNamed:@"videoSettings"],
                    },
                    @{
                        @"title": @"Audio",
                        @"type": typeSubmenu,
                        @"submenu": audioMenu,
                        @"image": [UIImage imageNamed:@"audioSettings"],
                    },
                    @{
                        @"title": @"Controls",
                        @"type": typeSubmenu,
                        @"submenu": controlsMenu,
                        @"image": [UIImage imageNamed:@"controlsSettings"],
                    },
            ]
        }
    ];
}


+ (UIViewController *)settingsViewControllerWithLeftButton:(UIBarButtonItem *)button
{
    GBSettingsViewController *root = [[self alloc] initWithStructure:[self rootStructure] title:@"Settings" style:UITableViewStyleGrouped];
    UINavigationController *controller = [[UINavigationController alloc] initWithRootViewController:root];
    [controller.visibleViewController.navigationItem setLeftBarButtonItem:button];
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        return controller;
    }
    
    UISplitViewController *split = [[UISplitViewController alloc] init];
    UIViewController *blank = [[UIViewController alloc] init];
    blank.view.backgroundColor = root.view.backgroundColor;
    root->_detailsNavigation = [[UINavigationController alloc] initWithRootViewController:blank];
    split.viewControllers = @[controller, root->_detailsNavigation];
    split.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    return split;
}

- (instancetype)initWithStructure:(NSArray *)structure title:(NSString *)title style:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (!self) return nil;
    self.title = title;
    _structure = structure;
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _structure.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_structure[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _structure[section][@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if ([_structure[section][@"footer"] respondsToSelector:@selector(invoke)]) {
        return ((NSString *(^)(void))_structure[section][@"footer"])();
    }
    return _structure[section][@"footer"];
}

- (NSDictionary *)itemForIndexPath:(NSIndexPath *)indexPath
{
    return _structure[[indexPath indexAtPosition:0]][@"items"][[indexPath indexAtPosition:1]];
}

- (NSDictionary *)followingItemForIndexPath:(NSIndexPath *)indexPath
{
    NSArray *items = _structure[[indexPath indexAtPosition:0]][@"items"];
    if ([indexPath indexAtPosition:1] + 1 >= items.count) {
        return nil;
    }
    return items[[indexPath indexAtPosition:1] + 1];
}

+ (void)fixSliderTint:(UIView *)view
{
    if ([view isKindOfClass:[UIImageView class]]) {
        view.tintColor = [UIColor systemGrayColor];
    }
    for (UIView *subview in view.subviews) {
        [self fixSliderTint:subview];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self itemForIndexPath:indexPath];

    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = item[@"title"];
    if (item[@"type"] == typeSubmenu || item[@"type"] == typeOptionSubmenu) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        if (item[@"type"] == typeOptionSubmenu) {
            for (NSDictionary *section in item[@"submenu"]) {
                for (NSDictionary *item in section[@"items"]) {
                    if (item[@"value"] && [([[NSUserDefaults standardUserDefaults] objectForKey:item[@"pref"]] ?: @0) isEqual:item[@"value"]]) {
                        cell.detailTextLabel.text = item[@"title"];
                        break;
                    }
                }
            }
        }
    }
    else if (item[@"type"] == typeRadio) {
        if ([([[NSUserDefaults standardUserDefaults] objectForKey:item[@"pref"]] ?: @0) isEqual:item[@"value"]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    else if (item[@"type"] == typeCheck) {
        UISwitch *button = [[UISwitch alloc] init];
        cell.accessoryView = button;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:item[@"pref"]]) {
            button.on = true;
        }
        
        __weak typeof(self) weakSelf = self;
        id block = ^(){
            [[NSUserDefaults standardUserDefaults] setBool:button.on forKey:item[@"pref"]];
            unsigned section = [indexPath indexAtPosition:0];
            UITableViewHeaderFooterView *view = [weakSelf.tableView footerViewForSection:section];
            view.textLabel.text = [weakSelf tableView:weakSelf.tableView titleForFooterInSection:section];
            [UIView setAnimationsEnabled:false];
            [weakSelf.tableView beginUpdates];
            [view sizeToFit];
            [weakSelf.tableView endUpdates];
            [UIView setAnimationsEnabled:true];
        };
        objc_setAssociatedObject(cell, "RetainedBlock", block, OBJC_ASSOCIATION_RETAIN);
        
        [button addTarget:block action:@selector(invoke) forControlEvents:UIControlEventValueChanged];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else if (item[@"type"] == typeDisabled) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (@available(iOS 13.0, *)) {
            cell.textLabel.textColor = [UIColor separatorColor];
        }
        else {
            cell.textLabel.textColor = [UIColor colorWithWhite:0 alpha:0.75];
        }
    }
    else if (item[@"type"] == typeSeparator) {
        cell.backgroundColor = [UIColor clearColor];
        cell.separatorInset = UIEdgeInsetsZero;
    }
    else if (item[@"type"] == typeSlider ||
             item[@"type"] == typeLightTemp) {
        CGRect rect = cell.contentView.bounds;
        rect.size.width -= 24;
        rect.size.height -= 24;
        rect.origin.x += 12;
        rect.origin.y += 12;
        UISlider *slider = [item[@"type"] == typeLightTemp? [GBTemperatureSlider alloc] : [UISlider alloc] initWithFrame:rect];
        slider.continuous = true;
        slider.minimumValue = [item[@"min"] floatValue];
        slider.maximumValue = [item[@"max"] floatValue];
        slider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:slider];
        slider.value = [[NSUserDefaults standardUserDefaults] floatForKey:item[@"pref"]];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (item[@"minImage"] && item[@"maxImage"]) {
            if ([item[@"minImage"] isKindOfClass:[UIImage class]]) {
                slider.minimumValueImage = item[@"minImage"];
            }
            else if (@available(iOS 13.0, *)) {
                slider.minimumValueImage = [UIImage systemImageNamed:item[@"minImage"]];
            }
            
            if ([item[@"maxImage"] isKindOfClass:[UIImage class]]) {
                slider.maximumValueImage = item[@"maxImage"];
            }
            else if (@available(iOS 13.0, *)) {
                slider.maximumValueImage = [UIImage systemImageNamed:item[@"maxImage"]];
            }
            [GBSettingsViewController fixSliderTint:slider];
        }
        
        id block = ^(){
            [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:item[@"pref"]];
        };
        objc_setAssociatedObject(cell, "RetainedBlock", block, OBJC_ASSOCIATION_RETAIN);

        [slider addTarget:block action:@selector(invoke) forControlEvents:UIControlEventValueChanged];
    }
    
    if ([self followingItemForIndexPath:indexPath][@"type"] == typeSeparator) {
        cell.separatorInset = UIEdgeInsetsZero;
    }
    cell.imageView.image = item[@"image"];
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self itemForIndexPath:indexPath];
    if (item[@"type"] == typeSubmenu || item[@"type"] == typeOptionSubmenu) {
        UITableViewStyle style = UITableViewStyleGrouped;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            if (@available(iOS 13.0, *)) {
                style = UITableViewStyleInsetGrouped;
            }
        }
        GBSettingsViewController *submenu = [[GBSettingsViewController alloc] initWithStructure:item[@"submenu"]
                                                                                          title:item[@"title"]
                                                                                          style:style];
        if (_detailsNavigation) {
            [_detailsNavigation setViewControllers:@[submenu] animated:false];
        }
        else {
            [self.navigationController pushViewController:submenu animated:true];
        }
        return indexPath;
    }
    else if (item[@"type"] == typeRadio) {
        [[NSUserDefaults standardUserDefaults] setObject:item[@"value"] forKey:item[@"pref"]];
        [self.tableView reloadData];
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self itemForIndexPath:indexPath];
    if (item[@"type"] == typeSeparator) {
        return 8;
    }
    if (item[@"type"] == typeSlider ||
        item[@"type"] == typeLightTemp) {
        return 63;
    }
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

@end
