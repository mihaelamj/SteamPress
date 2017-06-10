import XCTest
@testable import Vapor
@testable import SteamPress
import HTTP
import FluentProvider
import Sessions
import Cookies

class BlogAdminControllerTests: XCTestCase {
    static var allTests = [
        ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
        ("testLogin", testLogin),
        ("testCannotAccessAdminPageWithoutBeingLoggedIn", testCannotAccessAdminPageWithoutBeingLoggedIn),
        ("testCannotAccessCreateBlogPostPageWithoutBeingLoggedIn", testCannotAccessCreateBlogPostPageWithoutBeingLoggedIn),
        ("testCannotSendCreateBlogPostPageWithoutBeingLoggedIn", testCannotSendCreateBlogPostPageWithoutBeingLoggedIn),
        ("testCannotAccessEditPostPageWithoutLogin", testCannotAccessEditPostPageWithoutLogin),
        ("testCannotSendEditPostPageWithoutLogin", testCannotSendEditPostPageWithoutLogin),
        ("testCannotAccessCreateUserPageWithoutLogin", testCannotAccessCreateUserPageWithoutLogin),
        ("testCannotSendCreateUserPageWithoutLogin", testCannotSendCreateUserPageWithoutLogin),
        ("testCannotAccessProfilePageWithoutLogin", testCannotAccessProfilePageWithoutLogin),
        ("testCannotAccessEditUserPageWithoutLogin", testCannotAccessEditUserPageWithoutLogin),
        ("testCannotSendEditUserPageWithoutLogin", testCannotSendEditUserPageWithoutLogin),
        ("testCannotDeletePostWithoutLogin", testCannotDeletePostWithoutLogin),
        ("testCannotDeleteUserWithoutLogin", testCannotDeleteUserWithoutLogin),
        ("testCannotAccessResetPasswordPageWithoutLogin", testCannotAccessResetPasswordPageWithoutLogin),
        ("testCannotSendResetPasswordPageWithoutLogin", testCannotSendResetPasswordPageWithoutLogin),
        ("testCanAccessAdminPageWhenLoggedIn", testCanAccessAdminPageWhenLoggedIn),
        ("testCanAccessCreatePostPageWhenLoggedIn", testCanAccessCreatePostPageWhenLoggedIn),
        ("testCanAccessEditPostPageWhenLoggedIn", testCanAccessEditPostPageWhenLoggedIn),
        ("testCanAccessCreateUserPageWhenLoggedIn", testCanAccessCreateUserPageWhenLoggedIn),
        ("testCanAccessEditUserPageWhenLoggedIn", testCanAccessEditUserPageWhenLoggedIn),
        ("testCanAccessProfilePageWhenLoggedIn", testCanAccessProfilePageWhenLoggedIn),
        ("testCanAccessResetPasswordPage", testCanAccessResetPasswordPage),
        ("testCanDeleteBlogPost", testCanDeleteBlogPost),
        ("testCanDeleteUser", testCanDeleteUser),
        ("testCannotDeleteSelf", testCannotDeleteSelf),
        ("testCannotDeleteLastUser", testCannotDeleteLastUser),
        ("testUserCannotResetPasswordWithMismatchingPasswords", testUserCannotResetPasswordWithMismatchingPasswords),
        ("testUserCannotResetPasswordWithBasicPassword", testUserCannotResetPasswordWithBasicPassword),
        ("testUserCanResetPassword", testUserCanResetPassword),
        ("testUserCannotResetPasswordWithoutPassword", testUserCannotResetPasswordWithoutPassword),
        ("testUserCannotResetPasswordWithoutConfirmPassword", testUserCannotResetPasswordWithoutConfirmPassword),
        ("testUserCannotResetPasswordWithShortPassword", testUserCannotResetPasswordWithShortPassword),
        ("testUserIsRedirectedWhenLoggingInAndPasswordResetRequired", testUserIsRedirectedWhenLoggingInAndPasswordResetRequired),
        ("testPostCanBeCreated", testPostCanBeCreated),
        ("testPostCannotBeCreatedIfDraftAndPublishNotSet", testPostCannotBeCreatedIfDraftAndPublishNotSet),
        ("testCreatePostMustIncludeTitle", testCreatePostMustIncludeTitle),
        ("testCreatePostMustIncludeContents", testCreatePostMustIncludeContents),
        ("testCreatePostWithDraftDoesNotPublishPost", testCreatePostWithDraftDoesNotPublishPost),
        ("testUserCanBeCreatedSuccessfully", testUserCanBeCreatedSuccessfully),
        ("testUserMustResetPasswordIfSetToWhenCreatingUser", testUserMustResetPasswordIfSetToWhenCreatingUser),
        ("testUserCannotBeCreatedWithoutName", testUserCannotBeCreatedWithoutName),
        ("testUserCannotBeCreatedWithoutUsername", testUserCannotBeCreatedWithoutUsername),
        ("testUserCannotBeCreatedWithoutPassword", testUserCannotBeCreatedWithoutPassword),
        ("testUserCannotBeCreatedWithoutSpecifyingAConfirmPassword", testUserCannotBeCreatedWithoutSpecifyingAConfirmPassword),
        ("testUserCannotBeCreatedWithPasswordsThatDontMatch", testUserCannotBeCreatedWithPasswordsThatDontMatch),
        ("testUserCannotBeCreatedWithSimplePassword", testUserCannotBeCreatedWithSimplePassword),
        ("testUserCannotBeCreatedWithEmptyName", testUserCannotBeCreatedWithEmptyName),
        ("testUserCannotBeCreatedWithEmptyUsername", testUserCannotBeCreatedWithEmptyUsername),
        ("testUserCannotBeCreatedWithInvalidName", testUserCannotBeCreatedWithInvalidName),
        ("testUserCannotBeCreatedWithInvalidUsername", testUserCannotBeCreatedWithInvalidUsername),
        ("testPostCanBeUpdated", testPostCanBeUpdated),
        ("testUserCanBeUpdated", testUserCanBeUpdated),
    ]
    
