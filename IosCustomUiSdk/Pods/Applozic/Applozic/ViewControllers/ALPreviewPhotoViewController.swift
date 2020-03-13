//
//  ALKPreviewPhotoViewController.swift
//  
//
//  Created by Mukesh Thawani on 04/05/17.
//  Copyright © 2017 Applozic. All rights reserved.
//

import Foundation
import UIKit

@objc public class ALPreviewPhotoViewController: UIViewController {

    var pathExtention: String  = ""

    fileprivate let scrollView: UIScrollView = {
        let sv = UIScrollView(frame: .zero)
        sv.backgroundColor = UIColor.clear
        sv.isUserInteractionEnabled = true
        sv.isScrollEnabled = true
        return sv
    }()

    fileprivate let imageView: UIImageView = {
        let mv = UIImageView(frame: .zero)
        mv.contentMode = .scaleAspectFit
        mv.backgroundColor = UIColor.clear
        mv.isUserInteractionEnabled = false
        return mv
    }()

    @objc required public init(image: UIImage, pathExtension: String) {
        super.init(nibName: nil, bundle: nil)
        self.pathExtention = pathExtension
        self.image = image

    }
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var image: UIImage = UIImage()

    var imageViewTopConstraint: NSLayoutConstraint?
    var imageViewBottomConstraint: NSLayoutConstraint?
    var imageViewLeadingConstraint: NSLayoutConstraint?
    var imageViewTrailingConstraint: NSLayoutConstraint?

    func setupViews() {
        scrollView.delegate = self
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
        singleTap.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTap)
        
        if(pathExtention != "gif"){
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(tap:)))
            doubleTap.numberOfTapsRequired = 2
            scrollView.addGestureRecognizer(doubleTap)
            singleTap.require(toFail: doubleTap)
        }
        view.backgroundColor = ALApplozicSettings.getImagePreviewBackgroundColor()
        imageView.image = image
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        imageViewTopConstraint = imageView.topAnchor.constraint(equalTo: scrollView.topAnchor)
        imageViewTopConstraint?.isActive = true

        imageViewBottomConstraint = imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        imageViewBottomConstraint?.isActive = true

        imageViewLeadingConstraint = imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
        imageViewLeadingConstraint?.isActive = true

        imageViewTrailingConstraint = imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor)
        imageViewTrailingConstraint?.isActive = true
        view.layoutIfNeeded()
    }

    private func setupNavigation() {
        self.navigationItem.title = NSLocalizedString("imagePreview", tableName: ALApplozicSettings.getLocalizableName(), bundle: Bundle.main, value: "Image Preview", comment: "")

        var backImage = UIImage.init(named: "icon_back", in: Bundle(for: ALChatViewController.self), compatibleWith: nil)
            backImage = backImage?.imageFlippedForRightToLeftLayoutDirection()
        self.navigationItem.rightBarButtonItem =  UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.showShare(_:)))

    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNavigation()
        scrollView.maximumZoomScale = 7.0
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMinZoomScaleForSize(size: view.bounds.size)
        updateConstraintsForSize(size: view.bounds.size)
    }

    @objc func doubleTapped(tap: UITapGestureRecognizer) {

        UIView.animate(withDuration: 0.5, animations: {

            let view = self.imageView

            let viewFrame = view.frame

            let location = tap.location(in: view)
            let viewWidth = viewFrame.size.width/2.0
            let viewHeight = viewFrame.size.height/2.0

            let rect = CGRect(x: location.x - (viewWidth/2), y: location.y - (viewHeight/2), width: viewWidth, height: viewHeight)

            if self.scrollView.minimumZoomScale == self.scrollView.zoomScale {
                self.scrollView.zoom(to: rect, animated: false)
            } else {
                self.updateMinZoomScaleForSize(size: self.view.bounds.size)
            }

        }, completion: nil)

    }
    
    /// Single Tap is for hide navigationBar and change the background color view
    ///
    /// - Parameter tap: UITapGestureRecognizer
    @objc func singleTapped(tap: UITapGestureRecognizer) {
        guard let nav = self.navigationController else {
            return
        }
        let isHidden = nav.navigationBar.isHidden

        if(!isHidden){
            self.view.backgroundColor = UIColor.black
        }else{
            self.view.backgroundColor = ALApplozicSettings.getImagePreviewBackgroundColor()
        }
        nav.navigationBar.isHidden = !isHidden

    }

    @objc func showShare(_ sender: Any?) {
            let activityItems = [self.image]
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            activityVC.excludedActivityTypes = [
                .assignToContact,
                .print,
                .postToTwitter,
                .postToWeibo,
                .mail
            ]
            present(activityVC, animated: true)
    }

    func updateMinZoomScaleForSize(size: CGSize) {

        let widthScale = size.width / imageView.bounds.width
        let heightScale = size.height / imageView.bounds.height
        let minScale = min(widthScale, heightScale)

        if(!(minScale  > 0 &&  minScale <= 7.0 )){
            return
        }

        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
    }

    func updateConstraintsForSize(size: CGSize) {

        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)

        updateImageViewConstraintsWith(xOffset: xOffset, yOffset: yOffset)
    }
    
    func updateImageViewConstraintsWith(xOffset: CGFloat,yOffset: CGFloat) {
        imageViewTopConstraint?.constant = yOffset
        imageViewBottomConstraint?.constant = yOffset
        imageViewLeadingConstraint?.constant = xOffset
        imageViewTrailingConstraint?.constant = xOffset
    }

    @IBAction func dismissAction(_ sender: UIBarButtonItem) {
        self.navigationController?.popViewController(animated: false)
    }

}

extension ALPreviewPhotoViewController: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(size: view.bounds.size)
        view.layoutIfNeeded()
    }
}
