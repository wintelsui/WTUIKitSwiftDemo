//
//  WTImageZoomView.swift
//  iPicturePuzzleSwift
//
//  Created by wintel on 2018/3/19.
//  Copyright © 2018年 wintelsui. All rights reserved.
//

import UIKit

extension UIImage {
    
    /// 计算图片在尺寸内 AspectFit 尺寸
    ///
    /// - Parameter size: 区域尺寸
    /// - Returns: 图片适配尺寸
    func sizeFits(size: CGSize) -> CGSize {
        
        let imageSize: CGSize = self.size
        
        let wRatio = imageSize.width / size.width
        let hRatio = imageSize.height / size.height
        
        //将 Image 放入 Size 中（保持高宽比）
        if wRatio > hRatio {
            return CGSize(width: size.width, height: (imageSize.height / wRatio))
        }
        else {
            return CGSize(width: (imageSize.width / hRatio), height: size.height)
        }
        
    }
    
}

extension UIImageView {
    
    /// 图片在UIImageView内实际尺寸
    ///
    /// - Returns: 图片在UIImageView内实际尺寸
    func contentSize() -> CGSize {
        if self.image != nil {
            return self.image!.sizeFits(size: self.frame.size)
        }
        return CGSize(width: 0, height: 0)
    }
    
}

