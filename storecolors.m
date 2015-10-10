#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#define ICON_SIZE 100

static NSURL* topURL(BOOL paid, NSString *countryCode, int limit) {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/%@/rss/top%@applications/limit=%d/json", countryCode, paid ? @"paid" : @"free", limit]];
}

static NSString *countryName(NSString *countryCode) {
	return [[NSLocale currentLocale] displayNameForKey:NSLocaleCountryCode value:countryCode];
}

static void print_usage(void) {
    printf("Usage : storecolors [ -c <country_code> -l <list_size> -p ] -o output\n");
    printf("\t-c <country_code> : the country code to use (default: US)\n");
    printf("\t-p : search top paid\n");
    printf("\t-l <list_size> : 1-200\n");
    printf("\t-o <output_dir> : the output directory\n");
    printf("\nexample:\n\tstorecolors -c US -l 50\n");
    printf("\twill scan the 50 top free apps in US\n");
	exit(0);
}

static NSData *DataFromURL(NSURL *url, NSError *error);
static id JSONObjectFromURL(NSURL *url, NSError *error);
static NSArray* getEntries(id jsonObject);

int main(int argc, char *const argv[]) {
    
    @autoreleasepool {
        
        int listsize = 200; // list size (200 by default)
        BOOL paid = NO;    // paid flag (default : free)
        
        NSString *country = @"US"; // country to scan (US by default)
        NSString *output = nil; // output directory
        
        int c;
        opterr = 0;
        while ((c = getopt (argc, argv, ":c:l:o:fph")) != -1)
            switch (c)
        {
            case 'o':
                output = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 'c':
                country = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 'p':
                paid = YES;
                break;
            case 'h':
                print_usage();
                break;
            case 'l':
                listsize = MIN(atoi(optarg),200);
                break;
            case '?':
             default:
                if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr, "Unknown option character `\\x%x'.\n", optopt);
                return 1;
        }
        
        if (!output) {
            fprintf (stderr, "No output directory, use -o <output_dir>\n");
            print_usage();
        }
        
        printf("loading top %d %s in %s\n", listsize, paid ? "paid" : "free", countryName(country).UTF8String);
        
        NSURL *url = topURL(paid, country, listsize);
        NSError* error = nil;
        
        NSDictionary *result = JSONObjectFromURL(url, error);
        
        if (!error && result) {
            NSArray *entries = getEntries(result);
            NSMutableArray *urls = [[NSMutableArray alloc] initWithCapacity:entries.count];
            
            for (NSDictionary *entry in entries) {
                NSArray *images = entry[@"im:image"];
                for (NSDictionary *image in images) {
                    if ([image[@"attributes"][@"height"] integerValue] == ICON_SIZE) { // keep 100x100 imgs
                        [urls addObject:[NSURL URLWithString:image[@"label"]]];
                    }
                }
            }
            
            NSString *countryImagesPath = [output stringByAppendingPathComponent:country];
            NSFileManager *fm = [NSFileManager defaultManager];
            if (![fm fileExistsAtPath:countryImagesPath]){
                [fm createDirectoryAtPath:countryImagesPath withIntermediateDirectories:NO attributes:nil error:&error];
            }
            
            int count = 1;
            for (NSURL *url in urls) {
                NSData *data = DataFromURL(url, error);
                [data writeToFile:[countryImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.png",count]] atomically:YES];
                count++;
            }
            
            NSUInteger colors[ICON_SIZE*ICON_SIZE][3] = {[0 ... (ICON_SIZE*ICON_SIZE)-1] = {0,0,0}};
            NSUInteger pixel[3];
            int c,l;
            
            NSImage *image = nil;
            NSBitmapImageRep* raw_img = nil;
            
            for (count = 1; count<=listsize; count++) {
                
                NSString *path = [countryImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.png",count]];
                image = [[NSImage alloc] initWithContentsOfFile:path];
                if (image) {
                    [image lockFocus];
                    raw_img = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, ICON_SIZE, ICON_SIZE)];
                    [image unlockFocus];
                    
                    for (l = 0; l < ICON_SIZE; l++) {
                        for (c = 0; c < ICON_SIZE; c++) {
                            
                            [raw_img getPixel:pixel atX:c+1 y:l+1];
                            
                            long index = l+(100*c);
                            colors[index][0] += pixel[0];
                            colors[index][1] += pixel[1];
                            colors[index][2] += pixel[2];
                        }
                    }
                }
            }
            
            NSBitmapImageRep* final_img = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:ICON_SIZE pixelsHigh:ICON_SIZE bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:3*ICON_SIZE bitsPerPixel:0];
            
            for (l = 0; l < ICON_SIZE; l++) {
                for (c = 0; c < ICON_SIZE; c++) {
                    long index = l+(100*c);
                    
                    pixel[0] = (NSUInteger)(colors[index][0]/listsize) & 0xFF;
                    pixel[1] = (NSUInteger)(colors[index][1]/listsize) & 0xFF;;
                    pixel[2] = (NSUInteger)(colors[index][2]/listsize) & 0xFF;;
                    //pixel[3] = 255;
                    
                    [final_img setPixel:pixel atX:c y:l];
                }
            }
            
            NSData *outputImgData = [final_img representationUsingType:NSPNGFileType properties:@{}];
            [outputImgData writeToFile:[output stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",country]] atomically:YES];
            
        }
        
    }
    return 0;
}

static NSData *DataFromURL(NSURL *url, NSError *error) {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLResponse* response;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [request release];
#pragma GCC diagnostic pop
    if (!data) {
        fprintf(stderr, "Unable to load data `%s'.\n", url.absoluteString.UTF8String);
        return nil;
    }
    
    return data;
}

static id JSONObjectFromURL(NSURL *url, NSError *error) {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLResponse* response;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [request release];
#pragma GCC diagnostic pop
    if (!data) {
        fprintf(stderr, "Unable to load data `%s'.\n", url.absoluteString.UTF8String);
        return nil;
    }
    
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
}

static NSArray* getEntries(id jsonObject) {
    if ([jsonObject[@"feed"][@"entry"] isKindOfClass:[NSArray class]]) {
        return jsonObject[@"feed"][@"entry"];
    }else if (jsonObject[@"feed"][@"entry"]) {
        return @[jsonObject[@"feed"][@"entry"]];
    }
    return nil;
}