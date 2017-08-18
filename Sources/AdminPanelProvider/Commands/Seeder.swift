import Vapor
import Console

public final class Seeder: Command, ConfigInitializable {
    public let id = "admin-panel:seeder"

    public let help: [String] = [
        "Seeds the default user for the admin panel"
    ]

    public let console: ConsoleProtocol

    public init(config: Config) throws {
        self.console = try config.resolveConsole()
    }

    public func run(arguments: [String]) throws {
        console.info("Started the seeder")

        let user = try BackendUser(
            name: "Admin",
            title: "Default admin account",
            email: "admin@admin.com",
            password: "admin",
            role: "Super Admin",
            shouldResetPassword: false,
            avatar: nil
        )

        try user.save()

        console.info("Finished the seeder");
    }
}