class WTImageZoomViewSwift: UIScrollView,
    UIScrollViewDelegate,
    UIGestureRecognizerDelegate
{
    //UISorollView -> UIView -> UIImageView
    
    var image: UIImage!
    
    var baseView: UIView!
    var imageView: UIImageView!
    
    /// 最小尺寸
    var minSize: CGSize
    
    /// 是否处理屏幕旋转
    var rotateEnable: Bool = true
    
    /// 屏幕旋转
    private var rotating: Bool = false
    
    
    /// 图片点击回调
    var imageZoomViewClosureSingleTap: (() -> ())?
    
    /// 图片双击回调
    var imageZoomViewClosureDoubleTap: (() -> ())?
    
    /// 图片长按回调
    var imageZoomViewClosureLongTap: (() -> ())?
    
    override init(frame: CGRect) {
        self.minSize = CGSize(width: 0, height: 0)
        
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.minSize = CGSize(width: 0, height: 0)
        
        super.init(coder: aDecoder)
    }
    
    deinit {
        removeNotification()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.rotateEnable {
            if self.rotating {
                self.rotating = false
                
                let baseSize: CGSize = self.baseView.frame.size
                let baseSmallerThanSelf: Bool = (baseSize.width < self.bounds.size.width) && (baseSize.height < self.bounds.size.height)
                let imageSize: CGSize = self.imageView.image!.sizeFits(size: self.bounds.size)
                let minZoomScale: CGFloat = imageSize.width/self.minSize.width
                self.minimumZoomScale = minZoomScale
                if baseSmallerThanSelf || self.zoomScale == self.minimumZoomScale {
                    // 宽度或高度 都小于 self 的宽度和高度
                    self.zoomScale = minZoomScale
                }
                
                self.centerContent()
            }
        } else {
            self.rotating = false
            
        }
    }
    
    /// 创建对象
    ///
    /// - Parameter frame:  frame
    /// - Returns: WTImageZoomViewSwift
    open class func imageZoomViewMake(frame: CGRect) -> WTImageZoomViewSwift? {
        
        return WTImageZoomViewSwift(frame: frame)
    }
    
    /// 加载图片
    ///
    /// - Parameter image: 图片
    open func load(image: UIImage) {
        self.minimumZoomScale = 1.0
        self.setZoomScale(self.minimumZoomScale, animated: true)
        self.baseView.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: self.bounds.size.width, height: self.bounds.size.height)
        self.image = image
        imageView.image = image
        imageView.frame = baseView.bounds
        
        let imageSize: CGSize = imageView.contentSize()
        self.baseView.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: imageSize.width, height: imageSize.height)
        imageView.bounds = CGRect(x: CGFloat(0), y: CGFloat(0), width: imageSize.width, height: imageSize.height)
        imageView.center = CGPoint(x: imageSize.width/2, y: imageSize.height/2)
        self.contentSize = imageSize
        self.minSize = imageSize
        self.mathZoomScaleMax()
        
        self.centerContent()

    }
    
    ///  缩放图片到最小
    open func scaleImageMin() {
        if self.zoomScale != self.minimumZoomScale {
            self.setZoomScale(self.minimumZoomScale, animated: true)
        }
    }
    
    // MARK: - Init Start
    
    /// 初始化 UI 等
     private func setup() {
        self.delegate = self
        self.bouncesZoom = true
        
        baseView = UIView()
        baseView.backgroundColor = UIColor.clear
        self.addSubview(baseView)
        
        imageView = UIImageView()
        baseView.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        
        setupGestureRecognizer()
        addNotification()
    }
    
    /// 设置手势
    private func setupGestureRecognizer() {
        //双击
        let doubleTapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(recognizer:)))
        doubleTapGesture.numberOfTapsRequired = 2
        baseView.addGestureRecognizer(doubleTapGesture)
        //单击
        let singleTapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(recognizer:)))
        singleTapGesture.numberOfTapsRequired = 1
        baseView.addGestureRecognizer(singleTapGesture)
        singleTapGesture.require(toFail: doubleTapGesture)
        //长按
        let longTapGesture: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action:  #selector(handleLongTap(recognizer:)))
        longTapGesture.delegate = self
        longTapGesture.minimumPressDuration = 1.0
        baseView.addGestureRecognizer(longTapGesture)
    }
    
    /// 添加屏幕方向监听
    private func addNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged(sender:)), name: NSNotification.Name.UIApplicationDidChangeStatusBarOrientation, object: nil)

    }
    
    /// 移除屏幕方向监听
    private func removeNotification() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - UIScrollViewDelegate Start
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.baseView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.centerContent()
    }
    
    // MARK: - UIScrollViewDelegate End
    
    // MARK: - GestureRecognizer Start
    
    /// 双击手势事件
    ///
    /// - Parameter recognizer: 双击手势
    @objc private func handleDoubleTap(recognizer: UITapGestureRecognizer) {
        
        if self.zoomScale > self.minimumZoomScale {
            self.setZoomScale(self.minimumZoomScale, animated: true)
        } else if self.zoomScale < self.maximumZoomScale {
            let location: CGPoint = recognizer.location(in: recognizer.view)
            var zoomToRect: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            zoomToRect.origin = CGPoint(x: (location.x - zoomToRect.size.width / 2), y: (location.y - zoomToRect.size.height/2))
            self.zoom(to: zoomToRect, animated: true)
        }
        
        if imageZoomViewClosureDoubleTap != nil {
            imageZoomViewClosureDoubleTap!()
        }
    }
    
    /// 单击手势事件
    ///
    /// - Parameter recognizer: 单击手势
    @objc private func handleSingleTap(recognizer: UIGestureRecognizer) {
        
        if imageZoomViewClosureSingleTap != nil {
            imageZoomViewClosureSingleTap!()
        }
    }
    
    /// 长按手势事件
    ///
    /// - Parameter recognizer: 长按手势
    @objc private func handleLongTap(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            if imageZoomViewClosureLongTap != nil {
                imageZoomViewClosureLongTap!()
            }
        }
    }
    
    // MARK: - GestureRecognizer End

    // MARK: - Notification Start
    
    @objc private func orientationChanged(sender:Notification) {
        self.rotating = true
    }
    
    // MARK: - Notification End
    
    // MARK: - Additional Start
    
    /// 计算图片最大缩放比例
    private func mathZoomScaleMax() {
        var imageSize: CGSize!
        if imageView.image != nil {
            imageSize = self.imageView.image!.size
        }
        else{
            imageSize = CGSize(width: 0, height: 0)
        }
        
        let imageContentSize: CGSize = self.imageView.contentSize()
        let scaleMax: CGFloat = max(imageSize.height/imageContentSize.height, imageSize.width/imageContentSize.width)
        self.maximumZoomScale = max(4, scaleMax)

    }
    
    /// 中心位置
    private func centerContent() {
        let frame: CGRect = self.baseView.frame
        var top: CGFloat = 0
        var left: CGFloat = 0
        if self.contentSize.width < self.bounds.size.width {
            left = (self.bounds.size.width - self.contentSize.width) * 0.5
        }
        if self.contentSize.height < self.bounds.size.height {
            top = (self.bounds.size.height - self.contentSize.height) * 0.5
        }
        top -= frame.origin.y
        left -= frame.origin.x
        self.contentInset = UIEdgeInsetsMake(top, left, top, left)

    }
}