    // MARK: - Properties
    
    var database: Database!
    var drop: Droplet!
    var capturingViewFactory: CapturingViewFactory!
    
    // MARK: - Overrides
    
    override func setUp() {
        database = Database(try! MemoryDriver(()))
        try! Droplet.prepare(database: database)
        var config = try! Config()
        config.addConfigurable(middleware: { (_) -> (SessionsMiddleware) in
            let sessions = SessionsMiddleware(try! config.resolveSessions(), cookieName: "steampress-session")
            return sessions
        }, name: "steampress-sessions")
        try! config.set("droplet.middleware", ["error", "steampress-sessions"])
        
        drop = try! Droplet(config)
        capturingViewFactory = CapturingViewFactory()
        let adminController = BlogAdminController(drop: drop, pathCreator: BlogPathCreator(blogPath: "blog"), viewFactory: capturingViewFactory)
        adminController.addRoutes()
    }
    
    override func tearDown() {
        try! Droplet.teardown(database: database)
    }
    
    // Courtesy of https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite().testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }
    
    // MARK: - Tests
    
    // MARK: - Login Integration Test
    
    func testLogin() throws {
        let hashedPassword = try BlogUser.passwordHasher.make("password")
        let newUser = TestDataBuilder.anyUser()
        newUser.password = hashedPassword
        try newUser.save()
        
        let loginJson = JSON(try Node(node: [
                "inputUsername": newUser.username,
                "inputPassword": "password"
            ]))
        let loginRequest = Request(method: .post, uri: "/blog/admin/login/")
        loginRequest.json = loginJson
        let response = try drop.respond(to: loginRequest)
        
        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(response.headers[HeaderKey.location], "/blog/admin/")
    }
    
    // MARK: - Access restriction tests
    
    func testCannotAccessAdminPageWithoutBeingLoggedIn() throws {
        try assertLoginRequired(method: .get, path: "")
    }
    
    func testCannotAccessCreateBlogPostPageWithoutBeingLoggedIn() throws {
        try assertLoginRequired(method: .get, path: "createPost")
    }
    
    func testCannotSendCreateBlogPostPageWithoutBeingLoggedIn() throws {
        try assertLoginRequired(method: .post, path: "createPost")
    }
    
    func testCannotAccessEditPostPageWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "posts/2/edit")
    }
    
    func testCannotSendEditPostPageWithoutLogin() throws {
        try assertLoginRequired(method: .post, path: "posts/2/edit")
    }
    
    func testCannotAccessCreateUserPageWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "createUser")
    }
    
    func testCannotSendCreateUserPageWithoutLogin() throws {
        try assertLoginRequired(method: .post, path: "createUser")
    }
    
    func testCannotAccessProfilePageWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "profile")
    }
    
    func testCannotAccessEditUserPageWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "users/1/edit")
    }
    
    func testCannotSendEditUserPageWithoutLogin() throws {
        try assertLoginRequired(method: .post, path: "users/1/edit")
    }
    
    func testCannotDeletePostWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "posts/1/delete")
    }
    
    func testCannotDeleteUserWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "users/1/delete")
    }
    
    func testCannotAccessResetPasswordPageWithoutLogin() throws {
        try assertLoginRequired(method: .get, path: "resetPassword")
    }

    func testCannotSendResetPasswordPageWithoutLogin() throws {
        try assertLoginRequired(method: .post, path: "resetPassword")
    }
    
    // MARK: - Access Success Tests
    
    func testCanAccessAdminPageWhenLoggedIn() throws {
        let request = try createLoggedInRequest(method: .get, path: "")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    func testCanAccessCreatePostPageWhenLoggedIn() throws {
        let request = try createLoggedInRequest(method: .get, path: "createPost")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    func testCanAccessEditPostPageWhenLoggedIn() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        let post = TestDataBuilder.anyPost(author: user)
        try post.save()
        let request = try createLoggedInRequest(method: .get, path: "posts/\(post.id!.string!)/edit", for: user)
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    func testCanAccessCreateUserPageWhenLoggedIn() throws {
        let request = try createLoggedInRequest(method: .get, path: "createUser")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    func testCanAccessEditUserPageWhenLoggedIn() throws {
        let userToEdit = TestDataBuilder.anyUser(name: "Leia", username: "leia")
        try userToEdit.save()
        let request = try createLoggedInRequest(method: .get, path: "users/\(userToEdit.id!.string!)/edit")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    func testCanAccessProfilePageWhenLoggedIn() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        let request = try createLoggedInRequest(method: .get, path: "profile", for: user)
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    func testCanAccessResetPasswordPage() throws {
        let request = try createLoggedInRequest(method: .get, path: "resetPassword")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .ok)
    }
    
    // MARK: - Delete tests
    
    func testCanDeleteBlogPost() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        let post = TestDataBuilder.anyPost(author: user)
        try post.save()
        
        let request = try createLoggedInRequest(method: .get, path: "posts/\(post.id!.string!)/delete", for: user)
        
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(try BlogPost.count(), 0)
    }
    
    func testCanDeleteUser() throws {
        let user2 = TestDataBuilder.anyUser(name: "Han", username: "han")
        try user2.save()
        
        let request = try createLoggedInRequest(method: .get, path: "users/\(user2.id!.string!)/delete")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(try BlogUser.count(), 1)
        XCTAssertNotEqual(try BlogUser.all().first?.name, "Han")
    }
    
    func testCannotDeleteSelf() throws {
        let adminUser = TestDataBuilder.anyUser(name: "admin", username: "admin")
        try adminUser.save()
        let user = TestDataBuilder.anyUser(name: "Han", username: "han")
        try user.save()
        
        let request = try createLoggedInRequest(method: .get, path: "users/\(user.id!.string!)/delete", for: user)
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.adminViewErrors?.contains("You cannot delete yourself whilst logged in") ?? false)
    }
    
    func testCannotDeleteLastUser() throws {
        let user = TestDataBuilder.anyUser(name: "Han", username: "han")
        try user.save()
        
        let request = try createLoggedInRequest(method: .get, path: "users/\(user.id!.string!)/delete", for: user)
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.adminViewErrors?.contains("You cannot delete the last user") ?? false)
    }
    
    // MARK: - Reset Password tests
    
    func testUserCannotResetPasswordWithMismatchingPasswords() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        
        let request = try createLoggedInRequest(method: .post, path: "resetPassword", for: user)
        let resetPasswordData = try Node(node: [
            "inputPassword": "Th3S@m3password",
            "inputConfirmPassword": "An0th3rPass!"
            ])
        request.formURLEncoded = resetPasswordData
        
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.resetPasswordErrors?.contains("Your passwords must match!") ?? false)
    }
    
    func testUserCannotResetPasswordWithBasicPassword() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        
        let request = try createLoggedInRequest(method: .post, path: "resetPassword", for: user)
        let resetPasswordData = try Node(node: [
            "inputPassword": "simplepassword",
            "inputConfirmPassword": "simplepassword"
            ])
        request.formURLEncoded = resetPasswordData
        
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.resetPasswordErrors?.contains("Your password must contain a lowercase letter, an upperacase letter, a number and a symbol") ?? false)
    }
    
    func testUserCanResetPassword() throws {
        BlogUser.passwordHasher = FakePasswordHasher()
        let user = TestDataBuilder.anyUser()
        try user.save()
        let newPassword = "Th3S@m3password"
        
        let request = try createLoggedInRequest(method: .post, path: "resetPassword", for: user)
        let resetPasswordData = try Node(node: [
            "inputPassword": newPassword,
            "inputConfirmPassword": newPassword
            ])
        request.formURLEncoded = resetPasswordData
        
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(user.password, newPassword.makeBytes())
        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(response.headers[HeaderKey.location], "/blog/admin/")
    }
    
    func testUserCannotResetPasswordWithoutPassword() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        
        let request = try createLoggedInRequest(method: .post, path: "resetPassword", for: user)
        let resetPasswordData = try Node(node: [
            "inputConfirmPassword": "Th3S@m3password",
            ])
        request.formURLEncoded = resetPasswordData
        
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.resetPasswordErrors?.contains("You must specify a password") ?? false)
    }
    
    func testUserCannotResetPasswordWithoutConfirmPassword() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        
        let request = try createLoggedInRequest(method: .post, path: "resetPassword", for: user)
        let resetPasswordData = try Node(node: [
            "inputPassword": "Th3S@m3password",
            ])
        request.formURLEncoded = resetPasswordData
        
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.resetPasswordErrors?.contains("You must confirm your password") ?? false)
    }
    
    func testUserCannotResetPasswordWithShortPassword() throws {
        let user = TestDataBuilder.anyUser()
        try user.save()
        
        let request = try createLoggedInRequest(method: .post, path: "resetPassword", for: user)
        let resetPasswordData = try Node(node: [
            "inputPassword": "S12$",
            "inputConfirmPassword": "S12$"
            ])
        request.formURLEncoded = resetPasswordData
        
        _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.resetPasswordErrors?.contains("Your password must contain a lowercase letter, an upperacase letter, a number and a symbol") ?? false)
    }
    
    func testUserIsRedirectedWhenLoggingInAndPasswordResetRequired() throws {
        let user = TestDataBuilder.anyUser()
        user.resetPasswordRequired = true
        try user.save()
        
        let request = try createLoggedInRequest(method: .get, path: "", for: user)
        
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(response.headers[HeaderKey.location], "/blog/admin/resetPassword/")
    }
    
    // MARK: - Create Post Tests
    
    func testPostCanBeCreated() throws {
        let request = try createLoggedInRequest(method: .post, path: "createPost")
        let postTitle = "Post Title"
        var postData = Node([:], in: nil)
        try postData.set("inputTitle", postTitle)
        try postData.set("inputPostContents", "# Post Title\n\nWe have a post")
        try postData.set("inputTags", ["First Tag", "Second Tag"])
        try postData.set("inputSlugUrl", "post-title")
        try postData.set("publish", "true")
        request.formURLEncoded = postData
        
        let _  = try drop.respond(to: request)
        
        XCTAssertEqual(try BlogPost.count(), 1)
        XCTAssertEqual(try BlogPost.all().first?.title, postTitle)
        XCTAssertTrue(try BlogPost.all().first?.published ?? false)
    }
    
    func testPostCannotBeCreatedIfDraftAndPublishNotSet() throws {
        let request = try createLoggedInRequest(method: .post, path: "createPost")
        var postData = Node([:], in: nil)
        try postData.set("inputTitle", "Post Title")
        try postData.set("inputPostContents", "# Post Title\n\nWe have a post")
        try postData.set("inputTags", ["First Tag", "Second Tag"])
        try postData.set("inputSlugUrl", "post-title")
        request.formURLEncoded = postData
        
        let response  = try drop.respond(to: request)
        
        XCTAssertEqual(response.status.statusCode, 400)
    }
    
    func testCreatePostMustIncludeTitle() throws {
        let request = try createLoggedInRequest(method: .post, path: "createPost")
        var postData = Node([:], in: nil)
        try postData.set("inputPostContents", "# Post Title\n\nWe have a post")
        try postData.set("inputTags", ["First Tag", "Second Tag"])
        try postData.set("inputSlugUrl", "post-title")
        try postData.set("publish", "true")
        request.formURLEncoded = postData
        
        let _  = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createPostErrors?.contains("You must specify a blog post title") ?? false)
    }
    
    func testCreatePostMustIncludeContents() throws {
        let request = try createLoggedInRequest(method: .post, path: "createPost")
        var postData = Node([:], in: nil)
        try postData.set("inputTitle", "post-title")
        try postData.set("inputTags", ["First Tag", "Second Tag"])
        try postData.set("inputSlugUrl", "post-title")
        try postData.set("publish", "true")
        request.formURLEncoded = postData
        
        let _  = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createPostErrors?.contains("You must have some content in your blog post") ?? false)
    }
    
    func testCreatePostWithDraftDoesNotPublishPost() throws {
        let request = try createLoggedInRequest(method: .post, path: "createPost")
        let postTitle = "Post Title"
        var postData = Node([:], in: nil)
        try postData.set("inputTitle", postTitle)
        try postData.set("inputPostContents", "# Post Title\n\nWe have a post")
        try postData.set("inputTags", ["First Tag", "Second Tag"])
        try postData.set("inputSlugUrl", "post-title")
        try postData.set("save-draft", "true")
        request.formURLEncoded = postData
        
        let _  = try drop.respond(to: request)
        
        XCTAssertEqual(try BlogPost.count(), 1)
        XCTAssertEqual(try BlogPost.all().first?.title, postTitle)
        XCTAssertFalse(try BlogPost.all().first?.published ?? true)
    }
    
    // MARK: - Create User Tests
    
    func testUserCanBeCreatedSuccessfully() throws {
        BlogUser.passwordHasher = FakePasswordHasher()
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let newName = "Leia"
        let newUsername = "leia"
        let password = "AS3cretPassword"
        let profilePicture = "https://static.brokenhands.io/images/cat.png"
        let tagline = "The awesome tagline"
        let biography = "The biograhy"
        let twitterHandle = "brokenhandsio"
        var userData = Node([:], in: nil)
        try userData.set("inputName", newName)
        try userData.set("inputUsername", newUsername)
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputProfilePicture", profilePicture)
        try userData.set("inputTagline", tagline)
        try userData.set("inputBiography", biography)
        try userData.set("inputTwitterHandle", twitterHandle)
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        // We create the first user when setting up the logged in request
        XCTAssertEqual(try BlogUser.count(), 2)
        let user = try BlogUser.makeQuery().filter("name", newName).all().first
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.username, newUsername)
        XCTAssertEqual(user?.profilePicture, profilePicture)
        XCTAssertEqual(user?.tagline, tagline)
        XCTAssertEqual(user?.biography, biography)
        XCTAssertEqual(user?.twitterHandle, twitterHandle)
    }
    
    func testUserMustResetPasswordIfSetToWhenCreatingUser() throws {
        BlogUser.passwordHasher = FakePasswordHasher()
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let newName = "Leia"
        let password = "AS3cretPassword"
        var userData = Node([:], in: nil)
        try userData.set("inputName", newName)
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(try BlogUser.makeQuery().filter("name", newName).all().first?.resetPasswordRequired ?? false)
    }
    
    func testUserCannotBeCreatedWithoutName() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AS3cretPassword"
        var userData = Node([:], in: nil)
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("You must specify a name") ?? false)
    }
    
    func testUserCannotBeCreatedWithoutUsername() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AS3cretPassword"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("You must specify a username") ?? false)
    }
    
    func testUserCannotBeCreatedWithoutPassword() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AS3cretPassword"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputUsername", "leia")
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("You must specify a password") ?? false)
    }
    
    func testUserCannotBeCreatedWithoutSpecifyingAConfirmPassword() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AS3cretPassword"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("You must confirm your password") ?? false)
    }
    
    func testUserCannotBeCreatedWithPasswordsThatDontMatch() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AS3cretPassword"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", "Som£th!ngDifferent")
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("Your passwords must match!") ?? false)
    }
    
    func testUserCannotBeCreatedWithSimplePassword() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "simple"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("Your password must contain a lowercase letter, an upperacase letter, a number and a symbol") ?? false)
    }
    
    func testUserCannotBeCreatedWithEmptyName() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AComl3xPass!"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "")
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("You must specify a name") ?? false)
    }
    
    func testUserCannotBeCreatedWithEmptyUsername() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AComl3xPass!"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputUsername", "")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("You must specify a username") ?? false)
    }
    
    func testUserCannotBeCreatedWithInvalidName() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AComl3xPass!"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "An invalid Name!3")
        try userData.set("inputUsername", "leia")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("The name provided is not valid") ?? false)
    }
    
    func testUserCannotBeCreatedWithInvalidUsername() throws {
        let request = try createLoggedInRequest(method: .post, path: "createUser")
        let password = "AComl3xPass!"
        var userData = Node([:], in: nil)
        try userData.set("inputName", "Leia")
        try userData.set("inputUsername", "LEIA!")
        try userData.set("inputPassword", password)
        try userData.set("inputConfirmPassword", password)
        try userData.set("inputResetPasswordOnLogin", "true")
        request.formURLEncoded = userData
        
        let _ = try drop.respond(to: request)
        
        XCTAssertTrue(capturingViewFactory.createUserErrors?.contains("The username provided is not valid") ?? false)
    }
    
    // MARK: - Edit Post Tests
    
    func testPostCanBeUpdated() throws {
        let author = TestDataBuilder.anyUser()
        try author.save()
        
        let post = TestDataBuilder.anyPost(author: author, title: "Initial title", contents: "Some initial contents", slugUrl: "initial-title")
        try post.save()
        
        let request = try createLoggedInRequest(method: .post, path: "posts/\(post.id!.string!)/edit", for: author)
        let newTitle = "New Title"
        let newContents = "We have updated the contents"
        let newSlug = "new-title"
        var postData = Node([:], in: nil)
        try postData.set("inputTitle", newTitle)
        try postData.set("inputPostContents", newContents)
        try postData.set("inputSlugUrl", newSlug)
        request.formURLEncoded = postData
        
        let _  = try drop.respond(to: request)
        
        XCTAssertEqual(try BlogPost.count(), 1)
        XCTAssertEqual(try BlogPost.all().first?.title, newTitle)
        XCTAssertEqual(try BlogPost.all().first?.contents, newContents)
        XCTAssertEqual(try BlogPost.all().first?.id, post.id)
    }
    
    // MARK: - Edit User Tests
    
    func testUserCanBeUpdated() throws {
        let author = TestDataBuilder.anyUser(name: "Luke", username: "luke")
        try author.save()
        
        let request = try createLoggedInRequest(method: .post, path: "users/\(author.id!.string!)/edit", for: author)
        let newName = "Darth Vader"
        let newUsername = "darth_vader"
        var userData = Node([:], in: nil)
        try userData.set("inputName", newName)
        try userData.set("inputUsername", newUsername)
        request.formURLEncoded = userData
        
        let _  = try drop.respond(to: request)
        
        XCTAssertEqual(try BlogUser.count(), 1)
        XCTAssertEqual(try BlogUser.all().first?.id, author.id)
        XCTAssertEqual(try BlogUser.all().first?.name, newName)
        XCTAssertEqual(try BlogUser.all().first?.username, newUsername)
    }
    
    // MARK: - Helper functions
    
    private func assertLoginRequired(method: HTTP.Method, path: String) throws {
        let request = Request(method: method, uri: "/blog/admin/\(path)/")
        let response = try drop.respond(to: request)
        
        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(response.headers[HeaderKey.location], "/blog/admin/login/?loginRequired")
    }
    
    private func createLoggedInRequest(method: HTTP.Method, path: String, for user: BlogUser? = nil) throws -> Request {
        let uri = "/blog/admin/\(path)/"
        let request = Request(method: method, uri: uri)
        let cookie = Cookie(name: "steampress-session", value: "dummy-identifier")
        
        let authAuthenticatedKey = "auth-authenticated"
        
        if let user = user {
            request.storage[authAuthenticatedKey] = user
        }
        else {
            let testUser = TestDataBuilder.anyUser()
            try testUser.save()
            request.storage[authAuthenticatedKey] = testUser
        }
        
        
        request.cookies.insert(cookie)
        
        return request
    }
}

struct FakePasswordHasher: PasswordHasherVerifier {
    func verify(password: Bytes, matches hash: Bytes) throws -> Bool {
        return password == hash
    }
    
    func make(_ message: Bytes) throws -> Bytes {
        return message
    }
    
    func check(_ message: Bytes, matchesHash: Bytes) throws -> Bool {
        return message == matchesHash
    }
}
