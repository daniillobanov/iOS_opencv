//
//  ViewController.m
//  CV_test
//
//  Created by Daniil Lobanov on 21.07.16.
//  Copyright © 2016 Daniil Lobanov. All rights reserved.
//

#import "ViewController.h"

#include <opencv2/highgui/ios.h>

#import "MSERManager.h"
#import "MLManager.h"
#import "ImageUtils.h"
#import "GeometryUtil.h"

#import "FPS.h"
#import "SIFT.h"

#include <stdio.h>
#include <iostream>
#include "opencv2/core/core.hpp"
#include "opencv2/features2d/features2d.hpp"
#include "opencv2/highgui/highgui.hpp"
#include "opencv2/calib3d/calib3d.hpp"
#include "opencv2/nonfree/nonfree.hpp"

//this two values are dependant on defaultAVCaptureSessionPreset
#define W (480)
#define H (640)

@interface ViewController () <CvVideoCameraDelegate>

@property (assign, nonatomic) BOOL isStarted;

@property (nonatomic) cv::Mat searchTemplate;
@property (strong, nonatomic) CvVideoCamera* videoCamera;

@property (weak, nonatomic) IBOutlet UIImageView* imageView;
@property (weak, nonatomic) IBOutlet UIButton* button;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;

- (IBAction)buttonPressed:(id)sender;
- (IBAction)segmentedControlValueChanged:(id)sender;

@end

@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIImage* searchImage = [UIImage imageNamed:@"SS"];
    
    self.searchTemplate  = [ImageUtils cvMatFromUIImage:searchImage];
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:self.imageView];
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = NO;
    
    self.videoCamera.delegate = self;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];
    
    [self.videoCamera start];
}

#pragma mark - CvVideoCameraDelegate

- (void)processImage:(cv::Mat&)image
{
    if (self.isStarted)
    {
        switch (self.segmentedControl.selectedSegmentIndex)
        {
            case 0:
            {
                [self MSERProcess:image];
            }
                break;
                
            case 1:
            {
                [self MTProcess:image];
            }
                break;
                
            case 2:
            {
                [self SIFT_GPUProcess:image];
            }
                break;
                
            case 3:
            {
                [self SIFT_CPUProcess:image];
            }
                break;
                
            default:
                break;
        }
    }
    
    [FPS draw: image];
}

#pragma mark - Actions

- (IBAction)buttonPressed:(id)sender
{
    self.isStarted = !self.isStarted;
    
    if (self.isStarted)
    {
        [self.button setTitle:@"STOP"
                     forState:UIControlStateNormal];
    }
    else
    {
        [self.button setTitle:@"START"
                     forState:UIControlStateNormal];
    }
}

- (IBAction)segmentedControlValueChanged:(id)sender
{
    
}

#pragma mark - OpenCV

//http://docs.opencv.org/3.0-beta/doc/py_tutorials/py_feature2d/py_fast/py_fast.html
//https://github.com/altaibayar/toptal_logo_detector
- (void)MSERProcess:(cv::Mat &)image
{
    cv::Mat resp;
    
    cv::Mat gray;
    cvtColor(image, gray, CV_BGRA2GRAY);
    
    std::vector<std::vector<cv::Point>> msers;
    [[MSERManager sharedInstance] detectRegions: gray intoVector: msers];
    if (msers.size() == 0) { return; };
    
    std::vector<cv::Point> *bestMser = nil;
    double bestPoint = 10.0;
    
    std::for_each(msers.begin(), msers.end(), [&] (std::vector<cv::Point> &mser)
                  {
                      MSERFeature *feature = [[MSERManager sharedInstance] extractFeature: &mser];
                      
                      if(feature != nil)
                      {
                          if([[MLManager sharedInstance] isLogo: feature] )
                          {
                              double tmp = [[MLManager sharedInstance] distance: feature ];
                              if ( bestPoint > tmp ) {
                                  bestPoint = tmp;
                                  bestMser = &mser;
                              }
                              
                              //[ImageUtils drawMser: &mser intoImage: &image withColor: GREEN];
                          }
                          else
                          {
                              //NSLog(@"%@", [feature toString]);
                              //[ImageUtils drawMser: &mser intoImage: &image withColor: RED];
                          }
                      }
                      else
                      {
                          //[ImageUtils drawMser: &mser intoImage: &image withColor: BLUE];
                      }
                  });
    
    if (bestMser)
    {
        NSLog(@"minDist: %f", bestPoint);
        
        cv::Rect bound = cv::boundingRect(*bestMser);
        cv::rectangle(image, bound, GREEN, 3);
    }
    else
    {
        cv::rectangle(image, cv::Rect(0, 0, W, H), RED, 3);
    }
    
#if DEBUG
    const char* str_fps = [[NSString stringWithFormat: @"MSER: %ld", msers.size()] cStringUsingEncoding: NSUTF8StringEncoding];
    cv::putText(image, str_fps, cv::Point(10, H - 10), CV_FONT_HERSHEY_PLAIN, 1.0, RED);
#endif
}

//http://docs.opencv.org/2.4/doc/tutorials/imgproc/histograms/template_matching/template_matching.html
- (void)MTProcess:(cv::Mat &)image
{
    cv::Mat srcMat = image;
    cv::Mat tmpMat = self.searchTemplate;
    
    cv::Mat dst = srcMat.clone();
    
    cv::matchTemplate(srcMat, tmpMat, dst, cv::TM_CCOEFF);
    
    double min_val, max_val;
    cv::Point min_loc, max_loc;
    cv::minMaxLoc(dst, &min_val, &max_val, &min_loc, &max_loc);

    if (ABS(min_val) < 25000000 && ABS(max_val) < 25000000)
    {
        cv::rectangle(srcMat, max_loc, cv::Point(max_loc.x + tmpMat.cols, max_loc.y + tmpMat.rows), CV_RGB(0, 255, 0), 2);
    }
    
    const char* str_fps = [[NSString stringWithFormat: @"MATCH: min - %f max - %f", min_val, max_val] cStringUsingEncoding: NSUTF8StringEncoding];
    cv::putText(image, str_fps, cv::Point(10, H - 10), CV_FONT_HERSHEY_PLAIN, 1.0, RED);
}

