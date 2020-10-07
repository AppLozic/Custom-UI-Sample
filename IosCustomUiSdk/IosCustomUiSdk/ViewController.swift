//
//  ViewController.swift
//  IosCustomUiSdk
//
//  Created by apple on 27/09/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Applozic
import UIKit

class ViewController: UIViewController {
    override func viewDidAppear(_: Bool) {
        //        registerAndLaunch()
    }

    override func viewDidLoad() {}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func logoutAction(_: UIButton) {
        let registerUserClientService = ALRegisterUserClientService()
        registerUserClientService.logout { _, _ in
        }
        dismiss(animated: false, completion: nil)
    }

    @IBAction func launchChatList(_: Any) {
        let conversationVC = ConversationListViewController()
        let nav = ALKBaseNavigationViewController(rootViewController: conversationVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: false, completion: nil)
    }
}
