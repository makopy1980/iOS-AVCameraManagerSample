//
//  ViewController.m
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self settingCameraManager];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)settingCameraManager {
    
    _cameraManager = [AVCameraManager new];
    [_cameraManager setDelegate:self];
    [_cameraManager setUpPreviewlayer:_preview];
    
}

@end
