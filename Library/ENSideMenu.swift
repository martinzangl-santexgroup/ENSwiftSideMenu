//
//  SideMenu.swift
//  SwiftSideMenu
//
//  Created by Evgeny on 24.07.14.
//  Copyright (c) 2014 Evgeny Nazarov. All rights reserved.
//

import UIKit

@objc public protocol ENSideMenuDelegate {
    @objc optional func sideMenuWillOpen()
    @objc optional func sideMenuWillClose()
    @objc optional func sideMenuDidOpen()
    @objc optional func sideMenuDidClose()
    @objc optional func sideMenuShouldOpenSideMenu () -> Bool
}

@objc public protocol ENSideMenuProtocol {
    var sideMenu : ENSideMenu? { get }
    func setContentViewController(contentViewController: UIViewController)
}

public enum ENSideMenuAnimation : Int {
    case None
    case Default
}
/**
 The position of the side view on the screen.
 
 - Left:  Left side of the screen
 - Right: Right side of the screen
 */
public enum ENSideMenuPosition : Int {
    case Left
    case Right
}

public extension UIViewController {
    /**
     Changes current state of side menu view.
     */
   @objc public func toggleSideMenuView () {
        sideMenuController()?.sideMenu?.toggleMenu()
    }
    /**
     Hides the side menu view.
     */
    @objc public func hideSideMenuView () {
        sideMenuController()?.sideMenu?.hideSideMenu()
    }
    /**
     Shows the side menu view.
     */
    @objc public func showSideMenuView () {
        
        sideMenuController()?.sideMenu?.showSideMenu()
    }
    
    /**
     Returns a Boolean value indicating whether the side menu is showed.
     
     :returns: BOOL value
     */
    public func isSideMenuOpen () -> Bool {
        let sieMenuOpen = self.sideMenuController()?.sideMenu?.isMenuOpen
        return sieMenuOpen!
    }
    
    /**
     * You must call this method from viewDidLayoutSubviews in your content view controlers so it fixes size and position of the side menu when the screen
     * rotates.
     * A convenient way to do it might be creating a subclass of UIViewController that does precisely that and then subclassing your view controllers from it.
     */
    func fixSideMenuSize() {
        if let navController = self.navigationController as? ENSideMenuNavigationController {
            navController.sideMenu?.updateFrame()
        }
    }
    /**
     Returns a view controller containing a side menu
     
     :returns: A `UIViewController`responding to `ENSideMenuProtocol` protocol
     */
    public func sideMenuController () -> ENSideMenuProtocol? {
        var iteration : UIViewController? = self.parent
        if (iteration == nil) {
            return topMostController()
        }
        repeat {
            if (iteration is ENSideMenuProtocol) {
                return iteration as? ENSideMenuProtocol
            } else if (iteration?.parent != nil && iteration?.parent != iteration) {
                iteration = iteration!.parent
            } else {
                iteration = nil
            }
        } while (iteration != nil)
        
        return iteration as? ENSideMenuProtocol
    }
    
    internal func topMostController () -> ENSideMenuProtocol? {
        var topController : UIViewController? = UIApplication.shared.keyWindow?.rootViewController
        if (topController is UITabBarController) {
            topController = (topController as! UITabBarController).selectedViewController
        }
        while (topController?.presentedViewController is ENSideMenuProtocol) {
            topController = topController?.presentedViewController
        }
        
        return topController as? ENSideMenuProtocol
    }
}

public class ENSideMenu : NSObject, UIGestureRecognizerDelegate {
    /// The width of the side menu view. The default value is 160.
    public var menuWidth : CGFloat = 160.0 {
        didSet {
            needUpdateApperance = true
            updateFrame()
        }
    }
    private var menuPosition:ENSideMenuPosition = .Left
    ///  A Boolean value indicating whether the bouncing effect is enabled. The default value is TRUE.
    public var bouncingEnabled :Bool = true
    /// The duration of the slide animation. Used only when `bouncingEnabled` is FALSE.
    public var animationDuration = 0.4
    private let sideMenuContainerView =  UIView()
    private var menuViewController : UIViewController!
    private var animator : UIDynamicAnimator!
    private var sourceView : UIView!
    private var needUpdateApperance : Bool = false
    /// The delegate of the side menu
    public weak var delegate : ENSideMenuDelegate?
    private(set) var isMenuOpen : Bool = false
    /// A Boolean value indicating whether the left swipe is enabled.
    public var allowLeftSwipe : Bool = true
    /// A Boolean value indicating whether the right swipe is enabled.
    public var allowRightSwipe : Bool = true
    
