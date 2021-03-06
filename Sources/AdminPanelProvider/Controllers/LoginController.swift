import AuthProvider
import Cookies
import SMTP
import Vapor

public typealias LoginController = CustomUserLoginController<AdminPanelUser>

public final class CustomUserLoginController<U: AdminPanelUserType> {
    public let renderer: ViewRenderer
    public let mailer: MailProtocol?
    public let panelConfig: PanelConfig

    public init(
        renderer: ViewRenderer,
        mailer: MailProtocol?,
        panelConfig: PanelConfig
    ) {
        self.renderer = renderer
        self.mailer = mailer
        self.panelConfig = panelConfig
    }

    public func login(req: Request) throws -> ResponseRepresentable {
        do {
            guard
                let username = req.data["email"]?.string,
                let password = req.data["password"]?.string
            else {
                return redirect("/admin/login").flash(.error, "Invalid username and/or password")
            }

            let credentials = Password(username: username, password: password)
            let user = try U.authenticate(credentials)
            try req.auth.authenticate(user, persist: true)

            var redir = "/admin/dashboard"
            if let next = req.query?["next"]?.string, !next.isEmpty {
                redir = next
            }

            return redirect(redir).flash(.success, "Logged in as \(username)")
        } catch {
            return redirect("/admin/login").flash(.error, "Invalid username and/or password")
        }
    }

    public func landing(req: Request) throws -> ResponseRepresentable {
        guard !req.auth.isAuthenticated(U.self) else {
            return redirect("/admin/dashboard")
        }

        let next = req.query?["next"]

        return try renderer.make(
            "AdminPanel/Login/index",
            [
                "collapse": "true",
                "next": next
            ],
            for: req
        )
    }

    public func resetPassword(req: Request) throws -> ResponseRepresentable {
        return try renderer.make("AdminPanel/Login/reset", for: req)
    }

    public func resetPasswordSubmit(req: Request) throws -> ResponseRepresentable {
        do {
            guard
                let email = req.data["email"]?.string,
                let user = try U.makeQuery().filter(U.emailKey, email).first()
            else {
                return redirect("/admin/login")
                    .flash(.success, "E-mail with instructions sent if user exists")
            }

            try AdminPanelUserResetToken.makeQuery().filter("email", email).delete()

            let randomString = String.random(64)
            let token = AdminPanelUserResetToken(
                email: email,
                token: randomString,
                expireAt: Date().addingTimeInterval(60*60)
            )
            try token.save()
            if let fromEmail = panelConfig.fromEmail {
                mailer?.sendEmail(
                    from: EmailAddress(name: panelConfig.fromName, address: fromEmail),
                    to: user,
                    subject: "Reset password",
                    path: "AdminPanel/Emails/reset-password",
                    renderer: renderer,
                    context: [
                        "name": .string(panelConfig.panelName),
                        "user": try user.makeViewData(),
                        "url": .string(panelConfig.baseUrl),
                        "token": .string(token.token),
                        "expire": 60
                    ]
                )
            }

            return redirect("/admin/login")
                .flash(.success, "E-mail with instructions sent if user exists")
        } catch {
            return redirect("/admin/login/reset").flash(.error, "An error occured")
        }
    }

    public func resetPasswordToken(req: Request) throws -> ResponseRepresentable {
        let tokenParam = try req.parameters.next(String.self)

        guard
            let token = try AdminPanelUserResetToken
                .makeQuery()
                .filter("token", tokenParam)
                .first(),
            token.canBeUsed
        else {
            return redirect("/admin/login").flash(.error, "Token does not exist")
        }

        return try renderer.make("AdminPanel/ResetPassword/form", ["token": token.token], for: req)
    }

    public func resetPasswordTokenSubmit(req: Request) throws -> ResponseRepresentable {
        guard
            let tokenParam = req.data["token"]?.string,
            let email = req.data["email"]?.string,
            let password = req.data["password"]?.string,
            let passwordRepeat = req.data["passwordRepeat"]?.string
        else {
            return redirect("/admin/login").flash(.error, "Invalid request")
        }

        guard
            let token = try AdminPanelUserResetToken
                .makeQuery()
                .filter("token", tokenParam)
                .first(),
            token.canBeUsed
        else {
            return redirect("/admin/login").flash(.error, "Token does not exist")
        }

        if token.email != email {
            return redirect("/admin/login").flash(.error, "Token is not valid for given email")
        }

        if password != passwordRepeat {
            return redirect("/admin/login/reset/" + tokenParam)
                .flash(.error, "Passwords do not match")
        }

        guard let user = try U.makeQuery().filter(U.emailKey, email).first() else {
            return redirect("/admin/login").flash(.error, "User not found")
        }

        let hashedPassword = try U.hashPassword(password)
        user.password = hashedPassword
        try user.save()
        try token.use()
        return redirect("/admin/login").flash(.success, "Password reset")
    }

    public func dashboard(req: Request) throws -> ResponseRepresentable {
        let ordersData: [Node] = [
            Node([
                "id": "OR9842",
                "title": "Call of Duty IV",
                "status": Node(["value": "Shipped", "type": "success"])
            ]),
            Node([
                "id": "OR9842",
                "title": "Call of Duty IV",
                "status": Node(["value": "Shipped", "type": "success"])
            ]),
            Node([
                "id": "OR1848",
                "title": "Samsung Smart TV",
                "status": Node(["value": "Pending", "type": "warning"])
            ]),
            Node([
                "id": "OR9842",
                "title": "Call of Duty IV",
                "status": Node(["value": "Cancelled", "type": "danger"])
            ]),
            Node([
                "id": "OR9842",
                "title": "Call of Duty IV",
                "status": Node(["value": "Shipped", "type": "success"])
            ])
        ]

        let orders = Node(ordersData)
        return try renderer.make("AdminPanel/Dashboard/index", ["orders": orders], for: req)
    }
}