//https://github.com/Moodstocks/sift-gpu-iphone
- (void)SIFT_GPUProcess:(cv::Mat &)image
{
    UIImage* imageToProcess = [ImageUtils UIImageFromCVMat:image];
    SIFT* siftProcessor = [[SIFT alloc] init];
    [siftProcessor initWithWidth:360 Height:480 Octaves:4];
    NSMutableArray * test = [siftProcessor computeSiftOnCGImage:[imageToProcess CGImage]];
    
    const char* str_fps = [[NSString stringWithFormat: @"SIFT GPU: %@", @(test.count)] cStringUsingEncoding: NSUTF8StringEncoding];
    cv::putText(image, str_fps, cv::Point(10, H - 10), CV_FONT_HERSHEY_PLAIN, 1.0, RED);
    
    test = nil;
}

//http://docs.opencv.org/2.4/doc/tutorials/features2d/feature_homography/feature_homography.html
- (void)SIFT_CPUProcess:(cv::Mat &)image
{
    //-- Prepearing
    cv::Mat img_object = image;
    cv::Mat img_scene  = self.searchTemplate;
    
    //-- Step 1: Detect the keypoints using SURF Detector
    int minHessian = 400;
    
    cv::SurfFeatureDetector detector( minHessian );
    
    std::vector<cv::KeyPoint> keypoints_object, keypoints_scene;
    
    detector.detect( img_object, keypoints_object );
    detector.detect( img_scene, keypoints_scene );
    
    //-- Step 2: Calculate descriptors (feature vectors)
    cv::OrbDescriptorExtractor extractor;
    
    cv::Mat descriptors_object, descriptors_scene;
                      
    extractor.compute( img_object, keypoints_object, descriptors_object );
    extractor.compute( img_scene,  keypoints_scene,  descriptors_scene  );
    
    //
    
    //-- Step 3: Matching descriptor vectors using FLANN matcher
    cv::FlannBasedMatcher matcher;
    std::vector< cv::DMatch > matches;
    
    matcher.match( descriptors_object, descriptors_scene, matches );
    
    double max_dist = 0; double min_dist = 100;
/*
 
    //-- Quick calculation of max and min distances between keypoints
    for( int i = 0; i < descriptors_object.rows; i++ )
    { double dist = matches[i].distance;
        if( dist < min_dist ) min_dist = dist;
        if( dist > max_dist ) max_dist = dist;
    }
    
    printf("-- Max dist : %f \n", max_dist );
    printf("-- Min dist : %f \n", min_dist );
    
    //-- Draw only "good" matches (i.e. whose distance is less than 3*min_dist )
    std::vector< cv::DMatch > good_matches;
    
    for( int i = 0; i < descriptors_object.rows; i++ )
    { if( matches[i].distance < 3*min_dist )
    { good_matches.push_back( matches[i]); }
    }
    
    cv::Mat img_matches;
    drawMatches( img_object, keypoints_object, img_scene, keypoints_scene,
                good_matches, img_matches, cv::Scalar::all(-1), cv::Scalar::all(-1),
                std::vector<char>(), cv::DrawMatchesFlags::NOT_DRAW_SINGLE_POINTS );
    
    //-- Localize the object
    std::vector<cv::Point2f> obj;
    std::vector<cv::Point2f> scene;
    
    for( int i = 0; i < good_matches.size(); i++ )
    {
        //-- Get the keypoints from the good matches
        obj.push_back( keypoints_object[ good_matches[i].queryIdx ].pt );
        scene.push_back( keypoints_scene[ good_matches[i].trainIdx ].pt );
    }
    
    cv::Mat h = findHomography( obj, scene, CV_RANSAC );
    
    //-- Get the corners from the image_1 ( the object to be "detected" )
    std::vector<cv::Point2f> obj_corners(4);
    obj_corners[0] = cvPoint(0,0); obj_corners[1] = cvPoint( img_object.cols, 0 );
    obj_corners[2] = cvPoint( img_object.cols, img_object.rows ); obj_corners[3] = cvPoint( 0, img_object.rows );
    std::vector<cv::Point2f> scene_corners(4);
    
    perspectiveTransform( obj_corners, scene_corners, h);
    
    //-- Draw lines between the corners (the mapped object in the scene - image_2 )
    line( img_matches, scene_corners[0] + cv::Point2f( img_object.cols, 0), scene_corners[1] + cv::Point2f( img_object.cols, 0), cv::Scalar(0, 255, 0), 4  );
    line( img_matches, scene_corners[1] + cv::Point2f( img_object.cols, 0), scene_corners[2] + cv::Point2f( img_object.cols, 0), cv::Scalar( 0, 255, 0), 4 );
    line( img_matches, scene_corners[2] + cv::Point2f( img_object.cols, 0), scene_corners[3] + cv::Point2f( img_object.cols, 0), cv::Scalar( 0, 255, 0), 4 );
    line( img_matches, scene_corners[3] + cv::Point2f( img_object.cols, 0), scene_corners[0] + cv::Point2f( img_object.cols, 0), cv::Scalar( 0, 255, 0), 4 );
    
    //-- Show detected matches
    imshow( "Good Matches & Object detection", img_matches );
     
     */
}

#pragma MARK - Test

@end