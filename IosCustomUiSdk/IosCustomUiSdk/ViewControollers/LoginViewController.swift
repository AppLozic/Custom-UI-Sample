import Applozic
import UIKit

class LoginViewController: UIViewController {
    @IBOutlet var userName: UITextField!
    @IBOutlet var password: UITextField!

    @IBOutlet var emailId: UITextField!
    var applozicClient = ApplozicClient()

    override func viewDidLoad() {
        super.viewDidLoad()

        applozicClient = ApplozicClient(applicationKey: "applozic-sample-app") as ApplozicClient // Pass applicationKey here
    }

    @IBAction func getStartedBtn(_: AnyObject) {
        let alUser = ALUser()
        if userName.text as NSString? == nil || (userName.text! as NSString).length == 0 {
            let alert = UIAlertController(title: "Applozic", message: "Please enter userId ", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        alUser.userId = userName.text
        ALUserDefaultsHandler.setUserId(alUser.userId)
        ALUserDefaultsHandler.setUserAuthenticationTypeId(1) // APPLOZIC
        print("userName:: ", alUser.userId as Any)
        if !((emailId.text?.isEmpty)!) {
            alUser.email = emailId.text
            ALUserDefaultsHandler.setEmailId(alUser.email)
        }

        if !((password.text?.isEmpty)!) {
            alUser.password = password.text
            ALUserDefaultsHandler.setPassword(alUser.password)
        }
        registerUserToApplozic(alUser: alUser)
    }

    private func registerUserToApplozic(alUser: ALUser) {
        if ALUserDefaultsHandler.isLoggedIn() {
            applozicClient.logoutUser { error, _ in

                if error == nil {
                    self.login(alUser: alUser)
                }
            }
        } else {
            login(alUser: alUser)
        }
    }

    public func login(alUser: ALUser) {
        applozicClient = ApplozicClient(applicationKey: "applozic-sample-app") as ApplozicClient // Pass
        applozicClient.loginUser(alUser) { _, error in

            if error == nil {
                let conversationVC = ConversationListViewController()
                let nav = ALKBaseNavigationViewController(rootViewController: conversationVC)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true, completion: nil)
            } else {
                NSLog("[REGISTRATION] Applozic user registration error: %@", error.debugDescription)
            }
        }
    }
}