    /**
     Initializes an instance of a `ENSideMenu` object.
     
     :param: sourceView   The parent view of the side menu view.
     :param: menuPosition The position of the side menu view.
     
     :returns: An initialized `ENSideMenu` object, added to the specified view.
     */
    public init(sourceView: UIView, menuPosition: ENSideMenuPosition) {
        super.init()
        self.sourceView = sourceView
        self.menuPosition = menuPosition
        self.setupMenuView()
        
        animator = UIDynamicAnimator(referenceView:sourceView)
        animator.delegate = self
        
        // Add right swipe gesture recognizer
        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.handleGesture))
        rightSwipeGestureRecognizer.delegate = self
        rightSwipeGestureRecognizer.direction =  UISwipeGestureRecognizerDirection.right
        
        // Add left swipe gesture recognizer
        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.handleGesture))
        leftSwipeGestureRecognizer.delegate = self
        leftSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.left
        
        if (menuPosition == .Left) {
            sourceView.addGestureRecognizer(rightSwipeGestureRecognizer)
            sideMenuContainerView.addGestureRecognizer(leftSwipeGestureRecognizer)
        }
        else {
            sideMenuContainerView.addGestureRecognizer(rightSwipeGestureRecognizer)
            sourceView.addGestureRecognizer(leftSwipeGestureRecognizer)
        }
        
    }
    /**
     Initializes an instance of a `ENSideMenu` object.
     
     :param: sourceView         The parent view of the side menu view.
     :param: menuViewController A menu view controller object which will be placed in the side menu view.
     :param: menuPosition       The position of the side menu view.
     
     :returns: An initialized `ENSideMenu` object, added to the specified view, containing the specified menu view controller.
     */
    public convenience init(sourceView: UIView, menuViewController: UIViewController, menuPosition: ENSideMenuPosition) {
        self.init(sourceView: sourceView, menuPosition: menuPosition)
        self.menuViewController = menuViewController
        self.menuViewController.view.frame = sideMenuContainerView.bounds
        self.menuViewController.view.autoresizingMask =  [.flexibleHeight, .flexibleWidth]
        sideMenuContainerView.addSubview(self.menuViewController.view)
    }
    /*
     public convenience init(sourceView: UIView, view: UIView, menuPosition: ENSideMenuPosition) {
     self.init(sourceView: sourceView, menuPosition: menuPosition)
     view.frame = sideMenuContainerView.bounds
     view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
     sideMenuContainerView.addSubview(view)
     }
     */
    /**
     Updates the frame of the side menu view.
     */
    func updateFrame() {
        var width:CGFloat
        var height:CGFloat
        (width, height) = adjustFrameDimensions( width: sourceView.frame.size.width, height: sourceView.frame.size.height)
        let menuFrame = CGRect(x:
            (menuPosition == .Left) ?
                isMenuOpen ? 0 : -menuWidth-1.0 :
                isMenuOpen ? width - menuWidth : width+1.0,
                               y: sourceView.frame.origin.y,
                               width: menuWidth,
                               height: height
        )
        sideMenuContainerView.frame = menuFrame
    }
    
    private func adjustFrameDimensions( width: CGFloat, height: CGFloat ) -> (CGFloat,CGFloat) {
        if floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1 &&
            (UIApplication.shared.statusBarOrientation == UIInterfaceOrientation.landscapeRight ||
                UIApplication.shared.statusBarOrientation == UIInterfaceOrientation.landscapeLeft) {
            // iOS 7.1 or lower and landscape mode -> interchange width and height
            return (height, width)
        }
        else {
            return (width, height)
        }
        
    }
    
    private func setupMenuView() {
        
        // Configure side menu container
        updateFrame()
        
        sideMenuContainerView.backgroundColor = UIColor.clear
        sideMenuContainerView.clipsToBounds = false
        sideMenuContainerView.layer.masksToBounds = false
        sideMenuContainerView.layer.shadowOffset = (menuPosition == .Left) ? CGSize(width: 1.0, height: 1.0) : CGSize(width: -1.0, height: -1.0)
        sideMenuContainerView.layer.shadowRadius = 1.0
        sideMenuContainerView.layer.shadowOpacity = 0.125
        sideMenuContainerView.layer.shadowPath = UIBezierPath(rect: sideMenuContainerView.bounds).cgPath
        
        sourceView.addSubview(sideMenuContainerView)
        
        if (NSClassFromString("UIVisualEffectView") != nil) {
            // Add blur view
            let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light)) as UIVisualEffectView
            visualEffectView.frame = sideMenuContainerView.bounds
            visualEffectView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            sideMenuContainerView.addSubview(visualEffectView)
        }
        else {
            // TODO: add blur for ios 7
        }
    }
    
    private func toggleMenu (shouldOpen: Bool) {
        if (shouldOpen && delegate?.sideMenuShouldOpenSideMenu?() == false) {
            return
        }
        updateSideMenuApperanceIfNeeded()
        isMenuOpen = shouldOpen
        var width:CGFloat
        var height:CGFloat
        (width, height) = adjustFrameDimensions( width: sourceView.frame.size.width, height: sourceView.frame.size.height)
        if (bouncingEnabled) {
            
            animator.removeAllBehaviors()
            
            var gravityDirectionX: CGFloat
            var pushMagnitude: CGFloat
            var boundaryPointX: CGFloat
            var boundaryPointY: CGFloat
            
            if (menuPosition == .Left) {
                // Left side menu
                gravityDirectionX = (shouldOpen) ? 1 : -1
                pushMagnitude = (shouldOpen) ? 20 : -20
                boundaryPointX = (shouldOpen) ? menuWidth : -menuWidth-2
                boundaryPointY = 20
            }
            else {
                // Right side menu
                gravityDirectionX = (shouldOpen) ? -1 : 1
                pushMagnitude = (shouldOpen) ? -20 : 20
                boundaryPointX = (shouldOpen) ? width-menuWidth : width+menuWidth+2
                boundaryPointY =  -20
            }
            
            let gravityBehavior = UIGravityBehavior(items: [sideMenuContainerView])
            gravityBehavior.gravityDirection = CGVector(dx: gravityDirectionX,  dy: 0)
            animator.addBehavior(gravityBehavior)
            
            let collisionBehavior = UICollisionBehavior(items: [sideMenuContainerView])
            collisionBehavior.addBoundary(withIdentifier: "menuBoundary" as NSCopying, from: CGPoint(x: boundaryPointX, y: boundaryPointY),
                                          to: CGPoint(x: boundaryPointX, y: height))
            animator.addBehavior(collisionBehavior)
            
            let pushBehavior = UIPushBehavior(items: [sideMenuContainerView], mode: UIPushBehaviorMode.instantaneous)
            pushBehavior.magnitude = pushMagnitude
            animator.addBehavior(pushBehavior)
            
            let menuViewBehavior = UIDynamicItemBehavior(items: [sideMenuContainerView])
            menuViewBehavior.elasticity = 0.25
            animator.addBehavior(menuViewBehavior)
            
        }
        else {
            var destFrame :CGRect
            if (menuPosition == .Left) {
                destFrame = CGRect(x: (shouldOpen) ? -2.0 : -menuWidth, y: 0, width: menuWidth, height: height)
            }
            else {
                destFrame = CGRect(x: (shouldOpen) ? width-menuWidth : width+2.0,
                                   y:0,
                                   width: menuWidth,
                                   height: height)
            }
            
            UIView.animate(
                withDuration: animationDuration,
                animations: { () -> Void in
                    self.sideMenuContainerView.frame = destFrame
            },
                completion: { (Bool) -> Void in
                    if (self.isMenuOpen) {
                        self.delegate?.sideMenuDidOpen?()
                    } else {
                        self.delegate?.sideMenuDidClose?()
                    }
            })
        }
        
        if (shouldOpen) {
            delegate?.sideMenuWillOpen?()
        } else {
            delegate?.sideMenuWillClose?()
        }
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UISwipeGestureRecognizer {
            let swipeGestureRecognizer = gestureRecognizer as! UISwipeGestureRecognizer
            if !self.allowLeftSwipe {
                if swipeGestureRecognizer.direction == .left {
                    return false
                }
            }
            
            if !self.allowRightSwipe {
                if swipeGestureRecognizer.direction == .right {
                    return false
                }
            }
        }
        return true
    }
    
    @objc internal func handleGesture(gesture: UISwipeGestureRecognizer) {
        toggleMenu(shouldOpen: (self.menuPosition == .Right && gesture.direction == .left)
            || (self.menuPosition == .Left && gesture.direction == .right))
    }
    
    private func updateSideMenuApperanceIfNeeded () {
        if (needUpdateApperance) {
            var frame = sideMenuContainerView.frame
            frame.size.width = menuWidth
            sideMenuContainerView.frame = frame
            sideMenuContainerView.layer.shadowPath = UIBezierPath(rect: sideMenuContainerView.bounds).cgPath
            
            needUpdateApperance = false
        }
    }
    
    /**
     Toggles the state of the side menu.
     */
    public func toggleMenu () {
        if (isMenuOpen) {
            toggleMenu(shouldOpen: false)
        }
        else {
            updateSideMenuApperanceIfNeeded()
            toggleMenu(shouldOpen: true)
        }
    }
    /**
     Shows the side menu if the menu is hidden.
     */
    public func showSideMenu () {
        if (!isMenuOpen) {
            toggleMenu(shouldOpen: true)
        }
    }
    /**
     Hides the side menu if the menu is showed.
     */
    public func hideSideMenu () {
        if (isMenuOpen) {
            toggleMenu(shouldOpen: false)
        }
    }
}

extension ENSideMenu: UIDynamicAnimatorDelegate {
    public func dynamicAnimatorDidPause(_ animator: UIDynamicAnimator) {
        if (self.isMenuOpen) {
            self.delegate?.sideMenuDidOpen?()
        } else {
            self.delegate?.sideMenuDidClose?()
        }
    }
    
    public func dynamicAnimatorWillResume(_ animator: UIDynamicAnimator) {
        print("resume")
    }
}


